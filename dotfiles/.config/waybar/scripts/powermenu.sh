#!/usr/bin/env bash

# CMDs
uptime="`uptime -p | sed -e 's/up //g'`"

entries="⏻ Shutdown\n↻ Reboot\n⏽ Hibernate\n⇠ Logout\n🔒 Lock"
if [[ -n "$WAYLAND_DISPLAY" ]]; then
  selected=$(echo -e "$entries" | wofi --dmenu --cache-file /dev/null --hide-scroll --style ~/.config/wofi/powermenu.css --prompt "Uptime: $uptime" --width 100% --height 100% --columns 3)
else
  selected=$(echo -e "$entries" | rofi -dmenu -p "Uptime: $uptime" -width 250 -lines 5 -location 0 -theme ~/.config/rofi/powermenu.rasi)
fi


case $selected in
  "⇠ Logout")
    case "$DESKTOP_SESSION" in
      openbox)
        openbox --exit
        ;;
      bspwm)
        bspc quit
        ;;
      dwm)
        pkill dwm
        ;;
      i3)
        i3-msg exit
        ;;
      plasma)
        qdbus org.kde.ksmserver /KSMServer logout 0 0 0
        ;;
      sway)
        swaymsg exit
        ;;
      hyprland)
        hyprctl dispatch exit
        ;;
      awesome)
        echo 'awesome.quit()' | awesome-client
        ;;
		esac
    ;;
  # "⏾ Suspend")
  #   mpc -q pause
  #   pactl set-sink-mute @DEFAULT_SINK@ 1
  #   systemctl suspend;;
  "⏽ Hibernate")
    systemctl hibernate;;
  "↻ Reboot")
    systemctl reboot;;
  "⏻ Shutdown")
    systemctl poweroff;;
  "🔒 Lock")
    if command -v swaylock &> /dev/null; then
      swaylock \
          --color 2d353b \
          --inside-color 3a454a \
          --inside-clear-color 5c6a72 \
          --inside-ver-color 5a524c \
          --inside-wrong-color 543a3a \
          --ring-color 7a8478 \
          --ring-clear-color a7c080 \
          --ring-ver-color dbbc7f \
          --ring-wrong-color e67e80 \
          --key-hl-color d699b6 \
          --bs-hl-color e69875 \
          --separator-color 2d353b \
          --text-color d3c6aa \
          --text-clear-color d3c6aa \
          --text-ver-color d3c6aa \
          --text-wrong-color d3c6aa \
          --indicator-radius 100 \
          --indicator-thickness 10 \
          --font "JetBrainsMono Nerd Font Propo"
    elif command -v slock &> /dev/null; then
      slock
    elif command -v i3lock &> /dev/null; then
      i3lock
    else
      xscreensaver-command -lock
    fi
    ;;
esac