#!/usr/bin/env bash

dbus-run-session -- sh -c "$HOME/.config/polybar/launch.sh & exec dwm"
