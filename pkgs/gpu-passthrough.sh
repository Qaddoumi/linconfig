#!/usr/bin/env bash

# GPU PCI ID Identifier Script for VFIO Passthrough
# This script identifies GPU PCI IDs and generates VFIO configuration

# Colors for better readability
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
no_color='\033[0m' # No Color

for tool in sudo doas pkexec; do
	if command -v "${tool}" >/dev/null 2>&1; then
		ESCALATION_TOOL="${tool}"
		echo -e "${blue}Using ${tool} for privilege escalation${no_color}"
		break
	fi
done
if [ -z "${ESCALATION_TOOL}" ]; then
	echo -e "${red}Error: This script requires root privileges. Please install sudo, doas, or pkexec.${no_color}"
	exit 1
fi


# Function to create backup files
backup_file() {
	local file="$1"
	if "$ESCALATION_TOOL" test -f "$file"; then
		"$ESCALATION_TOOL" cp -an "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
		echo -e "${green}Backed up $file${no_color}"
	else
		echo -e "${yellow}File $file does not exist, skipping backup${no_color}"
	fi
}

echo -e "${green}Starting IOMMU setup for KVM virtualization, And GPU Passthrough...${no_color}"

echo -e "${green}Checking CPU vendor and IOMMU support...${no_color}"
CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')
echo -e "${green}CPU Vendor: $CPU_VENDOR${no_color}"

# Determine IOMMU parameter based on CPU vendor
echo -e "${green}Determining IOMMU parameter based on CPU vendor${no_color}"
if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
	IOMMU_PARAM="intel_iommu=on"
	echo -e "${green}Intel CPU detected - will use intel_iommu=on${no_color}"
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
	echo -e "${red}This script does not handle amd inegrated gpu with amd discrete gpe probebly${no_color}"
	IOMMU_PARAM="amd_iommu=on"
	echo -e "${green}AMD CPU detected - will use amd_iommu=on${no_color}"
else
	echo -e "${red}Unknown CPU vendor: $CPU_VENDOR${no_color}"
	echo -e "${red}Please manually add the appropriate IOMMU parameter for your CPU${no_color}"
	#exit 1
fi

# Check if IOMMU is already enabled
echo -e "${green}Checking current IOMMU status...${no_color}"
if "$ESCALATION_TOOL" dmesg | grep -qE "IOMMU enabled|DMAR: IOMMU enabled"; then
	echo -e "${yellow}IOMMU appears to already be enabled in kernel logs${no_color}"
else
	echo -e "${green}IOMMU not currently enabled in kernel logs${no_color}"
fi

# Check if IOMMU groups are populated (crucial for nested virt)
if [ -d "/sys/kernel/iommu_groups" ] && [ "$(ls -A /sys/kernel/iommu_groups 2>/dev/null)" ]; then
	echo -e "${green}IOMMU groups are populated.${no_color}"
else
	echo -e "${red}Warning: IOMMU groups are empty or missing!${no_color}"
	echo -e "${yellow}If you are in a VM (Nested Passthrough), ensure you have added an IOMMU device to the VM config.${no_color}"
	echo -e "${yellow}For example, in libvirt/virt-manager, add: <iommu model='intel'/> (and use Q35 chipset).${no_color}"
fi

echo -e "${green}=== GPU PCI ID Identifier for VFIO Passthrough ===${no_color}"
echo ""

# Function to extract PCI ID (vendor:device) from lspci output
extract_pci_id() {
	echo "$1" | grep -o '[0-9a-f]\{4\}:[0-9a-f]\{4\}' | tail -1
}

# Function to extract PCI address (with domain prefix for sysfs compatibility)
extract_pci_address() {
	local short_addr
	short_addr=$(echo "$1" | cut -d' ' -f1)
	# Add the PCI domain prefix (0000:) required for sysfs paths
	echo "0000:$short_addr"
}

echo -e "${green}Detecting all GPUs in system...${no_color}"
echo ""

# Get all VGA and 3D controllers
gpu_devices=$(lspci -nn | grep -E "(VGA|3D controller)")

if [ -z "$gpu_devices" ]; then
	echo -e "${red}No GPU devices found!${no_color}"
	#exit 1
fi

echo -e "${green}Found GPU devices:${no_color}"
echo "$gpu_devices"
echo ""

# Separate integrated and discrete GPUs
echo -e "${green}Categorizing GPUs...${no_color}"
echo ""

nvidia_gpu=""
amd_gpu=""

while IFS= read -r line; do
	if [[ $line == *"NVIDIA"* ]]; then
		nvidia_gpu="$line"
		echo -e "${green}NVIDIA dGPU:${no_color} $line"
	elif [[ $line == *"AMD"* ]] || [[ $line == *"Advanced Micro Devices"* ]]; then
		amd_gpu="$line"
		echo -e "${green}AMD GPU:${no_color} $line"
	fi
done <<< "$gpu_devices"

echo ""

# Find associated audio devices for discrete GPUs
echo -e "${green}Finding associated audio devices...${no_color}"
echo ""

nvidia_audio=""
amd_audio=""

if [ -n "$nvidia_gpu" ]; then
	nvidia_pci_addr=$(extract_pci_address "$nvidia_gpu")
	nvidia_bus=$(echo "$nvidia_pci_addr" | cut -d':' -f1)
	
	# Look for NVIDIA audio on same bus first
	nvidia_audio=$(lspci -nn | grep -E "Audio.*NVIDIA" | grep "^$nvidia_bus:")
	
	# If not found on same bus, look for ANY NVIDIA audio (common in VMs/nested)
	if [ -z "$nvidia_audio" ]; then
		nvidia_audio=$(lspci -nn | grep -E "Audio.*NVIDIA" | head -n 1)
	fi
	
	if [ -n "$nvidia_audio" ]; then
		echo -e "${green}NVIDIA Audio Device:${no_color} $nvidia_audio"
	else
		echo -e "${yellow}No NVIDIA audio device found${no_color}"
	fi
