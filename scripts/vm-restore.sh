#!/usr/bin/env bash


QCOW2_DIR="/var/lib/libvirt/images"

# Destination directory for the backups (change as needed)
DRIVE_NAME="Mkohaa4TB"
DEVICE="/dev/$(lsblk -no NAME,LABEL | grep "$DRIVE_NAME" | awk '{print $1}' | sed 's/^[^a-zA-Z0-9]*//')"
MOUNT_POINT=$(lsblk -no MOUNTPOINTS $DEVICE | grep -v "^$" | head -1)

# Find the newest dated folder in archBackup/vms (by folder name)
NEWEST_BACKUP=$(ls -d "$MOUNT_POINT/archBackup/vms"/*/ 2>/dev/null | sort -V | tail -1)
backup_DIR="${NEWEST_BACKUP%/}"
echo "Restoring from backup directory: $backup_DIR"

for file in "$backup_DIR"/*; do
    if [ -f "$file" ]; then
        filename="$(basename "$file")"
        if [[ "$file" == *.qcow2 ]]; then
            echo "Copying $filename to $QCOW2_DIR"
            sudo cp "$file" "$QCOW2_DIR/"
        fi
    fi
done

for file in "$backup_DIR"/*; do
    if [ -f "$file" ]; then
        filename="$(basename "$file")"
        if [[ "$file" == *.xml ]]; then
            sudo virsh define "$file"
        fi
    fi
done
