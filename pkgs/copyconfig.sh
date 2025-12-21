#!/usr/bin/env bash

sudo mkdir -p ~/.config

sudo cp -afr ~/shared/github/MyGithubs/linconfig/.config/* ~/.config/
cp -af ~/shared/github/MyGithubs/linconfig/.config/.gtkrc-2.0 ~
cp -af ~/shared/github/MyGithubs/linconfig/.config/.xscreensaver ~

sudo rm -f ~/.config/mimeinfo.cache || true
sudo rm -f ~/.local/share/applications/mimeinfo.cache || true
sudo update-desktop-database ~/.local/share/applications || true

sudo chmod +x ~/.config/waybar/scripts/*.sh > /dev/null || true
sudo chmod +x ~/.config/quickshell/scripts/*.sh > /dev/null || true
sudo chmod +x ~/.config/sway/scripts/*.sh > /dev/null || true

sudo chown -R $USER:$USER ~/.config > /dev/null || true

echo -e "${green}\n\nReloading session...${no_color}"
if [  "$XDG_SESSION_DESKTOP" = "Hyprland" ]; then
    echo -e "${green}Reloading Hyprland...${no_color}"
    hyprctl reload > /dev/null || true
elif [  "$XDG_SESSION_DESKTOP" = "sway" ]; then
    echo -e "${green}Reloading Sway...${no_color}"
    swaymsg reload > /dev/null || true
elif [  "$XDG_SESSION_DESKTOP" = "awesome" ]; then
    echo -e "${green}Reloading Awesome...${no_color}"
    echo 'awesome.restart()' | awesome-client > /dev/null || true
fi