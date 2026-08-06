# Caelestia Greeter

The lock screen, running as the login screen — same clock, avatar, password
field, brightness/volume sliders and wrong-password physics, but shown by
[greetd](https://sr.ht/~kennylevinsen/greetd) before anyone is logged in.

Plus what a login screen needs and a lock screen doesn't: a session picker, an
account picker, and power controls.

## How it differs from the lock screen

The lock screen is a `WlSessionLock` client: it locks a session that already
exists. Before login there is no session, so two things change and the rest of
the module is shared unmodified.

| | Lock screen | Greeter |
|---|---|---|
| Surface | `WlSessionLockSurface` | layershell `PanelWindow`, overlay layer, exclusive keyboard |
| Backdrop | `ScreencopyView` of the live desktop | the wallpaper, blurred the same way — there is no desktop to capture |
| Auth | `PamContext` directly | greetd's IPC, which owns PAM pre-login |
| Volume | PipeWire | ALSA via `amixer` — the `greetd` user has no sound server |
| Fingerprint | `fprintd` | unavailable; greetd exposes one PAM conversation |

`Pam.qml` deliberately keeps its filename, and therefore its QML type name, so
`InputField`, `StateMessage` and `PasswordInput` — which all declare
`required property Pam pam` — work against it unchanged.

## greetd IPC

greetd speaks length-prefixed JSON over a unix socket: a native-endian `u32`
byte count followed by that many bytes of JSON. Quickshell's `Socket` only
splits on a delimiter and cannot frame that, so `assets/greetd-bridge.py` sits
in between and speaks line-delimited JSON on stdio instead.

The conversation is strictly request/response:

```
create_session{username}       -> auth_message{secret,"Password:"}
post_auth_message_response{pw} -> success | error{auth_error}
start_session{cmd}             -> success, then greetd execs the session
```

A failed password may or may not leave the half-configured session alive — the
spec calls it "not a fatal error … handle as appropriate" without saying — so
every new attempt sends a speculative `cancel_session` first. That cancel is
tagged so its reply can be discarded rather than shown as a login failure.

Run the bridge with `--demo` to exercise the UI with no greetd at all.

## Install

```sh
sudo bash greeter/scripts/install.sh
```

Installs and configures everything, and deliberately leaves GDM as the login
screen. To try it without committing:

```sh
sudo systemctl start greetd     # appears on VT1
```

To make it permanent:

```sh
sudo systemctl disable gdm && sudo systemctl enable greetd
```

**Recovery.** If the greeter ever fails to appear: `Ctrl+Alt+F3`, log in, then

```sh
sudo /usr/local/sbin/restore-gdm
```

## Things that are not obvious

Each of these was a failure that took a boot or a VT test to find.

- **The `greetd` user starts in no groups at all.** Without `video` and `input`
  it cannot open `/dev/dri/card1` or any input device, and Hyprland dies in
  ~400 ms with `CBackend::create() failed`.
- **`XDG_RUNTIME_DIR` is not propagated** from PAM to the greeter, and Hyprland
  aborts outright without one. `/etc/tmpfiles.d/greetd-runtime.conf` provides a
  fallback.
- **Do not force `LIBSEAT_BACKEND=seatd`.** logind works correctly at real boot;
  forcing seatd means racing `seatd.service` and failing to get DRM master.
  Running `greetd` by hand from a root shell produces a *different* PAM
  environment than systemd does at boot — which is exactly how this was missed.
- **Fonts in `~/.local/share/fonts` are invisible** to the greeter, because the
  home directory is mode 700. Material Symbols renders as tofu boxes.
- **The backlight needs a udev rule.** `brightnessctl` goes through logind's
  `SetBrightness`, which needs an active seat session.
- **greetd gives the greeter no `PATH`.** Anything it execs must be an absolute
  path, or the button appears to do nothing: the click lands, `execDetached`
  fires, and the binary is never found.
- **Hibernate needs disk-backed swap.** zram cannot hold a hibernation image, so
  `CanHibernate` reports `na` until a real swapfile exists, is named by
  `resume=`/`resume_offset=` on the kernel command line, and the initramfs
  carries the `resume` module. See below.
- **Physics bodies must reparent onto the card while displaced.** Moving a body
  *within* its layout slot — by `transform` or by `x`/`y` — renders correctly
  but cannot be clicked: Qt only descends into a parent that contains the point,
  so a button lying at the bottom of the pile keeps its hit area up in the row.

## Hibernate

The hibernate button needs disk-backed swap; zram is not enough, since it lives
in the memory being saved. On btrfs:

```sh
btrfs subvolume create /swap                      # own subvolume: never snapshotted
btrfs filesystem mkswapfile --size 16g --uuid clear /swap/swapfile
semanage fcontext -a -t swapfile_t /swap/swapfile && restorecon /swap/swapfile
swapon /swap/swapfile
echo '/swap/swapfile none swap defaults 0 0' >> /etc/fstab

grubby --update-kernel=ALL \
  --args="resume=UUID=$(findmnt -no UUID /) \
          resume_offset=$(btrfs inspect-internal map-swapfile -r /swap/swapfile)"

echo 'add_dracutmodules+=" resume "' > /etc/dracut.conf.d/resume.conf
dracut -f --regenerate-all
```

Size the swapfile at least as large as RAM. The change only takes effect after a
reboot: until the kernel is booted with `resume=`, `CanHibernate` reports `na`.

Two further things will block it even once all of the above is right:

- **The sleep targets may be masked.** `systemctl unmask sleep.target
  suspend.target hibernate.target hybrid-sleep.target`. While masked,
  `CanHibernate` fails with `AccessDenied` no matter how the swap is set up.
- **SELinux must be able to reach the swapfile.** A freshly created `/swap`
  subvolume is *unlabelled*, so logind cannot traverse it, and the failure
  surfaces as `AccessDenied` from a process running as root:

  ```sh
  semanage fcontext -a -t root_t /swap
  restorecon -Rv /swap
  ```

  logind's own debug log is what identifies this — `systemctl
  service-log-level systemd-logind debug` then look for
  `Failed to get devno and offset for swap`.

## Layout

```
greeter/
  shell.qml              greeter root; no bar, island, or background daemon
  modules/greeter/       Greeter, LockSurface, Content, Pam, and the pickers
  assets/greetd-bridge.py
  system/                greetd, hyprland, udev, tmpfiles, polkit, systemd
  scripts/install.sh     installer
  scripts/restore-gdm.sh rollback
```

## Licence

GPL-3.0, inherited from [caelestia-dots/shell](https://github.com/caelestia-dots/shell).
