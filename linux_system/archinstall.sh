#!/usr/bin/env bash

# Arch Linux Installation Script

# Redirect stdout and stderr to archsetuplogs.txt and still output to console
exec > >(tee -i archsetuplogs.txt)
exec 2>&1

set -uo pipefail  # Strict error handling
trap 'cleanup' EXIT  # Ensure cleanup runs on exit

# Set default values
DEFAULT_ROOT_PASSWORD="" # the default is the same as user password
DEFAULT_USERNAME="user"
DEFAULT_USER_PASSWORD="user123"

start_time=$(date +%s)

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
bold="\e[1m"
no_color='\033[0m' # reset the color to default

# Security cleanup function
cleanup() {
	unset ROOT_PASSWORD USER_PASSWORD  # Wipe passwords from memory
	sync
	if mountpoint -q /mnt; then
		umount -R /mnt 2>/dev/null
	fi
}

error() { echo -e "${red}[ERROR] $*${no_color}" >&2; exit 1; }
info() { echo -e "${cyan}[*]${green} $*${no_color}"; }
newTask() { echo -e "${blue}$*${no_color}"; }
warn() { echo -e "${yellow}[WARN] $*${no_color}"; }

# Check if running from Arch Linux ISO (requires pacstrap)
if [ ! -f /usr/bin/pacstrap ]; then
	error "This script must be run from an Arch Linux ISO environment (pacstrap not found)."
fi
if [[ ! -e /etc/arch-release ]]; then
	error "This script must be run in Arch Linux!"
fi
# Check if pacman is locked
if [[ -f /var/lib/pacman/db.lck ]]; then
	error "Pacman is locked. If no other instance is running, remove /var/lib/pacman/db.lck"
fi

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Checking for root privileges"
[[ $(id -u) -eq 0 ]] || error "This script must be run as root"

info "Checking internet connection"
if ! ping -c 1 -W 5 archlinux.org &>/dev/null; then
	warn "No internet connection detected!"
	read -rp "Continue without internet? (not recommended) [y/N]: " NO_NET
	[[ "$NO_NET" == "y" ]] || error "Aborted"
fi

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

IS_VM=false
declare -a VIRT_PKGS=()
declare -a GPU_PKGS=()
GPU_OPTS=false

info "Detecting system environment..."
if systemd-detect-virt --vm &>/dev/null; then
	VIRT_TYPE=$(systemd-detect-virt)
	IS_VM=true
	info "Virtual machine detected: $VIRT_TYPE"

	info "Configuring VM graphics drivers..."
	case "$VIRT_TYPE" in
		"kvm"|"qemu"|"microsoft"|"hyperv")
			VIRT_PKGS+=("qemu-guest-agent" "spice-vdagent" "xf86-video-qxl" "vulkan-virtio" "virglrenderer")
			info "Added VirtIO/QXL drivers with VirGL 3D acceleration"
			;;
		"virtualbox")
			VIRT_PKGS+=("virtualbox-guest-utils")
			info "Added VirtualBox guest utilities"
			;;
		"vmware"|"svga")
			VIRT_PKGS+=("open-vm-tools" "xf86-video-vmware")
			info "Added VMware SVGA driver"
			;;
		*)
			VIRT_PKGS+=("vulkan-swrast")
			warn "Unknown virtualization platform: $VIRT_TYPE"
			info "Using Software Rasterizer (vulkan-swrast) for fallback"
			;;
	esac
else
	info "Running on physical hardware"
fi

