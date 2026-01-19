#!/usr/bin/env bash

# Void Linux Installation Script

# Redirect stdout and stderr to voidsetuplogs.txt and still output to console
exec > >(tee -i voidsetuplogs.txt)
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

# Check if running from Void Linux ISO (requires void-installer or similar)
if [[ ! -e /etc/os-release ]] || ! grep -qi "void" /etc/os-release; then
	error "This script must be run from a Void Linux ISO environment!"
fi

# Check for xbps-install
if [ ! -f /usr/bin/xbps-install ]; then
	error "This script must be run from a Void Linux ISO environment (xbps-install not found)."
fi

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Checking for root privileges"
[[ $(id -u) -eq 0 ]] || error "This script must be run as root"

info "Checking internet connection"
if ! ping -c 1 -W 5 voidlinux.org &>/dev/null; then
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
VIRT_TYPE=""
if [ -f /sys/class/dmi/id/product_name ]; then
	PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
	if echo "$PRODUCT_NAME" | grep -qi "virtualbox"; then
		VIRT_TYPE="virtualbox"
	elif echo "$PRODUCT_NAME" | grep -qi "vmware"; then
		VIRT_TYPE="vmware"
	elif echo "$PRODUCT_NAME" | grep -qi "kvm\|qemu"; then
		VIRT_TYPE="kvm"
	fi
fi

# Also check using cpu flags
if [[ -z "$VIRT_TYPE" ]] && grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
	VIRT_TYPE="unknown-hypervisor"
fi

if [[ -n "$VIRT_TYPE" ]]; then
	IS_VM=true
	info "Virtual machine detected: $VIRT_TYPE"

	info "Configuring VM graphics drivers..."
	case "$VIRT_TYPE" in
		"kvm"|"qemu"|"microsoft"|"unknown-hypervisor")
			# Note: qemu-guest-agent may need manual install depending on Void version
			VIRT_PKGS+=("spice-vdagent")
			info "Added spice-vdagent for VM clipboard/display support"
			info "You may want to install qemu or qemu-ga later for QEMU guest agent"
			;;
		"virtualbox")
			VIRT_PKGS+=("virtualbox-ose-guest" "virtualbox-ose-guest-dkms")
			info "Added VirtualBox guest utilities"
			;;
		"vmware"|"svga")
			VIRT_PKGS+=("open-vm-tools")
			info "Added VMware tools"
			;;
		*)
			VIRT_PKGS+=("mesa-vulkan-swrast")
			warn "Unknown virtualization platform: $VIRT_TYPE"
			info "Using Software Rasterizer for fallback"
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
	
	# Add base GPU packages (Void Linux equivalents)
	GPU_PKGS+=("mesa" "mesa-dri" "vulkan-loader")
	
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
				GPU_PKGS+=("xf86-video-amdgpu" "mesa-vulkan-radeon" "libva-mesa-driver" "radeontop")
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
		GPU_PKGS+=("mesa-vulkan-intel" "intel-video-accel" "libva-utils" "intel-gpu-tools")
		
		# Detect CPU Generation to choose correct VAAPI driver
		CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo)
		
		# Check for Gen 5+ (Broadwell and newer)
		if [[ "$CPU_MODEL" =~ i[3579]-([5-9]|[1-9][0-9]) ]] || [[ "$CPU_MODEL" =~ (N[0-9]{4}|J[0-9]{4}) ]]; then
			info "Detected Modern Intel CPU (Gen 5+), using intel-media-driver"
			GPU_PKGS+=("intel-media-driver")
		else
			info "Detected Older Intel CPU (Pre-Gen 5), using libva-intel-driver"
			GPU_PKGS+=("libva-intel-driver")
		fi
	fi
	
	# Handle NVIDIA GPUs
	if [[ ${#NVIDIA_GPUS[@]} -gt 0 ]]; then
		info "Detected ${#NVIDIA_GPUS[@]} NVIDIA GPU(s)"
		echo "Select NVIDIA driver:"
		echo "1) Nouveau (open-source, default)"
		echo "2) Proprietary NVIDIA (better performance)"
		read -rp "Select NVIDIA driver [1-2]: " NVIDIA_CHOICE
		case ${NVIDIA_CHOICE:-1} in
			1)
				GPU_PKGS+=("xf86-video-nouveau" "mesa-nouveau-dri")
				GPU_OPTS=false
				;;
			2)
				GPU_PKGS+=("nvidia" "nvidia-libs" "nvidia-libs-32bit")
				GPU_OPTS=true
				;;
			*)
				warn "Invalid choice. Defaulting to Nouveau (Option 1)."
				GPU_PKGS+=("xf86-video-nouveau" "mesa-nouveau-dri")
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
echo "1) Worldwide (tier-1)"
echo "2) Europe (Germany)"
echo "3) North America (US)"
echo "4) Asia"