fi

if [ -n "$amd_gpu" ]; then
	amd_pci_addr=$(extract_pci_address "$amd_gpu")
	amd_bus=$(echo "$amd_pci_addr" | cut -d':' -f1)
	
	# Look for AMD audio on same bus first
	amd_audio=$(lspci -nn | grep -E "Audio.*AMD" | grep "^$amd_bus:")
	
	# If not found on same bus, look for ANY AMD audio
	if [ -z "$amd_audio" ]; then
		amd_audio=$(lspci -nn | grep -E "Audio.*AMD" | head -n 1)
	fi
	
	if [ -n "$amd_audio" ]; then
		echo -e "${green}AMD Audio Device:${no_color} $amd_audio"
	else
		echo -e "${yellow}No AMD audio device found${no_color}"
	fi
fi

echo ""

# Generate VFIO configuration
echo -e "${green}VFIO Configuration for GPU Passthrough...${no_color}"
echo ""

GPU_PCI_ID=""
AUDIO_PCI_ID=""
VFIO_IDS=""
GPU_TYPE=""

if [ -n "$nvidia_gpu" ]; then
	nvidia_gpu_id=$(extract_pci_id "$nvidia_gpu")
	nvidia_pci_addr=$(extract_pci_address "$nvidia_gpu")
	GPU_TYPE="nvidia"
	
	echo -e "${green}=== NVIDIA GPU Passthrough Configuration ===${no_color}"
	echo -e "${yellow}GPU PCI Address:${no_color} $nvidia_pci_addr"
	echo -e "${yellow}GPU PCI ID:${no_color} $nvidia_gpu_id"
	
	VFIO_IDS="$nvidia_gpu_id"
	
	if [ -n "$nvidia_audio" ]; then
		nvidia_audio_id=$(extract_pci_id "$nvidia_audio")
		nvidia_audio_addr=$(extract_pci_address "$nvidia_audio")
		echo -e "${yellow}Audio PCI Address:${no_color} $nvidia_audio_addr"
		echo -e "${yellow}Audio PCI ID:${no_color} $nvidia_audio_id"
		
		VFIO_IDS="$VFIO_IDS,$nvidia_audio_id"
		AUDIO_PCI_ID="$nvidia_audio_addr"
	fi
	
	GPU_PCI_ID="$nvidia_pci_addr"
fi

if [ -n "$amd_gpu" ]; then
	amd_gpu_id=$(extract_pci_id "$amd_gpu")
	amd_pci_addr=$(extract_pci_address "$amd_gpu")
	GPU_TYPE="amdgpu"
	
	echo ""
	echo -e "${green}=== AMD GPU Passthrough Configuration ===${no_color}"
	echo -e "${yellow}GPU PCI Address:${no_color} $amd_pci_addr"
	echo -e "${yellow}GPU PCI ID:${no_color} $amd_gpu_id"
	
	VFIO_IDS="$amd_gpu_id"
	
	if [ -n "$amd_audio" ]; then
		amd_audio_id=$(extract_pci_id "$amd_audio")
		amd_audio_addr=$(extract_pci_address "$amd_audio")
		echo -e "${yellow}Audio PCI Address:${no_color} $amd_audio_addr"
		echo -e "${yellow}Audio PCI ID:${no_color} $amd_audio_id"
		
		VFIO_IDS="$VFIO_IDS,$amd_audio_id"
		AUDIO_PCI_ID="$amd_audio_addr"
	fi
	
	GPU_PCI_ID="$amd_pci_addr"
fi

echo -e "${green}\nAdding $IOMMU_PARAM iommu=pt to the bootloader\n${no_color}"

echo -e "${green}Detecting bootloader...${no_color}"
bootloader_type=2
echo -e "${green}check for systemd-boot first${no_color}"
if bootctl status 2>/dev/null | grep -q "systemd-boot"; then
	echo -e "${green}systemd-boot confirmed via bootctl${no_color}"
	bootloader_type=0
fi
if (( bootloader_type == 2 )); then
	echo -e "${green}check for Grub bootloader${no_color}"
	if [[ -f "/boot/grub/grub.cfg" ]] || "$ESCALATION_TOOL" test -d "/boot/grub"; then
		echo -e "${green}GRUB bootloader detected${no_color}"
		bootloader_type=1 # GRUB detected
	fi
fi

