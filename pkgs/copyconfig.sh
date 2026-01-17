#!/usr/bin/env bash

for tool in sudo doas pkexec; do
	if command -v "${tool}" >/dev/null 2>&1; then
		ESCALATION_TOOL="${tool}"
		echo -e "Using ${tool} for privilege escalation"
		break
	fi
done
if [ -z "${ESCALATION_TOOL}" ]; then
	echo -e "Error: This script requires root privileges. Please install sudo, doas, or pkexec."
	exit 1
fi


sourceDir=""
if [[ "$(pwd)" != *"shared"* ]]; then
	sourceDir=~/linconfig
else
	sourceDir=~/shared/github/MyGithubs/linconfig
fi


"$ESCALATION_TOOL" cp -afr $sourceDir/dotfiles/. ~

"$ESCALATION_TOOL" rm -f ~/.config/mimeinfo.cache ~/.local/share/applications/mimeinfo.cache || true
"$ESCALATION_TOOL" update-desktop-database ~/.local/share/applications || true

systemctl --user restart xdg-desktop-portal.service

echo "Setting up permissions for configuration files"
"$ESCALATION_TOOL" chmod +x ~/.config/quickshell/scripts/*.sh > /dev/null || true
find ~/.local/bin/ -maxdepth 1 -type f -exec chmod +x {} +

echo "Setting up ownership for configuration files"
"$ESCALATION_TOOL" chown -R $USER:$USER ~/.config > /dev/null || true
"$ESCALATION_TOOL" chown -R $USER:$USER ~/.local > /dev/null || true
"$ESCALATION_TOOL" chown $USER:$USER ~/.gtkrc-2.0 > /dev/null || true
"$ESCALATION_TOOL" chown $USER:$USER ~/.xscreensaver > /dev/null || true

cp -af $sourceDir/pkgs/installconfig.sh ~/installconfig.sh
chmod +x ~/installconfig.sh

cd ~/.local/share/dwm && "$ESCALATION_TOOL" make clean install || true
cd ~
echo -e "\nReload session with \$mod + Shift + c"