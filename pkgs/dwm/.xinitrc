#!/usr/bin/env bash

dbus-run-session -- sh -c "killall -q quickshell; quickshell; exec dwm"
