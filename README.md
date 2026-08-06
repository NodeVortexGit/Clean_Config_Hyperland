# Clean Config — Hyprland

A personal fork of [caelestia-dots/shell](https://github.com/caelestia-dots/shell),
reworked around a macOS-style **Dynamic Island** and a flat black / dark-blue
theme.

Everything upstream provided is still here — the original documentation is kept
as [README.upstream.md](README.upstream.md). This fork changes how the shell is
presented and adds a few things it didn't have.

## What's different

### Dynamic Island

Replaces the vertical sidebar with a floating top-centre pill.

- **Live states** — clock when idle, now-playing, timers, workspace switches
- **Battery** always visible (white / green charging / red low, yellow bolt)
- **Transients** take over the pill: volume, brightness, charging, unplugged,
  low battery, device hotplug, notifications
- **Left click** opens the media player when something's playing, otherwise the
  quick panel. **Right click** cycles music / timer / idle
- **Meta** on its own toggles the quick panel

### Quick panel

Expands from the pill into a full-screen grid: clock, weather, battery with a
real fill-level icon, WiFi (with a Wired tab), Bluetooth, an audio **output
switcher**, Focus/Airplane toggles, workspaces, timers, calendar, and a 16:9
picture frame.

The frame is a slideshow — click it to pick images from your system with
checkboxes. Two or more cross-fade every 5s with a randomised transition
(fade / zoom / slide / shred); the selection persists to
`~/.local/state/caelestia/island-pictures.txt`.

### Media player

An audio-reactive blob driven by cava, split across bass/mid/treble bands.
Press it and it dents *inward at the point you touched*, with elastic
squash-and-stretch. Left third = previous, middle = play/pause, right third =
next. The fill ring shows song progress, and swaps to volume for 5s whenever
you change it.

### Lock screen

Stripped back to a clock, avatar, username, password box, and vertical
brightness (left) / volume (right) sliders.

- **Locking** — the pill drops from the island's position to centre, throws the
  bolt shut, then explodes into the lock panel. Unlocking reverses it.
- **A wrong password runs a small rigid-body physics sim** — gravity,
  restitution, angular velocity, wall/floor/ceiling collisions. Everything
  falls and tumbles, and *stays fully interactive while it does*, because the
  simulation only ever drives each item's `transform`, never its layout slot.
  Repeat failures add another impulse.
- **The correct password** floats everything back into place, then unlocks.

### Login screen

The lock screen also runs as the *login* screen, via
[greetd](https://sr.ht/~kennylevinsen/greetd) — same clock, avatar, password
field, sliders and physics, plus a session picker, an account picker and power
controls. Volume goes through ALSA there, since the greeter runs as `greetd`
and has no sound server.

See [greeter/README.md](greeter/README.md) for how it works and how to install
it. It does not replace your display manager until you explicitly enable it.

### Elsewhere

- Notification centre restyled to match; the pill is the only popup surface
  (toasts, OSD and the hover dashboard are disabled)
- Inline reply — repliable notifications expand the pill into a text box that
  won't auto-dismiss while you're typing
- Bluetooth lists only paired/connected devices (BlueZ exposes no "is it
  nearby" flag and caches everything it has ever seen), deduped across the
  rotating BLE addresses that made one device show up several times
- Continuous WiFi rescanning
- Hotplug notices for USB / ethernet / displays, grouped as "Dock" when several
  arrive together
- Galaxy Buds low-battery warnings via GalaxyBudsClient

## Requirements

Everything upstream needs, plus `wpctl` / `pipewire` for the output switcher
and, optionally, `GalaxyBudsClient` (Flatpak) for earbud battery.

## Install

As upstream — clone over `~/.config/quickshell/caelestia` and restart
`caelestia-shell.service`. See [README.upstream.md](README.upstream.md) for the
full instructions.

The Hyprland keybinds referenced above (`Meta+L` to lock, volume keys capped at
100%, brightness routed through the shell) live in `~/.config/hypr/hyprland.conf`
and are not part of this repo.

## Licence

**GPL-3.0**, inherited from upstream — see [LICENSE](LICENSE). This is a
derivative work of [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
and remains under the same terms.
