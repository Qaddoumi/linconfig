#!/usr/bin/env bash

# Idle Inhibitor Toggle Script
# Works with Hyprland, Sway, and X11 (xscreensaver)

# Detect which compositor/display server is running
if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    COMPOSITOR="hyprland"
elif [[ -n "$SWAYSOCK" ]]; then
    COMPOSITOR="sway"
elif [[ "$XDG_SESSION_TYPE" == "x11" ]]; then
    COMPOSITOR="x11"
else
    echo "{\"text\": \"E\", \"tooltip\": \"Error (idle.sh): No supported display server detected\", \"class\": \"activated\"}"
    exit 1
fi

# Function to check if inhibitor is active
is_inhibited() {
    if [[ "$COMPOSITOR" == "x11" ]]; then
        ! pgrep -x xscreensaver > /dev/null
    else
        ! pgrep -x swayidle > /dev/null
    fi
}

# Function to start inhibitor
start_inhibitor() {
    if [[ "$COMPOSITOR" == "x11" ]]; then
        # X11: Kill xscreensaver daemon
        if pgrep -x xscreensaver > /dev/null; then
            xscreensaver-command -exit 2>/dev/null
        fi
    else
        # Wayland: Kill swayidle
        local PID=$(pgrep -x swayidle | head -n1)
        if [[ -n "$PID" ]]; then
            kill "$PID" 2>/dev/null
        fi
    fi
}

# Function to stop inhibitor
stop_inhibitor() {
    if [[ "$COMPOSITOR" == "hyprland" ]]; then
        # Start swayidle for Hyprland
        swayidle -w \
            timeout 300 'swaylock \
                --color 2d353b \
                --inside-color 3a454a \
                --inside-clear-color 5c6a72 \
                --inside-ver-color 5a524c \
                --inside-wrong-color 543a3a \
                --ring-color 7a8478 \
                --ring-clear-color a7c080 \
                --ring-ver-color dbbc7f \
                --ring-wrong-color e67e80 \
                --key-hl-color d699b6 \
                --bs-hl-color e69875 \
                --separator-color 2d353b \
                --text-color d3c6aa \
                --text-clear-color d3c6aa \
                --text-ver-color d3c6aa \
                --text-wrong-color d3c6aa \
                --indicator-radius 100 \
                --indicator-thickness 10 \
                --font "JetBrainsMono Nerd Font Propo"'
            timeout 1800 'hyprctl dispatch dpms off' \
            resume 'hyprctl dispatch dpms on' \
            before-sleep 'swaylock -f -c 000000' &
    elif [[ "$COMPOSITOR" == "sway" ]]; then
        # Start swayidle for Sway
        swayidle -w \
            timeout 300 'swaylock \
                --color 2d353b \
                --inside-color 3a454a \
                --inside-clear-color 5c6a72 \
                --inside-ver-color 5a524c \
                --inside-wrong-color 543a3a \
                --ring-color 7a8478 \
                --ring-clear-color a7c080 \
                --ring-ver-color dbbc7f \
                --ring-wrong-color e67e80 \
                --key-hl-color d699b6 \
                --bs-hl-color e69875 \
                --separator-color 2d353b \
                --text-color d3c6aa \
                --text-clear-color d3c6aa \
                --text-ver-color d3c6aa \
                --text-wrong-color d3c6aa \
                --indicator-radius 100 \
                --indicator-thickness 10 \
                --font "JetBrainsMono Nerd Font Propo"' \
            timeout 1800 'swaymsg output "*" power off' \
            resume 'swaymsg output "*" power on' \
            before-sleep 'swaylock -f -c 000000' &
    elif [[ "$COMPOSITOR" == "x11" ]]; then
        xscreensaver -no-splash -quiet & 2>/dev/null
    fi
}

# Function to get status for output
get_status() {
    if is_inhibited; then
        echo '{"text": "", "tooltip": "Idle inhibitor: Active", "class": "activated"}'
    else
        echo '{"text": "", "tooltip": "Idle inhibitor: Inactive", "class": "deactivated"}'
    fi
}

# Main toggle logic
case "${1:-toggle}" in
    toggle)
        if is_inhibited; then
            stop_inhibitor
            echo "Idle inhibitor deactivated"
        else
            start_inhibitor
            echo "Idle inhibitor activated"
        fi
        ;;
    on|activate)
        if ! is_inhibited; then
            start_inhibitor
            echo "Idle inhibitor activated"
        else
            echo "Idle inhibitor already active"
        fi
        ;;
    off|deactivate)
        if is_inhibited; then
            stop_inhibitor
            echo "Idle inhibitor deactivated"
        else
            echo "Idle inhibitor already inactive"
        fi
        ;;
    status)
        get_status
        ;;
    check)
        if is_inhibited; then
            echo "Active"
            exit 0
        else
            echo "Inactive"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {toggle|on|off|status|check}"
        echo "  toggle - Toggle idle inhibitor on/off"
        echo "  on     - Activate idle inhibitor"
        echo "  off    - Deactivate idle inhibitor"
        echo "  status - Output JSON status (for Waybar)"
        echo "  check  - Check if active (exit 0) or inactive (exit 1)"
        exit 1
        ;;
esac