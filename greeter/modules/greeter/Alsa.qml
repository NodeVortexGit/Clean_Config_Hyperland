pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Volume for the login screen, straight to ALSA.
//
// The session shell drives volume through PipeWire, but the greeter runs as
// `greetd`, which has no session bus and therefore no PipeWire daemon to talk
// to - the shell's own log shows "Failed to connect pipewire context, errno
// 112" every time. amixer talks to the kernel mixer directly, needs nothing
// running, and only requires membership of the audio group.
//
// -M asks amixer for the mapped (perceptual) volume rather than the raw
// register value, which is what a slider should be showing.
Singleton {
    id: root

    property int card: 0
    property string control: "Master"

    // 0..1, matching the shape of the PipeWire service this replaces so the
    // slider binding reads the same.
    property real volume: 0
    property bool muted: false
    property bool available: false

    function setVolume(v: real): void {
        const pct = Math.round(Math.max(0, Math.min(1, v)) * 100);
        // Optimistic: the poll is a second away and the slider must not lag
        // behind the finger dragging it.
        volume = pct / 100;
        Quickshell.execDetached(["amixer", "-c", `${card}`, "-M", "sset", control, `${pct}%`]);
    }

    function toggleMute(): void {
        muted = !muted;
        Quickshell.execDetached(["amixer", "-c", `${card}`, "sset", control, "toggle"]);
    }

    function parse(text: string): void {
        // e.g. "  Front Left: Playback 44 [51%] [on]"
        const pct = text.match(/\[(\d+)%\]/);
        const state = text.match(/\[(on|off)\]/);

        if (!pct) {
            available = false;
            return;
        }

        available = true;
        volume = parseInt(pct[1], 10) / 100;
        // A control with no playback switch reports no [on]/[off] at all; treat
        // that as unmuted rather than as muted-by-default.
        muted = state ? state[1] === "off" : false;
    }

    Process {
        id: readProc

        running: true
        command: ["amixer", "-c", `${root.card}`, "-M", "sget", root.control]

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }

        onExited: code => {
            if (code !== 0)
                root.available = false;
        }
    }

    // Nothing else is going to tell us the volume changed - there is no event
    // source without a sound server - so poll, but slowly. This only has to
    // catch the hardware keys.
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: if (!readProc.running)
            readProc.running = true
    }
}
