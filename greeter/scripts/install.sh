#!/bin/bash
# Install the Caelestia greeter as the system login screen.
#
# Run as root from the repository root:
#     sudo bash greeter/scripts/install.sh
#
# This installs and configures everything but deliberately does NOT switch the
# display manager. Enabling greetd is a separate, explicit step (see the README),
# because getting it wrong means booting to a black screen.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GREETER="$REPO/greeter"
DST=/usr/share/caelestia-greeter
GREETD_HOME=/var/lib/greetd

# The account the greeter offers by default, and whose ~/.face and wallpaper
# get copied somewhere the greeter can actually read.
USER_NAME="${GREETER_USER:-nodevortex}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
[ -n "$USER_HOME" ] || { echo "no such user: $USER_NAME"; exit 1; }

echo "==> packages"
dnf install -y greetd greetd-selinux seatd qt6-qtdeclarative alsa-utils

echo "==> greeter QML -> $DST"
rm -rf "$DST"
install -d -m 0755 "$DST" "$DST/assets" "$DST/assets/greeter"
cp -r "$GREETER/modules" "$DST/"
install -m 0644 "$GREETER/shell.qml" "$DST/shell.qml"
install -m 0755 "$GREETER/assets/greetd-bridge.py" "$DST/assets/greetd-bridge.py"

# The shared Caelestia components/services/utils come from the main config.
for d in components services utils; do
    [ -d "$REPO/$d" ] && cp -r "$REPO/$d" "$DST/"
done

find "$DST" -type d -exec chmod 0755 {} +
find "$DST" -type f -exec chmod a+r {} +

echo "==> assets the greeter cannot read from \$HOME"
# It runs as `greetd`, so the user's home (mode 700) is off limits.
[ -f "$USER_HOME/.face" ] && install -m 0644 "$USER_HOME/.face" "$DST/assets/greeter/avatar"
WALL="$(cat "$USER_HOME/.local/state/caelestia/wallpaper/path.txt" 2>/dev/null || true)"
[ -n "$WALL" ] && [ -f "$WALL" ] && install -m 0644 "$WALL" "$DST/assets/greeter/wallpaper"

echo "==> fonts system-wide"
# Fonts under ~/.local/share/fonts are unreadable to greetd; without these the
# login screen renders Material Symbols as tofu boxes.
if [ -d "$USER_HOME/.local/share/fonts" ]; then
    install -d -m 0755 /usr/local/share/fonts
    cp -rn "$USER_HOME/.local/share/fonts/." /usr/local/share/fonts/ 2>/dev/null || true
    find /usr/local/share/fonts -type d -exec chmod 0755 {} +
    find /usr/local/share/fonts -type f -exec chmod 0644 {} +
    fc-cache -f >/dev/null
fi

echo "==> greetd XDG dirs"
install -d -m 0700 -o greetd -g greetd "$GREETD_HOME"
install -d -m 0755 -o greetd -g greetd "$GREETD_HOME/.config/caelestia" \
    "$GREETD_HOME/.local/state/caelestia" "$GREETD_HOME/.cache"
[ -f "$USER_HOME/.config/caelestia/shell.json" ] && \
    install -m 0644 -o greetd -g greetd "$USER_HOME/.config/caelestia/shell.json" \
        "$GREETD_HOME/.config/caelestia/shell.json"
# scheme.json is 0600 in the user's home; the copy has to be greetd-readable.
[ -f "$USER_HOME/.local/state/caelestia/scheme.json" ] && \
    install -m 0644 -o greetd -g greetd "$USER_HOME/.local/state/caelestia/scheme.json" \
        "$GREETD_HOME/.local/state/caelestia/scheme.json"

echo "==> system configuration"
install -d -m 0755 /etc/greetd
install -m 0644 "$GREETER/system/config.toml"             /etc/greetd/config.toml
install -m 0644 "$GREETER/system/hyprland-greeter.conf"   /etc/greetd/hyprland-greeter.conf
install -m 0755 "$GREETER/system/caelestia-greeter-session" /usr/local/bin/caelestia-greeter-session
install -m 0644 "$GREETER/system/90-backlight.rules"      /etc/udev/rules.d/90-backlight.rules
install -m 0644 "$GREETER/system/greetd-runtime.conf"     /etc/tmpfiles.d/greetd-runtime.conf
install -m 0644 "$GREETER/system/49-greetd-power.rules"   /etc/polkit-1/rules.d/49-greetd-power.rules
install -d -m 0755 /etc/systemd/system/greetd.service.d
install -m 0644 "$GREETER/system/greetd-service-override.conf" \
    /etc/systemd/system/greetd.service.d/override.conf
install -m 0755 "$GREETER/scripts/restore-gdm.sh" /usr/local/sbin/restore-gdm

echo "==> permissions for the greeter user"
# video/input/render: DRM and libinput. audio: the ALSA mixer, since there is
# no PipeWire pre-login. seat: only if libseat ever falls back to seatd.
usermod -aG video,input,render,audio,seat greetd

echo "==> logging"
touch /var/log/greetd-greeter.log
chown greetd:greetd /var/log/greetd-greeter.log
chmod 0640 /var/log/greetd-greeter.log

systemd-tmpfiles --create /etc/tmpfiles.d/greetd-runtime.conf
udevadm control --reload-rules && udevadm trigger -s backlight --action=add
systemctl enable --now seatd
systemctl restart polkit
systemctl daemon-reload
restorecon -RF "$DST" /etc/greetd /usr/local/bin/caelestia-greeter-session \
    /usr/local/sbin/restore-gdm "$GREETD_HOME" /usr/local/share/fonts 2>/dev/null || true

echo
echo "Installed. The display manager has NOT been changed."
systemctl is-enabled gdm    2>&1 | sed 's/^/  gdm:    /'
systemctl is-enabled greetd 2>&1 | sed 's/^/  greetd: /'
echo
echo "Try it without committing:   sudo systemctl start greetd   (appears on VT1)"
echo "Make it permanent:           sudo systemctl disable gdm && sudo systemctl enable greetd"
echo "Undo from a TTY:             sudo /usr/local/sbin/restore-gdm"
