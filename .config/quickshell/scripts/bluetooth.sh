#!/usr/bin/env bash
# Bluetooth status script

# Check if bluetooth is powered
get_bluetooth_power() {
    bluetoothctl show | grep "Powered:" | awk '{print $2}'
}

# Get controller info
get_controller_info() {
    local info
    info=$(bluetoothctl show)
    local name alias powered discoverable
    
    name=$(echo "$info" | grep "Name:" | cut -d':' -f2- | xargs)
    alias=$(echo "$info" | grep "Alias:" | cut -d':' -f2- | xargs)
    powered=$(echo "$info" | grep "Powered:" | awk '{print $2}')
    discoverable=$(echo "$info" | grep "Discoverable:" | awk '{print $2}')
    
    echo "$name|$alias|$powered|$discoverable"
}

# Get connected devices
get_connected_devices() {
    local devices=""
    local device_count=0
    
    # Get list of paired devices
    while IFS= read -r line; do
        if [[ "$line" =~ ^Device\ ([0-9A-F:]+)\ (.+)$ ]]; then
            local mac="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]}"
            
            # Check if device is connected
            local device_info
            device_info=$(bluetoothctl info "$mac" 2>/dev/null)
            
            if echo "$device_info" | grep -q "Connected: yes"; then
                # Get battery if available
                local battery=""
                battery=$(echo "$device_info" | grep "Battery Percentage:" | awk -F'[()]' '{print $2}')
                
                # Get device type/icon
                local icon=""
                if echo "$device_info" | grep -qi "audio"; then
                    icon="󰋋"  # Headphones
                elif echo "$device_info" | grep -qi "input"; then
                    if echo "$device_info" | grep -qi "keyboard"; then
                        icon="󰌌"  # Keyboard
                    elif echo "$device_info" | grep -qi "mouse"; then
                        icon="󰍽"  # Mouse
                    else
                        icon="󰌌"  # Generic input
                    fi
                elif echo "$device_info" | grep -qi "phone"; then
                    icon="󰄜"  # Phone
                else
                    icon="󰂯"  # Generic bluetooth
                fi
                
                if [ $device_count -gt 0 ]; then
                    devices="${devices},"
                fi
                
                devices="${devices}{\"name\":\"${name}\",\"mac\":\"${mac}\",\"battery\":\"${battery:-}\",\"icon\":\"${icon}\"}"
                device_count=$((device_count + 1))
            fi
        fi
    done < <(bluetoothctl devices 2>/dev/null)
    
    echo "$devices"
    return $device_count
}

# Main logic
main() {
    # Check if bluetooth service is running
    if ! systemctl is-active --quiet bluetooth.service; then
        echo '{"powered": false, "controller": "", "deviceCount": 0, "devices": [], "icon": "󰂲", "status": "disabled"}'
        exit 0
    fi
    
    # Get controller info
    IFS='|' read -r name alias powered discoverable <<< "$(get_controller_info)"
    
    # Check if powered
    if [ "$powered" != "yes" ]; then
        echo '{"powered": false, "controller": "'"$alias"'", "deviceCount": 0, "devices": [], "icon": "󰂲", "status": "off"}'
        exit 0
    fi
    
    # Get connected devices
    local devices_json
    devices_json=$(get_connected_devices)
    local device_count=$?
    
    # Determine icon and status
    local icon status
    if [ $device_count -gt 0 ]; then
        icon="󰂯"  # Bluetooth connected
        status="connected"
    else
        icon="󰂯"  # Bluetooth on but not connected
        status="on"
    fi
    
    # Output JSON
    cat <<EOF
{"powered": true, "controller": "$alias", "deviceCount": $device_count, "devices": [$devices_json], "icon": "$icon", "status": "$status", "discoverable": $([ "$discoverable" = "yes" ] && echo "true" || echo "false")}
EOF
}

main