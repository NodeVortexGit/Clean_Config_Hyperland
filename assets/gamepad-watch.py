#!/usr/bin/python3
"""
Report real gamepad activity on stdout, one "active" line per second at most.

Wayland compositors only reset the idle timer on keyboard, pointer and touch
input. A gamepad is just another evdev device to them, so playing a game with a
controller looks exactly like sitting still: the screen dims, then locks. This
watches the joystick devices directly and lets the shell inhibit idle while they
are actually being used.

The subtlety is that analog sticks are never still. A resting stick emits a
steady trickle of EV_ABS events from drift, so counting every event would mean
"active" forever and the machine would never idle again. So:

  * EV_KEY (buttons, triggers, d-pad) counts unconditionally - a press is a press
  * EV_ABS (sticks, analog triggers) counts only when the axis moves further than
    DEADZONE from where it was last reported

Devices are found through udev's ID_INPUT_JOYSTICK tagging, exposed as the
*-event-joystick symlinks, and rescanned periodically so hotplug works.
"""

import glob
import os
import select
import struct
import sys
import time

# struct input_event { struct timeval time; __u16 type; __u16 code; __s32 value; }
EVENT_FORMAT = "llHHi"
EVENT_SIZE = struct.calcsize(EVENT_FORMAT)

EV_KEY = 0x01
EV_ABS = 0x03

# Axes are typically +/-32767; sticks at rest wander by a few hundred. This is
# comfortably above the noise and well below a deliberate nudge.
DEADZONE = 3000

RESCAN_INTERVAL = 5.0
REPORT_INTERVAL = 1.0


def find_devices():
    """Event devices udev has tagged as joysticks.

    Deliberately not the /dev/input/by-id/*-event-joystick symlinks: those are a
    USB naming convention, and a Bluetooth controller generally gets no by-id
    entry at all, so it would never be watched. udev records ID_INPUT_JOYSTICK
    for both transports in its own database, keyed by device number - event
    devices are character major 13, and the file is cheap to read, so this needs
    no subprocess and no libudev binding.
    """
    found = []
    for path in glob.glob("/dev/input/event*"):
        try:
            minor = os.minor(os.stat(path).st_rdev)
        except OSError:
            continue
        try:
            with open(f"/run/udev/data/c13:{minor}", "r") as db:
                if "ID_INPUT_JOYSTICK=1" in db.read():
                    found.append(path)
        except OSError:
            continue
    return sorted(found)


def open_devices(paths, already):
    opened = dict(already)
    for path in paths:
        if path in opened:
            continue
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        except OSError:
            continue  # unreadable or vanished between glob and open
        opened[path] = fd
    return opened


def close_missing(opened, paths):
    for path in list(opened):
        if path not in paths:
            try:
                os.close(opened[path])
            except OSError:
                pass
            del opened[path]


def main():
    opened = {}
    axis_state = {}  # (path, code) -> last reported value
    last_scan = 0.0
    last_report = 0.0

    while True:
        now = time.monotonic()

        if now - last_scan >= RESCAN_INTERVAL:
            paths = find_devices()
            close_missing(opened, paths)
            opened = open_devices(paths, opened)
            last_scan = now

        if not opened:
            time.sleep(RESCAN_INTERVAL)
            continue

        fd_to_path = {fd: path for path, fd in opened.items()}
        try:
            ready, _, _ = select.select(list(fd_to_path), [], [], RESCAN_INTERVAL)
        except OSError:
            opened = {}
            continue

        activity = False
        for fd in ready:
            path = fd_to_path[fd]
            try:
                data = os.read(fd, EVENT_SIZE * 64)
            except (OSError, BlockingIOError):
                # Device went away mid-read; the next rescan will drop it.
                continue

            for offset in range(0, len(data) - EVENT_SIZE + 1, EVENT_SIZE):
                _, _, etype, code, value = struct.unpack_from(EVENT_FORMAT, data, offset)

                if etype == EV_KEY:
                    activity = True
                elif etype == EV_ABS:
                    key = (path, code)
                    previous = axis_state.get(key)
                    if previous is None:
                        axis_state[key] = value
                    elif abs(value - previous) >= DEADZONE:
                        axis_state[key] = value
                        activity = True

        if activity:
            now = time.monotonic()
            if now - last_report >= REPORT_INTERVAL:
                sys.stdout.write("active\n")
                sys.stdout.flush()
                last_report = now


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        pass
