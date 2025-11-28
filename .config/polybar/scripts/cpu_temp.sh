#!/usr/bin/env bash

temp=$(sensors | grep 'Package id 0:' | awk '{print $4}' | sed 's/+//;s/°C//')

if [ -z "$temp" ]; then
    # Fallback to other temp reading methods
    temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    if [ -n "$temp" ]; then
        temp=$((temp / 1000))
    else
        echo "N/A"
        exit 0
    fi
fi

# Remove decimal if present
temp=${temp%.*}

echo "${temp}°C"