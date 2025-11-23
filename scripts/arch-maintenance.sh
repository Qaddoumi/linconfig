# Check systemd failed services
systemctl --failed

# Log files check
sudo journalctl -p 3 -xb

# Update
sudo pacman -Syu

# Yay Update
yay

#Delete Pacman Cache
sudo pacman -Scc

# Delete Yay Cache
yay -Scc

# Delete unwanted dependencies
echo -e "• Use ${blue}yay -Ps to see yay statistics"
echo -e "• Use ${blue}yay -Yc to clean unneeded dependencies"
yay -Yc

# Check Orphan packages
pacman -Qtdq

# Remove Orphan packages
sudo pacman -Rns $(pacman -Qtdq)

# Clean the Cache
rm -rf .cache/*

# Clean the journal (pacman logs and system logs)
sudo journalctl --vacuum-time=2weeks

# refresh the mirror list
sudo pacman-mirrors --fasttrack 5 && sudo pacman -Syy
sudo reflector -c Switzerland -a 6 --sort rate --save /etc/pacman.d/mirrorlist
