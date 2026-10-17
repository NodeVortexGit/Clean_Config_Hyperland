#!/usr/bin/env bash
# Switch Hyprland keyboard layout (us,bg,jp); Mozc is only on for jp.
hyprctl switchxkblayout all next
sleep 0.1
km=$(hyprctl -j devices | python3 -c 'import json,sys; k=json.load(sys.stdin)["keyboards"]; print((next((x for x in k if x["main"]), k[0]))["active_keymap"])')
if [[ $km == *apanese* ]]; then
  fcitx5-remote -o
else
  fcitx5-remote -c
fi
