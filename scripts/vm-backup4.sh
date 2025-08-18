#!/usr/bin/env bash

# Directory paths
QCOW2_DIR="/var/lib/libvirt/images"
XML_DIR="/etc/libvirt/qemu"

# Destination directory for XML copies (change as needed)
DEST_DIR="/run/media/moh/Mkohaa4TB/archBackup/vms/$(date +%Y%m%d_%H%M%S)"

# Create destination directory if it doesn't exist
sudo mkdir -p "$DEST_DIR"

# Process all qcow2 files
echo "Processing qcow2 files..."
for qcow_file in "$QCOW2_DIR"/*.qcow2; do
    if [ -f "$qcow_file" ]; then
        echo ""
        vm_name="$(basename "$qcow_file")"
        echo "Found qcow2 file: $vm_name"
        
        # Example commands to perform on each qcow2 file:
        # 1. Get file size
        size=$(du -sh "$qcow_file" | cut -f1)
        echo "  Size: $size"
        
        # 2. Get owner
        owner=$(stat -c "%U" "$qcow_file")
        echo "  Owner: $owner"
        
        # 3. Perform qemu-img operations (example)
        echo "  Checking disk..."
        sudo qemu-img check "$QCOW2_DIR/$vm_name"
        echo "  Converting and copying the disk..."
        sudo qemu-img convert -p -O qcow2 -c "$QCOW2_DIR/$vm_name" "$DEST_DIR/$vm_name"
        
        # Add your custom commands here
    fi
done

# Process all XML files
echo -e "\nProcessing XML files..."
for xml_file in "$XML_DIR"/*.xml; do
    if [ -f "$xml_file" ]; then
        echo ""
        vm_name="$(basename "$xml_file")"
        echo "Found XML file: $vm_name"
        
        # Copy the XML file to destination
        #cp -v "$xml_file" "$XML_DEST_DIR/"
        
        # Alternative: copy with timestamp
        # timestamp=$(date +%Y%m%d_%H%M%S)
        # cp -v "$xml_file" "${XML_DEST_DIR}/$(basename "$xml_file" .xml)_${timestamp}.xml"
        sudo cp "$XML_DIR/$vm_name" "$DEST_DIR/$vm_name"
    fi
done

echo "======================================================"
echo -e "\nOperation completed."