if [ -n "$VFIO_IDS" ]; then
	case "$bootloader_type" in
		0)
			# systemd-boot detected
			echo -e "${green}Configuring systemd-boot...${no_color}"
			
			# Find the correct entries directory
			# You can run '$ESCALATION_TOOL bootctl list' to find them
			entries_dir=""
			for path in "/boot/efi/loader/entries" "/boot/loader/entries" "/efi/loader/entries" "/boot/EFI/loader/entries"; do
				echo -e "${blue}Checking path: $path${no_color}"
				if "$ESCALATION_TOOL" test -d "$path"; then
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
			
			if [[ -z "$entries_dir" ]] || ! "$ESCALATION_TOOL" test -d "$entries_dir"; then
				echo -e "${red}Could not locate systemd-boot entries directory${no_color}"
				echo -e "${yellow}Please manually add '$IOMMU_PARAM iommu=pt' to your boot entry${no_color}"
				#exit 1
			fi
			
			# Get all .conf files (including backups and fallbacks)
			all_entries=($("$ESCALATION_TOOL" find "$entries_dir" -name "*.conf" 2>/dev/null))

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
			
			# Process each boot entry
			for entry in "${boot_entries[@]}"; do
				echo -e "${green}Processing boot entry: $(basename "$entry")${no_color}"
				backup_file "$entry"
				
				# Check if IOMMU parameter already exists
				if "$ESCALATION_TOOL" grep -q "$IOMMU_PARAM" "$entry"; then
					echo -e "${yellow}IOMMU parameter already present in $(basename "$entry")${no_color}"
					continue
				fi
				
				# Add IOMMU parameter to the options line
				if "$ESCALATION_TOOL" grep -q "^options" "$entry"; then
					"$ESCALATION_TOOL" sed -i "/^options/ s/$/ $IOMMU_PARAM iommu=pt/" "$entry"
					echo -e "${green}Updated $(basename "$entry") with: $IOMMU_PARAM iommu=pt${no_color}"
				else
					# If no options line exists, add one
					echo "options $IOMMU_PARAM iommu=pt" | "$ESCALATION_TOOL" tee -a "$entry" > /dev/null
					echo -e "${green}Added options line to $(basename "$entry") with: $IOMMU_PARAM iommu=pt${no_color}"
				fi
			done
			;;
		1)
			echo -e "${green}Configuring GRUB bootloader...${no_color}"

			GRUB_CONFIG="/etc/default/grub"
			backup_file "$GRUB_CONFIG"

			# Check if GRUB_CMDLINE_LINUX_DEFAULT exists
			if ! "$ESCALATION_TOOL" grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_CONFIG"; then
				echo -e "${red}GRUB_CMDLINE_LINUX_DEFAULT not found in $GRUB_CONFIG${no_color}"
				#exit 1
			fi

			# Check if IOMMU parameter already exists
			if "$ESCALATION_TOOL" grep "GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_CONFIG" | grep -q "$IOMMU_PARAM"; then
				echo -e "${yellow}IOMMU parameter already present in GRUB configuration${no_color}"
			else
				# Add IOMMU parameter to GRUB_CMDLINE_LINUX_DEFAULT
				"$ESCALATION_TOOL" sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"$/ $IOMMU_PARAM iommu=pt\"/" "$GRUB_CONFIG"
				echo -e "${green}Updated GRUB configuration with: $IOMMU_PARAM iommu=pt${no_color}"
			fi

			# Regenerate GRUB configuration
			echo -e "${green}Regenerating GRUB configuration...${no_color}"
			if "$ESCALATION_TOOL" grub-mkconfig -o /boot/grub/grub.cfg; then
				echo -e "${green}GRUB configuration updated successfully${no_color}"
			else
				echo -e "${red}Failed to regenerate GRUB configuration${no_color}"
				#exit 1
			fi
			;;
		2)
			# No bootloader detected
			echo -e "${red}Unable to detect bootloader (GRUB or systemd-boot)${no_color}"
			echo -e "${red}Please manually add '$IOMMU_PARAM iommu=pt' to your kernel parameters${no_color}"
			#exit 1
			;;
	esac
else
	echo -e "${red}No valid GPU configuration found for VFIO passthrough${no_color}"
	#exit 1
fi

echo ""

SWITCH_SCRIPT=~/.local/bin/gpu-switch
echo -e "${green}Creating GPU switch script at $SWITCH_SCRIPT${no_color}"

#TODO: don't hardcode the audio driver
AUDIO_DRIVER="snd_hda_intel"

# Try to detect the driver currently in use
DETECTED_DRIVER=""
if [ -n "$GPU_PCI_ID" ]; then
	DETECTED_DRIVER=$(lspci -nnk -s "$GPU_PCI_ID" | grep "Kernel driver in use" | awk -F': ' '{print $2}' | xargs)
fi

# Check if we are potentially in an install environment where nouveau is active but nvidia is installed
HAS_NVIDIA_INSTALLED=false
if command -v pacman &>/dev/null; then
	if pacman -Qq | grep -qE "^nvidia-dkms$|^nvidia-open-dkms$|^nvidia$"; then
		HAS_NVIDIA_INSTALLED=true
	fi
fi

if [[ -n "$DETECTED_DRIVER" && "$DETECTED_DRIVER" != "vfio-pci" ]]; then
	# If nouveau is detected but nvidia explicitly installed, prefer nvidia for the switch script
	if [[ "$DETECTED_DRIVER" == "nouveau" && "$HAS_NVIDIA_INSTALLED" == "true" ]]; then
		GPU_DRIVER="nvidia"
		echo -e "${yellow}Detected 'nouveau' active, but Nvidia proprietary packages are installed.${no_color}"
		echo -e "${green}Defaulting to 'nvidia' driver for host mode.${no_color}"
	else
		GPU_DRIVER="$DETECTED_DRIVER"
		echo -e "${green}Detected active GPU driver:${no_color} $GPU_DRIVER"
	fi
else
	# Fallback if detection fails or if already bound to vfio-pci
	case "$GPU_TYPE" in
		"nvidia")
			# check if nouveau is active or if nvidia is preferred
			if [[ "$HAS_NVIDIA_INSTALLED" == "true" ]]; then
				GPU_DRIVER="nvidia"
			elif lsmod | grep -q "nouveau"; then
				GPU_DRIVER="nouveau"
			else
				GPU_DRIVER="nvidia"
			fi
			;;
		"amdgpu")
			GPU_DRIVER="amdgpu"
			;;
		*)
			echo -e "${red}No supported GPU driver detected for switching${no_color}"
			GPU_DRIVER="unknown"
			;;
	esac
	if [ "$GPU_DRIVER" != "unknown" ]; then
		echo -e "${yellow}Used default driver '$GPU_DRIVER' for $GPU_TYPE (Detection result: '$DETECTED_DRIVER')${no_color}"
	fi
fi

# Generate the GPU switch script
cat << SWITCH_SCRIPT_EOF | "$ESCALATION_TOOL" tee "$SWITCH_SCRIPT" > /dev/null
#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
no_color='\033[0m' # No Color

# Log to /tmp so it persists across session crashes
exec > >(tee -i /tmp/gpu-switch.log)
exec 2>&1

ESCALATION_TOOL="$ESCALATION_TOOL"

