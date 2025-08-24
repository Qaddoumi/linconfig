#!/usr/bin/env bash

# CPU Temperature Waybar Module Script
# Save as ~/.config/waybar/scripts/cpu_temp.sh
# Make executable: chmod +x ~/.config/waybar/scripts/cpu_temp.sh

get_cpu_temp() {
    # Get the main CPU temperature (usually the first Package or Core temp found)
    # Redirect stderr to /dev/null to avoid error messages
    local temp=$(sensors 2>/dev/null | grep -E "(Package|Core|Tctl|CPU)" | head -1 | grep -oE '\+[0-9]+\.[0-9]+°C' | head -1 | sed 's/+//')
    
    # Fallback: try to get any temperature reading
    if [ -z "$temp" ]; then
        temp=$(sensors 2>/dev/null | grep -oE '\+[0-9]+\.[0-9]+°C' | head -1 | sed 's/+//')
    fi
    
    # If still no temp found, show error
    if [ -z "$temp" ]; then
        echo "N/A"
    else
        echo "$temp"
    fi
}

get_full_sensors() {
    # Get full sensors output and format for tooltip
    # Filter out ERROR lines, redirect stderr to /dev/null, and properly escape for JSON
    sensors 2>/dev/null | grep -v "^ERROR:" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//'
}

case $1 in
    --temp)
        get_cpu_temp
        ;;
    --tooltip)
        get_full_sensors
        ;;
    *)
        # Default output for waybar (JSON format)
        temp=$(get_cpu_temp)
        tooltip=$(get_full_sensors)
        
        # Extract numeric value for CSS classes
        temp_num=$(echo "$temp" | grep -oE '[0-9]+' | head -1)
        
        # Determine CSS class based on temperature
        if [ -n "$temp_num" ]; then
            if [ "$temp_num" -lt 50 ]; then
                class="cool"
            elif [ "$temp_num" -lt 70 ]; then
                class="warm"
            elif [ "$temp_num" -lt 85 ]; then
                class="hot"
            else
                class="critical"
            fi
        else
            class="unknown"
        fi
        
        # Output JSON for Waybar
        echo "{\"text\":\"$temp\",\"tooltip\":\"$tooltip\",\"class\":\"$class\"}"
        ;;
esac