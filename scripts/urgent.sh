#!/usr/bin/env bash

# urgency monitor - automatically sets urgency when windows request focus on inactive workspaces
# and trigger urgency on new windows because many modern applications (like browsers) only send the
# _NET_WM_STATE_DEMANDS_ATTENTION , WM_HINTS urgency and WM_STATE urgency
# signals if they detect that the Window Manager supports it.


# Check dependencies
if ! command -v xprop >/dev/null 2>&1; then
    echo "Error: xprop not found"
    exit 1
fi
if ! command -v xdotool >/dev/null 2>&1; then
    echo "Error: xdotool not found"
    exit 1
fi

# Check if window already has urgency
has_urgency() {
    local wid=$1
    if xprop -id "$wid" WM_HINTS 2>/dev/null | grep -qi "urgency"; then
        return 0
    fi
    if xprop -id "$wid" _NET_WM_STATE 2>/dev/null | grep -q "_NET_WM_STATE_DEMANDS_ATTENTION"; then
        return 0
    fi
    return 1
}

echo "Starting urgency monitor..."

# Track previously seen windows to detect new windows
declare -A seen_windows

# Monitor X events
xprop -root -spy _NET_ACTIVE_WINDOW _NET_CLIENT_LIST 2>/dev/null | while read -r line; do
    # When _NET_ACTIVE_WINDOW changes or new clients appear
    if [[ "$line" == *"_NET_ACTIVE_WINDOW"* ]] || [[ "$line" == *"_NET_CLIENT_LIST"* ]]; then
        current_desktop=$(xprop -root _NET_CURRENT_DESKTOP 2>/dev/null | awk '{print $3}')
        
        # Get all client windows
        clients=$(xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -o '0x[0-9a-f]\+')
        
        for wid in $clients; do
            # Skip if we've already processed this window recently
            if [[ -n "${seen_windows[$wid]}" ]]; then
                continue
            fi
            
            # Mark window as seen
            seen_windows[$wid]=1
            
            # Get window's desktop
            win_desktop=$(xprop -id "$wid" _NET_WM_DESKTOP 2>/dev/null | awk '{print $3}')
            
            # Skip sticky windows (4294967295) and windows on current desktop
            if [[ "$win_desktop" == "4294967295" ]] || [[ "$win_desktop" == "$current_desktop" ]]; then
                continue
            fi
            
            # Check if this is a newly mapped window or one requesting focus
            # If it's on a different desktop and not already urgent, set urgency
            if ! has_urgency "$wid"; then
                echo "Setting urgency for window $wid on desktop $win_desktop (current: $current_desktop)"
                xdotool set_window --urgency 1 "$wid" 2>/dev/null
            fi
        done
        
        # Clean up seen_windows periodically to prevent memory bloat
        if [[ ${#seen_windows[@]} -gt 100 ]]; then
            declare -A new_seen
            for wid in $clients; do
                new_seen[$wid]=1
            done
            seen_windows=()
            for key in "${!new_seen[@]}"; do
                seen_windows[$key]=1
            done
        fi
    fi
done