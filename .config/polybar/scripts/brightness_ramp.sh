#!/usr/bin/env bash

# Get brightness percentage
# brightnessctl -m output format: name,type,current,max,percent
PERC=$(brightnessctl -m | cut -d, -f5 | tr -d '%')

# Handle empty output (if brightnessctl fails)
if [ -z "$PERC" ]; then
    echo "Unknown"
    exit 0
fi

# Define ramp icons
ICONS=("󰃞" "󱩎" "󱩏" "󱩐" "󱩑" "󱩒" "󱩓" "󱩔" "󱩕" "󱩖" "󰛨")

# Calculate index (0-10) based on percentage
# 0-9% -> 0, 10-19% -> 1, ..., 100% -> 10
INDEX=$((PERC / 10))
if [ "$INDEX" -gt 10 ]; then INDEX=10; fi

# Output icon and percentage
echo "${ICONS[$INDEX]} $PERC%"