if [[ ${#VIRT_PKGS[@]} -eq 0 ]]; then
	info "No virtualization packages will be installed."
else
	info "Virtualization packages: ${VIRT_PKGS[*]}"
fi

info "Detecting GPU devices..."
# Use IFS to prevent word splitting
OLD_IFS="$IFS"
IFS=$'\n'
GPU_DEVICES=($(lspci | grep -E "VGA|3D|Display" | awk -F': ' '{print $2}'))
IFS="$OLD_IFS"

if [[ ${#GPU_DEVICES[@]} -eq 0 ]]; then
	warn "No GPU devices detected!"
	if [[ "$IS_VM" == true ]]; then
		GPU_PKGS+=("mesa")  # Mesa only for VMs without detected GPU
	else
		GPU_PKGS+=("mesa" "xf86-video-vesa")  # Fallback
	fi
else
	# Initialize arrays for different GPU types
	declare -a AMD_GPUS=()
	declare -a INTEL_GPUS=()
	declare -a NVIDIA_GPUS=()
	declare -a OTHER_GPUS=()
	
	# Add base GPU packages
	GPU_PKGS+=("mesa" "lib32-mesa" "mesa-utils" "lib32-mesa-utils" "vulkan-tools" "vulkan-icd-loader" "lib32-vulkan-icd-loader")
	
	info "Found ${#GPU_DEVICES[@]} GPU device(s):"
	for ((i=0; i<${#GPU_DEVICES[@]}; i++)); do
		echo "Categorize GPU $((i+1)): ${GPU_DEVICES[$i]}"
		
		gpu_lower=$(echo "${GPU_DEVICES[$i]}" | tr '[:upper:]' '[:lower:]')
		if echo "$gpu_lower" | grep -q "\bnvidia\b\|geforce\|quadro\|tesla"; then
			NVIDIA_GPUS+=("${GPU_DEVICES[$i]}")
			info "NVIDIA GPU detected: ${GPU_DEVICES[$i]}"
		elif echo "$gpu_lower" | grep -q "\bamd\b\|\bati\b\|radeon"; then
			AMD_GPUS+=("${GPU_DEVICES[$i]}")
			info "AMD GPU detected: ${GPU_DEVICES[$i]}"
		elif echo "$gpu_lower" | grep -q "\bintel\b"; then
			INTEL_GPUS+=("${GPU_DEVICES[$i]}")
			info "Intel GPU detected: ${GPU_DEVICES[$i]}"
		elif echo "$gpu_lower" | grep -q "\bqxl\|virtio\|vmware\|svga\|virtualbox"; then
			continue
		else
			OTHER_GPUS+=("${GPU_DEVICES[$i]}")
			warn "Unknown GPU detected: ${GPU_DEVICES[$i]}"
		fi
	done
	
	info "Configuring physical GPU drivers if exists..."

	# Handle AMD GPUs
	if [[ ${#AMD_GPUS[@]} -gt 0 ]]; then
		info "Detected ${#AMD_GPUS[@]} AMD GPU(s)"
		echo "Select AMD driver:"
		echo "1) AMDGPU (recommended for GCN 1.2+ and newer)"
		echo "2) Radeon (legacy, for older GPUs)"
		read -rp "Select AMD driver [1-2]: " AMD_CHOICE
		case ${AMD_CHOICE:-1} in
			1) 
				# Modern AMD GPUs (GCN 3 or newer / 2015+)
				GPU_PKGS+=("xf86-video-amdgpu" "vulkan-radeon" "lib32-vulkan-radeon" "libva-mesa-driver" "radeontop")
				;;
			2) 
				# Legacy ATI/Radeon GPUs (Pre-2015)
				GPU_PKGS+=("xf86-video-ati" "libva-mesa-driver" "radeontop")
				;;
		esac
	fi
	
	# Handle Intel GPUs
	if [[ ${#INTEL_GPUS[@]} -gt 0 ]]; then
		info "Detected ${#INTEL_GPUS[@]} Intel GPU(s)"
		GPU_PKGS+=("vulkan-intel" "lib32-vulkan-intel" "intel-compute-runtime" "libva-utils" "intel-gpu-tools")
		
		# Detect CPU Generation to choose correct VAAPI driver
		CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo)
		
		# Check for Gen 5+ (Broadwell and newer)
		if [[ "$CPU_MODEL" =~ i[3579]-([5-9]|[1-9][0-9]) ]] || [[ "$CPU_MODEL" =~ (N[0-9]{4}|J[0-9]{4}) ]]; then
			info "Detected Modern Intel CPU (Gen 5+), using intel-media-driver"
			GPU_PKGS+=("intel-media-driver" "lib32-intel-media-driver")
		else
			info "Detected Older Intel CPU (Pre-Gen 5), using libva-intel-driver"
			GPU_PKGS+=("libva-intel-driver" "lib32-libva-intel-driver")
		fi
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
			1)
				GPU_PKGS+=("xf86-video-nouveau" "vulkan-nouveau" "vulkan-mesa-layers")
				GPU_OPTS=false
				;;
			2)
				GPU_PKGS+=("nvidia-dkms" "nvidia-utils" "lib32-nvidia-utils" "nvidia-settings" "nvidia-prime")
				GPU_OPTS=true
				;;
			3)
				GPU_PKGS+=("nvidia-open-dkms" "nvidia-utils" "lib32-nvidia-utils" "nvidia-settings" "nvidia-prime")
				GPU_OPTS=true
				;;
			*)
				warn "Invalid choice. Defaulting to Nouveau (Option 1)."
				GPU_PKGS+=("xf86-video-nouveau" "vulkan-nouveau" "vulkan-mesa-layers")
				GPU_OPTS=false
				;;
		esac
	fi

	# Handle other/unknown GPUs
	if [[ ${#OTHER_GPUS[@]} -gt 0 ]]; then
		warn "Detected ${#OTHER_GPUS[@]} unknown GPU(s), using VESA fallback"
		GPU_PKGS+=("xf86-video-vesa")
	fi
	
	info "Selected GPU packages: ${GPU_PKGS[*]}"
fi

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

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

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

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
	echo "1) GRUB"
	echo "2) systemd-boot"
	if read -rp "Select bootloader [1-2] (press Enter for grub): " -t 30 BOOTLOADER_CHOICE; then
		BOOTLOADER_CHOICE=${BOOTLOADER_CHOICE:-1}
		if [[ -z "$BOOTLOADER_CHOICE" ]]; then
			info "Choosing GRUB as bootloader"
			BOOTLOADER="grub"
		else
			case $BOOTLOADER_CHOICE in
				1) BOOTLOADER="grub" ;;
				2) BOOTLOADER="systemd-boot" ;;
				*) warn "Invalid choice. Defaulting to GRUB."
					BOOTLOADER="grub" ;;
			esac
		fi
	else
		BOOTLOADER="grub"
		info "Timeout, defaulting to GRUB"
	fi
else
	BOOTLOADER="grub"
	info "Using GRUB as bootloader for BIOS mode as systemd-boot does not support BIOS"
fi
info "Selected bootloader: $BOOTLOADER"

# Bootloader kernel command line, this command to reduce the amount of output on boot (for faster boot)
# other options: debug.
KERNEL_CMDLINE="quiet"

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

if read -rp "Enter username (timeout 30s, default: $DEFAULT_USERNAME): " -t 30 USERNAME; then
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
echo -e "${blue}--------------------------------------------------${no_color}"
[[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] || error "Invalid username"

while true; do
	if read -rsp "Enter password for $USERNAME (timeout 30s, default: $DEFAULT_USER_PASSWORD): " -t 30 USER_PASSWORD; then
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

if [[ -z "$DEFAULT_ROOT_PASSWORD" ]]; then
	ROOT_PASSWORD="$USER_PASSWORD"
else
	ROOT_PASSWORD="$DEFAULT_ROOT_PASSWORD"
fi

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

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

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Would you like to run my post-install script? to install window manager and other packages? with my configuration files ?"
read -rp "Type 'y' to run post-install script, or hit enter to skip: " RUN_POST_INSTALL
RUN_POST_INSTALL=${RUN_POST_INSTALL:-n}
if [[ "$RUN_POST_INSTALL" == "y" ]]; then
	info "Post-install script will be run after installation"
else
	info "Skipping post-install script"
fi

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Would you like to reboot the system after the installation?"
read -rp "Type 'y' to reboot, or hit enter to skip: " REBOOT_AFTER_INSTALL
REBOOT_AFTER_INSTALL=${REBOOT_AFTER_INSTALL:-n}
if [[ "$REBOOT_AFTER_INSTALL" == "y" ]]; then
	info "System will reboot after installation"
else
	info "Skipping reboot after installation"
fi

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

free_disk_from_processes() {
	local attempts=3
	info "Freeing disk from processes ($attempts attempts)..."
	
	while (( attempts-- > 0 )); do
		# Kill processes using the disk
		info "Attempt $((3-attempts)): Killing processes..."
		pids=$(lsof +f -- "/dev/$DISK"* 2>/dev/null | awk '{print $2}' | uniq)
		sleep 1
		[[ -n "$pids" ]] && kill -9 $pids 2>/dev/null
		sleep 1
		for process in $(lsof +f -- /dev/${DISK}* 2>/dev/null | awk '{print $2}' | uniq); do kill -9 "$process"; done
		sleep 1
		# try again to kill any processes using the disk
		lsof +f -- /dev/${DISK}* 2>/dev/null | awk '{print $2}' | uniq | xargs -r kill -9
		sleep 1
		
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
		sleep 1

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

if ! free_disk_from_processes; then
	warn "Proceeding with disk operations despite cleanup warnings"
fi

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Wiping disk signatures..."
wipefs -a "/dev/$DISK" || error "Failed to wipe disk"

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

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

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

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

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

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

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "\n${green}[✓] Partitioning Summary:${no_color}"
info "Boot Mode: $BOOT_MODE"
if [[ "$BOOT_MODE" == "UEFI" ]]; then
	info "EFI System Partition: $EFI_PART (mounted at /mnt/boot/efi)"
	info "Root Partition: $ROOT_PART (mounted at /mnt)"
else
	info "BIOS Boot Partition: $BIOS_PART (unformatted, for GRUB)"
	info "Boot Partition: $BOOT_PART (mounted at /mnt/boot)"
	info "Root Partition: $ROOT_PART (mounted at /mnt)"
fi
newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Enabling NTP (timedate) synchronization"
timedatectl set-ntp true || warn "Failed to enable NTP synchronization"
info "Initializing pacman keyring"
pacman-key --init || warn "Failed to initialize pacman keyring"
info "Populating pacman keyring"
pacman-key --populate archlinux || warn "Failed to populate pacman keyring"
info "Syncing archlinux-keyring"
pacman -Sy --noconfirm archlinux-keyring || warn "Failed to sync archlinux-keyring"
info "Installing pacman-contrib to sort mirrors by speed"
#TODO: sort the mirrors by speed
pacman -S --noconfirm pacman-contrib || warn "Failed to install pacman-contrib"

info "Enabling parallel downloads"
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf || warn "Failed to enable parallel downloads"

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

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Enabling multilib repository for the installer environment"
CONFIG_FILE="/etc/pacman.conf"
if grep -q "^#\[multilib\]" "$CONFIG_FILE"; then
	sed -i '/\[multilib\]/,/Include/s/^#//' "$CONFIG_FILE"
	pacman -Sy --noconfirm || warn "Failed to update package databases with multilib enabled"
fi

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Updating package databases..."
pacman -Sy --noconfirm || warn "Failed to update package databases"

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

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
		dd if=/dev/zero of="$swapfile" bs=1M count=$(($swap_size/1048576)) status=progress || \
			error "Failed to create swap file with dd"
	fi
	chmod 600 "$swapfile"
	mkswap "$swapfile" || error "Failed to format swap file"
	swapon "$swapfile" || error "Failed to activate swap"
	
	info "Swap file created successfully:"
	swapon --show
}

create_swap

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Preparing to install essential packages..."
# Install essential packages
CPU_VENDOR=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
info "Detected CPU vendor: $CPU_VENDOR"
# Fix microcode package naming
case "$CPU_VENDOR" in
	"GenuineIntel") UCODE_PKG="intel-ucode" ;;
	"AuthenticAMD") UCODE_PKG="amd-ucode" ;;
	*) UCODE_PKG=""; warn "Unknown CPU vendor: $CPU_VENDOR" ;;
esac

info "Adding pipewire packages for audio management"
declare -a PIPEWIRE_PKGS=(
	pipewire
	pipewire-alsa
	pipewire-pulse
	pipewire-jack
	wireplumber
)

# Base packages, adjusted for bootloader choice
if [[ "$BOOTLOADER" == "grub" ]]; then
	declare -a BASE_PKGS=(
		base linux linux-headers linux-firmware linux-zen linux-zen-headers
		grub efibootmgr os-prober e2fsprogs archlinux-keyring
	)
else
	declare -a BASE_PKGS=(
		base linux linux-headers linux-firmware linux-zen linux-zen-headers
		efibootmgr e2fsprogs archlinux-keyring
	)
fi

declare -a OPTIONAL_PKGS=(curl networkmanager sudo git openssh terminus-font)

# Combine arrays
declare -a INSTALL_PKGS_ARR=(
	"${BASE_PKGS[@]}"
	"${OPTIONAL_PKGS[@]}"
	"${PIPEWIRE_PKGS[@]}"
)

# Add cpu and gpu pkgs
[[ -n "$UCODE_PKG" ]]           && INSTALL_PKGS_ARR+=("$UCODE_PKG")
[[ ${#GPU_PKGS[@]} -gt 0 ]]     && INSTALL_PKGS_ARR+=("${GPU_PKGS[@]}")
[[ ${#VIRT_PKGS[@]} -gt 0 ]]    && INSTALL_PKGS_ARR+=("${VIRT_PKGS[@]}")

info "Checking package availability and removing duplicates"
declare -A seen_pkgs
declare -a VALID_PKGS=()
for item in "${INSTALL_PKGS_ARR[@]}"; do
	[[ -z "$item" ]] && continue
	
	# Split items if they contain spaces (like "lib32-vulkan-radeon radeontop")
	for pkg in $item; do
		# Skip if we've already processed this package
		[[ -n "${seen_pkgs[$pkg]:-}" ]] && continue
		
		if pacman -Sp "$pkg" &>/dev/null; then
			VALID_PKGS+=("$pkg")
			seen_pkgs[$pkg]=1
		else
			error_msg=$(pacman -Sp "$pkg" 2>&1 >/dev/null)
			warn "Skipping package ${red}$pkg${yellow}: ${error_msg:-"not found in repositories"}"
		fi
	done
done

# Convert to space-separated string for pacstrap
INSTALL_PKGS="${VALID_PKGS[*]}"

info "Installing: "
echo "$INSTALL_PKGS"
pacstrap /mnt $INSTALL_PKGS || error "Package installation failed"

# Ensure /mnt/etc exists before generating fstab
mkdir -p /mnt/etc

if [[ "$GPU_OPTS" == true ]]; then
	info "Blacklisting nouveau driver..."
	mkdir -p /mnt/etc/modprobe.d
	echo "blacklist nouveau" > /mnt/etc/modprobe.d/blacklist-nouveau.conf
fi

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

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"
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
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
bold="\e[1m"
no_color='\033[0m'

error() { echo -e "${red}[ERROR] $*${no_color}" >&2; exit 1; }
info() { echo -e "${green}[*] $*${no_color}"; }
newTask() { echo -e "${blue}$*${no_color}"; }
warn() { echo -e "${yellow}[WARN] $*${no_color}"; }

TIMEZONE="Asia/Amman"
LOCALE="en_US.UTF-8"
HOSTNAME="${USERNAME}Arch"
KEYMAP="us"

# Set timezone
info "Setting timezone to ${TIMEZONE}"
timedatectl set-timezone ${TIMEZONE} || warn "Failed to set timezone"
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

timedatectl set-ntp true || warn "Failed to enable NTP synchronization"
systemctl enable systemd-timesyncd || warn "Failed to enable systemd-timesyncd"

# Set locale
info "Setting locale to ${LOCALE}"
sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf

# Set keymaps
info "Setting keymap to ${KEYMAP}"
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
echo "XKBLAYOUT=${KEYMAP}" >> /etc/vconsole.conf
echo "Keymap set to: ${KEYMAP}"
info "Installing tty font"
echo "FONT=ter-v18b" >> /etc/vconsole.conf
setfont -C /dev/tty1 ter-v18b

# Set hostname and hosts
info "Setting hostname to ${HOSTNAME}"
echo "$HOSTNAME" > /etc/hostname
cat <<HOSTSEOF > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTSEOF

#Set colors and enable the easter egg
info "Enabling colors and easter egg"
sed -i 's/^#Color/Color\nILoveCandy/' /etc/pacman.conf

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

# Set root password
info "Setting root password"
echo "root:${ROOT_PASSWORD}" | chpasswd

# Create user 
info "Creating user ${USERNAME} account"
useradd -m -G wheel -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

# Ensure home directory exists and has correct permissions
mkdir -p "/home/$USERNAME" || error "Failed to create home directory"
# Set ownership and permissions
info "Setting ownership and permissions for /home/$USERNAME"
chown "$USERNAME:$USERNAME" "/home/$USERNAME"
chmod 755 "/home/$USERNAME"

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Enabling multilib repos for the new system"
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

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Updating databases and upgrading packages..."
pacman -Syu --noconfirm || error "Failed to update and upgrade packages in chroot"

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

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
	info "Installing GRUB bootloader (using grub-install)"
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
	
	info "Installing systemd-boot (using bootctl)"
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
	cp -an /etc/default/grub /etc/default/grub.backup

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

	GRUB_CONFIG_FILE="/etc/default/grub"

	info "Configuring GRUB for dual boot"
	if grep -q "GRUB_DISABLE_OS_PROBER" "$GRUB_CONFIG_FILE"; then
		echo "Existing 'GRUB_DISABLE_OS_PROBER' found. Updating/Uncommenting to 'false'..."
		sed -i 's/^#*\s*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$GRUB_CONFIG_FILE" || warn "Failed to update GRUB_DISABLE_OS_PROBER"
	else
		echo "'GRUB_DISABLE_OS_PROBER' not found. Appending new line to file."
		echo "GRUB_DISABLE_OS_PROBER=false" | tee -a "$GRUB_CONFIG_FILE" || warn "Failed to append GRUB_DISABLE_OS_PROBER"
	fi

	info "Disabling GRUB submenu"
	NEW_LINE="GRUB_DISABLE_SUBMENU=y"

	# Check 1: Check if the variable exists (commented or uncommented)
	if grep -q "GRUB_DISABLE_SUBMENU" "$GRUB_CONFIG_FILE"; then
		echo "Existing 'GRUB_DISABLE_SUBMENU' found. Updating/Uncommenting to 'y'..."
		sed -i 's/^#*\s*GRUB_DISABLE_SUBMENU=.*/GRUB_DISABLE_SUBMENU=y/' "$GRUB_CONFIG_FILE" || warn "Failed to update GRUB_DISABLE_SUBMENU"
	else
		echo "'GRUB_DISABLE_SUBMENU' not found. Appending new line to file."
		echo "$NEW_LINE" | tee -a "$GRUB_CONFIG_FILE" || warn "Failed to append GRUB_DISABLE_SUBMENU"
	fi

	info "Setting default option for grub"
	GRUB_TOP_LEVEL="/boot/vmlinuz-linux"
	if grep -q "GRUB_TOP_LEVEL" "$GRUB_CONFIG_FILE"; then
		echo "Existing 'GRUB_TOP_LEVEL' found. Updating/Uncommenting to '$GRUB_TOP_LEVEL'..."
		sed -i "s/^#*\s*GRUB_TOP_LEVEL=.*/GRUB_TOP_LEVEL=\"$GRUB_TOP_LEVEL\"/" "$GRUB_CONFIG_FILE" || warn "Failed to update GRUB_TOP_LEVEL"
	else
		echo "'GRUB_TOP_LEVEL' not found. Appending to $GRUB_CONFIG_FILE."
		echo "GRUB_TOP_LEVEL=\"$GRUB_TOP_LEVEL\"" | tee -a "$GRUB_CONFIG_FILE" || warn "Failed to append GRUB_TOP_LEVEL"
	fi

	info "setting default timeout"
	GRUB_TIMEOUT="1"
	if grep -q "GRUB_TIMEOUT" "$GRUB_CONFIG_FILE"; then
		echo "Existing 'GRUB_TIMEOUT' found. Updating/Uncommenting to '$GRUB_TIMEOUT'..."
		sed -i "s/^#*\s*GRUB_TIMEOUT=.*/GRUB_TIMEOUT=\"$GRUB_TIMEOUT\"/" "$GRUB_CONFIG_FILE" || warn "Failed to update GRUB_TIMEOUT"
	else
		echo "'GRUB_TIMEOUT' not found. Appending to $GRUB_CONFIG_FILE."
		echo "GRUB_TIMEOUT=\"$GRUB_TIMEOUT\"" | tee -a "$GRUB_CONFIG_FILE" || warn "Failed to append GRUB_TIMEOUT"
	fi

	info "run grub-mkconfig to generate GRUB configuration"
	grub-mkconfig -o /boot/grub/grub.cfg || error "Failed to generate GRUB configuration"

	info "Installing grub theme"
	# Clone the repository
	git clone --depth 1 https://github.com/Qaddoumi/grub-theme-mr-robot.git

	# Navigate to the directory
	cd grub-theme-mr-robot

	# Run the installation script
	./install.sh

	# Clean up
	cd ..
	rm -rf grub-theme-mr-robot

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

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Installing memtest86+ for memory testing"

if [[ "$BOOTLOADER" == "grub" ]]; then
	info "Installing memtest86+ for GRUB"
	
	if [[ "$BOOT_MODE" == "UEFI" ]]; then
		# For UEFI, we need the EFI version of memtest86+
		pacman -S --needed --noconfirm memtest86+-efi || warn "Failed to install memtest86+-efi"
	else
		# For BIOS, use the standard version
		pacman -S --needed --noconfirm memtest86+ || warn "Failed to install memtest86+"
	fi
	
	# Update GRUB configuration to include memtest86+
	grub-mkconfig -o /boot/grub/grub.cfg || warn "Failed to update GRUB configuration"
	
	# Verify memtest86+ was added to GRUB menu
	if grep -q "memtest" /boot/grub/grub.cfg; then
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

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

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

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

# Enable services
info "Enabling openssh service"
systemctl enable sshd || warn "Failed to enable sshd"

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Setting shutdown timeout to 30 seconds"
mkdir -p /etc/systemd/system/shutdown.target.d && printf '[Manager]\nDefaultTimeoutStopSec=30s\n' | tee /etc/systemd/system/shutdown.target.d/override.conf >/dev/null || warn "Failed to configure shutdown timeout"

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

# Clear sensitive variables in chroot
info "Clearing sensitive variables in chroot"
unset ROOT_PASSWORD USER_PASSWORD

EOF

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

#========================================
#  HIBERNATION TESTING COMMANDS (for post-install)
#========================================
info "Creating hibernation test script"
mkdir -p /mnt/home/$USERNAME/.local/bin
cat > /mnt/home/$USERNAME/.local/bin/test_hibernation <<EOF
#!/usr/bin/env bash

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
	sudo cat /boot/loader/entries/99-arch.conf | grep resume
fi
echo ""

echo "4.0 Check systemd hibernate configuration:"
systemctl status systemd-logind
echo ""

echo "5.0 Test hibernation (WARNING: This will hibernate the system!):"
echo "	 sudo systemctl hibernate"
echo "5.1 If you encounter issues, check the logs:"
echo "	 journalctl -b -1 -u systemd-logind"
echo ""

echo "Setup appears to be: \$(grep -q 'resume=' /proc/cmdline && echo 'COMPLETE' || echo 'INCOMPLETE')"
EOF

info "Hibernation test script created at /home/$USERNAME/.local/bin/test_hibernation"
chmod +x /mnt/home/$USERNAME/.local/bin/test_hibernation
chown 1000:1000 /mnt/home/$USERNAME/.local/bin/test_hibernation


newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"
echo
info "====${blue} POST-CHROOT CONFIGURATION ${green}===="
echo
newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Enabling NetworkManager service"
arch-chroot /mnt systemctl enable NetworkManager || warn "NetworkManager not installed"

# info "Enabling polkit service"
# arch-chroot /mnt systemctl enable polkit || warn "Failed to enable polkit"

info "PipeWire services will start automatically via socket activation"
## PipeWire uses socket activation and will start on-demand when the user logs in
## No need to manually enable services in chroot - they're managed by user sessions
#info "Enable PipeWire services"
#arch-chroot /mnt /bin/bash <<PIPWIREEOF
#systemctl --user enable pipewire.service
#systemctl --user enable pipewire-pulse.service
##systemctl --user enable pipewire-jack.service
##systemctl --user enable pipewire-alsa.service
#systemctl --user enable wireplumber.service
#PIPWIREEOF

info "Configuring sudo for user $USERNAME"
echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers || warn "Failed to configure sudo"

# Ensure all writes are committed to disk before cleanup
sync

# Cleanup will run automatically due to trap
# cleanup  # no need to uncommit this line as it's redundant
sleep 1

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════\n"

if [[ "$RUN_POST_INSTALL" == "y" ]]; then
	info "Running post-install script..."

	arch-chroot /mnt /bin/bash -s -- "$USERNAME" "$IS_VM" <<'POSTINSTALLEOF' || error "Post-install script failed to run"

USER_NAME="$1"
isVM="$2"

echo -e "\n"

echo "Temporarily disabling sudo password for wheel group"
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

su "$USER_NAME" <<USEREOF
	echo "Running post-install script as user $USER_NAME..."
	bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/pkgs/install_arch_pkgs.sh) --is-vm "$isVM" || echo "Failed to run the install script"
USEREOF

echo "Restoring sudo password requirement for wheel group"
sed -i '/^%wheel ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers
POSTINSTALLEOF
else
	warn "Skipping post-install script, you may reboot now."
	info "if you would like to run my post-install script later, you can run it with the command:"
	info "bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/pkgs/install_arch_pkgs.sh) --is-vm \"$IS_VM\""
fi

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════\n"

info "\n${green}[✓] INSTALLATION COMPLETE!${no_color}"
info "\n${yellow}Next steps:${no_color}"
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

echo -e "\n${green}Operation ${blue}completed ${yellow}in ${red}${time_str}${no_color}\n"

cp archsetuplogs.txt /mnt/home/$USERNAME/
arch-chroot /mnt chown -R $USERNAME:$USERNAME /home/$USERNAME/archsetuplogs.txt
info "Installation log saved to /home/$USERNAME/archsetuplogs.txt"

info "you may remove the installation media"
if [[ "$REBOOT_AFTER_INSTALL" == "y" ]]; then
	info "Rebooting system in 7 seconds..."
	circle=("-" "\\" "|" "/")
	i=1
	for ((i=1; i<=7; i++)); do
		echo -ne "\rRebooting in $((8-i)) seconds... ${circle[$((i % 4))]}"
		sleep 1
	done
	echo -e "\n"
	systemctl reboot || error "Failed to reboot system"
else
	info "You can reboot the system manually when ready."
fi
