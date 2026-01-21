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

for tool in sudo doas pkexec; do
	if command -v "${tool}" >/dev/null 2>&1; then
		ESCALATION_TOOL="${tool}"
		echo -e "${cyan}Using ${tool} for privilege escalation${no_color}"
		break
	fi
done
if [ -z "${ESCALATION_TOOL}" ]; then
	echo -e "${red}Error: This script requires root privileges. Please install sudo, doas, or pkexec.${no_color}"
	exit 1
fi


if [ -d ~/linconfig ]; then
	echo -e "${green}Removing the old repo directory...${no_color}"
	"$ESCALATION_TOOL" rm -rf ~/linconfig > /dev/null || true
fi
echo -e "${green}Cloning the repository...${no_color}"
if ! git clone --depth 1 -b main https://github.com/Qaddoumi/linconfig.git ~/linconfig; then
	echo "Failed to clone repository" >&2
	exit 1
fi

echo -e "${green}Copying config files...${no_color}"
"$ESCALATION_TOOL" cp -arf ~/linconfig/dotfiles/. ~

echo -e "${green}Removing mimeinfo cache...${no_color}"
"$ESCALATION_TOOL" rm -f ~/.config/mimeinfo.cache ~/.local/share/applications/mimeinfo.cache || true
"$ESCALATION_TOOL" update-desktop-database ~/.local/share/applications || true

echo -e "${green}Restarting xdg-desktop-portal...${no_color}"
systemctl --user restart xdg-desktop-portal.service || \
pkill xdg-desktop-portal || \
pkill xdg-desktop-portal-gtk || \
pkill xdg-desktop-portal-wlr || \
pkill xdg-desktop-portal-hyprland || true

echo -e "${green}Setting up permissions for configuration files${no_color}"
"$ESCALATION_TOOL" chmod +x ~/.config/quickshell/scripts/*.sh > /dev/null || true
find ~/.local/bin/ -maxdepth 1 -type f -exec chmod +x {} +

echo -e "${green}Setting up ownership for configuration files...${no_color}"
"$ESCALATION_TOOL" chown -R $USER:$USER ~/.config > /dev/null || true
"$ESCALATION_TOOL" chown -R $USER:$USER ~/.local > /dev/null || true
"$ESCALATION_TOOL" chown $USER:$USER ~/.gtkrc-2.0 > /dev/null || true
"$ESCALATION_TOOL" chown $USER:$USER ~/.xscreensaver > /dev/null || true

echo -e "${green}Setting up oh-my-posh (bash prompt)...${no_color}"
if ! "$ESCALATION_TOOL" grep -q "source ~/.config/oh-my-posh/gmay.omp.json" ~/.bashrc; then
	echo 'eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/gmay.omp.json)"' | "$ESCALATION_TOOL" tee -a ~/.bashrc > /dev/null
fi

source ~/.bashrc || true


echo -e "${green}Copy the installconfig.sh script${no_color}"
cp -af ~/linconfig/pkgs/installconfig.sh ~/installconfig.sh
chmod +x ~/installconfig.sh

# echo -e "${green}Removing temporary files...${no_color}"
# "$ESCALATION_TOOL" rm -rf ~/linconfig

echo -e "${green}\nInstalling dwm...${no_color}"
cd ~/.local/share/dwm
"$ESCALATION_TOOL" make clean install || true

cd ~

echo -e "${green}\nReload session with \$mod + Shift + c${no_color}"

# "$ESCALATION_TOOL" rm -rf ~/linconfig > /dev/null || true

echo -e "${green}\nSetup completed!${no_color}\n"