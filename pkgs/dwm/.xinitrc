#!/bin/bash

dbus-run-session -- sh -c '~/.local/share/polybar/launch.sh & exec dwm'
