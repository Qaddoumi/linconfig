#!/bin/bash
# Arch Linux Installation Script

set -uo pipefail  # Strict error handling
trap 'cleanup' EXIT  # Ensure cleanup runs on exit

# Set default values
DEFAULT_ROOT_PASSWORD="root123"
DEFAULT_USERNAME="user"
DEFAULT_USER_PASSWORD="root123"

start_time=$(date +%s)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NO_COLOR='\033[0m' # rest the color to default

# Security cleanup function
cleanup() {
    unset ROOT_PASSWORD USER_PASSWORD  # Wipe passwords from memory
    sync
    if mountpoint -q /mnt; then
        umount -R /mnt 2>/dev/null
    fi
}

error() {
    echo -e "${RED}[ERROR] $*${NO_COLOR}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}[*] $*${NO_COLOR}"
}

newTask() {
    echo -e "${BLUE}$*${NO_COLOR}"
}

warn() {
    echo -e "${YELLOW}[WARN] $*${NO_COLOR}"
}

# Check if running on Arch Linux
if [ ! -f "/etc/arch-release" ]; then
    error "This script must be run on Arch Linux"
fi

newTask "==================================================\n=================================================="

info "Checking for root privileges"
[[ $(id -u) -eq 0 ]] || error "This script must be run as root"

info "Checking internet connection"
if ! ping -c 1 archlinux.org &>/dev/null; then
    warn "No internet connection detected!"
    read -rp "Continue without internet? (not recommended) [y/N]: " NO_NET
    [[ "$NO_NET" == "y" ]] || error "Aborted"
fi

newTask "==================================================\n=================================================="

IS_VM=false
VIRT_PKGS=""
GPU_PKGS=""

info "Detecting system environment..."
if systemd-detect-virt --vm &>/dev/null; then
    VIRT_TYPE=$(systemd-detect-virt)
    IS_VM=true
    info "Virtual machine detected: $VIRT_TYPE"

    case "$VIRT_TYPE" in
        "kvm"|"qemu")
            VIRT_PKGS="qemu-guest-agent"
            info "Checking if SPICE/QXL availables"
            if [[ -e "/dev/virtio-ports/org.spice-space.webdav.0" ]] || lspci | grep -qi "qxl"; then
                VIRT_PKGS="$VIRT_PKGS spice-vdagent"
            fi
            ;;
        "virtualbox")
            VIRT_PKGS="virtualbox-guest-utils-nox"
            ;;
        "vmware")
            VIRT_PKGS="open-vm-tools"
            ;;
        *)
            VIRT_PKGS=""
            warn "Unknown virtualization platform: $VIRT_TYPE"
            ;;
    esac
else
    info "Running on physical hardware"
fi

if [ -z "$VIRT_PKGS" ]; then
    info "No virtualization packages will be installed."
else
    info "Virtualization packages: $VIRT_PKGS"
fi

info "Detecting GPU devices..."
# Use IFS to prevent word splitting
OLD_IFS="$IFS"
IFS=$'\n'
GPU_DEVICES=($(lspci | grep -E "VGA|3D|Display" | awk -F': ' '{print $2}'))
IFS="$OLD_IFS"
echo -e "Detected GPU devices: ${#GPU_DEVICES[@]}"
for gpu in "${GPU_DEVICES[@]}"; do
    echo " - $gpu"
done

