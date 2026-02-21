#!/usr/bin/env bash


find_keyboard() {
    for dev in /sys/class/input/event*; do
        name=$(cat "$dev/device/name" 2>/dev/null)
        # Check if device has both LEDs and keys (capabilities)
        if [ -f "$dev/device/capabilities/led" ] && [ -f "$dev/device/capabilities/key" ]; then
            led=$(cat "$dev/device/capabilities/led")
            key=$(cat "$dev/device/capabilities/key")
            # Skip if led or key capability is all zeros
            if [ "$led" != "0" ] && [ "$key" != "0" ]; then
                echo "/dev/input/$(basename $dev) $name"
                return
            fi
        fi
    done
}

read -r devpath devname <<< "$(find_keyboard)"

if [ -z "$devpath" ]; then
    echo "No keyboard found"
    exit 1
fi

# echo "Device: $devname ($devpath)"

# Read LED states from /sys
sysdev="/sys/class/input/$(basename $devpath)"

get_led() {
    local ledname="$1"
    if [ -f "/sys/class/leds/${ledname}/brightness" ]; then
        brightness=$(cat "/sys/class/leds/${ledname}/brightness")
        [ "$brightness" -gt 0 ] && echo "ON" || echo "OFF"
    else
        # fallback: check all led entries
        for f in /sys/class/leds/*/brightness; do
            dir=$(dirname "$f")
            name=$(basename "$dir")
            if [[ "$name" == *"$ledname"* ]]; then
                brightness=$(cat "$f")
                [ "$brightness" -gt 0 ] && echo "ON" || echo "OFF"
                return
            fi
        done
        echo "UNKNOWN"
    fi
}

# LED names vary by distro/kernel, common patterns:
numlock=$(get_led "numlock" || get_led "num_lock")
capslock=$(get_led "capslock" || get_led "caps_lock")
scrolllock=$(get_led "scrolllock" || get_led "scroll_lock")

echo "{\"numlock\":\"$numlock\", \"capslock\":\"$capslock\", \"scrolllock\":\"$scrolllock\"}"