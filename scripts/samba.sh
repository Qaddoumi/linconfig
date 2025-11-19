#!/usr/bin/env bash

set -e  # Exit on any error

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
no_color='\033[0m' # rest the color to default


echo -e "${green}Installing and configuring Samba for VM shared folder access...${no_color}"
sudo pacman -S --needed --noconfirm samba

echo -e "${green}Creating shared directory at ~/shared...${no_color}"
sudo mkdir -p ~/shared
sudo chown -R $USER:$USER ~/shared
sudo chmod 755 ~/shared

echo -e "${green}Configuring Samba file at /etc/samba/smb.conf...${no_color}"
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup > /dev/null 2>&1 || true

# Create new Samba configuration
sudo tee /etc/samba/smb.conf > /dev/null <<EOF
[global]
   workgroup = WORKGROUP
   server string = mohArch
   security = user
   map to guest = never
   dns proxy = no

[shared]
   comment = Shared folder for VMs
   path = /home/$USER/shared
   browseable = yes
   writable = yes
   read only = no
   valid users = $USER
   create mask = 0644
   directory mask = 0755
   force user = $USER
   force group = $USER
EOF

echo -e "\nSetting Samba password for user: $USER"
sudo smbpasswd -a $USER

echo -e "${green}\nEnabling and starting Samba services...${no_color}"
sudo systemctl enable --now smb nmb

# Check status
echo -e "\nChecking Samba status..."
sudo systemctl status smb nmb --no-pager

# Configure firewall (if applicable)
echo -e "${green}\nConfiguring firewall for Samba...${no_color}"
sudo ufw allow Samba > /dev/null 2>&1 || true
sudo firewall-cmd --add-service=samba --permanent > /dev/null 2>&1 || true
sudo firewall-cmd --reload > /dev/null 2>&1 || true

# Test Samba configuration
echo -e "\nTesting Samba configuration..."
testparm -s

# Show the host IP for VMs
echo ""
echo "Your host IP for VMs (use this to connect):"
HOST_IP=$(ip addr show virbr0 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
echo "$HOST_IP"

echo ""
echo ""
echo -e "${green}To conncet on windows VM, open File Explorer and enter the following in the address bar:${no_color}"
echo -e "${blue}\\$HOST_IP\shared${no_color}"
echo -e "$green}and make sure to map the network drive${no_color}"
echo -e "${green}To connect on Linux VM, use the following address in your file manager${no_color}"
echo -e "${blue}smb://$HOST_IP/shared${no_color}"

