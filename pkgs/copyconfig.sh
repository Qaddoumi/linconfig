#!/usr/bin/env bash

sudo mkdir -p ~/.config

sudo cp -afr ~/shared/github/MyGithubs/linconfig/.config/* ~/.config/
sudo mkdir -p ~/.local/share/applications/
sudo cp -f ~/shared/github/MyGithubs/linconfig/.config/mimeapps.list ~/.local/share/applications/

sudo chmod +x ~/.config/waybar/scripts/*.sh > /dev/null || true
sudo chmod +x ~/.config/quickshell/scripts/*.sh > /dev/null || true
sudo chmod +x ~/.config/sway/scripts/*.sh > /dev/null || true

sudo chown -R $USER:$USER ~/.config > /dev/null || true
sudo chown -R $USER:$USER ~/.local > /dev/null || true

swaymsg reload