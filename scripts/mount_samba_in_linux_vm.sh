#!/usr/bin/env bash

# Samba Share Mount Script for Linux Mint
# This script helps you connect to a Samba share

echo "=== Samba Share Mount Script ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use: sudo bash script.sh)"
    exit 1
fi

# Get user input
read -p "Enter Samba server IP or hostname: " SERVER
read -p "Enter share name: " SHARE
read -p "Enter your username: " USERNAME
read -sp "Enter your password: " PASSWORD
echo ""
read -p "Enter mount point (default: /mnt/samba): " MOUNTPOINT
MOUNTPOINT=${MOUNTPOINT:-/mnt/samba}

read -p "Mount permanently (auto-mount at boot)? (y/n): " PERMANENT

# Install cifs-utils if not installed
echo ""
echo "Checking for cifs-utils..."
if ! dpkg -l | grep -q cifs-utils; then
    echo "Installing cifs-utils..."
    apt update > /dev/null 2>&1 || true
    apt install -y cifs-utils > /dev/null 2>&1 || true
    pacman -Syu --noconfirm > /dev/null 2>&1 || true
    pacman -S --noconfirm cifs-utils > /dev/null 2>&1 || true
else
    echo "cifs-utils already installed."
fi

# Create mount point
echo ""
echo "Creating mount point at $MOUNTPOINT..."
mkdir -p "$MOUNTPOINT"

if [ "$PERMANENT" = "y" ] || [ "$PERMANENT" = "Y" ]; then
    # Permanent mount setup
    echo ""
    echo "Setting up permanent mount..."
    
    # Create credentials file
    CRED_FILE="/root/.smbcredentials"
    echo "username=$USERNAME" > "$CRED_FILE"
    echo "password=$PASSWORD" >> "$CRED_FILE"
    chmod 600 "$CRED_FILE"
    echo "Credentials saved to $CRED_FILE"
    
    # Get the UID and GID of the user who invoked sudo
    ACTUAL_USER=${SUDO_USER:-$USER}
    USER_UID=$(id -u "$ACTUAL_USER")
    USER_GID=$(id -g "$ACTUAL_USER")
    
    # Add to fstab if not already present
    FSTAB_ENTRY="//$SERVER/$SHARE $MOUNTPOINT cifs credentials=$CRED_FILE,uid=$USER_UID,gid=$USER_GID 0 0"
    
    if grep -q "$MOUNTPOINT" /etc/fstab; then
        echo "Entry already exists in /etc/fstab. Skipping..."
    else
        echo "$FSTAB_ENTRY" >> /etc/fstab
        echo "Added entry to /etc/fstab"
    fi
    
    # Mount using fstab
    echo "Mounting share..."
    mount -a
    
else
    # Temporary mount
    echo ""
    echo "Mounting share temporarily..."
    mount -t cifs "//$SERVER/$SHARE" "$MOUNTPOINT" -o username="$USERNAME",password="$PASSWORD"
fi

# Check if mount was successful
if mountpoint -q "$MOUNTPOINT"; then
    echo ""
    echo "✓ Success! Samba share mounted at $MOUNTPOINT"
    echo ""
    ls -la "$MOUNTPOINT"
else
    echo ""
    echo "✗ Failed to mount share. Please check your credentials and server address."
    exit 1
fi
