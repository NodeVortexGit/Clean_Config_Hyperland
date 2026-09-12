#!/usr/bin/env bash
# Deploy these dotfiles into place. Run after cloning the repo.
# NOTE: this overwrites the target config files with the versions in this repo.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> ~/.config and ~/.local"
cp -rv "$here/.config/." "$HOME/.config/"
cp -rv "$here/.local/."  "$HOME/.local/"

echo "==> wallpaper"
mkdir -p "$HOME/Pictures"
cp -v "$here/wallpaper.png" "$HOME/Pictures/wallhaven-p838q3.png"
mkdir -p "$HOME/.local/state/caelestia/wallpaper"
# Point the shell's background at it WITHOUT running `caelestia wallpaper`,
# which would regenerate scheme.json from the image and clobber the custom
# black + dark-blue palette shipped in .local/state/caelestia/scheme.json.
printf '%s' "$HOME/Pictures/wallhaven-p838q3.png" > "$HOME/.local/state/caelestia/wallpaper/path.txt"

chmod +x "$HOME/.config/hypr/scripts/close-workspace.sh" 2>/dev/null || true

echo
echo "Done. Log into Hyprland (SDDM -> Hyprland), or if already in it:"
echo "  hyprctl reload && pkill -x qs; qs -c caelestia &"
echo
echo "Needs installed: hyprland, kitty, albert(-bin), playerctl, brightnessctl,"
echo "and the caelestia shell itself (see ../finish-install.sh)."
