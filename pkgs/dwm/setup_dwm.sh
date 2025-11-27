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

setupDisplayManager() {
    printf "%b\n" "${green}Setting up Xorg${no_color}"
    sudo pacman -S --needed --noconfirm xorg-xinit xorg-server
    printf "%b\n" "${green}Xorg installed successfully${no_color}"
    printf "%b\n" "${green}Setting up Display Manager${no_color}"
    currentdm="none"
    for dm in sddm ly; do
        if command -v "$dm" >/dev/null 2>&1 || sudo systemctl is-active --quiet "$dm"; then
            currentdm="$dm"
            break
        fi
    done
    printf "%b\n" "${green}Display Manager Setup: $currentdm${no_color}"
    if [ "$currentdm" = "none" ] || [ "$currentdm" = "sddm" ]; then
        echo -e "${yellow}Unkonwn display manager${no_color}"
        sudo pacman -S --needed --noconfirm sddm
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"
        sudo systemctl enable sddm
    elif [ "$currentdm" = "ly" ]; then
        sudo pacman -S --needed --noconfirm ly
        sudo systemctl enable ly
    else
        echo -e "${yellow}Unknown display manager${no_color}"
    fi
}

setupDWM() {
    printf "%b\n" "${green}Installing DWM-Titus...${no_color}"
    sudo pacman -S --needed --noconfirm base-devel libx11 libxinerama \
            libxft imlib2 git unzip flameshot nwg-look feh mate-polkit alsa-utils \
            kitty rofi xclip xarchiver thunar tumbler tldr gvfs thunar-archive-plugin \
            dunst dex xscreensaver xorg-xprop polybar pamixer playerctl picom \
            xdg-user-dirs xdg-desktop-portal-gtk pipewire pavucontrol gnome-keyring flatpak \
            networkmanager network-manager-applet
}

makeDWM() {
    mkdir -p "$HOME/.local/share/dwm"
    cd "$HOME/.local/share/dwm"
    sudo make clean install # Run make clean install
}

install_nerd_font() {
    # Check to see if the MesloLGS Nerd Font is installed (Change this to whatever font you would like)
    FONT_NAME="MesloLGS Nerd Font Mono"
    FONT_DIR="$HOME/.local/share/fonts"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
    FONT_INSTALLED=$(fc-list | grep -i "Meslo")

    if [ -n "$FONT_INSTALLED" ]; then
        printf "%b\n" "${GREEN}Meslo Nerd-fonts are already installed.${no_color}"
        return 0
    fi

    printf "%b\n" "${YELLOW}Installing Meslo Nerd-fonts${no_color}"

    # Create the fonts directory if it doesn't exist
    if [ ! -d "$FONT_DIR" ]; then
        mkdir -p "$FONT_DIR" || {
            printf "%b\n" "${RED}Failed to create directory: $FONT_DIR${no_color}"
            return 1
        }
    fi

    printf "%b\n" "${YELLOW}Installing font '$FONT_NAME'${no_color}"
    # Change this URL to correspond with the correct font
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
    FONT_DIR="$HOME/.local/share/fonts"
    TEMP_DIR=$(mktemp -d)
    curl -sSLo "$TEMP_DIR"/"${FONT_NAME}".zip "$FONT_URL"
    unzip "$TEMP_DIR"/"${FONT_NAME}".zip -d "$TEMP_DIR"
    mkdir -p "$FONT_DIR"/"$FONT_NAME"
    mv "${TEMP_DIR}"/*.ttf "$FONT_DIR"/"$FONT_NAME"
    fc-cache -fv
    rm -rf "${TEMP_DIR}"
    printf "%b\n" "${GREEN}'$FONT_NAME' installed successfully.${no_color}"
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




setupDisplayManager
setupDWM
makeDWM
install_nerd_font
configure_backgrounds