if read -rp "Select mirror region [1-4] (press Enter for Worldwide): " -t 30 REGION_CHOICE; then
	info "Region choice: $REGION_CHOICE"
else
	REGION_CHOICE=1  # Default to Worldwide if no input
	info "Timeout, defaulting to Worldwide"
fi

# Default to Worldwide (1) if empty
REGION_CHOICE=${REGION_CHOICE:-1}

# Map selection to mirror URLs
case $REGION_CHOICE in
	1) MIRROR_URL="https://repo-default.voidlinux.org"; REGION="Worldwide (tier-1)" ;;
	2) MIRROR_URL="https://repo-de.voidlinux.org"; REGION="Europe (Germany)" ;;
	3) MIRROR_URL="https://repo-us.voidlinux.org"; REGION="North America (US)" ;;
	4) MIRROR_URL="https://repo-fi.voidlinux.org"; REGION="Asia (via Finland)" ;;
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

BOOTLOADER="grub"
info "Using GRUB as bootloader."

echo
echo -e "${blue}--------------------------------------------------\n${no_color}"
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

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

echo "Press Enter or wait 30 seconds to use defaults..."
echo "Default username: $DEFAULT_USERNAME"
echo "Default user password: [hidden]"
echo

echo -e "${blue}--------------------------------------------------\n${no_color}"
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
echo -e "${blue}--------------------------------------------------\n${no_color}"
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

info "Would you like to run my post-install script? to install sway and other packages? with my configuration files ?"
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

