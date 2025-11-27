#!/bin/bash
# You'll need to customize this with your actual prayer times API or calculation
# This is a placeholder - replace with your actual prayer times script

if [ "$1" = "full" ]; then
    echo "Fajr: 05:30
Dhuhr: 12:45
Asr: 16:00
Maghrib: 18:30
Isha: 20:00"
else
    # Get current time
    current_hour=$(date +%H)
    current_min=$(date +%M)
    
    # Simple example - replace with actual prayer time calculation
    if [ $current_hour -lt 5 ]; then
        echo " Fajr in $(( (5 - current_hour) ))h"
    elif [ $current_hour -lt 12 ]; then
        echo " Dhuhr in $(( (12 - current_hour) ))h"
    elif [ $current_hour -lt 16 ]; then
        echo " Asr in $(( (16 - current_hour) ))h"
    elif [ $current_hour -lt 18 ]; then
        echo " Maghrib in $(( (18 - current_hour) ))h"
    else
        echo " Isha in $(( (20 - current_hour) ))h"
    fi
fi