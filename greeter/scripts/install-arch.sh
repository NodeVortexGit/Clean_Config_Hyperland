#!/bin/bash
# Install the Caelestia greeter as the system login screen -- ARCH + SDDM variant.
#
# Adapted from scripts/install.sh (Fedora / GDM / SELinux) for an Arch machine
# whose current display manager is SDDM. Differences from the Fedora script:
#   * packages via pacman, not dnf; no SELinux packages
#   * no restorecon / semanage (Arch has no SELinux by default)
#   * the greeter service user is Arch's `greeter` (uid 959), NOT `greetd`
#     (Fedora's name). This is auto-detected and patched into config.toml.
#   * rollback restores SDDM (restore-sddm), not GDM
#
# Run as root from the repository root:
#     sudo bash greeter/scripts/install-arch.sh
#
# Installs and configures everything but deliberately does NOT switch the
# display manager. Enabling greetd is a separate, explicit step (see the end).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GREETER="$REPO/greeter"
DST=/usr/share/caelestia-greeter
GREETD_HOME=/var/lib/greetd

USER_NAME="${GREETER_USER:-nodevortex}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
[ -n "$USER_HOME" ] || { echo "no such user: $USER_NAME"; exit 1; }

echo "==> packages (pacman)"
# greetd's package creates the greeter service user via systemd-sysusers, so
# this must run first. --needed skips what is already present.
pacman -S --needed --noconfirm greetd seatd qt6-declarative alsa-utils
command -v qs       >/dev/null || { echo "quickshell (qs) not found in PATH"; exit 1; }
command -v Hyprland >/dev/null || { echo "Hyprland not found in PATH"; exit 1; }

# The greeter runs as this account. Arch names it `greeter`; the repo's Fedora
# assets say `greetd`. Detect whichever exists so ownership + config.toml agree.
if   getent passwd greeter >/dev/null; then GREETD_USER=greeter
elif getent passwd greetd  >/dev/null; then GREETD_USER=greetd
else echo "no greetd/greeter user after installing greetd"; exit 1; fi
GREETD_GROUP="$(id -gn "$GREETD_USER")"
echo "    greeter service user = $GREETD_USER:$GREETD_GROUP"

echo "==> greeter QML -> $DST"
rm -rf "$DST"
install -d -m 0755 "$DST" "$DST/assets" "$DST/assets/greeter"
cp -r "$GREETER/modules" "$DST/"
install -m 0644 "$GREETER/shell.qml" "$DST/shell.qml"
install -m 0755 "$GREETER/assets/greetd-bridge.py" "$DST/assets/greetd-bridge.py"

# Shared Caelestia components/services/utils come from the main config.
for d in components services utils; do
    [ -d "$REPO/$d" ] && cp -r "$REPO/$d" "$DST/"
done

find "$DST" -type d -exec chmod 0755 {} +
find "$DST" -type f -exec chmod a+r {} +

echo "==> assets the greeter cannot read from \$HOME (home is mode 700)"
[ -f "$USER_HOME/.face" ] && install -m 0644 "$USER_HOME/.face" "$DST/assets/greeter/avatar"
WALL="$(cat "$USER_HOME/.local/state/caelestia/wallpaper/path.txt" 2>/dev/null || true)"
[ -n "$WALL" ] && [ -f "$WALL" ] && install -m 0644 "$WALL" "$DST/assets/greeter/wallpaper"

echo "==> fonts system-wide (greeter cannot read ~/.local/share/fonts)"
if [ -d "$USER_HOME/.local/share/fonts" ]; then
    install -d -m 0755 /usr/local/share/fonts
    cp -rn "$USER_HOME/.local/share/fonts/." /usr/local/share/fonts/ 2>/dev/null || true
    find /usr/local/share/fonts -type d -exec chmod 0755 {} +
    find /usr/local/share/fonts -type f -exec chmod 0644 {} +
    fc-cache -f >/dev/null
fi

echo "==> greeter XDG dirs (owned by $GREETD_USER)"
install -d -m 0700 -o "$GREETD_USER" -g "$GREETD_GROUP" "$GREETD_HOME"
install -d -m 0755 -o "$GREETD_USER" -g "$GREETD_GROUP" "$GREETD_HOME/.config/caelestia" \
    "$GREETD_HOME/.local/state/caelestia" "$GREETD_HOME/.cache"
[ -f "$USER_HOME/.config/caelestia/shell.json" ] && \
    install -m 0644 -o "$GREETD_USER" -g "$GREETD_GROUP" "$USER_HOME/.config/caelestia/shell.json" \
        "$GREETD_HOME/.config/caelestia/shell.json"
[ -f "$USER_HOME/.local/state/caelestia/scheme.json" ] && \
    install -m 0644 -o "$GREETD_USER" -g "$GREETD_GROUP" "$USER_HOME/.local/state/caelestia/scheme.json" \
        "$GREETD_HOME/.local/state/caelestia/scheme.json"

echo "==> system configuration"
install -d -m 0755 /etc/greetd
# Patch the greeter user into config.toml (repo says greetd; Arch is greeter).
sed "s/^user = \"greetd\"/user = \"$GREETD_USER\"/" \
    "$GREETER/system/config.toml" > /etc/greetd/config.toml
chmod 0644 /etc/greetd/config.toml
install -m 0644 "$GREETER/system/hyprland-greeter.conf"     /etc/greetd/hyprland-greeter.conf
install -m 0755 "$GREETER/system/caelestia-greeter-session" /usr/local/bin/caelestia-greeter-session
install -m 0644 "$GREETER/system/90-backlight.rules"        /etc/udev/rules.d/90-backlight.rules
# tmpfiles runtime dir must be owned by the real greeter user, too.
sed "s/greetd greetd/$GREETD_USER $GREETD_GROUP/" \
    "$GREETER/system/greetd-runtime.conf" > /etc/tmpfiles.d/greetd-runtime.conf
install -m 0644 "$GREETER/system/49-greetd-power.rules"     /etc/polkit-1/rules.d/49-greetd-power.rules
install -d -m 0755 /etc/systemd/system/greetd.service.d
install -m 0644 "$GREETER/system/greetd-service-override.conf" \
    /etc/systemd/system/greetd.service.d/override.conf
install -m 0755 "$GREETER/scripts/restore-sddm.sh" /usr/local/sbin/restore-sddm

echo "==> permissions for the greeter user"
usermod -aG video,input,render,audio,seat "$GREETD_USER"

echo "==> logging"
touch /var/log/greetd-greeter.log
chown "$GREETD_USER:$GREETD_GROUP" /var/log/greetd-greeter.log
chmod 0640 /var/log/greetd-greeter.log

systemd-tmpfiles --create /etc/tmpfiles.d/greetd-runtime.conf
udevadm control --reload-rules && udevadm trigger -s backlight --action=add
systemctl restart polkit
systemctl daemon-reload

echo
echo "Installed for user '$GREETD_USER'. The display manager has NOT been changed."
echo "  sddm:   $(systemctl is-enabled sddm   2>&1)"
echo "  greetd: $(systemctl is-enabled greetd 2>&1)"
echo
echo "Sanity check the config BEFORE switching:"
echo "    grep -E 'command|user' /etc/greetd/config.toml   # user must be $GREETD_USER"
echo "Make it permanent (SDDM -> greetd), then reboot to test:"
echo "    sudo systemctl disable sddm && sudo systemctl enable greetd && reboot"
echo "Recovery if the greeter fails (from a TTY, Ctrl+Alt+F3):"
echo "    sudo /usr/local/sbin/restore-sddm"