if [[ ${#GPU_DEVICES[@]} -eq 0 ]]; then
    warn "No GPU devices detected!"
    if [[ "$IS_VM" == true ]]; then
        GPU_PKGS="mesa"  # Mesa only for VMs without detected GPU
    else
        GPU_PKGS="mesa xf86-video-vesa"  # Fallback for bare metal
    fi
else
    # Initialize arrays for different GPU types
    declare -a AMD_GPUS=()
    declare -a INTEL_GPUS=()
    declare -a NVIDIA_GPUS=()
    declare -a VM_GPUS=()
    declare -a OTHER_GPUS=()
    declare -a FINAL_GPU_PKGS=()
    
    info "Found ${#GPU_DEVICES[@]} GPU device(s):"
    for ((i=0; i<${#GPU_DEVICES[@]}; i++)); do
        echo "Categorize GPU $((i+1)): ${GPU_DEVICES[$i]}"
        
        gpu_lower=$(echo "${GPU_DEVICES[$i]}" | tr '[:upper:]' '[:lower:]')
        if echo "$gpu_lower" | grep -q "qxl"; then
            VM_GPUS+=("qxl")
        elif echo "$gpu_lower" | grep -q "virtio"; then
            VM_GPUS+=("virtio")
        elif echo "$gpu_lower" | grep -q "vmware\|svga"; then
            VM_GPUS+=("vmware")
        elif echo "$gpu_lower" | grep -q "\bnvidia\b\|geforce\|quadro\|tesla"; then
            NVIDIA_GPUS+=("${GPU_DEVICES[$i]}")
            info "NVIDIA GPU detected: ${GPU_DEVICES[$i]}"
        elif echo "$gpu_lower" | grep -q "\bamd\b\|\bati\b\|radeon"; then
            AMD_GPUS+=("${GPU_DEVICES[$i]}")
            info "AMD GPU detected: ${GPU_DEVICES[$i]}"
        elif echo "$gpu_lower" | grep -q "\bintel\b"; then
            INTEL_GPUS+=("${GPU_DEVICES[$i]}")
            info "Intel GPU detected: ${GPU_DEVICES[$i]}"
        elif [[ "$IS_VM" == true ]]; then
            VM_GPUS+=("generic")
        else
            OTHER_GPUS+=("${GPU_DEVICES[$i]}")
            warn "Unknown GPU detected: ${GPU_DEVICES[$i]}"
        fi
    done
    
    # Always include mesa as base
    FINAL_GPU_PKGS=(
        "mesa"                   # OpenGL/Vulkan
        "vulkan-mesa-layers"     # Vulkan validation
        "mesa-utils"             # glxinfo, etc.
        "libva"                  # Video Acceleration API
    )
    
    # VM-specific drivers 
    info "Configuring VM graphics drivers..."
    if printf '%s\n' "${VM_GPUS[@]}" | grep -E "qxl|virtio"; then
        FINAL_GPU_PKGS+=("xf86-video-qxl" "virglrenderer")
        info "Added virtio and QXL driver for SPICE graphics"
    elif printf '%s\n' "${VM_GPUS[@]}" | grep -q "vmware"; then
        FINAL_GPU_PKGS+=("xf86-video-vmware")
        info "Added VMware SVGA driver"
    else
        # Fallback: Software rendering
        FINAL_GPU_PKGS+=("mesa-vulkan-swrast")
        info "Using generic Mesa drivers (software rendering)"
    fi

    # Physical hardware OR GPU passthrough - handle multiple GPU types
    info "Configuring physical GPU drivers if exists..."
    
    #TODO: (Learnaboutthem) Adding radeontop, intel-gpu-tools, and nvidia-prime for better GPU management 

    # Handle AMD GPUs
    if [[ ${#AMD_GPUS[@]} -gt 0 ]]; then
        info "Detected ${#AMD_GPUS[@]} AMD GPU(s)"
        echo "Select AMD driver:"
        echo "1) AMDGPU (recommended for GCN 1.2+ and newer)"
        echo "2) Radeon (legacy, for older GPUs)"
        read -rp "Select AMD driver [1-2]: " AMD_CHOICE
        case ${AMD_CHOICE:-1} in
            1) FINAL_GPU_PKGS+=("xf86-video-amdgpu" "vulkan-radeon" "lib32-vulkan-radeon radeontop") ;;
            2) FINAL_GPU_PKGS+=("xf86-video-ati radeontop") ;;
        esac
    fi
    
    # Handle Intel GPUs
    if [[ ${#INTEL_GPUS[@]} -gt 0 ]]; then
        info "Detected ${#INTEL_GPUS[@]} Intel GPU(s)"
        FINAL_GPU_PKGS+=("xf86-video-intel" "vulkan-intel" "lib32-vulkan-intel intel-gpu-tools")
    fi
    
    # Handle NVIDIA GPUs
    if [[ ${#NVIDIA_GPUS[@]} -gt 0 ]]; then
        info "Detected ${#NVIDIA_GPUS[@]} NVIDIA GPU(s)"
        echo "Select NVIDIA driver:"
        echo "1) Nouveau (open-source, default)"
        echo "2) Proprietary NVIDIA (better performance)"
        echo "3) NVIDIA Open Kernel Module (Turing+ GPUs)"
        read -rp "Select NVIDIA driver [1-3]: " NVIDIA_CHOICE
        case ${NVIDIA_CHOICE:-1} in
            1) FINAL_GPU_PKGS+=("mesa-utils" "vulkan-nouveau" "xf86-video-nouveau" "vulkan-mesa-layers" "vulkan-tools") ;;
            2) FINAL_GPU_PKGS+=("nvidia" "nvidia-utils" "nvidia-settings" "lib32-nvidia-utils nvidia-prime") ;;
            3) FINAL_GPU_PKGS+=("nvidia-open" "nvidia-utils" "nvidia-settings" "lib32-nvidia-utils nvidia-prime") ;;
        esac
    fi

    # Handle other/unknown GPUs
    if [[ ${#OTHER_GPUS[@]} -gt 0 ]]; then
        warn "Detected ${#OTHER_GPUS[@]} unknown GPU(s), using VESA fallback"
        FINAL_GPU_PKGS+=("xf86-video-vesa")
    fi
    
    # Remove duplicates and create final package list
    GPU_PKGS=$(printf '%s\n' "${FINAL_GPU_PKGS[@]}" | sort -u | tr '\n' ' ')
    info "Selected GPU packages: $GPU_PKGS"
fi

newTask "==================================================\n=================================================="

info "Configuring mirrors..."
info "Available regions:"
echo "1) United States"
echo "2) Germany"
echo "3) United Kingdom"
echo "4) Jordan"
echo "5) Netherlands"

if read -rp "Select mirror region [1-5] (press Enter for United States): " -t 30 REGION_CHOICE; then
    info "Region choice: $REGION_CHOICE"
else
    REGION_CHOICE=1  # Default to United States if no input
    info "Timeout, defaulting to United States"
fi

# Default to United States (1) if empty
REGION_CHOICE=${REGION_CHOICE:-1}

# Map selection to country codes used by archlinux.org API
case $REGION_CHOICE in
    1) COUNTRY_CODE="US"; REGION="United States" ;;
    2) COUNTRY_CODE="DE"; REGION="Germany" ;;
    3) COUNTRY_CODE="GB"; REGION="United Kingdom" ;;
    4) COUNTRY_CODE="JO"; REGION="Jordan" ;;
    5) COUNTRY_CODE="NL"; REGION="Netherlands" ;;
    *) error "Invalid region selection" ;;
esac

info "Mirror will be set to $REGION"

newTask "==================================================\n=================================================="

info "Detecting boot mode..."
if [[ -d "/sys/firmware/efi" ]]; then
    BOOT_MODE="UEFI"
    info "UEFI boot mode detected"
else
    BOOT_MODE="BIOS"
    info "BIOS/Legacy boot mode detected"
fi

info "Select bootloader:"
if [[ "$BOOT_MODE" == "UEFI" ]]; then
    echo "1) systemd-boot (default for UEFI)"
    echo "2) GRUB"
    if read -rp "Select bootloader [1-2] (press Enter for systemd-boot): " -t 30 BOOTLOADER_CHOICE; then
        BOOTLOADER_CHOICE=${BOOTLOADER_CHOICE:-1}
        if [[ -z "$BOOTLOADER_CHOICE" ]]; then
            info "No choice made, defaulting to systemd-boot for UEFI"
            BOOTLOADER="systemd-boot"
        else
            case $BOOTLOADER_CHOICE in
                1) BOOTLOADER="systemd-boot" ;;
                2) BOOTLOADER="grub" ;;
                *) warn "Invalid choice. Defaulting to systemd-boot for UEFI."
                    BOOTLOADER="systemd-boot" ;;
            esac
        fi
    else
        BOOTLOADER="systemd-boot"
        info "Timeout, defaulting to systemd-boot for UEFI"
    fi
else
    BOOTLOADER="grub"
    info "Using GRUB as bootloader for BIOS mode as systemd-boot does not support BIOS"
fi
info "Selected bootloader: $BOOTLOADER"

echo
info "Bootloader kernel command line options:"
echo "1) quiet (minimal output, recommended for daily use)"
echo "2) debug (verbose output, useful for troubleshooting)"
if read -rp "Select bootloader kernel mode [1-2] (press Enter for quiet): " -t 30 KERNEL_MODE_CHOICE; then
    KERNEL_MODE_CHOICE=${KERNEL_MODE_CHOICE:-1}
    if [[ "$KERNEL_MODE_CHOICE" == "2" ]]; then
        KERNEL_CMDLINE="debug"
        info "Bootloader will use debug mode"
    else
        KERNEL_CMDLINE="quiet"
        info "Bootloader will use quiet mode"
    fi
else
    KERNEL_CMDLINE="quiet"
    info "Timeout, defaulting to quiet mode"
fi

newTask "==================================================\n=================================================="

echo "Press Enter or wait 30 seconds to use defaults..."
echo "Default root password: [hidden]"
echo "Default username: $DEFAULT_USERNAME"
echo "Default user password: [hidden]"
echo

while true; do
    if read -rsp "Enter root password (default: [hidden]): " -t 30 ROOT_PASSWORD; then
        echo
        # If user pressed enter without typing anything, use default
        if [[ -z "$ROOT_PASSWORD" ]]; then
            ROOT_PASSWORD="$DEFAULT_ROOT_PASSWORD"
            echo "Using default root password"
            break  # Skip confirmation for defaults
        fi
    else
        # Timeout occurred
        echo
        echo "Timeout - using default root password"
        ROOT_PASSWORD="$DEFAULT_ROOT_PASSWORD"
        break  # Skip confirmation for defaults
    fi
    
    [[ -n "$ROOT_PASSWORD" ]] || { warn "Password cannot be empty"; continue; }
    
    read -rsp "Confirm root password: " ROOT_PASSWORD_CONFIRM
    echo
    [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]] && break
    warn "Passwords don't match!"
done

if read -rp "Enter username (default: $DEFAULT_USERNAME): " -t 30 USERNAME; then
    # If user pressed enter without typing anything, use default
    if [[ -z "$USERNAME" ]]; then
        USERNAME="$DEFAULT_USERNAME"
        echo "Using default username: $USERNAME"
    fi
else
    # Timeout occurred
    echo
    echo "Timeout - using default username: $DEFAULT_USERNAME"
    USERNAME="$DEFAULT_USERNAME"
fi

[[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] || error "Invalid username"

while true; do
    if read -rsp "Enter password for $USERNAME (default: [hidden]): " -t 30 USER_PASSWORD; then
        echo
        # If user pressed enter without typing anything, use default
        if [[ -z "$USER_PASSWORD" ]]; then
            USER_PASSWORD="$DEFAULT_USER_PASSWORD"
            echo "Using default user password"
            break  # Skip confirmation for defaults
        fi
    else
        # Timeout occurred
        echo
        echo "Timeout - using default user password"
        USER_PASSWORD="$DEFAULT_USER_PASSWORD"
        break  # Skip confirmation for defaults
    fi
    
    [[ -n "$USER_PASSWORD" ]] || { warn "Password cannot be empty"; continue; }
    
    read -rsp "Confirm password: " USER_PASSWORD_CONFIRM
    echo
    [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]] && break
    warn "Passwords don't match!"
done

newTask "==================================================\n=================================================="

info "Available disks:"
lsblk -d -o NAME,SIZE,MODEL,TRAN,MOUNTPOINT

read -rp "Enter disk to wipe (e.g., vda, sda, nvme0n1): " DISK
[[ -e "/dev/$DISK" ]] || error "Disk /dev/$DISK not found"

echo
info "Selected disk layout:"
lsblk "/dev/$DISK"

# Final confirmation
read -rp "WARNING: ALL DATA ON /dev/$DISK WILL BE DESTROYED! Confirm (type 'y'): " CONFIRM
[[ "$CONFIRM" == "y" ]] || error "Operation cancelled"

newTask "==================================================\n=================================================="

info "Would you like to run my post-install script? to install sway and other packages? with my configuration files ?"
read -rp "Type 'y', or hit enter to run post-install script, and anything else to skip: " RUN_POST_INSTALL
RUN_POST_INSTALL=${RUN_POST_INSTALL:-y}
login_manager_choice="sddm" # Default login manager
if [[ "$RUN_POST_INSTALL" == "y" ]]; then
    info "Post-install script will be run after installation"
    echo ""
    info "chose the login manager you want to use"
    info "1) SDDM (Simple Desktop Display Manager)"
    info "2) Ly  (TUI lightweight display manager)"
    read -r -p "Select login manager [1-2] (default: 1): " login_manager_choice_num
    login_manager_choice_num=${login_manager_choice_num:-1}
    if [[ "$login_manager_choice_num" == "2" ]]; then
        login_manager_choice="ly"
    fi
    info "$login_manager_choice will be installed"
else
    info "Skipping post-install script"
fi

newTask "==================================================\n=================================================="

info "Would you like to reboot the system after the installation?"
read -rp "Type 'y' to reboot, or hit enter to skip: " REBOOT_AFTER_INSTALL
REBOOT_AFTER_INSTALL=${REBOOT_AFTER_INSTALL:-y}
if [[ "$REBOOT_AFTER_INSTALL" == "y" ]]; then
    info "System will reboot after installation"
else
    info "Skipping reboot after installation"
fi

newTask "==================================================\n=================================================="

cleanup_disks() {
    local attempts=3
    info "Starting cleanup process (3 attempts)..."
    
    while (( attempts-- > 0 )); do
        # Kill processes using the disk
        info "Attempt $((3-attempts)): Killing processes..."
        pids=$(lsof +f -- "/dev/$DISK"* 2>/dev/null | awk '{print $2}' | uniq)
        sleep 2
        [[ -n "$pids" ]] && kill -9 $pids 2>/dev/null
        sleep 2
        for process in $(lsof +f -- /dev/${DISK}* 2>/dev/null | awk '{print $2}' | uniq); do kill -9 "$process"; done
        sleep 2
        # try again to kill any processes using the disk
        lsof +f -- /dev/${DISK}* 2>/dev/null | awk '{print $2}' | uniq | xargs -r kill -9
        sleep 2
        
        info "Unmounting partitions..."
        umount -R "/dev/$DISK"* 2>/dev/null
        
        # Deactivate LVM
        if command -v vgchange &>/dev/null; then
            info "Deactivating LVM..."
            vgchange -an 2>/dev/null
            lvremove -f $(lvs -o lv_path --noheadings 2>/dev/null | grep "$DISK") 2>/dev/null
        fi
        
        info "Disabling swap..."
        swapoff -a 2>/dev/null
        for swap in $(blkid -t TYPE=swap -o device | grep "/dev/$DISK"); do
            swapoff -v "$swap"
        done
        sleep 2

        info "Checking for mounted partitions on /dev/$DISK..."
        for part in $(lsblk -lnp -o NAME | grep "^/dev/$DISK" | tail -n +2); do
            info "Attempting to unmount $part..."
            if ! umount "$part" 2>/dev/null; then
                warn "Failed to unmount $part, maybe it was not mounted."
            else
                info "$part unmounted successfully."
            fi
        done
        
        # Check if cleanup was successful
        if ! (mount | grep -q "/dev/$DISK") && \
           ! (lsof +f -- "/dev/$DISK"* 2>/dev/null | grep -q .); then
            echo
            info "Cleanup successful :) "
            return 0
        fi
        
    done
    
    warn "Cleanup incomplete - some resources might still be in use"
    return 1
}

if ! cleanup_disks; then
    warn "Proceeding with disk operations despite cleanup warnings"
fi

newTask "==================================================\n=================================================="

info "Wiping disk signatures..."
wipefs -a "/dev/$DISK" || error "Failed to wipe disk"

newTask "==================================================\n=================================================="

# Update partition naming (fix for NVMe disks)
if [[ "$DISK" =~ "nvme" ]]; then
    PART1="/dev/${DISK}p1"
    PART2="/dev/${DISK}p2"
    PART3="/dev/${DISK}p3"
else
    PART1="/dev/${DISK}1"
    PART2="/dev/${DISK}2"
    PART3="/dev/${DISK}3"
fi

info "Creating new GPT partition table..."
parted -s "/dev/$DISK" mklabel gpt || error "Partitioning failed"

newTask "==================================================\n=================================================="

if [[ "$BOOT_MODE" == "UEFI" ]]; then
    info "Creating UEFI partitions..."
    
    # EFI System Partition
    EFI_SIZE="2G"
    ROOT_SIZE="100%"
    
    info "Creating EFI System Partition (2G)"
    parted -s "/dev/$DISK" mkpart primary fat32 1MiB "$EFI_SIZE" || error "EFI partition failed"
    parted -s "/dev/$DISK" set 1 esp on || error "Failed to set ESP flag"
    
    info "Creating root partition"
    parted -s "/dev/$DISK" mkpart primary ext4 "$EFI_SIZE" "$ROOT_SIZE" || error "Root partition failed"
    
    # Set partition variables for UEFI
    EFI_PART="$PART1"
    ROOT_PART="$PART2"
    
    info "Formatting UEFI partitions..."
    mkfs.fat -F32 "$EFI_PART" || error "EFI format failed"
    mkfs.ext4 -F "$ROOT_PART" || error "Root format failed"

    info "Mounting UEFI partitions..."
    mkdir -p /mnt || error "Failed to create /mnt"
    mount "$ROOT_PART" /mnt || error "Failed to mount root partition"
    
    # Mount ESP based on bootloader choice
    if [[ "$BOOTLOADER" == "systemd-boot" ]]; then
        info "Mounting ESP at /boot for systemd-boot"
        mkdir -p /mnt/boot || error "Failed to create /mnt/boot"
        mount "$EFI_PART" /mnt/boot || error "Failed to mount EFI partition"
    else
        info "Mounting ESP at /boot/efi for GRUB"
        mkdir -p /mnt/boot/efi || error "Failed to create /mnt/boot/efi"
        chmod 700 /mnt/boot/efi || error "Failed to set permissions on /mnt/boot/efi"
        mkdir -p /mnt/boot/efi/loader || error "Failed to create /mnt/boot/efi/loader"
        #mount -o uid=0,gid=0,umask=077 "$EFI_PART" /mnt/boot/efi || error "Failed to mount EFI partition"
        mount "$EFI_PART" /mnt/boot/efi || error "Failed to mount EFI partition"
    fi
else
    info "Creating BIOS partitions..."
    
    BIOS_BOOT_SIZE="2MiB"
    BOOT_SIZE="2G"
    ROOT_SIZE="100%"
    
    info "Creating BIOS boot partition (2MiB)"
    parted -s "/dev/$DISK" mkpart primary 1MiB "$BIOS_BOOT_SIZE" || error "BIOS boot partition failed"
    parted -s "/dev/$DISK" set 1 bios_grub on || error "Failed to set bios_grub flag"
    
    info "Creating boot partition (2G)"
    parted -s "/dev/$DISK" mkpart primary ext4 "$BIOS_BOOT_SIZE" "$BOOT_SIZE" || error "Boot partition failed"
    
    info "Creating root partition"
    parted -s "/dev/$DISK" mkpart primary ext4 "$BOOT_SIZE" "$ROOT_SIZE" || error "Root partition failed"
    
    # Set partition variables for BIOS
    BIOS_PART="$PART1"
    BOOT_PART="$PART2"
    ROOT_PART="$PART3"
    
    info "Formatting BIOS partitions..."
    # BIOS boot partition is not formatted (raw)
    mkfs.ext4 -F "$BOOT_PART" || error "Boot format failed"
    mkfs.ext4 -F "$ROOT_PART" || error "Root format failed"
    
    info "Mounting BIOS partitions..."
    mkdir -p /mnt || error "Failed to create /mnt"
    mount "$ROOT_PART" /mnt || error "Failed to mount root partition"
    mkdir -p /mnt/boot || error "Failed to create /mnt/boot"
    mount "$BOOT_PART" /mnt/boot || error "Failed to mount boot partition"
fi

newTask "==================================================\n=================================================="

info "Verifying new layout:"
fdisk -l "/dev/$DISK" || error "Verification failed"

info "Verifying mounts:"
findmnt | grep "/mnt" || error "Mount verification failed"

info "Partitions mounted successfully for $BOOT_MODE mode:"
mount | grep "/dev/$DISK"

# Show ESP mount point for verification
if [[ "$BOOT_MODE" == "UEFI" ]]; then
    info "ESP mounted at:"
    if [[ "$BOOTLOADER" == "systemd-boot" ]]; then
        echo "  /mnt/boot (systemd-boot)"
    else
        echo "  /mnt/boot/efi (GRUB)"
    fi
fi

newTask "==================================================\n=================================================="

info "\n${GREEN}[✓] Partitioning Summary:${NO_COLOR}"
info "Boot Mode: $BOOT_MODE"
if [[ "$BOOT_MODE" == "UEFI" ]]; then
    info "EFI System Partition: $EFI_PART (mounted at /mnt/boot/efi)"
    info "Root Partition: $ROOT_PART (mounted at /mnt)"
else
    info "BIOS Boot Partition: $BIOS_PART (unformatted, for GRUB)"
    info "Boot Partition: $BOOT_PART (mounted at /mnt/boot)"
    info "Root Partition: $ROOT_PART (mounted at /mnt)"
fi
newTask "==================================================\n=================================================="

info "Enabling multilib repos"
CONFIG_FILE="/etc/pacman.conf"
info "Checking if config file exists"
if [[ ! -f "$CONFIG_FILE" ]]; then
    warn -e "Pacman configuration file not found at $CONFIG_FILE."
else
    info "Backup the original config file"
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak" || {
        warn -e "Failed to create a backup of $CONFIG_FILE."
    }

    multiline=$(grep -n "^[[:space:]]*#*[[:space:]]*\[multilib\]" "$CONFIG_FILE" | cut -d: -f1)
    multiline_num=${multiline:-0}

    info "check if mutilib section exist in the file"
    if [[ "$multiline_num" -eq 0 ]]; then
        info "Multilib section does not exist; append it"
        echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> "$CONFIG_FILE"
        info "Added [multilib] repository to $CONFIG_FILE."
    else
        info "Multilib section exists; check if it's commented"
        first_char=$(sed -n "${multiline_num}{s/^[[:space:]]*\(.\).*/\1/p; q}" "$CONFIG_FILE")
        if [[ "$first_char" == "#" ]]; then
            sed -i "${multiline_num}s/^\s*#\s*\(\[multilib\]\)/\1/" "$CONFIG_FILE"
            info "Uncommented [multilib] section in $CONFIG_FILE."

            include_line=$(($multiline_num + 1))
            sed -i "${include_line}s/^\s*#\s*\(Include = \/etc\/pacman\.d\/mirrorlist\)/\1/" "$CONFIG_FILE"
            info "Uncommented Include line for multilib repository in $CONFIG_FILE."
        else
            info "Multilib repository is already enabled in $CONFIG_FILE."
        fi
    fi
    info "Multilib repository is now enabled"
fi

newTask "==================================================\n=================================================="

info "Enabling NTP (timedate) synchronization"
timedatectl set-ntp true || warn "Failed to enable NTP synchronization"
info "Initializing pacman keyring"
pacman-key --init || warn "Failed to initialize pacman keyring"
info "Populating pacman keyring"
pacman-key --populate archlinux || warn "Failed to populate pacman keyring"
info "Syncing archlinux-keyring"
pacman -Sy archlinux-keyring --noconfirm || warn "Failed to sync archlinux-keyring"

info "Setting mirrors for $REGION"
# Create pacman.d directory if it doesn't exist
mkdir -p /etc/pacman.d || warn "Failed to create /etc/pacman.d"

# Create a default mirrorlist with a known good mirror
echo "Server = https://mirror.rackspace.com/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist || warn "Failed to create initial mirrorlist"

# Backup this working mirrorlist
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup || warn "Failed to backup mirrorlist"

# Download and configure new mirrorlist using country codes
info "Downloading mirrorlist for $REGION..."
MIRRORLIST_URL="https://archlinux.org/mirrorlist/?country=${COUNTRY_CODE}&protocol=https&use_mirror_status=on"
# Download mirrorlist with better error handling
if curl -f -s "$MIRRORLIST_URL" -o /tmp/mirrorlist.new; then
    # Uncomment all servers and remove comments
    sed -e 's/^#Server/Server/' -e '/^#/d' /tmp/mirrorlist.new > /etc/pacman.d/mirrorlist
    
    # Verify mirrorlist is not empty and has valid entries
    if [[ -s /etc/pacman.d/mirrorlist ]] && grep -q "^Server" /etc/pacman.d/mirrorlist; then
        info "Successfully downloaded mirrorlist for $REGION"
    else
        warn "Downloaded mirrorlist is empty or invalid"
        if [[ -f /etc/pacman.d/mirrorlist.backup ]]; then
            cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
            warn "Restored backup mirrorlist"
        fi
    fi
else
    warn "Failed to download mirrorlist from archlinux.org"
    warn "Mirror configuration failed - check internet connection"
fi
# Clean up temporary file
rm -f /tmp/mirrorlist.new

info "Testing mirror connectivity..."
info "This may take a moment..."

# Test mirrors with timeout
if timeout 30 pacman -Sy --noconfirm &>/dev/null; then
    info "Mirror configuration completed successfully"
    info "$(grep -c "^Server" /etc/pacman.d/mirrorlist) mirrors configured for $REGION"
else
    warn "Mirror test failed or timed out"
    if [[ -f /etc/pacman.d/mirrorlist.backup ]]; then
        cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
        warn "Restored backup mirrorlist"
        info "You may want to try a different region or check your internet connection"
    else
        # Create a fallback mirrorlist with global mirrors
        warn "Creating fallback mirrorlist with worldwide mirrors"
        cat > /etc/pacman.d/mirrorlist << 'MIRROREOF'
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = https://mirrors.kernel.org/archlinux/$repo/os/$arch
Server = https://archive.archlinux.org/repos/last/$repo/os/$arch
MIRROREOF
        info "Fallback mirrors configured"
    fi
fi

info "Mirror configuration process completed"

newTask "==================================================\n=================================================="

info "Updating package databases..."
pacman -Sy --noconfirm || warn "Failed to update package databases"

newTask "==================================================\n=================================================="

info "Creating swap file with hibernation support..."
create_swap() {
    # Get precise RAM size in bytes
    local ram_bytes=$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)
    local ram_gib=$(awk "BEGIN {print int(($ram_bytes/1073741824)+0.5)}")  # Round to nearest GB
    local swapfile="/mnt/swapfile"
    
    # For hibernation, swap should be RAM size + 10-20% (kernel docs recommendation)
    local swap_size=$(awk "BEGIN {print int($ram_bytes * 1.15)}")  # 15% larger than RAM
    
    info "System has ${ram_gib}GB RAM (precise: $(numfmt --to=iec $ram_bytes))"
    info "Creating swap file for hibernation (size: $(numfmt --to=iec $swap_size))..."
    
    # Create swap file with proper alignment for hibernation
    # Use fallocate if available (faster), otherwise dd
    if command -v fallocate >/dev/null 2>&1; then
        fallocate -l $swap_size "$swapfile" || error "Failed to create swap file with fallocate"
    else
        dd if=/dev/zero of="$swapfile" bs=1M count=$(($swap_size/1048576)) status=progress || 
            error "Failed to create swap file with dd"
    fi
    chmod 600 "$swapfile"
    mkswap "$swapfile" || error "Failed to format swap file"
    swapon "$swapfile" || error "Failed to activate swap"
    
    info "Swap file created successfully:"
    swapon --show
}

create_swap

newTask "==================================================\n=================================================="

info "Preparing to install essential packages..."
# Install essential packages
CPU_VENDOR=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
info "Detected CPU vendor: $CPU_VENDOR"
# Initialize array for inegrated gpu
declare -a INEGRATED_GPU_PKGS=()
# Fix microcode package naming
case "$CPU_VENDOR" in
    "GenuineIntel")
        UCODE_PKG="intel-ucode" 
        INEGRATED_GPU_PKGS+=("vulkan-intel" "intel-media-driver" "intel-compute-runtime" "libva-utils" "libva-intel-driver" "intel-gpu-tools")
    ;;
    "AuthenticAMD")
        UCODE_PKG="amd-ucode" 
        INEGRATED_GPU_PKGS+=("xf86-video-amdgpu" "vulkan-radeon" "radeontop")
    ;;
    *) UCODE_PKG=""; warn "Unknown CPU vendor: $CPU_VENDOR" ;;