cleanup_disks() {
	local attempts=3
	info "Starting cleanup process (3 attempts)..."
	
	# Helper to find PIDs using the disk
	find_pids_using_disk() {
		local disk_path="/dev/$DISK"
		local pids=""
		# Scan /proc for open file descriptors
		# We must be very careful not to match random strings
		for pid_dir in /proc/[0-9]*; do
			local pid=${pid_dir##*/}
			
			# Skip self
			[[ "$pid" == "$BASHPID" ]] && continue
			[[ "$pid" == "1" ]] && continue  # NEVER kill init

			local found=0
			
			# Check open files (fd)
			if [ -d "$pid_dir/fd" ]; then
				# Use find to get links, readlink to check target
				# iterating over files is safer than parsing ls
				for fd in "$pid_dir"/fd/*; do
					[ -e "$fd" ] || continue
					target=$(readlink -f "$fd" 2>/dev/null)
					if [[ "$target" == "$disk_path"* ]]; then
						found=1
						break
					fi
				done
			fi
			
			# Check mounts if not found in fd
			if [[ $found -eq 0 ]] && [ -f "$pid_dir/mounts" ]; then
				# Check if any mount point source starts with our disk
				if grep -qs "^$disk_path" "$pid_dir/mounts"; then
					found=1
				fi
			fi

			if [[ $found -eq 1 ]]; then
				pids="$pids $pid"
			fi
		done
		echo "$pids"
	}

	while (( attempts-- > 0 )); do
		# Kill processes using the disk
		info "Attempt $((3-attempts)): Killing processes..."
		
		# Initial check and kill
		pids=$(find_pids_using_disk)
		if [[ -n "$pids" ]]; then
			echo "Killing PIDs: $pids"
			# Double check we are not killing critical pids
			for pid in $pids; do
				if [[ "$pid" != "1" ]] && [[ "$pid" != "$BASHPID" ]]; then
					kill -9 "$pid" 2>/dev/null
				fi
			done
		fi
		sleep 2
		
		# Second check
		pids=$(find_pids_using_disk)
		if [[ -n "$pids" ]]; then
			echo "Killing remaining PIDs: $pids"
			kill -9 $pids 2>/dev/null
		fi
		sleep 2
		
		info "Unmounting partitions..."
		umount -R "/dev/$DISK"* 2>/dev/null
		
		# Deactivate LVM
		if command -v vgchange &>/dev/null; then
			info "Deactivating LVM..."
			vgchange -an 2>/dev/null
			# Use lsblk or manual scan if lvs usage is complex without it, 
			# but lvs is usually standard if lvm2 is there. 
			# Keeping lvs for now as it wasn't flagged as missing.
			lvremove -f $(lvs -o lv_path --noheadings 2>/dev/null | grep "$DISK") 2>/dev/null
		fi
		
		info "Disabling swap..."
		swapoff -a 2>/dev/null
		# scan /proc/swaps manually if needed, but swapoff -a is usually enough
		for swap in $(grep "/dev/$DISK" /proc/swaps | awk '{print $1}'); do
			swapoff -v "$swap"
		done
		sleep 2

		info "Checking for mounted partitions on /dev/$DISK..."
		# Using mount command instead of lsblk loop if strict, but lsblk is standard.
		# Parsing /proc/mounts is safer than assume lsblk is there, but lsblk IS standard util-linux.
		# We'll stick to lsblk for iterating parts as it's standard.
		for part in $(lsblk -lnp -o NAME | grep "^/dev/$DISK" | tail -n +2); do
			info "Attempting to unmount $part..."
			if ! umount "$part" 2>/dev/null; then
				warn "Failed to unmount $part, maybe it was not mounted."
			else
				info "$part unmounted successfully."
			fi
		done
		
		# Check if cleanup was successful by rescanning
		if ! (mount | grep -q "/dev/$DISK") && \
		   [[ -z "$(find_pids_using_disk)" ]]; then
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

info "Creating partitions with sfdisk..."

if [[ "$BOOT_MODE" == "UEFI" ]]; then
	info "Creating UEFI partitions layout..."
	# 1. EFI System Partition (2G) - Type U
	# 2. Root Partition (Rest) - Type L
	sfdisk "/dev/$DISK" <<EOF
label: gpt
, 2G, U
, , L
EOF
	if [[ $? -ne 0 ]]; then error "Partitioning failed"; fi
	
	# Set partition variables for UEFI
	EFI_PART="$PART1"
	ROOT_PART="$PART2"
	
	info "Formatting UEFI partitions..."
	mkfs.fat -F32 "$EFI_PART" || error "EFI format failed"
	mkfs.ext4 -F "$ROOT_PART" || error "Root format failed"

	info "Mounting UEFI partitions..."
	mkdir -p /mnt || error "Failed to create /mnt"
	mount "$ROOT_PART" /mnt || error "Failed to mount root partition"
	
	# Mount ESP for GRUB
	info "Mounting ESP at /mnt/boot/efi for GRUB"
	mkdir -p /mnt/boot/efi || error "Failed to create /mnt/boot/efi"
	chmod 700 /mnt/boot/efi || error "Failed to set permissions on /mnt/boot/efi"
	mount "$EFI_PART" /mnt/boot/efi || error "Failed to mount EFI partition"
else
	info "Creating BIOS partitions layout..."
	# 1. BIOS Boot Partition (2M) - Type 21686148-6449-6E6F-744E-656564454649
	# 2. Boot Partition (2G) - Type L
	# 3. Root Partition (Rest) - Type L
	sfdisk "/dev/$DISK" <<EOF
label: gpt
, 2M, 21686148-6449-6E6F-744E-656564454649
, 2G, L
, , L
EOF
	if [[ $? -ne 0 ]]; then error "Partitioning failed"; fi
	
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
	echo "  /mnt/boot/efi (GRUB)"
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

info "Configuring XBPS mirrors"
mkdir -p /mnt/etc/xbps.d
echo "repository=${MIRROR_URL}/current" > /mnt/etc/xbps.d/00-repository-main.conf
echo "repository=${MIRROR_URL}/current/nonfree" >> /mnt/etc/xbps.d/00-repository-main.conf
echo "repository=${MIRROR_URL}/current/multilib" >> /mnt/etc/xbps.d/00-repository-main.conf
echo "repository=${MIRROR_URL}/current/multilib/nonfree" >> /mnt/etc/xbps.d/00-repository-main.conf

info "Updating XBPS package manager"
xbps-install -Syu xbps || warn "Failed to update xbps"

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
# Fix microcode package naming for Void
case "$CPU_VENDOR" in
	"GenuineIntel") UCODE_PKG="intel-ucode" ;;
	"AuthenticAMD") UCODE_PKG="linux-firmware-amd" ;;
	*) UCODE_PKG=""; warn "Unknown CPU vendor: $CPU_VENDOR" ;;
esac

info "Adding pipewire packages for audio management"
declare -a PIPEWIRE_PKGS=(
	pipewire
	alsa-pipewire
	libjack-pipewire
	wireplumber
)

# Base packages for Void Linux
declare -a BASE_PKGS=(
	base-container linux linux-firmware linux-headers booster
	grub grub-x86_64-efi efibootmgr os-prober e2fsprogs void-repo-nonfree void-repo-multilib
	eudev runit-void kbd kmod dosfstools
)

declare -a OPTIONAL_PKGS=(bash curl NetworkManager dbus opendoas git openssh terminus-font chrony neovim)

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

info "Removing duplicate packages..."
declare -A seen_pkgs
declare -a VALID_PKGS=()
for item in "${INSTALL_PKGS_ARR[@]}"; do
	[[ -z "$item" ]] && continue
	
	# Split items if they contain spaces
	for pkg in $item; do
		# Skip if we've already processed this package
		[[ -n "${seen_pkgs[$pkg]:-}" ]] && continue
		VALID_PKGS+=("$pkg")
		seen_pkgs[$pkg]=1
	done
done

# Convert to space-separated string
INSTALL_PKGS="${VALID_PKGS[*]}"

info "Installing: "
echo "$INSTALL_PKGS"

# Copy repository keys from live system to target to avoid interactive key import prompt
info "Copying repository keys to target system..."
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/ 2>/dev/null || warn "Could not copy repo keys"

# Install packages
info "Installing packages to /mnt..."
XBPS_ARCH=x86_64 xbps-install -Sy -r /mnt -R "${MIRROR_URL}/current" -R "${MIRROR_URL}/current/nonfree" -R "${MIRROR_URL}/current/multilib" -R "${MIRROR_URL}/current/multilib/nonfree" $INSTALL_PKGS || error "Package installation failed"

# Ensure /mnt/etc exists
mkdir -p /mnt/etc

if [[ "$GPU_OPTS" == true ]]; then
	info "Blacklisting nouveau driver..."
	mkdir -p /mnt/etc/modprobe.d
	echo "blacklist nouveau" > /mnt/etc/modprobe.d/blacklist-nouveau.conf
fi

info "Generating fstab"
# Void Linux doesn't have genfstab by default, create manually
cat > /mnt/etc/fstab <<FSTABEOF
# /etc/fstab - static file system information
# <file system>  <dir>  <type>  <options>  <dump>  <pass>

# Root partition
UUID=$(blkid -s UUID -o value "$ROOT_PART")  /  ext4  defaults  0  1

FSTABEOF

if [[ "$BOOT_MODE" == "UEFI" ]]; then
	echo "# EFI System Partition" >> /mnt/etc/fstab
	echo "UUID=$(blkid -s UUID -o value "$EFI_PART")  /boot/efi  vfat  defaults,fmask=0077,dmask=0077,iocharset=iso8859-1,codepage=437  0  2" >> /mnt/etc/fstab
else
	echo "# Boot partition" >> /mnt/etc/fstab
	echo "UUID=$(blkid -s UUID -o value "$BOOT_PART")  /boot  ext4  defaults  0  2" >> /mnt/etc/fstab
fi

echo "" >> /mnt/etc/fstab
echo "# Swap file" >> /mnt/etc/fstab
echo "/swapfile  none  swap  sw  0  0" >> /mnt/etc/fstab

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"
info "==== CHROOT SETUP ===="

info "Ensuring /mnt/etc directory exists..."
mkdir -p /mnt/etc

info "Copying DNS resolution to chroot..."
cp /etc/resolv.conf /mnt/etc/resolv.conf

# Bind mount necessary filesystems for chroot
info "Mounting virtual filesystems for chroot..."
mount --rbind /dev /mnt/dev && mount --make-rslave /mnt/dev
mount --rbind /proc /mnt/proc && mount --make-rslave /mnt/proc
mount --rbind /sys /mnt/sys && mount --make-rslave /mnt/sys

info "Configuring system in chroot..."
chroot /mnt /bin/bash -s -- \
	"$ROOT_PASSWORD" "$USERNAME" "$USER_PASSWORD" \
	"$DISK" "$ROOT_PART" "$BOOTLOADER" "$UCODE_PKG" \
	"$BOOT_MODE" "$KERNEL_CMDLINE" \
<<'EOF' || error "Chroot commands failed"

set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin


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
HOSTNAME="${USERNAME}Void"
KEYMAP="us"

# Set timezone
info "Setting timezone to ${TIMEZONE}"
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# Set locale
info "Setting locale to ${LOCALE}"
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "${LOCALE} UTF-8" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales 2>/dev/null || warn "Failed to reconfigure locales"

# Set keymaps
info "Setting keymap to ${KEYMAP}"
echo "KEYMAP=${KEYMAP}" > /etc/rc.conf
echo "FONT=ter-v18b" >> /etc/rc.conf

# Set hostname and hosts
info "Setting hostname to ${HOSTNAME}"
echo "$HOSTNAME" > /etc/hostname
cat <<HOSTSEOF > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTSEOF

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

# Determine best supported encryption method
info "Configuring password encryption method..."
CRYPT_METHOD="SHA512"
if chpasswd -h 2>&1 | grep -q "YESCRYPT"; then
	CRYPT_METHOD="YESCRYPT"
	info "Using YESCRYPT for password hashing."
else
	info "YESCRYPT not supported by chpasswd, falling back to SHA512."
fi

# Update configurations to use the selected method
sed -i "s/sha512/${CRYPT_METHOD,,}/" /etc/pam.d/system-auth 2>/dev/null || true
if grep -q "^ENCRYPT_METHOD" /etc/login.defs; then
	sed -i "s/^ENCRYPT_METHOD.*/ENCRYPT_METHOD $CRYPT_METHOD/" /etc/login.defs
else
	echo "ENCRYPT_METHOD $CRYPT_METHOD" >> /etc/login.defs
fi

# Set root password
info "Setting root password"
printf "root:%s\n" "${ROOT_PASSWORD}" | chpasswd -c "$CRYPT_METHOD"

# Create user 
info "Creating user ${USERNAME} account"
if ! id -u "${USERNAME}" >/dev/null 2>&1; then
	useradd -m -G wheel,audio,video,storage,network -s /bin/bash "${USERNAME}"
fi
printf "%s:%s\n" "${USERNAME}" "${USER_PASSWORD}" | chpasswd -c "$CRYPT_METHOD"

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

# Ensure home directory exists and has correct permissions
mkdir -p "/home/$USERNAME" || error "Failed to create home directory"
# Set ownership and permissions
info "Setting ownership and permissions for /home/$USERNAME"
chown "$USERNAME:$USERNAME" "/home/$USERNAME"
chmod 755 "/home/$USERNAME"

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

# Configure doas (Void's sudo alternative)
info "Configuring doas for wheel group"
echo "permit persist :wheel" > /etc/doas.conf
chmod 600 /etc/doas.conf

# Also configure sudo if installed
if [[ -f /etc/sudoers ]]; then
	echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
fi

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

info "Updating system packages..."
xbps-install -Syu --yes || warn "Failed to update packages"

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

# Configure booster (fast initramfs generator)
info "Configuring booster for hibernation"
mkdir -p /etc/booster.d

# Get resume device info for booster config
ROOT_UUID_EARLY=$(blkid -s UUID -o value "${ROOT_PART}")

cat > /etc/booster.yaml <<BOOSTEREOF
# Booster initramfs configuration
modules_force_load: ext4,vfat,fat,nls_cp437,nls_iso8859_1
compression: zstd

# Include udev for device management
enable_lvm: true
enable_mdraid: false

# Hibernation/resume support
resume: UUID=${ROOT_UUID_EARLY}

# Universal mode - includes all necessary modules
universal: true
BOOSTEREOF

# Swap dracut for booster - remove dracut first
info "Removing dracut and switching to booster..."
if xbps-query -l | grep -q dracut; then
	xbps-remove -RyF dracut || warn "Failed to remove dracut"
fi

# Regenerate initramfs using xbps-reconfigure (automatically uses booster)
info "Regenerating initramfs with booster..."
xbps-reconfigure -fa || warn "Failed to reconfigure packages"

info "Installing GRUB bootloader for $BOOT_MODE mode"
if [[ "$BOOT_MODE" == "UEFI" ]]; then
	# Ensure efivars are mounted inside chroot (fix for mounting issues)
	if ! mountpoint -q /sys/firmware/efi/efivars; then
		info "Mounting efivars..."
		mount -t efivarfs efivarfs /sys/firmware/efi/efivars || warn "Failed to mount efivars, GRUB installation might fail"
	fi

	info "Installing GRUB (Standard)..."
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void Linux" || {
		error "GRUB UEFI installation failed"
	}

	info "Installing GRUB (Removable Fallback)..."
	# Installs to EFI/BOOT/BOOTX64.EFI - fixes issues on some motherboards that don't look at NVRAM
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable || {
		warn "GRUB fallback installation failed"
	}
	info "GRUB installed successfully for UEFI"
else
	grub-install --target=i386-pc "/dev/$DISK" || {
		error "GRUB BIOS installation failed"
	}
	info "GRUB installed successfully for BIOS"
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
SWAPFILE_OFFSET=""
if [[ -f /swapfile ]]; then
	# Check if filefrag is available
	if command -v filefrag >/dev/null 2>&1; then
		# Get swapfile offset with multiple methods for robustness
		SWAPFILE_OFFSET=$(filefrag -v /swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}')
		if [[ -z "$SWAPFILE_OFFSET" ]] || [[ "$SWAPFILE_OFFSET" == "0" ]]; then
			warn "First method failed, trying second method..."
			SWAPFILE_OFFSET=$(filefrag -v /swapfile 2>/dev/null | awk 'NR==4 {gsub(/\\.\\..*/, "", $4); print $4}')
			if [[ -z "$SWAPFILE_OFFSET" ]] || [[ "$SWAPFILE_OFFSET" == "0" ]]; then
				warn "First and second methods failed, trying alternative..."
				SWAPFILE_OFFSET=$(filefrag -v /swapfile 2>/dev/null | awk '/^ *0:/ {print $4}' | sed 's/\\.\\.//')
				if [[ -z "$SWAPFILE_OFFSET" ]] || [[ "$SWAPFILE_OFFSET" == "0" ]]; then
					warn "All methods failed, trying last resort..."
					SWAPFILE_OFFSET=$(filefrag -v /swapfile | head -n 4 | tail -n 1 | awk '{print $4}' | sed 's/\.\.//')
				fi
			fi
		fi
	else
		warn "filefrag command not found, hibernation may not work"
	fi
else
	warn "Swapfile not found at /swapfile"
fi

# Generate GRUB config with proper path
info "Generating GRUB configuration"
mkdir -p /boot/grub || error "Failed to create /boot/grub directory"

info "Backing up original GRUB configuration"
cp -an /etc/default/grub /etc/default/grub.backup 2>/dev/null || true

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

info "Installing grub CyberRe theme"
# Clone the repository
git clone --depth 1 https://github.com/Qaddoumi/grub-theme-mr-robot.git

# Navigate to the directory
cd grub-theme-mr-robot

# Run the installation script
./install.sh

# Clean up
cd ..
rm -rf grub-theme-mr-robot

info "Bootloader configuration completed for $BOOTLOADER in $BOOT_MODE mode"
info "Resume UUID: $ROOT_UUID"
info "Resume offset: $SWAPFILE_OFFSET"

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

# (hibernate on lid close)
info "Configuring elogind for hibernation on lid close"
mkdir -p /etc/elogind/logind.conf.d
cat > /etc/elogind/logind.conf.d/hibernate.conf <<HIBERNATEEOF
[Login]
HandleLidSwitch=hibernate
HandleLidSwitchExternalPower=hibernate
HandlePowerKey=hibernate
IdleAction=ignore
IdleActionSec=30min
HIBERNATEEOF

info "Configuring sleep settings for hibernation"
cat > /etc/elogind/sleep.conf <<HIBERNATIONSLEEPEOF
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
AllowHybridSleep=yes
HibernateDelaySec=180min
HIBERNATIONSLEEPEOF

info "${BOOTLOADER} installation and configuration completed for $BOOT_MODE mode"

info "Regenerating initramfs with booster for hibernation support"
xbps-reconfigure -fa || warn "Failed to reconfigure packages"

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

# Enable services
info "Enabling services (runit)"

SV_DIR="/etc/runit/runsvdir/default"
mkdir -p "$SV_DIR" > /dev/null 2>&1 || true

# Create service links
info "Enabling udevd (device manager - must be first)"
ln -sf /etc/sv/udevd "$SV_DIR/udevd" || warn "Failed to enable udevd"

info "Enabling dbus (message bus)"
ln -sf /etc/sv/dbus "$SV_DIR/dbus" || warn "Failed to enable dbus"

info "Enabling elogind (session/power management)"
ln -sf /etc/sv/elogind "$SV_DIR/elogind" || warn "Failed to enable elogind"

info "Enabling NetworkManager"
ln -sf /etc/sv/NetworkManager "$SV_DIR/NetworkManager" || warn "Failed to enable NetworkManager"

info "Enabling chronyd (time sync)"
ln -sf /etc/sv/chronyd "$SV_DIR/chronyd" || warn "Failed to enable chronyd"

info "Enabling sshd (optional)"
ln -sf /etc/sv/sshd "$SV_DIR/sshd" || warn "Failed to enable sshd"

# PipeWire services (user services - handled differently in Void)
info "PipeWire services will start automatically via pipewire user service"

info "Setting up user services directory"
mkdir -p /home/${USERNAME}/.config/sv
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════"

# Clear sensitive variables in chroot
info "Clearing sensitive variables in chroot"
unset ROOT_PASSWORD USER_PASSWORD

EOF

# Unmount virtual filesystems after chroot
info "Unmounting virtual filesystems..."
umount -R /mnt/dev 2>/dev/null || true
umount -R /mnt/proc 2>/dev/null || true
umount -R /mnt/sys 2>/dev/null || true

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
doas grep -i resume /proc/cmdline
echo ""

echo "4.0 Check elogind hibernate configuration:"
sv status elogind
echo ""

echo "5.0 Test hibernation (WARNING: This will hibernate the system!):"
echo "	 doas zzz  # suspend"
echo "	 doas ZZZ  # hibernate"
echo "5.1 If you encounter issues, check the logs:"
echo "	 doas cat /var/log/socklog/messages/current | grep -i hibern"
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

# Ensure all writes are committed to disk before cleanup
sync

# Cleanup will run automatically due to trap
sleep 1

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════\n"

if [[ "$RUN_POST_INSTALL" == "y" ]]; then
	info "Running post-install script..."

	chroot /mnt /bin/bash -s -- "$USERNAME" "$IS_VM" <<'POSTINSTALLEOF' || error "Post-install script failed to run"

USER_NAME="$1"
isVM="$2"

echo -e "\n"

echo "Temporarily disabling doas password for wheel group"
echo "permit nopass :wheel" >> /etc/doas.conf

su "$USER_NAME" <<USEREOF
	echo "Running post-install script as user \$USER_NAME..."
	bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/pkgs/install_void_pkgs.sh) --is-vm "$isVM" || echo "Failed to run the install script"
USEREOF

echo "Restoring doas password requirement for wheel group"
sed -i '/^permit nopass :wheel/d' /etc/doas.conf
POSTINSTALLEOF
else
	warn "Skipping post-install script, you may reboot now."
	info "if you would like to run my post-install script later, you can run it with the command:"
	info "bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/pkgs/install_void_pkgs.sh) --is-vm \"$IS_VM\""
fi

newTask "════════════════════════════════════════════════════\n════════════════════════════════════════════════════\n"

info "\n${green}[✓] INSTALLATION COMPLETE!${no_color}"
info "\n${yellow}Next steps:${no_color}"
info "1. Reboot: reboot"
info "2. After reboot, run the hibernation test script:"
info "   /home/$USERNAME/.local/bin/test_hibernation"
info "3. If hibernation works, you can remove the test script:"
info "   rm /home/$USERNAME/.local/bin/test_hibernation"
info "4. Check GPU: lspci -k | grep -A 3 -E '(VGA|3D)'\n"

info "Remember your credentials:"
info "  Root password: Set during installation"
info "  User: $USERNAME (with doas/sudo privileges)"


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

cp voidsetuplogs.txt /mnt/home/$USERNAME/
chroot /mnt chown -R $USERNAME:$USERNAME /home/$USERNAME/voidsetuplogs.txt
info "Installation log saved to /home/$USERNAME/voidsetuplogs.txt"

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
	reboot || error "Failed to reboot system"
else
	info "You can reboot the system manually when ready."
fi
