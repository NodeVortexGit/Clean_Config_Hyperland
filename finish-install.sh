#!/usr/bin/env bash
# Finish installing the Clean_Config_Hyperland (caelestia-dots/shell fork) quickshell overlay.
# Run this AFTER sudo is working again: bash ~/.config/quickshell/caelestia/finish-install.sh
set -euo pipefail

echo "== sanity check: sudo =="
if ! sudo -n true 2>/dev/null && ! sudo -v; then
  echo "sudo still isn't working for $(whoami). Fix that first (see the sudoers note you got)." >&2
  exit 1
fi

echo "== base-devel + build deps (pacman, official repos only) =="
sudo pacman -S --needed --noconfirm \
  base-devel git cmake ninja meson fftw iniparser \
  ddcutil brightnessctl networkmanager lm_sensors \
  pipewire qt6-declarative qt6-base gcc-libs libqalculate bash \
  fish aubio cava swappy ttf-cascadia-code-nerd

echo "== libcava (dev lib + pkg-config, not shipped by Arch's cava binary package) =="
if ! pkg-config --exists cava libcava 2>/dev/null; then
  tmpdir=$(mktemp -d)
  git clone --depth 1 https://github.com/LukashonakV/cava.git "$tmpdir/cava"
  (cd "$tmpdir/cava" && meson setup build && meson compile -C build && sudo meson install -C build)
  rm -rf "$tmpdir"
fi
# libcava lands in /usr/local/lib (FHS-correct for a hand-built lib), but Arch's
# dynamic linker only searches /lib and /usr/lib by default -- without this the
# caelestia services plugin fails at runtime with "libcava.so.1: cannot open
# shared object file", which cascades into "Failed to load configuration".
if [ ! -e /etc/ld.so.conf.d/usrlocal.conf ]; then
  echo '/usr/local/lib' | sudo tee /etc/ld.so.conf.d/usrlocal.conf >/dev/null
fi
sudo ldconfig

echo "== yay (AUR helper) =="
if ! command -v yay >/dev/null 2>&1; then
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
  (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
fi

echo "== AUR-only deps (yay) =="
# NOTE: AUR had a real supply-chain compromise in June 2026 ("Atomic Arch",
# ~1500 packages via hijacked PKGBUILDs). These four were checked clean against
# the live compromised-package list as of this script being written, but AUR
# packages are unreviewed by nature -- re-check before installing on a new
# machine: https://github.com/lenucksi/aur-malware-check
yay -S --needed --noconfirm \
  quickshell-git caelestia-cli app2unit ttf-material-symbols-variable-git

echo "== build & install the shell (this repo) =="
cd "$(dirname "${BASH_SOURCE[0]}")"
# This fork has no git tags, so CMakeLists.txt's `git describe --tags` version
# lookup always fails -- pass VERSION explicitly instead. CMake's project()
# requires a plain numeric version; the commit hash goes in GIT_REVISION,
# which CMakeLists.txt already derives on its own via `git rev-parse HEAD`.
# libcava installs to /usr/local (meson's default prefix), which Arch's
# pkg-config does NOT search by default -- point it there explicitly.
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ -DVERSION="1.0.0"
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
