#!/usr/bin/env bash

set -e # Exit on error

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
no_color='\033[0m' # reset the color to default

echo -e "${yellow}Installing Chaotic-AUR repository...${no_color}"
if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    echo -e "${blue}Chaotic-AUR repository not found. Proceeding with installation...${no_color}"
    # install and enable Chaotic-AUR
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || true
    sudo pacman-key --lsign-key 3056513887B78AEB || true
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' || true
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || true
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf > /dev/null || true
    sudo pacman -Syu --noconfirm || true
    # Print message indicating Chaotic-AUR has been installed and enabled
    echo -e "${green}Chaotic-AUR repository installed and enabled${no_color}"
else
    echo -e "${green}Chaotic-AUR repository already exists. Skipping installation.${no_color}"
fi
