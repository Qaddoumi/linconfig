#!/usr/bin/env bash

set -e # Exit on error

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
no_color='\033[0m' # reset the color to default


#TODO: make hugepages dynamic by checking the xml and build basied on the memory allocated to the VM.
echo -e "${green}Setting up Hugepages for KVM guests${no_color}"
# as im allocating a 20GB of rams to vm ==> i need to allocate 10240 hugepages (20GB / 2MB per page = 10240 pages)
size_of_pages=10240

# Check if system has enough memory
total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_mem_gb=$((total_mem_kb / 1024 / 1024))
required_gb=20

if [ "$total_mem_gb" -lt $((required_gb + 4)) ]; then
    echo -e "${red}Warning: System has ${total_mem_gb}GB RAM. Allocating ${required_gb}GB for hugepages may cause issues.${no_color}"
    echo -e "${yellow}Consider leaving at least 4GB for the host system.${no_color}"
else
    # Check current hugepages allocation
    current_hugepages=$(cat /proc/sys/vm/nr_hugepages 2>/dev/null || echo "0")

    if [ "$current_hugepages" -ge $size_of_pages ]; then
        echo -e "${green}Hugepages are already configured (${current_hugepages} pages)${no_color}"
    else
        echo -e "${green}Configuring hugepages for KVM guests...${no_color}"
        
        # Set runtime hugepages
        echo $size_of_pages | sudo tee /proc/sys/vm/nr_hugepages > /dev/null || true
        
        # Make it persistent
        echo "vm.nr_hugepages=$size_of_pages" | sudo tee /etc/sysctl.d/99-hugepages.conf > /dev/null || true
        
        # Also add kernel parameter for boot-time allocation (more reliable)
        echo -e "${green}Detecting bootloader...${no_color}"
        bootloader_type="systemd-boot"
        echo -e "${green}check for systemd-boot first${no_color}"
        if bootctl status 2>/dev/null | grep -q "systemd-boot"; then
            echo -e "${green}systemd-boot confirmed via bootctl${no_color}"
        elif [[ -f "/boot/grub/grub.cfg" ]] || sudo test -d "/boot/grub"; then
                echo -e "${green}GRUB bootloader detected${no_color}"
                bootloader_type="grub" # GRUB detected
        fi
        echo -e "${green}Bootloader type: $bootloader_type${no_color}"
        if [ "$bootloader_type" = "grub" ]; then
            if ! grep -q "hugepages=$size_of_pages" /etc/default/grub; then
                backup_file "/etc/default/grub"
                
                sudo sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"hugepages=$size_of_pages /" /etc/default/grub
                sudo grub-mkconfig -o /boot/grub/grub.cfg
                echo -e "${yellow}Kernel parameters updated. Reboot required for optimal hugepages allocation.${no_color}"
            fi
        elif [ "$bootloader_type" = "systemd-boot" ]; then
            entries_dir=""
            for path in "/boot/efi/loader/entries" "/boot/loader/entries" "/efi/loader/entries" "/boot/EFI/loader/entries"; do
                echo -e "${blue}Checking path: $path${no_color}"
                if sudo test -d "$path"; then
                    entries_dir="$path"
                    echo -e "${green}Found entries directory: $entries_dir${no_color}"
                    break
                fi
            done
            
            if [[ -z "$entries_dir" ]]; then
                echo -e "${red}systemd-boot entries directory not found${no_color}"
                echo -e "${yellow}Attempting to find entries using bootctl...${no_color}"
                
                # Try to get boot entries using bootctl
                if command -v bootctl &> /dev/null; then
                    bootctl_output=$(bootctl list 2>/dev/null)
                    if [[ -n "$bootctl_output" ]]; then
                        echo -e "${green}Found boot entries via bootctl:${no_color}"
                        echo "$bootctl_output"
                        
                        # Get the ESP path from bootctl
                        esp_path=$(bootctl status 2>/dev/null | grep "ESP:" | awk '{print $2}')
                        if [[ -n "$esp_path" ]]; then
                            entries_dir="$esp_path/loader/entries"
                            echo -e "${green}Using ESP path: $entries_dir${no_color}"
                        fi
                    fi
                fi
            fi
            
            if [[ -z "$entries_dir" ]] || ! sudo test -d "$entries_dir"; then
                echo -e "${red}Could not locate systemd-boot entries directory${no_color}"
                echo -e "${yellow}Please manually add '$IOMMU_PARAM iommu=pt vfio-pci.ids=$VFIO_IDS $integrated_gpu_modeset $discrete_gpu_modeset' to your boot entry${no_color}"
                #exit 1
            fi
            
            # Get all .conf files (including backups and fallbacks)
            all_entries=($(sudo find "$entries_dir" -name "*.conf" 2>/dev/null))

            # Filter out backups and fallbacks
            boot_entries=()
            for entry in "${all_entries[@]}"; do
                if [[ "$(basename "$entry")" != *".backup."* && "$(basename "$entry")" != *"-fallback."* ]]; then
                    boot_entries+=("$entry")
                fi
            done
            
            if [[ ${#boot_entries[@]} -eq 0 ]]; then
                echo -e "${red}No boot entries found in $entries_dir${no_color}"
                #exit 1
            fi
            
            echo -e "${green}Found ${#boot_entries[@]} boot entries:${no_color}"
            for entry in "${boot_entries[@]}"; do
                echo "  - $(basename "$entry")"
            done
            
            for entry in "${boot_entries[@]}"; do
                if [ -f "$entry" ]; then
                    if ! grep -q "hugepages=$size_of_pages" "$entry"; then
                        backup_file "$entry"
                        echo -e "${green}Updating entry: $(basename "$entry")${no_color}"
                        # More robust sed command that handles various options line formats
                        sudo sed -i "/^options/ { /hugepages=/ ! s/options /&hugepages=$size_of_pages / }" "$entry"
                    else
                        echo -e "${green}Entry $(basename "$entry") already has hugepages configured${no_color}"
                    fi
                fi
            done
            
        fi
        
        echo -e "${green}Hugepages configured with $size_of_pages pages${no_color}"
    fi

    # Check if hugepages are mounted
    if mount | grep -q "hugetlbfs on /dev/hugepages"; then
        echo -e "${green}Hugepages are already mounted${no_color}"
    else
        echo -e "${green}Mounting hugepages...${no_color}"
        sudo mkdir -p /dev/hugepages || true
        
        
        sudo mount -a || true
        echo -e "${green}Hugepages mounted at /dev/hugepages${no_color}"
    fi
    # Check if already in fstab
    if ! grep -q "/dev/hugepages" /etc/fstab; then
        echo "hugetlbfs /dev/hugepages hugetlbfs mode=1770,gid=kvm 0 0" | sudo tee -a /etc/fstab > /dev/null || true
    fi

    # this part not recommended for most workloads
    # # Disabling Transparent hugepages for better performance
    # if grep -q "transparent_hugepage" /sys/kernel/mm/transparent_hugepage/enabled; then
    #     echo -e "${green}Disabling Transparent Hugepages...${no_color}"
    #     echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null || true
    #     echo -e "${green}Transparent Hugepages disabled${no_color}"
    # else
    #     echo -e "${yellow}Transparent Hugepages not supported or already disabled${no_color}"
    # fi

    # Display current hugepages status
    echo -e "${green}Current Hugepages configuration:${no_color}"
    if grep -q "HugePages_Total" /proc/meminfo; then
        grep "HugePages" /proc/meminfo | while read line; do
            echo -e "${green}  $line${no_color}"
        done
        hugepage_size=$(grep "Hugepagesize" /proc/meminfo | awk '{print $2}')
        echo -e "${green}  Hugepagesize: ${hugepage_size} kB${no_color}"
        
        # Calculate total allocated
        total_pages=$(grep "HugePages_Total" /proc/meminfo | awk '{print $2}')
        total_mb=$((total_pages * hugepage_size / 1024))
        echo -e "${green}  Total allocated: ${total_mb} MB (${total_pages} pages)${no_color}"
    else
        echo -e "${yellow}Hugepages information not available in /proc/meminfo${no_color}"
    fi

    echo -e "${green}Hugepages setup completed${no_color}"
fi