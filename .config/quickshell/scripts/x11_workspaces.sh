#!/usr/bin/env bash

# Check for dependencies
if ! command -v xprop >/dev/null 2>&1; then
    echo '{"error": "xprop missing"}'
    exit 1
fi
if ! command -v xdotool >/dev/null 2>&1; then
    echo '{"error": "xdotool missing"}'
    exit 1
fi

get_active_window() {
    local id=$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '{print $5}')
    if [ "$id" != "0x0" ] && [ -n "$id" ]; then
        local title=$(xprop -id "$id" _NET_WM_NAME 2>/dev/null | sed 's/.*= "//;s/"$//')
        if [ -z "$title" ]; then
            title=$(xprop -id "$id" WM_NAME 2>/dev/null | sed 's/.*= "//;s/"$//')
        fi
        echo "$title"
    else
        echo ""
    fi
}

get_focused_workspace() {
    local desktop=$(xprop -root _NET_CURRENT_DESKTOP 2>/dev/null | awk '{print $3}')
    if [ -n "$desktop" ]; then
        echo $((desktop + 1))
    else
        echo "1"
    fi
}

get_workspace_status() {
    local occupied=""
    local urgent=""
    
    # Get all client windows
    local clients=$(xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -o '0x[0-9a-f]\+')
    
    if [ -n "$clients" ]; then
        # Occupied: desktops that have at least one window
        local occ_list=$(echo "$clients" | while read -r id; do
            desktop=$(xprop -id "$id" _NET_WM_DESKTOP 2>/dev/null | awk '{print $3}')
            if [ -n "$desktop" ] && [ "$desktop" != "4294967295" ] && [ "$desktop" -ge 0 ] && [ "$desktop" -lt 20 ]; then
                echo $((desktop + 1))
            fi
        done | sort -un | tr '\n' ',' | sed 's/,$//')
        
        occupied="$occ_list"
        
        # Urgent: Check multiple methods for urgency
        local urg_list=$(echo "$clients" | while read -r id; do
            is_urgent=0
            
            # Method 1: Check WM_HINTS for Urgency flag
            if xprop -id "$id" WM_HINTS 2>/dev/null | grep -qi "urgency"; then
                is_urgent=1
            fi
            
            # Method 2: Check _NET_WM_STATE for DEMANDS_ATTENTION
            if [ $is_urgent -eq 0 ]; then
                if xprop -id "$id" _NET_WM_STATE 2>/dev/null | grep -q "_NET_WM_STATE_DEMANDS_ATTENTION"; then
                    is_urgent=1
                fi
            fi
            
            # Method 3: Check if window class contains common urgent indicators (dunst, notify, etc)
            if [ $is_urgent -eq 0 ]; then
                local wm_class=$(xprop -id "$id" WM_CLASS 2>/dev/null | tr '[:upper:]' '[:lower:]')
                if [[ "$wm_class" == *"dunst"* ]] || [[ "$wm_class" == *"notification"* ]]; then
                    is_urgent=1
                fi
            fi
            
            if [ $is_urgent -eq 1 ]; then
                desktop=$(xprop -id "$id" _NET_WM_DESKTOP 2>/dev/null | awk '{print $3}')
                if [ -n "$desktop" ] && [ "$desktop" != "4294967295" ] && [ "$desktop" -ge 0 ] && [ "$desktop" -lt 20 ]; then
                    echo $((desktop + 1))
                fi
            fi
        done | sort -un | tr '\n' ',' | sed 's/,$//')
        
        urgent="$urg_list"
    fi
    
    echo "{\"occupied\": [$occupied], \"urgent\": [$urgent]}"
}

case "$1" in
    window) get_active_window ;;
    workspace) get_focused_workspace ;;
    status) get_workspace_status ;;
    *)
        echo "Usage: $0 {window|workspace|status}"
        exit 1
        ;;
esac