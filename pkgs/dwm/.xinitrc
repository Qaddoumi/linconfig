#!/usr/bin/env bash

screensetup &
killall -q quickshell &
quickshell &

dbus-run-session -- sh -c "exec dwm"
