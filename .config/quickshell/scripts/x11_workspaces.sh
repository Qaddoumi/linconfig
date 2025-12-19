#!/usr/bin/env bash

# Check for dependencies
if ! command -v xprop >/dev/null 2>&1; then
    echo '{"error": "xprop missing"}'
    exit 1
fi

get_active_window() {
    local id=$(xprop -root _NET_ACTIVE_WINDOW | awk '{print $5}')
    if [ "$id" != "0x0" ] && [ -n "$id" ]; then
        xprop -id "$id" _NET_WM_NAME | sed 's/.*= "//;s/"$//'
    else
        echo ""
    fi
}

get_focused_workspace() {
    xprop -root _NET_CURRENT_DESKTOP | awk '{print $3 + 1}'
}

get_workspace_status() {
    local occupied=""
    local urgent=""
    
    # Get all client windows
    local clients=$(xprop -root _NET_CLIENT_LIST | grep -o '0x[0-9a-f]\+')
    
    if [ -n "$clients" ]; then
        # Occupied: desktops that have at least one window
        # Filter out 4294967296 (0xFFFFFFFF + 1) which is sticky
        occupied=$(echo "$clients" | xargs -I{} xprop -id {} _NET_WM_DESKTOP 2>/dev/null | awk '{print $3 + 1}' | sort -un | awk '$1 <= 20' | tr '\n' ',' | sed 's/,$//')
        
        # Urgent: desktops that have at least one urgent window
        urgent=$(echo "$clients" | while read -r id; do
            if xprop -id "$id" WM_HINTS 2>/dev/null | grep -q "flags:.*URGENCY"; then
                xprop -id "$id" _NET_WM_DESKTOP 2>/dev/null | awk '{print $3 + 1}'
            fi
        done | sort -un | awk '$1 <= 20' | tr '\n' ',' | sed 's/,$//')
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
