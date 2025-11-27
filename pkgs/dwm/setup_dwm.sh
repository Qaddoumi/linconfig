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
