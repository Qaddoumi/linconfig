#!/bin/bash
if [ "$1" = "full" ]; then
    # Full output for notifications
    date +"%d %B %Y" --date="$(date -d '+622 years +10 days' +%Y-%m-%d)"
else
    # Short output for bar
    date +"%d/%m/%Y" --date="$(date -d '+622 years +10 days' +%Y-%m-%d)"
fi