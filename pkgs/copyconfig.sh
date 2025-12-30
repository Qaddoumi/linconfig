#!/usr/bin/env bash

sourceDir=""
if [[ "$(pwd)" != *"shared"* ]]; then
    sourceDir=~/linconfig
else
    sourceDir=~/shared/github/MyGithubs/linconfig
fi

sudo mkdir -p ~/.config

sudo cp -afr $sourceDir/.config/* ~/.config/
cp -af $sourceDir/.config/.gtkrc-2.0 ~
cp -af $sourceDir/.config/.xscreensaver ~

sudo rm -f ~/.config/mimeinfo.cache || true
sudo rm -f ~/.local/share/applications/mimeinfo.cache || true
sudo update-desktop-database ~/.local/share/applications || true

sudo chmod +x ~/.config/waybar/scripts/*.sh > /dev/null || true
sudo chmod +x ~/.config/quickshell/scripts/*.sh > /dev/null || true
sudo chmod +x ~/.config/sway/scripts/*.sh > /dev/null || true

sudo chown -R $USER:$USER ~/.config > /dev/null || true

cd ~/linconfig/pkgs/dwm || true
sudo make clean install || true

echo -e "\nReloading session with \$mod + Shift + c"