# Delay function with progress indicator
delay_with_progress() {
	local secs=\$1
	echo -n -e "\${blue}Waiting \$secs seconds "
	for ((i=0; i<secs; i++)); do
		echo -n "."
		sleep 1
	done
	echo -e "\${no_color}"
}

# GPU Switch Script for VFIO Passthrough
# Switches GPU between host and VM

GPU_PCI_ID="$GPU_PCI_ID"
AUDIO_PCI_ID="$AUDIO_PCI_ID"
GPU_DRIVER="$GPU_DRIVER"
AUDIO_DRIVER="$AUDIO_DRIVER"
HAS_NVIDIA_INSTALLED="$HAS_NVIDIA_INSTALLED"

case "\$1" in
	"vm")
		echo -e "\${green}Switching GPU to VM mode...\${no_color}"

		echo -e "\${blue}Unloading host drivers...\${no_color}"
		# Unload nvidia_drm first because of modeset dependencies
		for module in nvidia_drm nvidia_modeset nvidia_uvm nvidia nouveau nvidiafb amdgpu radeon; do
			echo -e "\${green}Looking for module: \$module\${no_color}"
			if lsmod | grep -q "\$module"; then
				echo -e "\${green}Removing module: \$module\${no_color}"
				"\$ESCALATION_TOOL" modprobe -r "\$module" 2>/dev/null || true
			else
				echo -e "\${yellow}Module \$module not found, skipping.\${no_color}"
			fi
		done
		delay_with_progress 3

		# Load vfio-pci module first
		echo -e "\${blue}Loading vfio-pci module...\${no_color}"
		if ! "\$ESCALATION_TOOL" modprobe vfio-pci; then
			echo -e "\${red}Failed to load vfio-pci module\${no_color}"
			exit 1
		fi
		sleep 1

		# Bind GPU to vfio-pci
		if [[ -n "\$GPU_PCI_ID" && -d "/sys/bus/pci/devices/\$GPU_PCI_ID" ]]; then
			echo -e "\${blue}Processing GPU: \$GPU_PCI_ID\${no_color}"
			
			# Unbind from current driver if any
			if [[ -L "/sys/bus/pci/devices/\$GPU_PCI_ID/driver" ]]; then
				echo -e "\${green}Unbinding GPU from current driver...\${no_color}"
				echo "\$GPU_PCI_ID" | "\$ESCALATION_TOOL" tee /sys/bus/pci/devices/\$GPU_PCI_ID/driver/unbind > /dev/null 2>&1 || true
				sleep 0.5
			fi
			
			# Set driver_override to vfio-pci
			echo -e "\${green}Setting driver_override for GPU to vfio-pci...\${no_color}"
			echo "vfio-pci" | "\$ESCALATION_TOOL" tee /sys/bus/pci/devices/\$GPU_PCI_ID/driver_override > /dev/null
			
			# Bind to vfio-pci
			echo -e "\${green}Binding GPU to vfio-pci...\${no_color}"
			echo "\$GPU_PCI_ID" | "\$ESCALATION_TOOL" tee /sys/bus/pci/drivers/vfio-pci/bind > /dev/null 2>&1 || true
			
			# Verify binding
			if [[ -L "/sys/bus/pci/devices/\$GPU_PCI_ID/driver" ]]; then
				gpu_driver=\$(basename \$(readlink /sys/bus/pci/devices/\$GPU_PCI_ID/driver))
				if [[ "\$gpu_driver" == "vfio-pci" ]]; then
					echo -e "\${green}GPU successfully bound to vfio-pci\${no_color}"
				else
					echo -e "\${red}GPU bound to \$gpu_driver instead of vfio-pci\${no_color}"
				fi
			else
				echo -e "\${red}GPU has no driver bound after bind attempt\${no_color}"
			fi
		fi

		# Bind Audio to vfio-pci
		if [[ -n "\$AUDIO_PCI_ID" && -d "/sys/bus/pci/devices/\$AUDIO_PCI_ID" ]]; then
			echo -e "\${blue}Processing Audio: \$AUDIO_PCI_ID\${no_color}"
			
			# Unbind from current driver if any
			if [[ -L "/sys/bus/pci/devices/\$AUDIO_PCI_ID/driver" ]]; then
				echo -e "\${green}Unbinding Audio from current driver...\${no_color}"
				echo "\$AUDIO_PCI_ID" | "\$ESCALATION_TOOL" tee /sys/bus/pci/devices/\$AUDIO_PCI_ID/driver/unbind > /dev/null 2>&1 || true
				sleep 0.5
			fi
			
			# Set driver_override to vfio-pci
			echo -e "\${green}Setting driver_override for Audio to vfio-pci...\${no_color}"
			echo "vfio-pci" | "\$ESCALATION_TOOL" tee /sys/bus/pci/devices/\$AUDIO_PCI_ID/driver_override > /dev/null
			
			# Bind to vfio-pci
			echo -e "\${green}Binding Audio to vfio-pci...\${no_color}"
			echo "\$AUDIO_PCI_ID" | "\$ESCALATION_TOOL" tee /sys/bus/pci/drivers/vfio-pci/bind > /dev/null 2>&1 || true
			
			# Verify binding
			if [[ -L "/sys/bus/pci/devices/\$AUDIO_PCI_ID/driver" ]]; then
				audio_driver=\$(basename \$(readlink /sys/bus/pci/devices/\$AUDIO_PCI_ID/driver))
				if [[ "\$audio_driver" == "vfio-pci" ]]; then
					echo -e "\${green}Audio successfully bound to vfio-pci\${no_color}"
				else
					echo -e "\${red}Audio bound to \$audio_driver instead of vfio-pci\${no_color}"
				fi
			else
				echo -e "\${red}Audio has no driver bound after bind attempt\${no_color}"
			fi
		fi

		echo -e "\${green}GPU switched to VM mode\${no_color}"
		echo "To check , look for 'vfio-pci' in the output of 'lspci -nnk | grep -A 3 "NVIDIA"'"
		echo "you should see 'Kernel driver in use: vfio-pci' in both GPU and Audio"
		;;
	"host")
		echo -e "\${green}Switching GPU to host mode...\${no_color}"
		# Unbind from vfio-pci
		echo -e "\${blue}Unbinding GPU and audio devices from vfio-pci...\${no_color}"
		if [[ -n "\$GPU_PCI_ID" && -d "/sys/bus/pci/devices/\$GPU_PCI_ID" ]]; then
			echo -e "\${green}Unbinding GPU: \$GPU_PCI_ID from vfio-pci\${no_color}"
			echo "\$GPU_PCI_ID" | "\$ESCALATION_TOOL" tee /sys/bus/pci/devices/\$GPU_PCI_ID/driver/unbind 2>/dev/null || true
		fi
		if [[ -n "\$AUDIO_PCI_ID" && -d "/sys/bus/pci/devices/\$AUDIO_PCI_ID" ]]; then
			echo -e "\${green}Unbinding Audio: \$AUDIO_PCI_ID from vfio-pci\${no_color}"
			echo "\$AUDIO_PCI_ID" | "\$ESCALATION_TOOL" tee /sys/bus/pci/devices/\$AUDIO_PCI_ID/driver/unbind 2>/dev/null || true
		fi
		sleep 1

		# Clear driver overrides
		echo -e "\${blue}Clearing driver overrides...\${no_color}"
		if [[ -n "\$GPU_PCI_ID" && -d "/sys/bus/pci/devices/\$GPU_PCI_ID" ]]; then
			echo -e "\${green}Clearing GPU driver override: \$GPU_PCI_ID\${no_color}"
			echo "" | "\$ESCALATION_TOOL" tee /sys/bus/pci/devices/\$GPU_PCI_ID/driver_override 2>/dev/null || true
		fi
		if [[ -n "\$AUDIO_PCI_ID" && -d "/sys/bus/pci/devices/\$AUDIO_PCI_ID" ]]; then
			echo -e "\${green}Clearing Audio driver override: \$AUDIO_PCI_ID\${no_color}"
			echo "" | "\$ESCALATION_TOOL" tee /sys/bus/pci/devices/\$AUDIO_PCI_ID/driver_override 2>/dev/null || true
		fi
		sleep 1

		# load host GPU drivers
		echo -e "\${blue}loading host drivers...\${no_color}"
		if [[ "\$GPU_DRIVER" == "nouveau" || "\$GPU_DRIVER" == "nvidia" ]]; then
			for module in nvidia nouveau nvidiafb nvidia_drm nvidia_modeset nvidia_uvm; do
				if [[ "\$module" == "nouveau" && "\$HAS_NVIDIA_INSTALLED" == "true" ]]; then
					echo -e "\${yellow}Skipping nouveau module (Nvidia drivers installed)\${no_color}"
					continue
				fi
				echo -e "\${green}Loading module: \$module\${no_color}"
				"\$ESCALATION_TOOL" modprobe "\$module" 2>/dev/null || true
			done
		elif [[ "\$GPU_DRIVER" == "amdgpu" ]]; then
			for module in amdgpu radeon; do
				echo -e "\${green}Loading module: \$module\${no_color}"
				"\$ESCALATION_TOOL" modprobe "\$module" 2>/dev/null || true
			done
		fi
		sleep 1

		# Bind to host drivers
		echo -e "\${blue}Binding GPU and audio devices to host drivers...\${no_color}"
		if [[ -n "\$GPU_PCI_ID" && -d "/sys/bus/pci/devices/\$GPU_PCI_ID" ]]; then
			echo -e "\${green}Binding GPU: \$GPU_PCI_ID to \$GPU_DRIVER\${no_color}"
			echo "\$GPU_PCI_ID" | "\$ESCALATION_TOOL" tee /sys/bus/pci/drivers/\$GPU_DRIVER/bind 2>/dev/null || true
		fi
		if [[ -n "\$AUDIO_PCI_ID" && -d "/sys/bus/pci/devices/\$AUDIO_PCI_ID" ]]; then
			echo -e "\${green}Binding Audio: \$AUDIO_PCI_ID to \$AUDIO_DRIVER\${no_color}"
			echo "\$AUDIO_PCI_ID" | "\$ESCALATION_TOOL" tee /sys/bus/pci/drivers/\$AUDIO_DRIVER/bind 2>/dev/null || true
		fi

		echo -e "\${green}GPU switched to host mode\${no_color}"
		echo "To check , look for 'nvidia'|'nouveau' or 'amdgpu' in the output of 'lspci -nnk | grep -A 3 "NVIDIA"'"
		echo "you should see 'Kernel driver in use: nvidia' or 'Kernel driver in use: amdgpu'"
		;;
	*)
		echo -e "\${red}Usage: \$0 {vm|host}\${no_color}"
		echo -e "\${yellow}  vm   - Switch GPU to VM mode (bind to vfio-pci)\${no_color}"
		echo -e "\${yellow}  host - Switch GPU to host mode (bind to host driver)\${no_color}"
		echo "To check what's using your gpu run: 'fuser -v /dev/nvidia*'"
		exit 1
		;;