esac

info "Installing GPU packages :\n ${GPU_PKGS}"

info "Adding pipwire packages for audio management"
PIPWIRE_PKGS="pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber"

# Base packages, adjusted for bootloader choice
if [[ "$BOOTLOADER" == "grub" ]]; then
    BASE_PKGS="base linux linux-headers linux-firmware linux-zen linux-zen-headers grub efibootmgr os-prober e2fsprogs archlinux-keyring polkit"
else
    # For systemd-boot package it's part of the base packages
    BASE_PKGS="base linux linux-headers linux-firmware linux-zen linux-zen-headers efibootmgr e2fsprogs archlinux-keyring polkit"
fi
OPTIONAL_PKGS="curl networkmanager sudo git openssh"

# Convert all package groups to arrays
declare -a BASE_PKGS_ARR=($BASE_PKGS)
declare -a OPTIONAL_PKGS_ARR=($OPTIONAL_PKGS)
declare -a PIPWIRE_PKGS_ARR=($PIPWIRE_PKGS)

# Combine arrays
INSTALL_PKGS_ARR=(
    "${BASE_PKGS_ARR[@]}"
    "${OPTIONAL_PKGS_ARR[@]}"
    "${PIPWIRE_PKGS_ARR[@]}"
    "${INEGRATED_GPU_PKGS[@]}"
)

