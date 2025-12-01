#!/usr/bin/env bash

killall waybar
while pgrep -u $UID -x waybar >/dev/null; do sleep 1; done

dbus-run-session -- sh -c "waybar & exec dwm"
