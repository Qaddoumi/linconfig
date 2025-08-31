#!/usr/bin/env bash

ACTION=$(printf "Copy\nDelete\nClear" | wofi --dmenu --prompt "Clipboard action...")

case "$ACTION" in
    "Copy") 
        SELECTION=$(cliphist list | wofi --dmenu --prompt "Search the clipboard...")
        echo "$SELECTION" | cliphist decode | wl-copy
        ;;
    "Delete") 
        SELECTION=$(cliphist list | wofi --dmenu --prompt "Search the clipboard...")
        echo "$SELECTION" | cliphist delete
        ;;
    "Clear")
        rm -f ~/.cache/cliphist/db
        notify-send "Clipboard cleared"
        ;;
esac