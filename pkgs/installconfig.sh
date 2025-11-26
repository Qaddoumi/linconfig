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

if [ -z "$1" ]; then
    echo "Usage: $0 <window-manager>"
    # exit 1
fi

case "$1" in
    --window-manager)
        window_manager="$2"
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

if [ -d ~/swaytemp ]; then
    sudo rm -rf ~/swaytemp > /dev/null || true
fi
if ! git clone --depth 1 https://github.com/Qaddoumi/linconfig.git ~/swaytemp; then
    echo "Failed to clone repository" >&2
    exit 1
fi
sudo rm -rf ~/.config/sway ~/.config/waybar ~/.config/wofi ~/.config/kitty ~/.config/swaync \
    ~/.config/kanshi ~/.config/oh-my-posh ~/.config/fastfetch ~/.config/mimeapps.list ~/.local/share/applications/mimeapps.list \
    ~/.config/looking-glass ~/.config/gtk-3.0 ~/.config/gtk-4.0 ~/.config/tmux \
    ~/.config/xfce4/ ~/.config/Thunar

sudo cp -r ~/swaytemp/.config/* ~/.config/
sudo cp -f ~/swaytemp/.config/mimeapps.list ~/.local/share/applications/

echo -e "${green}Setting up permissions for configuration files${no_color}"
sudo chmod +x ~/.config/waybar/scripts/*.sh > /dev/null || true
sudo chmod +x ~/.config/sway/scripts/*.sh > /dev/null || true

# Save the script (use the first artifact "X11 to Wayland Clipboard Bridge")
sudo cp -f ~/swaytemp/pkgs/clipboard-bridge.sh ~/.local/bin/clipboard-bridge.sh > /dev/null || true
sudo chmod +x ~/.local/bin/clipboard-bridge.sh

sudo chown -R $USER:$USER ~/.config > /dev/null || true
sudo chown -R $USER:$USER ~/.local > /dev/null || true


if ! sudo grep -q "source ~/.config/oh-my-posh/gmay.omp.json" ~/.bashrc; then
    echo 'eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/gmay.omp.json)"' | sudo tee -a ~/.bashrc > /dev/null
fi

source ~/.bashrc || true

sudo rm -rf ~/swaytemp

#swaymsg reload
