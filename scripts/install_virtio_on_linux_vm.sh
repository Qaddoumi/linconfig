

sudo pacman -S qemu-guest-agent spice-vdagent

sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent

sudo systemctl enable spice-vdagentd
sudo systemctl start spice-vdagentd

# sudo reboot