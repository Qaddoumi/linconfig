#!/usr/bin/env bash

sourceDir=""
if [[ "$(pwd)" != *"shared"* ]]; then
	sourceDir=~/linconfig
else
	sourceDir=~/shared/github/MyGithubs/linconfig
fi


sudo cp -afr $sourceDir/dotfiles/. ~

sudo rm -f ~/.config/mimeinfo.cache ~/.local/share/applications/mimeinfo.cache || true
sudo update-desktop-database ~/.local/share/applications || true

echo "Setting up permissions for configuration files"
sudo chmod +x ~/.config/quickshell/scripts/*.sh > /dev/null || true
find ~/.local/bin/ -maxdepth 1 -type f -exec chmod +x {} +

echo "Setting up ownership for configuration files"
sudo chown -R $USER:$USER ~/.config > /dev/null || true
sudo chown -R $USER:$USER ~/.local > /dev/null || true
sudo chown $USER:$USER ~/.gtkrc-2.0 > /dev/null || true
sudo chown $USER:$USER ~/.xscreensaver > /dev/null || true

cp -af $sourceDir/pkgs/installconfig.sh ~/installconfig.sh
chmod +x ~/installconfig.sh

cd ~/.local/share/dwm && sudo make clean install || true
cd ~/.local/share/dwl && sudo make clean install || true
cd ~
echo -e "\nReload session with \$mod + Shift + c"