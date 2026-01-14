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

pkgs=(
	"base-devel" # Basic tools to build Arch Linux packages
	"wine" # A compatibility layer for running Windows programs
	"dbus" # Freedesktop.org message bus system
	"git" # the fast distributed version control system
	"steam" # Valve's digital software delivery system
	"lutris" # Open Gaming Platform
	"goverlay" # A GUI to help manage Vulkan/OpenGL overlays

	"libxcomposite" "lib32-libxcomposite" # X11 Composite extension library
	"libxinerama" "lib32-libxinerama" # X11 Xinerama extension library

	"libpng" "lib32-libpng" # A collection of routines used to create PNG format graphics files
	"libjpeg-turbo" "lib32-libjpeg-turbo" # JPEG image codec with accelerated baseline compression and decompression
	"giflib" "lib32-giflib" # Library for reading and writing gif images

	"sdl2-compat" "lib32-sdl2-compat" # library for portable low-level access to a video framebuffer, audio output, mouse, and keyboard (Version 2)

	"alsa-lib" "lib32-alsa-lib" # An alternative implementation of Linux sound support
	"alsa-utils" "lib32-alsa-utils" # Advanced Linux Sound Architecture - Utilities
	"alsa-plugins" "lib32-alsa-plugins" # Additional ALSA plugins
	"libpulse" "lib32-libpulse" # A featureful, general-purpose sound server (client library)
	"mpg123" "lib32-mpg123" # Console based real time MPEG Audio Player for Layer 1, 2 and 3

	"gnutls" "lib32-gnutls" # A library which provides a secure layer over a reliable transport layer
	"gtk3" "lib32-gtk3" # GObject-based multi-platform GUI toolkit
	"sqlite" "lib32-sqlite" # A C library that implements an SQL database engine
	"libxslt" "lib32-libxslt" # XML stylesheet transformation library
	"libldap" "lib32-libldap" # Lightweight Directory Access Protocol (LDAP) client libraries
	"libgcrypt" "lib32-libgcrypt" # General purpose cryptographic library based on the code from GnuPG
	"libgpg-error" "lib32-libgpg-error" # Support library for libgcrypt
	"ncurses" "lib32-ncurses" # System V Release 4.0 curses emulation library
	"v4l-utils" "lib32-v4l-utils" # Userspace tools and conversion library for Video 4 Linux
	"ocl-icd" "lib32-ocl-icd" # OpenCL ICD Bindings
	"python-google-auth" # Google Authentication Library
	"python-protobuf" # Python 3 bindings for Google Protocol Buffers

	"gamescope" # SteamOS session compositing window manager
	"mangohud" "lib32-mangohud" # A Vulkan overlay layer for monitoring FPS, temperatures, CPU/GPU load and more.
	"gamemode" "lib32-gamemode" # A daemon/lib combo that allows games to request a set of optimisations be temporarily applied to the host OS
	"openal" "lib32-openal" # Cross-platform 3D audio library, software implementation
	"gst-plugins-base-libs" "lib32-gst-plugins-base-libs" # Multimedia graph framework - base
	"cups" # OpenPrinting CUPS - daemon package
	"samba" # SMB Fileserver and AD Domain server
)

printf "%b\n" "${blue}Installing core gaming dependencies...${no_color}"
sudo pacman -S --needed --noconfirm "${pkgs[@]}"

## GPU-Specific Driver Detection
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
