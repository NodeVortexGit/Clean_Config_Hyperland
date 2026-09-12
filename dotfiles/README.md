# dotfiles

The system configs that go with this caelestia shell fork — a black + dark-blue
rice on Hyprland.

Run `./deploy.sh` after cloning to copy everything into place.

## What's here

| Path in repo | Deploys to | What it is |
|---|---|---|
| `.config/hypr/hyprland.conf` | `~/.config/hypr/` | Hyprland config (native `.conf`, zero gaps, dark-blue borders, all keybinds) |
| `.config/hypr/scripts/close-workspace.sh` | `~/.config/hypr/scripts/` | Super+Q "close every window on this workspace" |
| `.config/caelestia/shell.json` | `~/.config/caelestia/` | shell config: dashboard off, Celsius, 24h clock, frosted transparency |
| `.config/kitty/kitty.conf` | `~/.config/kitty/` | frosted transparency + dark-blue cursor |
| `.config/albert/config` | `~/.config/albert/` | Albert config incl. the "Black Blue" theme selection |
| `.local/share/albert/widgetsboxmodel/themes/Black Blue.ini` | `~/.local/share/...` | Albert theme: black bar, blue text/cursor |
| `.local/state/caelestia/scheme.json` | `~/.local/state/caelestia/` | custom **black + dark-blue** colour scheme |
| `wallpaper.jpg` | `~/wallhaven-vpyekp.jpg` | wallpaper |

## Keybinds (Hyprland)

- **Meta** (tap alone) — toggle the island (combos are ignored)
- **Meta + Left-Alt** — Albert launcher
- **Meta + Space** — switch keyboard layout (US ⇄ BG)
- **Meta + Q** — close all windows on the workspace
- **Meta + Shift + Q** — close the window under the cursor
- **Meta + Return** — terminal · **Meta + E** — files · **Meta + 1–0** — workspaces

## Requirements

The caelestia shell (see `../finish-install.sh`) plus: `hyprland`, `kitty`,
`albert`/`albert-bin`, `playerctl`, `brightnessctl`.
