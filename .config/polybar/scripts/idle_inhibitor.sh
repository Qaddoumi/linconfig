#!/bin/bash
# Simple idle inhibitor toggle using xdg-screensaver or caffeine
# You may need to install 'caffeine' or use another tool

STATE_FILE="/tmp/polybar_idle_inhibitor"

if [ "$1" = "toggle" ]; then
    if [ -f "$STATE_FILE" ]; then
        # Disable inhibitor
        pkill -f "xdg-screensaver reset" 2>/dev/null
        rm "$STATE_FILE"
    else
        # Enable inhibitor
        touch "$STATE_FILE"
        while [ -f "$STATE_FILE" ]; do
            xdg-screensaver reset
            sleep 50
        done &
    fi
else
    # Check status
    if [ -f "$STATE_FILE" ]; then
        echo " "
    else
        echo " "
    fi
fi