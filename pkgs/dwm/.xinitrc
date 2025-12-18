#!/usr/bin/env bash

export XDG_CURRENT_DESKTOP=dwm
export XDG_SESSION_DESKTOP=dwm
dbus-run-session -- sh -c "exec dwm"