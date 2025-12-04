#!/usr/bin/env bash

set -e # Exit on error

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
bold="\e[1m"
no_color='\033[0m' # reset the color to default


sudo mkdir -p ~/.config > /dev/null || true
sudo mkdir -p ~/.local/bin > /dev/null || true
sudo mkdir -p ~/.local/share/applications > /dev/null || true

if [ -d ~/configtemp ]; then
    sudo rm -rf ~/configtemp > /dev/null || true
fi
if ! git clone --depth 1 -b quickshell https://github.com/Qaddoumi/linconfig.git ~/configtemp; then
    echo "Failed to clone repository" >&2
    exit 1
fi

echo -e "${green}Copying config files...${no_color}"
sudo cp -rf ~/configtemp/.config/* ~/.config/
sudo cp -f ~/configtemp/.config/mimeapps.list ~/.local/share/applications/

echo -e "${green}Setting up permissions for configuration files${no_color}"
sudo chmod +x ~/.config/waybar/scripts/*.sh > /dev/null || true
sudo chmod +x ~/.config/sway/scripts/*.sh > /dev/null || true

# Save the script (use the first artifact "X11 to Wayland Clipboard Bridge")
echo -e "${green}Setting up clipboard-bridge.sh...${no_color}"
sudo cp -f ~/configtemp/pkgs/clipboard-bridge.sh ~/.local/bin/clipboard-bridge.sh > /dev/null || true
sudo chmod +x ~/.local/bin/clipboard-bridge.sh

echo -e "${green}Setting up ownership for configuration files...${no_color}"
sudo chown -R $USER:$USER ~/.config > /dev/null || true
sudo chown -R $USER:$USER ~/.local > /dev/null || true

echo -e "${green}Setting up oh-my-posh (bash prompt)...${no_color}"
if ! sudo grep -q "source ~/.config/oh-my-posh/gmay.omp.json" ~/.bashrc; then
    echo 'eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/gmay.omp.json)"' | sudo tee -a ~/.bashrc > /dev/null
fi

source ~/.bashrc || true


echo -e "${green}Copying script files...${no_color}"

mkdir -p ~/.local/bin
# Copy both regular files and hidden files (like .xinitrc)
cp -rf ~/configtemp/pkgs/scripts/. ~/.local/bin/ 2>/dev/null || true
find ~/.local/bin/ -maxdepth 1 -type f -exec chmod +x {} +

cd ~

cp -f ~/configtemp/pkgs/installconfig.sh ~/installconfig.sh
chmod +x ~/installconfig.sh

echo -e "${green}Removing temporary files...${no_color}"
sudo rm -rf ~/configtemp

read -p "would you like to reload your session? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [  "$XDG_SESSION_DESKTOP" = "Hyprland" ]; then
        echo -e "${green}Reloading Hyprland...${no_color}"
        hyprctl reload
    elif [  "$XDG_SESSION_DESKTOP" = "sway" ]; then
        echo -e "${green}Reloading Sway...${no_color}"
        swaymsg reload
    elif [  "$XDG_SESSION_DESKTOP" = "awesome" ]; then
        echo -e "${green}Reloading Awesome...${no_color}"
        echo 'awesome.restart()' | awesome-client
    fi
fi

echo -e "${green}\n\nSetup completed!${no_color}\n"