# Add conditional packages
[[ -n "$UCODE_PKG" ]] && INSTALL_PKGS_ARR+=($UCODE_PKG)
[[ -n "$GPU_PKGS" ]] && INSTALL_PKGS_ARR+=($GPU_PKGS)
[[ -n "$VIRT_PKGS" ]] && INSTALL_PKGS_ARR+=($VIRT_PKGS)


## Check if package exists in repositories
check_package() {
    local pkg="$1"
    if pacman -Sp "$pkg" &>/dev/null; then
        return 0  # Package exists
    else
        return 1  # Package not found
    fi
}

info "Checking package availability"
for pkg in "${INSTALL_PKGS_ARR[@]}"; do
    [ -z "$pkg" ] && continue  # Skip empty elements
    if ! check_package "$pkg"; then
        warn "Skipping package $pkg as it is not available in repositories"
        # Remove from array instead of string manipulation
        INSTALL_PKGS_ARR=("${INSTALL_PKGS_ARR[@]/$pkg}")
    fi
done
# Convert back to space-separated string and remove extra spaces
INSTALL_PKGS=$(echo "${INSTALL_PKGS_ARR[@]}" | tr -s ' ')

info "Installing: "
echo "$INSTALL_PKGS"
pacstrap /mnt $INSTALL_PKGS || error "Package installation failed"

