#!/usr/bin/env bash
# Close every window on the currently active workspace (bound to Super+Q).
set -euo pipefail

ws=$(hyprctl activeworkspace -j | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')

hyprctl clients -j | python3 -c "
import sys, json
for c in json.load(sys.stdin):
    if c.get('workspace', {}).get('id') == $ws:
        print(c['address'])
" | while read -r addr; do
    [ -n "$addr" ] && hyprctl dispatch closewindow "address:$addr"
done
