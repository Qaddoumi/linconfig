#!/usr/bin/env bash

# Idle Inhibitor Toggle Script
# Works with both Hyprland and Sway

#TODO: add awesome wm

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/idle-inhibit.state"
INHIBITOR_PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/idle-inhibit.pid"

# Detect which compositor is running
if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    COMPOSITOR="hyprland"
elif [[ -n "$SWAYSOCK" ]]; then
    COMPOSITOR="sway"
else
    echo "Error: Neither Hyprland nor Sway detected"
    exit 1
fi

# Function to check if inhibitor is active
is_inhibited() {
    [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE")" == "inhibited" ]]
}

# Function to start inhibitor
start_inhibitor() {
    if [[ "$COMPOSITOR" == "hyprland" ]]; then
        # Hyprland uses systemd-inhibit or hypridle
        systemd-inhibit --what=idle --who="Manual" --why="User requested" --mode=block sleep infinity &
        echo $! > "$INHIBITOR_PID_FILE"
    elif [[ "$COMPOSITOR" == "sway" ]]; then
        # Sway uses wayland-idle-inhibitor or swayidle
        if command -v wayland-idle-inhibitor.py &> /dev/null; then
            wayland-idle-inhibitor.py &
            echo $! > "$INHIBITOR_PID_FILE"
        elif command -v sway-idle-inhibit.py &> /dev/null; then
            sway-idle-inhibit.py &
            echo $! > "$INHIBITOR_PID_FILE"
        else
            # Fallback: use systemd-inhibit
            systemd-inhibit --what=idle --who="Manual" --why="User requested" --mode=block sleep infinity &
            echo $! > "$INHIBITOR_PID_FILE"
        fi
    fi
    echo "inhibited" > "$STATE_FILE"
}

# Function to stop inhibitor
stop_inhibitor() {
    if [[ -f "$INHIBITOR_PID_FILE" ]]; then
        PID=$(cat "$INHIBITOR_PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            kill "$PID" 2>/dev/null
        fi
        rm -f "$INHIBITOR_PID_FILE"
    fi
    rm -f "$STATE_FILE"
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