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



# Set the variable PIC_DIR which stores the path for images
PIC_DIR="$HOME/Pictures"

# Set the variable BG_DIR to the path where backgrounds will be stored
BG_DIR="$PIC_DIR/backgrounds"

mkdir ~/Pictures

# Check if the backgrounds directory (BG_DIR) exists
if [ ! -d "$BG_DIR" ]; then
	# If the backgrounds directory doesn't exist, attempt to clone a repository containing backgrounds
	if ! git clone --depth 1 https://github.com/ChrisTitusTech/nord-background.git "$PIC_DIR/backgrounds"; then
		# If the git clone command fails, print an error message and return with a status of 1
		printf "%b\n" "${red}Failed to clone the repository${no_color}"
		return 1
	fi
	# Print a success message indicating that the backgrounds have been downloaded
	printf "%b\n" "${green}Downloaded desktop backgrounds to $BG_DIR${no_color}"	
else
	# If the backgrounds directory already exists, print a message indicating that the download is being skipped
	printf "%b\n" "${yellow}Path $BG_DIR exists for desktop backgrounds, skipping download of backgrounds${no_color}"
fi