esac
SWITCH_SCRIPT_EOF

"$ESCALATION_TOOL" chmod +x "$SWITCH_SCRIPT"

echo ""
# Load vfio modules
echo -e "${green}Loading VFIO kernel modules...${no_color}"
MODULES_LOAD_CONF="/etc/modules-load.d/vfio.conf"
if [[ ! -f "$MODULES_LOAD_CONF" ]]; then
	echo -e "vfio\nvfio_iommu_type1\nvfio_pci" | "$ESCALATION_TOOL" tee "$MODULES_LOAD_CONF" > /dev/null
	echo -e "${green}Created $MODULES_LOAD_CONF with VFIO modules${no_color}"
else
	echo -e "${yellow}VFIO modules configuration already exists${no_color}"
fi
echo ""
echo -e "${green}Update initramfs to include VFIO modules:${no_color}"

# Initramfs Configuration & Regeneration
echo -e "${green}Configuring VFIO modules for Initramfs...${no_color}"
VFIO_MODULES="vfio vfio_iommu_type1 vfio_pci"
INITRAMFS_UPDATED=false

# 1. Dracut
if command -v dracut &>/dev/null; then
	echo -e "${blue}Dracut detected.${no_color}"
	DRACUT_CONF_DIR="/etc/dracut.conf.d"
	"$ESCALATION_TOOL" mkdir -p "$DRACUT_CONF_DIR"
	DRACUT_VFIO_CONF="$DRACUT_CONF_DIR/10-vfio.conf"
	
	echo -e "${green}Writing Dracut configuration to $DRACUT_VFIO_CONF...${no_color}"
	echo "force_drivers+=\" $VFIO_MODULES \"" | "$ESCALATION_TOOL" tee "$DRACUT_VFIO_CONF" > /dev/null
	
	echo -e "${green}Regenerating Dracut initramfs...${no_color}"
	if command -v xbps-reconfigure &>/dev/null; then
		"$ESCALATION_TOOL" xbps-reconfigure -fa || echo -e "${red}Dracut regeneration failed${no_color}"
	else
		"$ESCALATION_TOOL" dracut --force --regenerate-all || echo -e "${red}Dracut regeneration failed${no_color}"
	fi
	INITRAMFS_UPDATED=true
