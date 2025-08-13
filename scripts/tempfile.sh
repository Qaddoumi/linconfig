#!/bin/bash

# Colors for output
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
no_color='\033[0m'

echo -e "${green}Removing Hugepages configuration...${no_color}"

# 1. Disable current hugepages allocation
echo -e "${green}Step 1: Disabling current hugepages...${no_color}"
echo 0 | sudo tee /proc/sys/vm/nr_hugepages > /dev/null
current_hugepages=$(cat /proc/sys/vm/nr_hugepages)
echo -e "${green}Current hugepages set to: $current_hugepages${no_color}"

# 2. Remove persistent sysctl configuration
echo -e "${green}Step 2: Removing sysctl configuration...${no_color}"
if [ -f "/etc/sysctl.d/99-hugepages.conf" ]; then
    sudo rm -f /etc/sysctl.d/99-hugepages.conf
    echo -e "${green}Removed /etc/sysctl.d/99-hugepages.conf${no_color}"
else
    echo -e "${yellow}No sysctl hugepages configuration found${no_color}"
fi

# 3. Remove from /etc/fstab
echo -e "${green}Step 3: Removing hugepages mount from /etc/fstab...${no_color}"
if grep -q "/dev/hugepages" /etc/fstab; then
    sudo cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
    sudo sed -i '/hugetlbfs.*\/dev\/hugepages/d' /etc/fstab
    echo -e "${green}Removed hugepages entry from /etc/fstab${no_color}"
    echo -e "${yellow}Backup created at /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)${no_color}"
else
    echo -e "${yellow}No hugepages entry found in /etc/fstab${no_color}"
fi

# 4. Unmount hugepages
echo -e "${green}Step 4: Unmounting hugepages...${no_color}"
if mount | grep -q "hugetlbfs on /dev/hugepages"; then
    sudo umount /dev/hugepages
    echo -e "${green}Unmounted /dev/hugepages${no_color}"
else
    echo -e "${yellow}Hugepages not currently mounted${no_color}"
fi

# # 5. Remove hugepages directory (optional) 
# echo -e "${green}Step 5: Cleaning up hugepages directory...${no_color}"
# if [ -d "/dev/hugepages" ]; then
#     sudo rmdir /dev/hugepages 2>/dev/null || echo -e "${yellow}Directory /dev/hugepages not empty or in use${no_color}"
# fi

# 6. Remove kernel parameters from bootloader
echo -e "${green}Step 6: Removing kernel parameters from bootloader...${no_color}"

# Detect bootloader
bootloader_type="unknown"
if bootctl status 2>/dev/null | grep -q "systemd-boot"; then
    bootloader_type="systemd-boot"
    echo -e "${green}systemd-boot detected${no_color}"
elif [[ -f "/boot/grub/grub.cfg" ]] || sudo test -d "/boot/grub"; then
    bootloader_type="grub"
    echo -e "${green}GRUB bootloader detected${no_color}"
fi

if [ "$bootloader_type" = "grub" ]; then
    if grep -q "hugepages=" /etc/default/grub; then
        # Backup GRUB config
        sudo cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)
        
        # Remove hugepages parameter
        sudo sed -i 's/hugepages=[0-9]*[ ]*//g' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        echo -e "${green}Removed hugepages parameter from GRUB configuration${no_color}"
        echo -e "${yellow}Reboot required to apply bootloader changes${no_color}"
    else
        echo -e "${yellow}No hugepages parameter found in GRUB configuration${no_color}"
    fi

elif [ "$bootloader_type" = "systemd-boot" ]; then
    # Find systemd-boot entries directory
    entries_dir=""
    for path in "/boot/efi/loader/entries" "/boot/loader/entries" "/efi/loader/entries" "/boot/EFI/loader/entries"; do
        if sudo test -d "$path"; then
            entries_dir="$path"
            break
        fi
    done
    
    if [[ -z "$entries_dir" ]]; then
        # Try to get ESP path from bootctl
        esp_path=$(bootctl status 2>/dev/null | grep "ESP:" | awk '{print $2}')
        if [[ -n "$esp_path" ]]; then
            entries_dir="$esp_path/loader/entries"
        fi
    fi
    
    if [[ -n "$entries_dir" ]] && sudo test -d "$entries_dir"; then
        # Get boot entries (excluding backups and fallbacks)
        all_entries=($(sudo find "$entries_dir" -name "*.conf" 2>/dev/null))
        boot_entries=()
        for entry in "${all_entries[@]}"; do
            if [[ "$(basename "$entry")" != *".backup."* && "$(basename "$entry")" != *"-fallback."* ]]; then
                boot_entries+=("$entry")
            fi
        done
        
        echo -e "${green}Processing ${#boot_entries[@]} boot entries...${no_color}"
        
        for entry in "${boot_entries[@]}"; do
            if [ -f "$entry" ] && grep -q "hugepages=" "$entry"; then
                # Backup entry file
                sudo cp "$entry" "${entry}.backup.$(date +%Y%m%d_%H%M%S)"
                
                # Remove hugepages parameter
                sudo sed -i 's/hugepages=[0-9]*[ ]*//g' "$entry"
                echo -e "${green}Removed hugepages from $(basename "$entry")${no_color}"
            fi
        done
        echo -e "${yellow}Reboot required to apply bootloader changes${no_color}"
    else
        echo -e "${yellow}Could not locate systemd-boot entries directory${no_color}"
        echo -e "${yellow}Please manually remove 'hugepages=XXXX' from your boot entries${no_color}"
    fi
else
    echo -e "${yellow}Unknown bootloader. Please manually remove 'hugepages=XXXX' from your kernel parameters${no_color}"
fi

# 7. Display current status
echo -e "${green}Step 7: Current hugepages status:${no_color}"
if grep -q "HugePages_Total" /proc/meminfo; then
    grep "HugePages" /proc/meminfo | while read line; do
        echo -e "${blue}  $line${no_color}"
    done
else
    echo -e "${green}  No hugepages currently allocated${no_color}"
fi

echo ""
echo -e "${green}Hugepages removal completed!${no_color}"
echo -e "${yellow}Summary of actions taken:${no_color}"
echo -e "${yellow}  - Disabled current hugepages allocation${no_color}"
echo -e "${yellow}  - Removed sysctl configuration file${no_color}"
echo -e "${yellow}  - Removed hugepages from /etc/fstab${no_color}"
echo -e "${yellow}  - Unmounted hugepages filesystem${no_color}"
echo -e "${yellow}  - Removed kernel parameters from bootloader${no_color}"
echo ""
echo -e "${red}IMPORTANT: Reboot your system to fully apply all changes!${no_color}"
