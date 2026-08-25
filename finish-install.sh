#!/usr/bin/env bash
# Finish installing the Clean_Config_Hyperland (caelestia-dots/shell fork) quickshell overlay.
# Run this AFTER sudo is working again: bash ~/.config/quickshell/caelestia/finish-install.sh
set -euo pipefail

echo "== sanity check: sudo =="
if ! sudo -n true 2>/dev/null && ! sudo -v; then
  echo "sudo still isn't working for $(whoami). Fix that first (see the sudoers note you got)." >&2
  exit 1
fi

echo "== base-devel + build deps (pacman) =="
sudo pacman -S --needed --noconfirm \
  base-devel git cmake ninja \
  ddcutil brightnessctl networkmanager lm_sensors \
  pipewire qt6-declarative qt6-base gcc-libs libqalculate bash \
  fish aubio cava swappy

echo "== yay (AUR helper) =="
if ! command -v yay >/dev/null 2>&1; then
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
  (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
fi

echo "== AUR-only deps (yay) =="
yay -S --needed --noconfirm \
  quickshell-git caelestia-cli app2unit \
  ttf-material-symbols-variable-git ttf-caskaydia-cove-nerd

echo "== build & install the shell (this repo) =="
cd "$(dirname "${BASH_SOURCE[0]}")"
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
cmake --build build
sudo cmake --install build

echo "== fetch (spinning-3D-logo fastfetch companion, github.com/areofyl/fetch) =="
if ! command -v fetch >/dev/null 2>&1; then
  tmpdir=$(mktemp -d)
  git clone --depth 1 https://github.com/areofyl/fetch.git "$tmpdir/fetch"
  (cd "$tmpdir/fetch" && make && PREFIX="$HOME/.local" make install)
  rm -rf "$tmpdir"
fi

echo "== done =="
echo "Start it with:  qs -c caelestia"
echo "Or:              caelestia shell -d"
echo
echo "'fetch' installed to ~/.local/bin/fetch -- run it any time for the spinning 3D logo."
echo
echo "To autostart with Hyprland, add to ~/.config/hypr/hyprland.lua's AUTOSTART section:"
echo '  hl.exec("qs -c caelestia")'
echo
echo "Meta+L lock / volume-key / brightness keybinds referenced in the README are NOT in this"
echo "repo -- they'd normally come from the full caelestia-dots/caelestia dotfiles. Say the word"
echo "if you want those added to ~/.config/hypr/hyprland.lua too."
