#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root." >&2
    exit 1
fi

echo "== Checking sudo =="
sudo -v

echo "== Installing official-repository dependencies =="
sudo pacman -S --needed --noconfirm \
    base-devel git cmake ninja meson pkgconf \
    fftw iniparser ddcutil brightnessctl networkmanager lm_sensors \
    pipewire wireplumber \
    qt6-base qt6-declarative qt6-shadertools \
    gcc-libs libqalculate \
    bash fish python python-pyudev \
    aubio cava swappy fastfetch \
    ttf-cascadia-code-nerd \
    hyprland kitty dolphin playerctl \
    fcitx5 fcitx5-mozc fcitx5-gtk fcitx5-qt

echo "== Installing libcava =="
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"

if ! pkg-config --exists libcava && ! pkg-config --exists cava; then
    tmpdir="$(mktemp -d)"
    git clone --depth 1 https://github.com/LukashonakV/cava.git "$tmpdir/cava"
    (
        cd "$tmpdir/cava"
        meson setup build
        meson compile -C build
        sudo meson install -C build
    )
    rm -rf "$tmpdir"
fi

if [[ ! -e /etc/ld.so.conf.d/usrlocal.conf ]]; then
    echo '/usr/local/lib' | sudo tee /etc/ld.so.conf.d/usrlocal.conf >/dev/null
fi
sudo ldconfig

echo "== Installing yay =="
if ! command -v yay >/dev/null 2>&1; then
    tmpdir="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
    (
        cd "$tmpdir/yay-bin"
        makepkg -si --noconfirm
    )
    rm -rf "$tmpdir"
fi

echo "== Installing AUR dependencies =="
yay -S --needed --noconfirm \
    quickshell-git \
    caelestia-cli \
    app2unit \
    ttf-material-symbols-variable-git

if ! command -v albert >/dev/null 2>&1; then
    yay -S --needed --noconfirm albert-bin
fi

echo "== Building and installing Caelestia shell =="
cd "$repo_dir"

cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/ \
    -DVERSION="1.0.0"

cmake --build build
sudo cmake --install build

echo "== Installing fetch =="
if ! command -v fetch >/dev/null 2>&1; then
    tmpdir="$(mktemp -d)"
    git clone --depth 1 https://github.com/areofyl/fetch.git "$tmpdir/fetch"
    (
        cd "$tmpdir/fetch"
        make
        PREFIX="$HOME/.local" make install
    )
    rm -rf "$tmpdir"
fi

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

    if [[ -f "$HOME/.zshrc" ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi

    if [[ -d "$HOME/.config/fish" ]]; then
        mkdir -p "$HOME/.config/fish/conf.d"
        echo 'fish_add_path $HOME/.local/bin' \
            > "$HOME/.config/fish/conf.d/local-bin.fish"
    fi
fi

echo "== Backing up existing configuration =="
backup_dir="$HOME/.config/clean-config-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"

for config in hypr kitty caelestia albert fcitx5 mozc; do
    if [[ -e "$HOME/.config/$config" ]]; then
        cp -a "$HOME/.config/$config" "$backup_dir/"
    fi
done

echo "Backups saved to: $backup_dir"

echo "== Using automatic monitor configuration =="
hypr_config="$repo_dir/dotfiles/.config/hypr/hyprland.conf"

if [[ -f "$hypr_config" ]]; then
    sed -i \
        's/^monitor = , 1920x1080@60, auto, 1\.0$/monitor = , preferred, auto, 1.0/' \
        "$hypr_config"
fi

echo "== Deploying dotfiles =="
bash "$repo_dir/dotfiles/deploy.sh"

echo
echo "== Installation complete =="
echo
echo "Your previous configuration is backed up in:"
echo "  $backup_dir"
echo
echo "Log out and back into Hyprland, or run:"
echo "  hyprctl reload"
echo "  pkill -x qs 2>/dev/null || true"
echo "  qs -c caelestia"
echo
echo "Run 'fastfetch' for system information or 'fetch' for the animated logo."
echo "The optional greeter was not installed or enabled."
