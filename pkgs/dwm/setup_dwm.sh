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


setupDWM() {
    printf "%b\n" "${green}Installing DWM...${no_color}"
    sudo pacman -S --needed --noconfirm xorg-xinit xorg-server
    sudo pacman -S --needed --noconfirm base-devel libx11 libxinerama \
            libxft imlib2 git unzip flameshot nwg-look feh mate-polkit alsa-utils \
            kitty rofi xclip xarchiver thunar tumbler tldr gvfs thunar-archive-plugin \
            dunst dex xscreensaver xorg-xprop polybar pamixer playerctl picom \
            xdg-user-dirs xdg-desktop-portal-gtk pipewire pavucontrol gnome-keyring flatpak \
            networkmanager network-manager-applet
    mkdir -p "$HOME/.local/share/dwm"
    cd "$HOME/.local/share/dwm"
    sudo make clean install # Run make clean install
}

configure_backgrounds() {
    # Set the variable PIC_DIR which stores the path for images
    PIC_DIR="$HOME/Pictures"

    # Set the variable BG_DIR to the path where backgrounds will be stored
    BG_DIR="$PIC_DIR/backgrounds"

    # Check if the ~/Pictures directory exists
    if [ ! -d "$PIC_DIR" ]; then
        # If it doesn't exist, print an error message and return with a status of 1 (indicating failure)
        printf "%b\n" "${RED}Pictures directory does not exist${no_color}"
        mkdir ~/Pictures
        printf "%b\n" "${GREEN}Directory was created in Home folder${no_color}"
    fi

    # Check if the backgrounds directory (BG_DIR) exists
    if [ ! -d "$BG_DIR" ]; then
        # If the backgrounds directory doesn't exist, attempt to clone a repository containing backgrounds
        if ! git clone --depth 1 https://github.com/ChrisTitusTech/nord-background.git "$PIC_DIR/backgrounds"; then
            # If the git clone command fails, print an error message and return with a status of 1
            printf "%b\n" "${RED}Failed to clone the repository${no_color}"
            return 1
        fi
        # Print a success message indicating that the backgrounds have been downloaded
        printf "%b\n" "${GREEN}Downloaded desktop backgrounds to $BG_DIR${no_color}"    
    else
        # If the backgrounds directory already exists, print a message indicating that the download is being skipped
        printf "%b\n" "${GREEN}Path $BG_DIR exists for desktop backgrounds, skipping download of backgrounds${no_color}"
    fi
}



setupDWM
configure_backgrounds