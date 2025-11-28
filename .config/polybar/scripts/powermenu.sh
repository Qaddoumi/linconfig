#!/usr/bin/env bash

# Simple power menu using rofi

chosen=$(echo -e "⏻ Shutdown\n Reboot\n⏾ Suspend\n Lock\n Logout" | rofi -dmenu -i -p "Power Menu")

case "$chosen" in
    *Shutdown) systemctl poweroff ;;
    *Reboot) systemctl reboot ;;
    *Suspend) systemctl suspend ;;
    *Lock) 
        if command -v slock &> /dev/null; then
            slock
        elif command -v i3lock &> /dev/null; then
            i3lock
        else
            xscreensaver-command -lock
        fi
        ;;
    *Logout) 
        # For DWM, you might need to adjust this
        pkill -TERM -u "$USER"
        ;;
esac