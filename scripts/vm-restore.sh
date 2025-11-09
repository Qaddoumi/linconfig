#!/usr/bin/env bash


XML_DIR="$HOME/XMLs"
QCOW2_DIR="/var/lib/libvirt/images"



for xml_file in "$XML_DIR"/*.xml; do
    if [ -f "$xml_file" ]; then
        echo ""
        vm_name="$(basename "$xml_file")"
        echo "Found : $vm_name"
        sudo virsh define $xml_file 
    fi 
done
