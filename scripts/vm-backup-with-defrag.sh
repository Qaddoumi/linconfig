#!/usr/bin/env bash

start_time=$(date +%s)

# Directory paths
QCOW2_DIR="/var/lib/libvirt/images"
XML_DIR="/etc/libvirt/qemu"

# Destination directory for the backups (change as needed)
DRIVE_NAME="Mkohaa4TB"
DEVICE="/dev/$(lsblk -no NAME,LABEL | grep "$DRIVE_NAME" | awk '{print $1}' | sed 's/^[^a-zA-Z0-9]*//')"
MOUNT_POINT=$(lsblk -no MOUNTPOINTS $DEVICE | grep -v "^$" | head -1)
DEST_DIR="$MOUNT_POINT/archBackup/vms/$(date +%Y%m%d_%H%M%S)"

echo "Destination directory: $DEST_DIR"
# Create destination directory if it doesn't exist
sudo mkdir -p "$DEST_DIR" || { echo "Failed to create destination directory: $DEST_DIR"; exit 1; }
#sudo chown -R $USER:$USER "$DEST_DIR"


vm_name="003-win11-study.qcow2"

sudo virt-sparsify -v --tmp $MOUNT_POINT/archBackup/temp/ "$QCOW2_DIR/$vm_name" "$DEST_DIR/$vm_name"




echo "======================================================"

end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

# Convert seconds to human readable format
hours=$((elapsed_time / 3600))
minutes=$(( (elapsed_time % 3600) / 60 ))
seconds=$((elapsed_time % 60))

time_str=""
if [[ $hours -gt 0 ]]; then
    time_str+="${hours}h "
fi
if [[ $minutes -gt 0 || $hours -gt 0 ]]; then
    time_str+="${minutes}m "
fi
time_str+="${seconds}s"

echo -e "Operation completed in ${time_str}"