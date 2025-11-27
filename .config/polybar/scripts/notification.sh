#!/bin/bash
# Requires swaync (sway notification center)
if command -v swaync-client &> /dev/null; then
    count=$(swaync-client -c 2>/dev/null || echo "0")
    dnd=$(swaync-client -D 2>/dev/null)
    
    if [ "$dnd" = "true" ]; then
        if [ "$count" -gt 0 ]; then
            echo " 󰍜"
        else
            echo " "
        fi
    else
        if [ "$count" -gt 0 ]; then
            echo " 󰍜"
        else
            echo " "
        fi
    fi
else
    echo " "
fi