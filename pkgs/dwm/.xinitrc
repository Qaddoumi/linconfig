#!/usr/bin/env bash

killall quickshell
while pgrep -u $UID -x quickshell >/dev/null; do sleep 1; done

dbus-run-session -- sh -c "quickshell & exec dwm"
