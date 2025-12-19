#!/usr/bin/env bash

# Check for xprop
if ! command -v xprop >/dev/null 2>&1; then
    echo "Error: xprop is not installed or not in PATH."
    exit 1
fi

echo "=== EWMH Desktop Properties ==="

num_desktops=$(xprop -root _NET_NUMBER_OF_DESKTOPS | awk '{print $3}')
current_desktop=$(xprop -root _NET_CURRENT_DESKTOP | awk '{print $3}')
desktop_names=$(xprop -root _NET_DESKTOP_NAMES | sed 's/.*= //')

echo "Number of desktops: ${num_desktops:-N/A}"
echo "Current desktop index: ${current_desktop:-N/A} (1-based: $((${current_desktop:-0} + 1)))"
echo "Desktop names: ${desktop_names:-N/A}"

echo -e "\n=== Active Window Info ==="
active_window_id=$(xprop -root _NET_ACTIVE_WINDOW | awk '{print $5}')
if [ "$active_window_id" != "0x0" ] && [ -n "$active_window_id" ]; then
    echo "Active Window ID: $active_window_id"
    active_window_name=$(xprop -id "$active_window_id" _NET_WM_NAME | sed 's/.*= "//;s/"$//')
    active_window_class=$(xprop -id "$active_window_id" WM_CLASS | sed 's/.*= //')
    echo "Active Window Name: $active_window_name"
    echo "Active Window Class: $active_window_class"
else
    echo "No active window found."
fi

echo -e "\n=== Occupied Desktops ==="
# Get desktops of all clients
if command -v wmctrl >/dev/null 2>&1; then
    echo "Occupied desktops (via wmctrl):"
    wmctrl -l | awk '{print $2 + 1}' | sort -u | tr '\n' ' '
    echo
else
    echo "Occupied desktops (via xprop):"
    xprop -root _NET_CLIENT_LIST | grep -o '0x[0-9a-f]\+' | while read -r id; do
        xprop -id "$id" _NET_WM_DESKTOP 2>/dev/null | awk '{print $3 + 1}'
    done | sort -nu | tr '\n' ' '
    echo
fi

echo -e "\n=== Urgent Windows ==="
xprop -root _NET_CLIENT_LIST | grep -o '0x[0-9a-f]\+' | while read -r id; do
    if xprop -id "$id" WM_HINTS 2>/dev/null | grep -q "flags:.*URGENCY"; then
        desktop=$(xprop -id "$id" _NET_WM_DESKTOP 2>/dev/null | awk '{print $3 + 1}')
        echo "Window $id is URGENT on desktop ${desktop:-N/A}"
    fi
done
