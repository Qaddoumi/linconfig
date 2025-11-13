#!/usr/bin/env bash

sudo rm -rf ~/.config/sway ~/.config/waybar ~/.config/wofi ~/.config/kitty ~/.config/swaync \
    ~/.config/kanshi ~/.config/oh-my-posh ~/.config/fastfetch ~/.config/mimeapps.list ~/.local/share/applications/mimeapps.list \
    ~/.config/looking-glass ~/.config/gtk-3.0 ~/.config/gtk-4.0

sudo mkdir -p ~/.config

sudo cp -r ~/projects/linconfig/.config/* ~/.config/
sudo cp -f ~/projects/linconfig/.config/mimeapps.list ~/.local/share/applications/mimeapps.list

sudo chmod +x ~/.config/waybar/scripts/*.sh
sudo chmod +x ~/.config/sway/scripts/*.sh

sudo chown -R $USER:$USER ~/.config
sudo chown -R $USER:$USER ~/.local

swaymsg reload