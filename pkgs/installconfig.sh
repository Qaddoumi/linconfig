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


if [ -d ~/linconfig ]; then
    echo -e "${green}Removing the old repo directory...${no_color}"
    sudo rm -rf ~/linconfig > /dev/null || true
fi
echo -e "${green}Cloning the repository...${no_color}"
if ! git clone --depth 1 -b main https://github.com/Qaddoumi/linconfig.git ~/linconfig; then
    echo "Failed to clone repository" >&2
    exit 1
fi

echo -e "${green}Copying config files...${no_color}"
sudo cp -arf ~/linconfig/dotfiles/. ~

echo -e "${green}Removing mimeinfo cache...${no_color}"
sudo rm -f ~/.config/mimeinfo.cache ~/.local/share/applications/mimeinfo.cache || true
sudo update-desktop-database ~/.local/share/applications || true

echo -e "${green}Setting up permissions for configuration files${no_color}"
sudo chmod +x ~/.config/waybar/scripts/*.sh > /dev/null || true
sudo chmod +x ~/.config/quickshell/scripts/*.sh > /dev/null || true
find ~/.local/bin/ -maxdepth 1 -type f -exec chmod +x {} +

echo -e "${green}Setting up ownership for configuration files...${no_color}"
sudo chown -R $USER:$USER ~/.config > /dev/null || true
sudo chown -R $USER:$USER ~/.local > /dev/null || true
sudo chown $USER:$USER ~/.gtkrc-2.0 > /dev/null || true
sudo chown $USER:$USER ~/.xscreensaver > /dev/null || true

echo -e "${green}Setting up oh-my-posh (bash prompt)...${no_color}"
if ! sudo grep -q "source ~/.config/oh-my-posh/gmay.omp.json" ~/.bashrc; then
    echo 'eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/gmay.omp.json)"' | sudo tee -a ~/.bashrc > /dev/null
fi

source ~/.bashrc || true


echo -e "${green}Copy the installconfig.sh script${no_color}"
cp -af ~/linconfig/pkgs/installconfig.sh ~/installconfig.sh
chmod +x ~/installconfig.sh

# echo -e "${green}Removing temporary files...${no_color}"
# sudo rm -rf ~/linconfig

echo -e "${green}\nInstalling dwm...${no_color}"
cd ~/.local/share/dwm
sudo make clean install || true

cd ~

echo -e "${green}\nReload session with \$mod + Shift + c${no_color}"

# sudo rm -rf ~/linconfig > /dev/null || true

echo -e "${green}\nSetup completed!${no_color}\n"