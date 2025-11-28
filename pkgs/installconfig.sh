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


update_dwm="true"

case "$1" in
    --update-dwm)
        update_dwm="$2"
        shift 2
        ;;
    *)
        echo -e "${red}Unknown argument: $1${no_color}"
        # exit 1
        ;;
esac


sudo mkdir -p ~/.config > /dev/null || true
sudo mkdir -p ~/.local/bin > /dev/null || true
sudo mkdir -p ~/.local/share/applications > /dev/null || true

if [ -d ~/configtemp ]; then
    sudo rm -rf ~/configtemp > /dev/null || true
fi
if ! git clone --depth 1 https://github.com/Qaddoumi/linconfig.git ~/configtemp; then
    echo "Failed to clone repository" >&2
    exit 1
fi

# Remove existing config files/directories that are in the cloned repo
echo -e "${blue}Removing existing config files that will be replaced...${no_color}"
for item in ~/configtemp/.config/*; do
    if [ -e "$item" ]; then
        basename_item=$(basename "$item")
        echo -e "${blue}Removing $basename_item...${no_color}"
        sudo rm -rf ~/.config/"$basename_item"
    fi
done

# Also remove mimeapps.list from .local/share/applications if it exists in the repo
if [ -f ~/configtemp/.config/mimeapps.list ]; then
    echo -e "${blue}Removing mimeapps.list...${no_color}"
    sudo rm -rf ~/.local/share/applications/mimeapps.list ~/.config/mimeapps.list
fi

echo -e "${green}Copying config files...${no_color}"
sudo cp -r ~/configtemp/.config/* ~/.config/
sudo cp -f ~/configtemp/.config/mimeapps.list ~/.local/share/applications/

echo -e "${green}Setting up permissions for configuration files${no_color}"
sudo chmod +x ~/.config/waybar/scripts/*.sh > /dev/null || true
sudo chmod +x ~/.config/rofi/*.sh > /dev/null || true
sudo chmod +x ~/.config/sway/scripts/*.sh > /dev/null || true
sudo chmod +x ~/.config/polybar/scripts/*.sh > /dev/null || true

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

echo -e "${green}Setting up polybar (launch script)...${no_color}"
# Ensure Polybar launch script is executable
chmod +x ~/.config/polybar/launch.sh

if [ "$update_dwm" = "true" ]; then
    echo -e "${green}Installing dwm...${no_color}"
    mkdir -p ~/.local/share/dwm
    mkdir -p ~/.local/bin
    cp -rf ~/configtemp/pkgs/dwm/* ~/.local/share/dwm
    cp -rf "$HOME/.local/share/dwm/scripts/." "$HOME/.local/bin/"
    rm -rf "$HOME/.local/share/dwm/scripts"
    cd ~/.local/share/dwm
    echo -e "${green}Building dwm...${no_color}"
    sudo make clean install
fi

echo -e "${green}Removing temporary files...${no_color}"
sudo rm -rf ~/configtemp

#swaymsg reload

echo -e "${green}Setup completed!${no_color}"