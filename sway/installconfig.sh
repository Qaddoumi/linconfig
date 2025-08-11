#!/bin/bash


if [ -d ~/swaytemp ]; then
    sudo rm -rf ~/swaytemp
fi
if ! git clone --depth 1 https://github.com/Qaddoumi/linconfig.git ~/swaytemp; then
    echo "Failed to clone repository" >&2
    exit 1
fi
sudo rm -rf ~/.config/sway ~/.config/waybar ~/.config/wofi ~/.config/kitty ~/.config/swaync \
    ~/.config/kanshi ~/.config/oh-my-posh ~/.config/fastfetch ~/.config/mimeapps.list ~/.config/looking-glass \
    ~/.config/gtk-3.0 ~/.config/gtk-4.0
sudo mkdir -p ~/.config && sudo cp -r ~/swaytemp/.config/* ~/.config/
sudo rm -rf ~/swaytemp

sudo chmod +x ~/.config/waybar/scripts/*.sh
sudo chmod +x ~/.config/sway/scripts/*.sh

swaymsg reload

# if ! grep -q 'export PATH="$PATH:$HOME/.local/bin"' ~/.bashrc; then
#     echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
# fi
if ! grep -q "source ~/.config/oh-my-posh/gmay.omp.json" ~/.bashrc; then
    echo 'eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/gmay.omp.json)"' >> ~/.bashrc
fi
