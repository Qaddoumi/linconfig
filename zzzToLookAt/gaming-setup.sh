#!/usr/bin/env bash

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
bold="\e[1m"
no_color='\033[0m' # reset the color to default

# Check if multilib is enabled (Required for lib32 packages)
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
	printf "%b\n" "${yellow}Enabling multilib repository...${no_color}"
	if grep -q "^#\[multilib\]" /etc/pacman.conf; then
		# Uncomment existing multilib section
		sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
	else
		# Add multilib section if missing
		echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
	fi
else
	printf "%b\n" "${green}Multilib already enabled.${no_color}"
fi

sudo pacman -Syy --noconfirm

# 1. Base Essentials
BASE_DEPS="base-devel wine dbus git steam lutris goverlay"

# 2. 32-bit Libraries (Non-negotiable for Proton/Wine)
LIB32_DEPS="
	lib32-mesa
	lib32-vulkan-icd-loader
	lib32-gnutls
	lib32-gtk3
	lib32-libpulse
	lib32-alsa-lib
	lib32-alsa-plugins
	lib32-giflib
	lib32-libpng
	lib32-libldap
	lib32-libxcomposite
	lib32-libxinerama
	lib32-libgcrypt
	lib32-libgpg-error
	lib32-ncurses
	lib32-mpg123
	lib32-libjpeg-turbo
	lib32-sqlite
	lib32-libva
	lib32-sdl2
	lib32-v4l-utils
	lib32-ocl-icd
	lib32-opencl-icd-loader
	lib32-libxslt
"

# 3. Graphics & Vulkan (Host)
GRAPHICS_DEPS="mesa vulkan-icd-loader libva libxcomposite libxinerama libpng libjpeg-turbo giflib sdl2"

# 4. Audio (Host)
AUDIO_DEPS="alsa-lib alsa-utils alsa-plugins libpulse mpg123"

# 5. Compatibility & Support Libraries
COMPAT_DEPS="
	gnutls
	gtk3
	sqlite
	libxslt
	libldap
	libgcrypt
	libgpg-error
	ncurses
	v4l-utils
	ocl-icd
	opencl-icd-loader
	python-google-auth
	python-protobuf
"

# 6. Optional & Network Features
FEATURE_DEPS="
	gamescope
	mangohud lib32-mangohud
	gamemode lib32-gamemode
	openal lib32-openal
	gst-plugins-base-libs lib32-gst-plugins-base-libs
	cups
	samba
"

printf "%b\n" "${blue}Installing core gaming dependencies...${no_color}"
sudo pacman -S --needed --noconfirm $BASE_DEPS $LIB32_DEPS $GRAPHICS_DEPS $AUDIO_DEPS $COMPAT_DEPS $FEATURE_DEPS

# # 7. GPU-Specific Driver Detection
# printf "%b\n" "${blue}Detecting GPU and installing specific drivers...${no_color}"
# gpu_info=$(lspci | grep -Ei "VGA|3D")

# if echo "$gpu_info" | grep -qi "NVIDIA"; then
# 	printf "%b\n" "${green}NVIDIA GPU detected.${no_color}"
# 	sudo pacman -S --needed --noconfirm nvidia-utils lib32-nvidia-utils
# elif echo "$gpu_info" | grep -qi "AMD"; then
# 	printf "%b\n" "${green}AMD GPU detected.${no_color}"
# 	sudo pacman -S --needed --noconfirm vulkan-radeon lib32-vulkan-radeon
# elif echo "$gpu_info" | grep -qi "Intel"; then
# 	printf "%b\n" "${green}Intel GPU detected.${no_color}"
# 	sudo pacman -S --needed --noconfirm vulkan-intel lib32-vulkan-intel
# else
# 	printf "%b\n" "${red}No specific GPU detected for proprietary/Vulkan drivers. Skipping...${no_color}"
# fi