fi

# 2. Booster
if command -v booster &>/dev/null; then
	echo -e "${blue}Booster detected.${no_color}"
	BOOSTER_OPTS="vfio,vfio_iommu_type1,vfio_pci"
	BOOSTER_CONF="/etc/booster.yaml"
	
	# Check configuration
	if [ -f "$BOOSTER_CONF" ]; then
		if "$ESCALATION_TOOL" grep -q "modules_force_load:" "$BOOSTER_CONF"; then
			if ! "$ESCALATION_TOOL" grep -q "vfio" "$BOOSTER_CONF"; then
				echo -e "${yellow}Adding VFIO modules to $BOOSTER_CONF${no_color}"
				"$ESCALATION_TOOL" sed -i "/^modules_force_load:/ s/$/,$BOOSTER_OPTS/" "$BOOSTER_CONF"
			fi
		else
			echo "modules_force_load: $BOOSTER_OPTS" | "$ESCALATION_TOOL" tee -a "$BOOSTER_CONF" > /dev/null
		fi
	else
		echo "modules_force_load: $BOOSTER_OPTS" | "$ESCALATION_TOOL" tee "$BOOSTER_CONF" > /dev/null
	fi
	
	echo -e "${green}Regenerating Booster initramfs...${no_color}"
	if command -v xbps-reconfigure &>/dev/null; then
		"$ESCALATION_TOOL" xbps-reconfigure -fa || echo -e "${red}Booster regeneration failed${no_color}"
	else
		# Try to detect kernel version for manual build
		for kmod in /lib/modules/*; do
			kver=$(basename "$kmod")
			if [[ -d "$kmod" ]]; then
				echo -e "Building for kernel $kver..."
				"$ESCALATION_TOOL" booster build --force --kernel-version "$kver" /boot/initramfs-"$kver".img || true
			fi
		done
	fi
	INITRAMFS_UPDATED=true
fi

# 3. Mkinitcpio (Standard Arch)
MKINITCPIO_CONF="/etc/mkinitcpio.conf"
if [ -f "$MKINITCPIO_CONF" ]; then
	echo -e "${blue}Mkinitcpio detected ($MKINITCPIO_CONF).${no_color}"
	backup_file "$MKINITCPIO_CONF"

	if ! "$ESCALATION_TOOL" grep -q "^MODULES=" "$MKINITCPIO_CONF"; then
		echo "MODULES=($VFIO_MODULES)" | "$ESCALATION_TOOL" tee -a "$MKINITCPIO_CONF" > /dev/null
	else
		current_modules=$("$ESCALATION_TOOL" grep "^MODULES=" "$MKINITCPIO_CONF" | sed 's/MODULES=//; s/[()]//g')
		all_present=true
		for module in $VFIO_MODULES; do
			if ! echo "$current_modules" | grep -qw "$module"; then
				all_present=false; break
			fi
		done
		if [[ "$all_present" == false ]]; then
			"$ESCALATION_TOOL" sed -i "/^MODULES=/d" "$MKINITCPIO_CONF"
			new_modules=$(echo "$current_modules $VFIO_MODULES" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/ $//')
			echo "MODULES=($new_modules)" | "$ESCALATION_TOOL" tee -a "$MKINITCPIO_CONF" > /dev/null
			echo -e "${green}Updated MODULES in mkinitcpio.conf${no_color}"
		fi
	fi

	#Note: blacklising is no longer needed as im doing the gpu switch.
	# echo -e "${green}Blacklist host GPU drivers to prevent automatic binding:${no_color}"
	# if [ "$GPU_TYPE" = "nvidia" ]; then
	# 	echo -e "blacklist nvidia\nblacklist nvidia_drm\nblacklist nvidia_modeset\nblacklist nouveau\nblacklist nvidiafb\nblacklist nvidia_uvm" | "$ESCALATION_TOOL" tee /etc/modprobe.d/blacklist-nvidia.conf > /dev/null
	# elif [ "$GPU_TYPE" = "amdgpu" ]; then
	# 	echo -e "blacklist amdgpu\nblacklist radeon" | "$ESCALATION_TOOL" tee /etc/modprobe.d/blacklist-amd.conf > /dev/null
	# fi

	# echo -e "${green}Creating VFIO configuration file /etc/modprobe.d/vfio.conf${no_color}"
	# echo -e "options vfio-pci ids=$VFIO_IDS" | "$ESCALATION_TOOL" tee /etc/modprobe.d/vfio.conf > /dev/null

	echo -e "${green}Regenerating Mkinitcpio initramfs...${no_color}"
	if "$ESCALATION_TOOL" mkinitcpio -P; then
		echo -e "${green}Initramfs updated successfully${no_color}"
	else
		echo -e "${red}Failed to update initramfs${no_color}"
	fi
	INITRAMFS_UPDATED=true
fi

if [ "$INITRAMFS_UPDATED" = false ]; then
	echo -e "${red}Error: No supported initramfs generator detected (dracut, booster, mkinitcpio)${no_color}"
	echo -e "${yellow}Please manually configure VFIO modules: $VFIO_MODULES${no_color}"
fi

# 4. Note: Run 'update-initramfs -u' for debian based distro and Run 'kernelstub' if you are on popos

echo ""
LIBVIRTHOOK_SCRIPT="/etc/libvirt/hooks/qemu"
"$ESCALATION_TOOL" mkdir -p "/etc/libvirt/hooks" || true
echo -e "${green}Create libvirt hook to automate GPU switching, at $LIBVIRTHOOK_SCRIPT${no_color}"

cat << LIBVIRTHOOK_SCRIPT_EOF | "$ESCALATION_TOOL" tee "$LIBVIRTHOOK_SCRIPT" > /dev/null
#!/usr/bin/env bash

exec >> /tmp/libvirt-hook-execution.log 2>&1
echo "=== Hook executed at \$(date) ==="

# Reference : https://libvirt.org/hooks.html

GUEST_NAME="\$1"
HOOK_NAME="\$2" # prepare, start, started, stopped or release
STATE_NAME="\$3" # begin or end
SHUTOFF_REASON="\$4" # provides the reason for the shutdown of the domain

# Function to send notifications to the user
# we need this method because libvirt hook runs as root
# and does not know the user name or session
send_notification() {
    local title="\$1"
    local message="\$2"
    local urgency="\${3:-normal}"
    
    # Debug log file
    local log_file="/tmp/libvirt-notification-debug.log"
    echo "=== \$(date) ===" >> "\$log_file"
    echo "Attempting to send notification: \$title - \$message" >> "\$log_file"
    
    # Try multiple methods to find active user session
    for user_dir in /run/user/*; do
        echo "Checking user_dir: \$user_dir" >> "\$log_file"
        [ -d "\$user_dir" ] || continue
        
        user_uid=\$(basename "\$user_dir")
        user_name=\$(id -nu "\$user_uid" 2>/dev/null) || continue
        
        echo "Found user: \$user_name (UID: \$user_uid)" >> "\$log_file"
        
        # Skip if not a real user
        [ "\$user_uid" -ge 1000 ] || continue
        
        dbus_addr="unix:path=\${user_dir}/bus"
        display=":0"
        
        # Try to get actual DISPLAY if possible
        if [ -f "/proc/\$(pgrep -u "\$user_uid" -x Xorg | head -n1)/environ" 2>/dev/null ]; then
            display=\$(tr '\0' '\n' < "/proc/\$(pgrep -u "\$user_uid" -x Xorg | head -n1)/environ" 2>/dev/null | grep ^DISPLAY= | cut -d= -f2)
            echo "Found DISPLAY: \$display" >> "\$log_file"
        fi
        
        echo "Attempting notification with DISPLAY=\$display DBUS=\$dbus_addr" >> "\$log_file"
        
        # Send notification
        if "$ESCALATION_TOOL" -u "\$user_name" \
            DISPLAY="\$display" \
            DBUS_SESSION_BUS_ADDRESS="\$dbus_addr" \
            notify-send -u "\$urgency" "\$title" "\$message" 2>>"\$log_file"; then
            echo "SUCCESS: Notification sent!" >> "\$log_file"
            return 0
        else
            echo "FAILED: notify-send returned error code \$?" >> "\$log_file"
        fi
    done
    
    echo "All attempts failed, falling back to syslog" >> "\$log_file"
    # Fallback: log to syslog
    logger -t "libvirt-hook" "\$title: \$message"
}

# Function to extract PCI devices from VM XML using xmllint (more robust)
get_vm_pci_devices_xmllint() {
	local vm_name="\$1"

	# Get the VM XML configuration
	if [ -t 0 ]; then
		# No stdin, use virsh
		# NOTE: This may cause libvirt to hang or stuck in infinite loop, if it 
		# called by libvirt, A deadlock is likely to occur.
		local vm_xml=\$(timeout 10 "$ESCALATION_TOOL" virsh dumpxml "\$vm_name" 2>/dev/null)
		if [ \$? -eq 124 ]; then
			echo "virsh dumpxml timed out" >&2
			return 1
		fi
	else
		# Read from stdin
		local vm_xml=\$(cat)
	fi

	if [ -z "\$vm_xml" ]; then
		echo "Failed to get XML for VM: \$vm_name" >&2
		return 1
	fi

	# Use xmllint to extract PCI hostdev addresses
	echo "\$vm_xml" | xmllint --xpath "//hostdev[@mode='subsystem' and @type='pci']/source/address/@domain | //hostdev[@mode='subsystem' and @type='pci']/source/address/@bus | //hostdev[@mode='subsystem' and @type='pci']/source/address/@slot | //hostdev[@mode='subsystem' and @type='pci']/source/address/@function" - 2>/dev/null | \
	sed 's/domain="\([^"]*\)"/\1/g; s/bus="\([^"]*\)"/\1/g; s/slot="\([^"]*\)"/\1/g; s/function="\([^"]*\)"/\1/g' | \
	paste -d' ' - - - - | \
	while read -r domain bus slot function; do
		# Convert hex to decimal and format as PCI address
		domain_dec=\$(printf "%04x" \$domain)
		bus_dec=\$(printf "%02x" \$bus)
		slot_dec=\$(printf "%02x" \$slot)
		func_dec=\$(printf "%01x" \$function)

		echo "\${domain_dec}:\${bus_dec}:\${slot_dec}.\${func_dec}"
	done
}

is_gpu_passed_to_vm() {
	local vm_name="\$1"

	if [ -z "\$vm_name" ]; then
		echo "Usage: \$0 <vm-name>"
		echo "Available VMs:"
		"$ESCALATION_TOOL" virsh list --all --name || true
		return 1
	fi

	echo "Testing VM: \$vm_name"
	echo ""

	echo "Using (xmllint) to check if the gpu is passed to vm:"
	if command -v xmllint &> /dev/null; then
		pci_devices_xmllint=\$(get_vm_pci_devices_xmllint "\$vm_name")
		if [ -n "\$pci_devices_xmllint" ]; then
			echo "\$pci_devices_xmllint"
			while IFS= read -r pci_device; do
				if [ -n "\$pci_device" ]; then
					local pci_addr=\$(echo "\$pci_device" | sed 's/^0000://')
					# Check if this PCI device is a VGA controller or 3D controller
					if lspci -s "\$pci_addr" 2>/dev/null | grep -qE "(VGA|3D controller)"; then
						echo "GPU found: \$pci_addr"
						return 0
					else
						echo "Not a GPU: \$pci_addr"
					fi
				fi
			done <<< "\$pci_devices_xmllint"
		else
			echo "No PCI devices found"
			return 1
		fi
	else
		echo "xmllint not available, can't run the script"
	fi
	return 1
}

# Main execution
if is_gpu_passed_to_vm "\$GUEST_NAME"; then
	echo "GPU is passed to VM"
	if [ "\$HOOK_NAME" = "prepare" ] && [ "\$STATE_NAME" = "begin" ]; then
		# $SWITCH_SCRIPT vm # i comment this part because i want to run the script manually
		if lspci -nnk -s "${GPU_PCI_ID#0000:}" | grep -q "vfio-pci"; then
			echo "GPU is already passed to VM"
			send_notification "GPU Passthrough" "GPU is passed to VM, continue running the vm"
		else
			echo "GPU is not passed to VM"
			send_notification "GPU Passthrough" "ERROR: GPU not bound to vfio-pci. Aborting VM start." "critical"
			send_notification "GPU Passthrough" "run 'gpu-switch vm' to pass the gpu to vm"
			exit 1
		fi
	elif [ "\$HOOK_NAME" = "release" ] && [ "\$STATE_NAME" = "end" ]; then
		# $SWITCH_SCRIPT host
		send_notification "GPU Passthrough" "VM stopped. You can now run 'gpu-switch host' to get the gpu back to host"
	else
		echo "Unknown HOOK: \$HOOK_NAME"
	fi
else
	echo "GPU is not passed to VM, Or something happen during the process!!"
fi

##TODO: make running the hugepages dynamic by checking the xml if it contains the hugepages tag.
## and check the memory size to determine the size of hugepages.
# if [ "\$HOOK_NAME" = "prepare" ] && [ "\$STATE_NAME" = "begin" ]; then
#	 echo "Enabling hugepages..."
#	 echo $size_of_pages | "$ESCALATION_TOOL" tee /proc/sys/vm/nr_hugepages
# elif [ "\$HOOK_NAME" = "release" ] && [ "\$STATE_NAME" = "end" ]; then
#	 echo "Disabling hugepages..."
#	 echo 0 | "$ESCALATION_TOOL" tee /proc/sys/vm/nr_hugepages
# fi



LIBVIRTHOOK_SCRIPT_EOF
"$ESCALATION_TOOL" chmod +x $LIBVIRTHOOK_SCRIPT

"$ESCALATION_TOOL" systemctl restart libvirtd || true

echo ""

echo -e "${yellow}IOMMU and GPU passthrough setup completed${no_color}"
echo -e "${yellow}To check if the kernel is binded to vfio-pci, run:${no_color}"
echo -e "${green}lspci -nnk -d $nvidia_gpu_id 2>/dev/null || lspci -nnk -d $amd_gpu_id 2>/dev/null${no_color}" # lspci -nnk -d 10de:28e0
echo -e "${green}The output must show Kernel driver in use: vfio-pci. If it does, you have succeeded!${no_color}"
echo -e "${green}(Don't worry if Kernel modules: still lists nouveau or radeon; the important line is Kernel driver in use:).${no_color}"
echo -e "${green}Check DRM devices: with ls /sys/class/drm/${no_color}"
echo -e "${green}You should now only see one card listed (e.g., card0, renderD128, etc.), which will be your integrated GPU${no_color}"

# # Additional commands to check GPU driver status
# echo -e "${green}Checking GPU driver status...${no_color}"
# echo -e "${blue}List of GPU driver files:${no_color}"
# ls -la /sys/class/drm/card*/device/driver || true
# echo -e "${blue}List of open files for GPU devices:${no_color}"
# "$ESCALATION_TOOL" lsof /dev/dri/card* || true
# echo -e "${blue}List of PCI devices related to GPU:${no_color}"
# lspci | grep -E "(VGA|3D|Display)"


echo -e "${yellow}Please reboot your system to apply the changes.${no_color}"
#TODO: the bottom line.
echo -e "${green}Additional Notes\n . Some laptops require additional ACPI patches for proper GPU switching${no_color}"
echo ""
echo -e "${yellow}Scripts summary : ${no_color}"
echo -e "${green}run 'check-iommu-groups' to check IOMMU groups after reboot${no_color}"
echo -e "${green}$SWITCH_SCRIPT Use To switch GPU between host and vm${no_color}"
echo -e "${green}$LIBVIRTHOOK_SCRIPT libvirt hook that automatically runs the switch script${no_color}"