# Ensure /mnt/etc exists before generating fstab
mkdir -p /mnt/etc

info "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab || error "Failed to generate fstab"
# Fix EFI partition permissions based on bootloader
if [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    info "Fixing /boot permissions for systemd-boot"
    sed -i '/\/boot.*vfat/s/defaults/defaults,fmask=0077,dmask=0077/' /mnt/etc/fstab
else
    info "Fixing /boot/efi permissions for GRUB"
    sed -i '/\/boot\/efi.*vfat/s/defaults/defaults,fmask=0077,dmask=0077/' /mnt/etc/fstab
fi

newTask "==================================================\n=================================================="
info "==== CHROOT SETUP ===="

info "Configuring BOOTLOADER and hibernation in chroot..."
arch-chroot /mnt /bin/bash -s -- \
    "$ROOT_PASSWORD" "$USERNAME" "$USER_PASSWORD" \
    "$DISK" "$ROOT_PART" "$BOOTLOADER" "$UCODE_PKG" \
    "$BOOT_MODE" "$KERNEL_CMDLINE" \
<<'EOF' || error "Chroot commands failed"

set +u

# Pass variables from parent script
ROOT_PASSWORD="${1}"
USERNAME="${2}"
USER_PASSWORD="${3}"
DISK="${4}"
ROOT_PART="${5}"
BOOTLOADER="${6}"
UCODE_PKG="${7}"
BOOT_MODE="${8}"
KERNEL_CMDLINE="${9}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NO_COLOR='\033[0m'

error() { echo -e "${RED}[ERROR] $*${NO_COLOR}" >&2; exit 1; }
info() { echo -e "${GREEN}[*] $*${NO_COLOR}"; }
newTask() { echo -e "${BLUE}$*${NO_COLOR}"; }
warn() { echo -e "${YELLOW}[WARN] $*${NO_COLOR}"; }

TIMEZONE="Asia/Amman"
LOCALE="en_US.UTF-8"
HOSTNAME="${USERNAME}Arch"

# Set timezone
info "Setting timezone to ${TIMEZONE}"
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Set locale
info "Setting locale to ${LOCALE}"
sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

# Set hostname and hosts
info "Setting hostname to ${HOSTNAME}"
echo "$HOSTNAME" > /etc/hostname
cat <<HOSTSEOF > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTSEOF

newTask "==================================================\n=================================================="

# Set root password
info "Setting root password"
echo "root:${ROOT_PASSWORD}" | chpasswd

# Create user 
info "Creating user ${USERNAME} account"
useradd -m -G wheel -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd

newTask "==================================================\n=================================================="

# Ensure home directory exists and has correct permissions
mkdir -p "/home/$USERNAME" || error "Failed to create home directory"
# Set ownership and permissions
info "Setting ownership and permissions for /home/$USERNAME"
chown "$USERNAME:$USERNAME" "/home/$USERNAME"
chmod 755 "/home/$USERNAME"

newTask "==================================================\n=================================================="

# Configure mkinitcpio for hibernation
info "Configuring mkinitcpio for hibernation"
# Backup original config
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup

# Add resume hook AFTER filesystems but BEFORE fsck
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems resume fsck)/' /etc/mkinitcpio.conf

