#!/usr/bin/env bash

# Idle inhibitor for xautolock (DWM/X11)
STATE_FILE="/tmp/polybar_idle_inhibitor"

if [ "$1" = "toggle" ]; then
    if [ -f "$STATE_FILE" ]; then
        # Disable inhibitor (Enable xautolock)
        xautolock -enable
        xset s on +dpms
        rm "$STATE_FILE"
    else
        # Enable inhibitor (Disable xautolock)
        touch "$STATE_FILE"
        xautolock -disable
        xset s off -dpms
    fi
else
    # Check status
    if [ -f "$STATE_FILE" ]; then
        echo "%{B#ecf0f1}%{F#2d3748}    %{F-}%{B-}"
    else
        echo "%{B#2d3748}%{F#ffffff}    %{F-}%{B-}"
    fi
fi