# Regenerate initramfs
mkinitcpio -P || error "Failed to regenerate initramfs"

info "Installing ${BOOTLOADER} bootloader for $BOOT_MODE mode"
if [[ "$BOOTLOADER" == "grub" ]]; then
    info "Installing GRUB bootloader (running grub-install)"
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable || {
            error "GRUB UEFI installation failed"
        }
        info "GRUB installed successfully for UEFI"
    else
        grub-install --target=i386-pc "/dev/$DISK" || {
            error "GRUB BIOS installation failed"
        }
        info "GRUB installed successfully for BIOS"
    fi
elif [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    if [[ "$BOOT_MODE" != "UEFI" ]]; then
        error "systemd-boot requires UEFI boot mode"
    fi
    
    # For systemd-boot, ESP should be mounted at /boot
    if ! mountpoint -q /boot; then
        error "ESP not mounted at /boot for systemd-boot"
    fi
    
    info "Installing systemd-boot (running bootctl)"
    bootctl install || {
        error "systemd-boot installation failed"
    }
    info "systemd-boot installed successfully for UEFI"
fi

# Now configure hibernation with proper error checking
info "Configuring hibernation"
# Get root partition UUID
ROOT_UUID=$(blkid -s UUID -o value "${ROOT_PART}")
if [[ -z "$ROOT_UUID" ]]; then
    warn "Could not get root partition UUID, hibernation may not work properly"
    ROOT_UUID=$(blkid -s UUID -o value $(findmnt -n -o SOURCE /))
fi

# Calculate swapfile offset (critical for hibernation)
info "Calculating swapfile offset for hibernation"
if [[ ! -f /swapfile ]]; then
    warn "Swapfile not found at /swapfile"
    SWAPFILE_OFFSET=""
fi

# Check if filefrag is available
if ! command -v filefrag >/dev/null 2>&1; then
    warn "filefrag command not found, hibernation may not work"
    SWAPFILE_OFFSET=""
    pacman -S --noconfirm e2fsprogs || {
        warn "Failed to install e2fsprogs which provides filefrag"
    }
fi

# Get swapfile offset with multiple methods for robustness
SWAPFILE_OFFSET=$(filefrag -v /swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}')
if [[ -z "$SWAPFILE_OFFSET" ]] || [[ "$SWAPFILE_OFFSET" == "0" ]]; then
    warn "First method failed, trying second method..."
    SWAPFILE_OFFSET=$(filefrag -v /swapfile 2>/dev/null | awk 'NR==4 {gsub(/\\.\\.*/, "", $4); print $4}')
    if [[ -z "$SWAPFILE_OFFSET" ]] || [[ "$SWAPFILE_OFFSET" == "0" ]]; then
        warn "First and second methods failed, trying alternative..."
        SWAPFILE_OFFSET=$(filefrag -v /swapfile 2>/dev/null | awk '/^ *0:/ {print $4}' | sed 's/\\.\\.//')
        if [[ -z "$SWAPFILE_OFFSET" ]] || [[ "$SWAPFILE_OFFSET" == "0" ]]; then
            warn "All methods failed, trying last resort..."
            SWAPFILE_OFFSET=$(filefrag -v /swapfile | head -n 4 | tail -n 1 | awk '{print $4}' | sed 's/\.\.//')
        fi
    fi
fi

if [[ "$BOOTLOADER" == "grub" ]]; then
    # Generate GRUB config with proper path
    info "Generating GRUB configuration"
    mkdir -p /boot/grub || error "Failed to create /boot/grub directory"

    info "Backing up original GRUB configuration"
    cp /etc/default/grub /etc/default/grub.backup

    # Final validation for GRUB
    if [[ -z "$SWAPFILE_OFFSET" ]] || [[ "$SWAPFILE_OFFSET" == "0" ]]; then
        warn "Could not determine swapfile offset. Hibernation may not work."
        warn "You can calculate it manually later with: filefrag -v /swapfile"
        # Set default GRUB config without hibernation
        sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 $KERNEL_CMDLINE\"/" /etc/default/grub
    else
        info "Swapfile offset: $SWAPFILE_OFFSET"
        # Configure GRUB with hibernation support
        sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 $KERNEL_CMDLINE resume=UUID=$ROOT_UUID resume_offset=$SWAPFILE_OFFSET\"/" /etc/default/grub
    fi

    info "Configuring GRUB for dual boot"
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub

    info "run grub-mkconfig to generate GRUB configuration"
    grub-mkconfig -o /boot/grub/grub.cfg || error "Failed to generate GRUB configuration"

elif [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    # For systemd-boot, everything goes in /boot (which is the ESP)
    mkdir -p /boot/loader/entries || error "Failed to create /boot/loader/entries directory"
    
    # Copy microcode if it exists
    if [[ -f /boot/${UCODE_PKG}.img ]]; then
        UCODE_LINE="initrd /${UCODE_PKG}.img"
    else
        UCODE_LINE=""
    fi

    info "Configuring systemd-boot entries"
    cat > /boot/loader/loader.conf <<LOADEREOF
default 99-arch.conf
timeout 1
console-mode max
editor no
LOADEREOF

    # Create proper systemd-boot entry
    cat > /boot/loader/entries/99-arch.conf <<ENTRYEOF
title Arch Linux
linux /vmlinuz-linux
${UCODE_LINE}
initrd /initramfs-linux.img
options root=UUID=${ROOT_UUID} rw loglevel=3 $KERNEL_CMDLINE resume=UUID=${ROOT_UUID} resume_offset=${SWAPFILE_OFFSET}
ENTRYEOF

    # Create fallback entry
    cat > /boot/loader/entries/97-arch-fallback.conf <<ENTRYEOF
title Arch Linux (fallback initramfs)
linux /vmlinuz-linux
${UCODE_LINE}
initrd /initramfs-linux-fallback.img
options root=UUID=${ROOT_UUID} rw
ENTRYEOF

    # Create zen entry (only if zen kernel is installed)
    if [[ -f /boot/vmlinuz-linux-zen ]]; then
        cat > /boot/loader/entries/98-arch-zen.conf <<ZENEOF
title Arch Linux (linux-zen)
linux /vmlinuz-linux-zen
${UCODE_LINE}
initrd /initramfs-linux-zen.img
options root=UUID=${ROOT_UUID} rw loglevel=3 $KERNEL_CMDLINE resume=UUID=${ROOT_UUID} resume_offset=${SWAPFILE_OFFSET}
ZENEOF

        # Create zen fallback entry
        cat > /boot/loader/entries/96-arch-zen-fallback.conf <<ZENFALLBACKEOF
title Arch Linux (linux-zen fallback initramfs)
linux /vmlinuz-linux-zen
${UCODE_LINE}
initrd /initramfs-linux-zen-fallback.img
options root=UUID=${ROOT_UUID} rw
ZENFALLBACKEOF
    fi

    # Final validation for systemd-boot
    if [[ -z "$SWAPFILE_OFFSET" ]] || [[ "$SWAPFILE_OFFSET" == "0" ]]; then
        warn "Could not determine swapfile offset. Hibernation may not work."
        warn "You can calculate it manually later with: filefrag -v /swapfile"
        # Remove hibernation parameters from boot entries
        sed -i "s/ resume=UUID=${ROOT_UUID} resume_offset=${SWAPFILE_OFFSET}//" /boot/loader/entries/arch.conf
        if [[ -f /boot/loader/entries/arch-zen.conf ]]; then
            sed -i "s/ resume=UUID=${ROOT_UUID} resume_offset=${SWAPFILE_OFFSET}//" /boot/loader/entries/arch-zen.conf
        fi
    else
        info "Swapfile offset: $SWAPFILE_OFFSET"
        info "systemd-boot entries configured with hibernation support"
    fi

    info "systemd-boot configuration completed"
fi

info "Bootloader configuration completed for $BOOTLOADER in $BOOT_MODE mode"
info "Resume UUID: $ROOT_UUID"
info "Resume offset: $SWAPFILE_OFFSET"

newTask "==================================================\n=================================================="

info "Installing memtest86+ for memory testing"

if [[ "$BOOTLOADER" == "grub" ]]; then
    info "Installing memtest86+ for GRUB"
    
    # Install the traditional memtest86+ for GRUB compatibility
    pacman -S --needed --noconfirm memtest86+ || warn "Failed to install memtest86+"
    
    # Update GRUB configuration to include memtest86+
    grub-mkconfig -o /boot/grub/grub.cfg || warn "Failed to update GRUB configuration"
    
    # Verify memtest86+ was added to GRUB menu
    if grep -q "Memory test" /boot/grub/grub.cfg; then
        info "memtest86+ successfully added to GRUB menu"
    else
        warn "memtest86+ may not have been properly added to GRUB menu"
    fi
elif [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    info "Installing memtest86+ for systemd-boot"
    
    pacman -S --needed --noconfirm memtest86+-efi || warn "Failed to install memtest86+efi"

    cat > /boot/loader/entries/95-memtest86+-efi.conf <<MEMTESTEOF
title Memory Test (memtest86+-efi)
efi /memtest86+/memtest.efi
options
MEMTESTEOF

    bootctl update || true
fi

newTask "==================================================\n=================================================="

# (hibernate on lid close)
info "Configuring systemd for hibernation on lid close"
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/hibernate.conf <<HIBERNATEEOF
[Login]
HandleLidSwitch=hibernate
HandleLidSwitchExternalPower=hibernate
HandlePowerKey=hibernate
IdleAction=ignore
IdleActionSec=30min
HIBERNATEEOF

info "Configuring systemd sleep settings for hibernation"
cat > /etc/systemd/sleep.conf <<HIBERNATIONSLEEPEOF
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
AllowHybridSleep=yes
HibernateDelaySec=180min
HIBERNATIONSLEEPEOF

info "${BOOTLOADER} installation and configuration completed for $BOOT_MODE mode"

info "Regenerating initramfs for hibernation support"
mkinitcpio -P || error "Failed to regenerate initramfs"

newTask "==================================================\n=================================================="

# Enable services
info "Enabling openssh service"
systemctl enable sshd || warn "Failed to enable sshd"

# Clear sensitive variables in chroot
unset ROOT_PASSWORD USER_PASSWORD

EOF

newTask "==================================================\n=================================================="

#========================================
#  HIBERNATION TESTING COMMANDS (for post-install)
#========================================
info "Creating hibernation test script"
cat > /mnt/home/$USERNAME/test_hibernation.sh <<EOF
#!/bin/bash
echo "Testing hibernation setup..."
echo "1.0 Check if swap is active:"
swapon --show
echo ""

echo "2.0 Check hibernation support:"
cat /sys/power/state
echo ""

echo "3.0 Check current bootloader configuration:"
if [[ "$BOOTLOADER" == "grub" ]]; then
    sudo grep -i resume /proc/cmdline
elif [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    sudo cat /boot/efi/loader/entries/arch.conf | grep resume
fi
echo ""

echo "4.0 Check systemd hibernate configuration:"
systemctl status systemd-logind
echo ""

echo "5.0 Test hibernation (WARNING: This will hibernate the system!):"
echo "     sudo systemctl hibernate"
echo "5.1 If you encounter issues, check the logs:"
echo "     journalctl -b -1 -u systemd-logind"
echo ""

echo "Setup appears to be: \$(grep -q 'resume=' /proc/cmdline && echo 'COMPLETE' || echo 'INCOMPLETE')"
EOF

info "Hibernation test script created at /home/$USERNAME/test_hibernation.sh"
chmod +x /mnt/home/$USERNAME/test_hibernation.sh
chown 1000:1000 /mnt/home/$USERNAME/test_hibernation.sh


newTask "==================================================\n=================================================="
echo
info "====${BLUE} POST-CHROOT CONFIGURATION ${GREEN}===="
echo
# Add swapfile entry to fstab for hibernation
#info "Configuring fstab for hibernation support" 
#echo "# Swap file for hibernation" >> /mnt/etc/fstab
#echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
#info "Hibernation support configured in fstab and $BOOTLOADER"

newTask "==================================================\n=================================================="

info "Enabling NetworkManager service"
arch-chroot /mnt systemctl enable NetworkManager || warn "NetworkManager not installed"

info "Enabling polkit service"
arch-chroot /mnt systemctl enable polkit || warn "Failed to enable polkit"

info "Enable PipeWire services"
arch-chroot /mnt /bin/bash <<PIPWIREEOF
systemctl --user enable pipewire.service
systemctl --user enable pipewire-pulse.service
systemctl --user enable wireplumber.service
PIPWIREEOF

info "Configuring sudo for user $USERNAME"
echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers || warn "Failed to configure sudo"

# Ensure all writes are committed to disk before cleanup
sync

# Cleanup will run automatically due to trap
# cleanup  # no need to uncommit this line as it's redundant
sleep 1

newTask "==================================================\n==================================================\n"

if [[ "$RUN_POST_INSTALL" == "y" ]]; then
    info "Running post-install script..."

    arch-chroot /mnt /bin/bash -s -- "$USERNAME" "$login_manager_choice" <<'POSTINSTALLEOF' || error "Post-install script failed to run"

USER_NAME="$1"
LOGIN_MANAGER="$2"

echo -e "\n"

echo "Temporarily disabling sudo password for wheel group"
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

su "$USER_NAME" <<USEREOF
    echo "Running post-install script as user \$USER with login manager $LOGIN_MANAGER..."
    bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/sway/install.sh) --login-manager "$LOGIN_MANAGER" || echo "Failed to run the install script"
USEREOF

echo "Restoring sudo password requirement for wheel group"
sed -i '/^%wheel ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers
echo -e "\n"
POSTINSTALLEOF
else
    warn "Skipping post-install script, you may reboot now."
    info "if you would like to run my post-install script later, you can run it with the command:"
    info "bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/sway/install.sh) --login-manager \"$login_manager_choice\""
fi

newTask "==================================================\n==================================================\n"

info "\n${GREEN}[✓] INSTALLATION COMPLETE!${NO_COLOR}"
info "\n${YELLOW}Next steps:${NO_COLOR}"
info "1. Reboot: systemctl reboot"
info "2. After reboot, run the hibernation test script:"
info "   /home/$USERNAME/test_hibernation.sh"
info "3. If hibernation works, you can remove the test script:"
info "   rm /home/$USERNAME/test_hibernation.sh"
info "4. Check GPU: lspci -k | grep -A 3 -E '(VGA|3D)'\n"

info "Remember your credentials:"
info "  Root password: Set during installation"
info "  User: $USERNAME (with sudo privileges)"


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

if [[ "$REBOOT_AFTER_INSTALL" == "y" ]]; then
    info "Rebooting system in 7 seconds..."
    i=1
    for ((i=1; i<=7; i++)); do
        echo -ne "\rRebooting in $((8-i)) seconds..."
        sleep 1
    done
    systemctl reboot || error "Failed to reboot system"
else
    info "You can reboot the system manually when ready."
fi

### version 0.7.4 ###
