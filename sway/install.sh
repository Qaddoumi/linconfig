#!/usr/bin/env bash

set -e # Exit on error

# to get a list of installed packages, you can use:
# pacman -Qqe
# or to get a list of all installed packages with their installation time and dependencies:
# grep "installed" /var/log/pacman.log

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
no_color='\033[0m' # rest the color to default

# # Check if running as root
# if [[ $EUID -eq 0 ]]; then
#    echo -e "${red}This script should not be run as root. Please run as a regular user with sudo privileges.${no_color}"
#    exit 1
# fi

backup_file() {
    local file="$1"
    if sudo test -f "$file"; then
        sudo cp "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${green}Backed up $file${no_color}"
    else
        echo -e "${yellow}File $file does not exist, skipping backup${no_color}"
    fi
}

cd ~ || echo -e "${red}Failed to change directory to home${no_color}"

echo -e "${green} ******************* Sway Installation Script ******************* ${no_color}"


# Parse named arguments --login-manager and --is-vm
login_manager=""
is_vm=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --login-manager)
            login_manager="$2"
            shift 2
            ;;
        --is-vm)
            is_vm="$2"
            echo -e "${green}is_vm flag set to: $is_vm${no_color}"
            shift 2
            ;;
        *)
            echo -e "${red}Unknown argument: $1${no_color}"
            exit 1
            ;;
    esac
done
if [ -z "$login_manager" ]; then
    login_manager="sddm" # Fallback to the default login manager
    echo -e "${yellow}Login manager cannot be empty. will use the default: $login_manager${no_color}"
fi
echo -e "${green}Login manager to be used : $login_manager${no_color}"
echo -e "${green}Username to be used      : $USER${no_color}"

echo -e "${blue}==================================================\n==================================================${no_color}"

echo -e "${green}"Updating databases and upgrading packages...${no_color}"
sudo pacman -Syy --noconfirm || echo -e "${yellow}Failed to update package databases${no_color}"
sudo pacman -Syu --noconfirm || echo -e "${yellow}Failed to upgrade packages${no_color}"

echo -e "${blue}==================================================\n==================================================${no_color}"

echo -e "${green}Installing yay (Yet Another Yaourt)${no_color}"

sudo pacman -S --needed --noconfirm git base-devel go || true
sudo rm -rf ~/go || true # Remove default Go workspace as i don't need it
# you can add 'export GOPATH=/tmp/go' to your environment variable if you don't want to use the default GOPATH

install_yay() {
    git clone --depth 1 https://aur.archlinux.org/yay.git ~/yay || true
    cd yay || true
    makepkg -si --noconfirm || true
    cd .. && sudo rm -rf yay || true
    yay --version || true
}

if command -v yay &> /dev/null ; then
    echo "yay is already installed."
    CURRENT_VERSION=$(yay --version | head -1 | awk '{print $2}')
    echo "Current version: $CURRENT_VERSION"
    
    echo "Checking for latest version..."
    LATEST_VERSION=$(curl -s "https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=yay" | grep -o '"Version":"[^"]*"' | cut -d'"' -f4 | head -1)
    echo "Latest version: $LATEST_VERSION"

    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
        echo "yay is already up to date (version $CURRENT_VERSION)"
    elif printf '%s\n%s\n' "$LATEST_VERSION" "$CURRENT_VERSION" | sort -V | tail -n1 | grep -q "^$LATEST_VERSION$"; then
        echo "Update available: $CURRENT_VERSION -> $LATEST_VERSION"
        echo "Proceeding with update..."
        install_yay || true
    else
        echo "Current version is newer than or equal to latest available"
    fi
else
    echo "yay is not installed. Proceeding with installation..."
    install_yay || true
fi

echo -e "${blue}==================================================\n==================================================${no_color}"

echo -e "${green}Installing Sway and related packages${no_color}"
sudo pacman -S --needed --noconfirm sway # Sway window manager
sudo pacman -S --needed --noconfirm waybar # Status bar for sway
sudo pacman -S --needed --noconfirm wofi # Application launcher
sudo pacman -S --needed --noconfirm swaync # Notification daemon and system tray for sway
sudo pacman -S --needed --noconfirm libappindicator-gtk3 libayatana-appindicator # AppIndicator support for swaync tray
sudo pacman -S --needed --noconfirm kitty # Terminal emulator
sudo pacman -S --needed --noconfirm swayidle # Idle management for sway
sudo pacman -S --needed --noconfirm swaylock # Screen locker for sway
sudo pacman -S --needed --noconfirm swaybg # Background setting utility for sway
sudo pacman -S --needed --noconfirm xorg-server-xwayland # XWayland for compatibility with X11 applications
sudo pacman -S --needed --noconfirm xdg-desktop-portal xdg-desktop-portal-wlr # Portal for Wayland
sudo pacman -S --needed --noconfirm pavucontrol # PulseAudio volume control
#sudo pacman -S --needed --noconfirm autotiling # Auto-tiling for sway
sudo pacman -S --needed --noconfirm htop # System monitor
sudo pacman -S --needed --noconfirm wget # Download utility
#sudo pacman -S --needed --noconfirm nemo # File manager
sudo pacman -S --needed --noconfirm thunar thunar-archive-plugin thunar-volman thunar-media-tags-plugin # Lightweight file manager with plugins
sudo pacman -S --needed --noconfirm udisks2 gvfs gvfs-mtp # Required for thunar to handle external drives
sudo systemctl enable --now udisks2.service || true
sudo usermod -aG storage $USER || true
sudo pacman -S --needed --noconfirm kanshi # Automatic Display manager for Wayland
sudo pacman -S --needed --noconfirm nano # Text editor
sudo pacman -S --needed --noconfirm neovim # Neovim text editor
sudo pacman -S --needed --noconfirm brightnessctl # Brightness control
sudo pacman -S --needed --noconfirm polkit-gnome # PolicyKit authentication agent (give sudo access to GUI apps)
sudo pacman -S --needed --noconfirm s-tui # Terminal UI for monitoring CPU
sudo pacman -S --needed --noconfirm gdu # Disk usage analyzer
sudo pacman -S --needed --noconfirm jq # JSON processor
sudo pacman -S --needed --noconfirm bc # Arbitrary precision calculator language
sudo pacman -S --needed --noconfirm fastfetch # Fast system information tool
sudo pacman -S --needed --noconfirm less # Pager program for viewing text files
sudo pacman -S --needed --noconfirm man-db man-pages # Manual pages and database
sudo pacman -S --needed --noconfirm mpv # video player
sudo pacman -S --needed --noconfirm celluloid # frontend for mpv video player
sudo pacman -S --needed --noconfirm imv # image viewer
#sudo pacman -S --needed --noconfirm file-roller # Handling archive files
sudo pacman -S --needed --noconfirm xarchiver # Lightweight archive manager
sudo pacman -S --needed --noconfirm trash-cli # Command line trash management
sudo mkdir -p ~/.local/share/Trash/{files,info}
sudo chmod 700 ~/.local/share/Trash
sudo chown -R $USER:$USER ~/.local
sudo pacman -S --needed --noconfirm libxml2 # XML parsing library
sudo pacman -S --needed --noconfirm pv # progress bar in terminal
sudo pacman -S --needed --noconfirm network-manager-applet # Network management applet
sudo pacman -S --needed --noconfirm grim # Screenshot tool
sudo mkdir -p ~/Screenshots || true
sudo pacman -S --needed --noconfirm slurp # Selection tool for Wayland
sudo pacman -S --needed --noconfirm wl-clipboard # Clipboard management for Wayland
sudo pacman -S --needed --noconfirm cliphist # Clipboard history manager
sudo pacman -S --needed --noconfirm cpupower # CPU frequency scaling utility ==> change powersave to performance mode.
sudo pacman -S --needed --noconfirm tlp # TLP for power management
sudo pacman -S --needed --noconfirm lm_sensors # Hardware monitoring
sudo pacman -S --needed --noconfirm thermald # Intel thermal daemon
sudo pacman -S --needed --noconfirm dmidecode # Desktop Management Interface table related utilities

yay -S --needed --noconfirm google-chrome || echo -e "${red}Failed to install google-chrome${no_color}" # Web browser
yay -S --needed --noconfirm brave-bin || echo -e "${red}Failed to install brave-bin${no_color}" # Brave browser
yay -S --needed --noconfirm visual-studio-code-bin || echo -e "${red}Failed to install visual-studio-code-bin${no_color}" # Visual Studio Code
yay -S --needed --noconfirm powershell-bin || echo -e "${red}Failed to install powershell-bin${no_color}" # PowerShell
yay -S --needed --noconfirm oh-my-posh || echo -e "${red}Failed to install oh-my-posh${no_color}" # Theme engine for terminal
yay -S --needed --noconfirm looking-glass || echo -e "${red}Failed to install looking-glass${no_color}" # Low latency video streaming tool

echo -e "${blue}==================================================\n==================================================${no_color}"

echo -e "${green}Setting up environment variable for Electron apps so they lunch in wayland mode${no_color}"
ENV_FILE="/etc/environment"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${green}Creating $ENV_FILE${no_color}"
    sudo touch "$ENV_FILE"
fi

if grep -q "ELECTRON_OZONE_PLATFORM_HINT" "$ENV_FILE"; then
    echo "${green}ELECTRON_OZONE_PLATFORM_HINT already exists in $ENV_FILE${no_color}"
else
    echo -e "${green}Adding ELECTRON_OZONE_PLATFORM_HINT to $ENV_FILE...${no_color}"
    echo "ELECTRON_OZONE_PLATFORM_HINT=wayland" | sudo tee -a "$ENV_FILE" > /dev/null || true
fi
echo -e "${yellow}You'll need to restart your session for this to take effect system-wide${no_color}"

# Check if running in vm
if [ "$is_vm" = true ]; then
    echo -e "${green}is_vm flag is set to true${no_color}"
    systemType="vm"
else
    echo -e "${green}is_vm flag is set to false, detecting system type...${no_color}"
    systemType="$(systemd-detect-virt 2>/dev/null || echo "none")"
fi
if [[ "$systemType" == "none" ]]; then
    echo -e "${green}Not running in a VM, no need to set the cursor${no_color}"
else
    echo -e "${green}Running in a VM: $systemType${no_color}"
    echo -e "${green}Setting the cursor rendering${no_color}"

    if grep -q "WLR_NO_HARDWARE_CURSORS" "$ENV_FILE"; then 
        echo -e "${green}Cursor is already set in $ENV_FILE${no_color}"
    else
        echo -e "${green}Adding cursor to "$ENV_FILE"...${no_color}"
        echo "WLR_NO_HARDWARE_CURSORS=1" | sudo tee -a "$ENV_FILE" > /dev/null || true
    fi
fi

echo -e "${blue}==================================================\n==================================================${no_color}"

# Check if .bashrc exists
BASHRC_FILE="$HOME/.bashrc"
if [ ! -f "$BASHRC_FILE" ]; then
    echo -e "${green}Creating .bashrc file${no_color}"
    touch "$BASHRC_FILE"
fi

echo -e "${green}Insuring XDG_RUNTIME_DIR is set so application like wl-clipboard works properly${no_color}"
if grep -q "XDG_RUNTIME_DIR" "$BASHRC_FILE"; then
    echo -e "${green}XDG_RUNTIME_DIR is already set in .bashrc${no_color}"
else
    echo -e "${green}Adding XDG_RUNTIME_DIR to .bashrc...${no_color}"
    echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)' >> "$BASHRC_FILE"
    echo -e "${green}Successfully added to .bashrc${no_color}"
fi

if ! grep -q '^gitpush()' "$BASHRC_FILE"; then
    cat >> "$BASHRC_FILE" <<'EOF'

gitpush() {
    git add .
    git commit --allow-empty-message -m ""
    git push
}
EOF
    echo -e "${green}Added gitpush function to $BASHRC_FILE${no_color}"
else
    echo -e "${yellow}gitpush function already present in $BASHRC_FILE, skipping${no_color}"
fi

source ~/.bashrc || true

echo -e "${blue}==================================================\n==================================================${no_color}"

echo -e "${green}Installing fonts${no_color}"

sudo pacman -S --needed --noconfirm ttf-jetbrains-mono-nerd # Nerd font for JetBrains Mono
sudo pacman -S --needed --noconfirm noto-fonts-emoji # Emoji font

echo -e "${green}Refreshing font cache${no_color}"
fc-cache -fv

echo -e "${blue}==================================================\n==================================================${no_color}"

echo -e "${green}Setting Dark theme for GTK applications${no_color}"
sudo pacman -S --needed --noconfirm materia-gtk-theme # Material Design GTK theme
#sudo pacman -S --needed --noconfirm papirus-icon-theme # Icon theme
# sudo pacman -S --needed --noconfirm capitaine-cursors # Cursor theme

echo -e "${green}Showing available themes${no_color}"
ls /usr/share/themes/
# echo -e "${green}Available icon and cursor themes:${no_color}"
# ls /usr/share/icons/

echo -e "${blue}==================================================\n==================================================${no_color}"

# echo -e "${green}Performance Mode Setup ${no_color}"
#
# # Remove conflicting cpupower service if it exists
# echo -e "${green}Cleaning up any existing cpupower services...${no_color}"
# if systemctl is-enabled cpu-performance.service &>/dev/null; then
#     sudo systemctl disable cpu-performance.service
#     sudo systemctl stop cpu-performance.service
#     echo -e "${green}Disabled existing cpu-performance service${no_color}"
# fi
#
# if [ -f /etc/systemd/system/cpu-performance.service ]; then
#     sudo rm /etc/systemd/system/cpu-performance.service
#     echo -e "${green}Removed conflicting cpu-performance service${no_color}"
# fi
#
# # Disable any conflicting services
# echo -e "${green}Disabling conflicting power management services...${no_color}"
# for service in power-profiles-daemon thermald; do
#     if systemctl is-active "$service" &>/dev/null; then
#         sudo systemctl disable "$service"
#         sudo systemctl stop "$service"
#         echo -e "${green}Disabled $service (conflicts with TLP)${no_color}"
#     fi
# done
#
# echo -e "${green}Installing and configuring TLP for automatic performance management...${no_color}"
#
# # Install TLP if not present
# if ! pacman -Q tlp &>/dev/null; then
#     echo -e "${green}Installing TLP...${no_color}"
#     sudo pacman -S --noconfirm tlp
# fi
#
# # Backup and configure TLP
# echo -e "${green}Backing up original TLP config (/etc/tlp.conf)...${no_color}"
# backup_file /etc/tlp.conf
#
# echo -e "${green}Configuring TLP for automatic AC/Battery performance switching...${no_color}"
#
# # Create optimized TLP configuration for Lenovo LOQ
# sudo tee /etc/tlp.conf > /dev/null <<'EOF'
#
# # Processor
# CPU_SCALING_GOVERNOR_ON_AC=performance
# CPU_SCALING_GOVERNOR_ON_BAT=powersave
#
# # CPU Energy Performance Policy
# CPU_ENERGY_PERF_POLICY_ON_AC=performance
# CPU_ENERGY_PERF_POLICY_ON_BAT=power
#
# # CPU Boost
# CPU_BOOST_ON_AC=1
# CPU_BOOST_ON_BAT=0
#
# # CPU Frequency Scaling
# CPU_SCALING_MIN_FREQ_ON_AC=0
# CPU_SCALING_MAX_FREQ_ON_AC=0
# CPU_SCALING_MIN_FREQ_ON_BAT=0
# CPU_SCALING_MAX_FREQ_ON_BAT=0
#
# # Platform Profile (for modern laptops)
# PLATFORM_PROFILE_ON_AC=performance
# PLATFORM_PROFILE_ON_BAT=low-power
#
# # Disk devices
# DISK_APM_LEVEL_ON_AC="254 254"
# DISK_APM_LEVEL_ON_BAT="128 128"
# DISK_IOSCHED="mq-deadline mq-deadline"
#
# # SATA Link Power Management
# SATA_LINKPWR_ON_AC="med_power_with_dipm max_performance"
# SATA_LINKPWR_ON_BAT="med_power_with_dipm min_power"
#
# # PCI Express Active State Power Management
# PCIE_ASPM_ON_AC=default
# PCIE_ASPM_ON_BAT=powersupersave
#
# # Graphics (Intel integrated + NVIDIA discrete)
# INTEL_GPU_MIN_FREQ_ON_AC=0
# INTEL_GPU_MIN_FREQ_ON_BAT=0
# INTEL_GPU_MAX_FREQ_ON_AC=0
# INTEL_GPU_MAX_FREQ_ON_BAT=0
# INTEL_GPU_BOOST_FREQ_ON_AC=0
# INTEL_GPU_BOOST_FREQ_ON_BAT=0
#
# # NVIDIA GPU Power Management
# RUNTIME_PM_ON_AC=auto
# RUNTIME_PM_ON_BAT=auto
#
# # USB
# USB_AUTOSUSPEND=1
# USB_BLACKLIST_BTUSB=0
# USB_BLACKLIST_PHONE=0
# USB_BLACKLIST_PRINTER=1
# USB_BLACKLIST_WWAN=0
#
# # Audio
# SOUND_POWER_SAVE_ON_AC=0
# SOUND_POWER_SAVE_ON_BAT=1
# SOUND_POWER_SAVE_CONTROLLER=Y
#
# # WiFi Power Management
# WIFI_PWR_ON_AC=off
# WIFI_PWR_ON_BAT=on
#
# # Wake-on-LAN
# WOL_DISABLE=Y
#
# # Battery Care (for Lenovo laptops)
# #START_CHARGE_THRESH_BAT0=40
# #STOP_CHARGE_THRESH_BAT0=80
# #START_CHARGE_THRESH_BAT1=40
# #STOP_CHARGE_THRESH_BAT1=80
#
# # Restore charge thresholds on reboot
# #RESTORE_THRESHOLDS_ON_BAT=1
# #RESTORE_THRESHOLDS_ON_AC=1
#
# # ThinkPad specific (may work on some Lenovo models)
# NATACPI_ENABLE=1
# TPACPI_ENABLE=1
# TPSMAPI_ENABLE=1
# EOF
#
# echo -e "${green}Enabling and starting TLP service...${no_color}"
# sudo systemctl enable tlp.service
# sudo systemctl start tlp.service
#
# # Install TLP-RDW for additional NetworkManager integration
# if ! pacman -Q tlp-rdw &>/dev/null; then
#     echo -e "${green}Installing TLP-RDW for NetworkManager integration...${no_color}"
#     sudo pacman -S --noconfirm tlp-rdw
# fi
#
# # Check current power source and apply settings
# echo -e "${green}Applying TLP settings for current power source...${no_color}"
# sudo tlp start
#
# # Hardware sensors setup (keeping your existing logic but cleaned up)
# echo -e "${green}=== Automated Hardware Sensors Detection ===${no_color}"
# echo -e "${green}Backing up existing config (if exists)...${no_color}"
# backup_file /etc/conf.d/lm_sensors
#
# echo -e "${green}Detecting system information...${no_color}"
# SYSTEM_VENDOR=$(sudo dmidecode -s system-manufacturer 2>/dev/null | head -1)
# SYSTEM_MODEL=$(sudo dmidecode -s system-product-name 2>/dev/null | head -1)
# CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}' | head -1)
# CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
# echo -e "${green}System: $SYSTEM_VENDOR $SYSTEM_MODEL${no_color}"
# echo -e "${green}CPU: $CPU_VENDOR - $CPU_MODEL${no_color}"
#
# echo -e "${green}Detecting and loading sensor modules...${no_color}"
# DETECTED_MODULES=""
#
# # Intel CPU thermal sensors
# if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
#     echo "Detecting Intel CPU thermal sensors..."
#     if sudo modprobe coretemp 2>/dev/null; then
#         echo "✓ Intel coretemp module loaded"
#         DETECTED_MODULES="$DETECTED_MODULES coretemp"
#     fi
# # AMD CPU thermal sensors
# elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
#     echo "Detecting AMD CPU thermal sensors..."
#     if sudo modprobe k10temp 2>/dev/null; then
#         echo "✓ AMD k10temp module loaded"
#         DETECTED_MODULES="$DETECTED_MODULES k10temp"
#     fi
# fi
#
# # Check for ACPI thermal zones
# if [ -d /sys/class/thermal ] && [ "$(ls -A /sys/class/thermal/thermal_zone* 2>/dev/null)" ]; then
#     echo "✓ ACPI thermal zones detected"
#     if sudo modprobe acpi-thermal 2>/dev/null; then
#         echo "✓ ACPI thermal module loaded"
#     fi
# fi
#
# # Check for NVMe drive temperatures
# if lspci | grep -i nvme >/dev/null 2>&1; then
#     echo "✓ NVMe drives detected"
#     if sudo modprobe nvme 2>/dev/null; then
#         echo "✓ NVMe temperature monitoring available"
#     fi
# fi
#
# # Common sensor chips for laptops
# CHIP_MODULES="it87 nct6775 w83627ehf"
# for module in $CHIP_MODULES; do
#     if sudo modprobe "$module" 2>/dev/null; then
#         echo "✓ Chip module $module loaded successfully"
#         DETECTED_MODULES="$DETECTED_MODULES $module"
#         sudo modprobe -r "$module" 2>/dev/null || true
#     fi
# done
#
# # I2C support
# if command -v i2cdetect &> /dev/null; then
#     if sudo modprobe i2c-i801 2>/dev/null; then
#         echo "✓ I2C support loaded"
#         DETECTED_MODULES="$DETECTED_MODULES i2c-i801"
#     fi
# fi
#
# # Create lm_sensors configuration
# echo -e "${green}Creating lm_sensors configuration...${no_color}"
# sudo tee /etc/conf.d/lm_sensors > /dev/null <<EOF
# # Generated by automated sensor detection script
# # $(date)
# # System: $SYSTEM_VENDOR $SYSTEM_MODEL
#
# # Kernel modules for hardware sensors
# HWMON_MODULES="$DETECTED_MODULES"
# EOF
#
# # Load detected modules
# if [ -n "$DETECTED_MODULES" ]; then
#     echo -e "${green}Loading detected sensor modules...${no_color}"
#     for module in $DETECTED_MODULES; do
#         if sudo modprobe "$module"; then
#             echo "✓ Module $module loaded successfully"
#         fi
#     done
# fi
#
# # Enable and start lm_sensors
# echo -e "${green}Enabling and starting lm_sensors service...${no_color}"
# sudo systemctl enable lm_sensors.service &>/dev/null || true
# sudo systemctl start lm_sensors.service &>/dev/null || true
#
# # Initialize sensors
# echo -e "${green}Initializing sensors...${no_color}"
# if command -v sensors &> /dev/null; then
#     sudo sensors -s 2>/dev/null || true
#     echo -e "${green}✓ Sensors initialized${no_color}"
# else
#     echo -e "${yellow}⚠ sensors command not available${no_color}"
# fi
#
# echo -e "${green}=== Setup Complete ===${no_color}"
# echo -e "${green}Current TLP Status:${no_color}"
# sudo tlp-stat -s
#
# echo -e "${green}Current Power Source and Settings:${no_color}"
# if [ -f /sys/class/power_supply/AC*/online ]; then
#     if [ "$(cat /sys/class/power_supply/AC*/online)" = "1" ]; then
#         echo "Power Source: AC (Performance mode active)"
#     else
#         echo "Power Source: Battery (Power-saving mode active)"
#     fi
# fi
#
# echo -e "${green}Current CPU Governor:${no_color}"
# if command -v cpupower &> /dev/null; then
#     cpupower frequency-info | grep -E "current policy" || echo "Install cpupower-tools to see detailed CPU info"
# else
#     cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "CPU governor info not available"
# fi
#
# echo -e "${green}Temperature Monitoring:${no_color}"
# if command -v sensors &> /dev/null; then
#     sensors 2>/dev/null | head -20 || echo "Run 'sensors' to see detailed temperature data"
# else
#     echo "Install lm_sensors package for temperature monitoring"
# fi
#
# echo ""
# echo -e "${green}=== Usage Instructions ===${no_color}"
# echo -e "${green}• TLP automatically switches between performance/power-saving based on AC/Battery${no_color}"
# echo -e "${green}• Check status: sudo tlp-stat -s${no_color}"
# echo -e "${green}• Force AC mode: sudo tlp ac${no_color}"
# echo -e "${green}• Force Battery mode: sudo tlp bat${no_color}"
# echo -e "${green}• Check temperatures: sensors${no_color}"
# echo -e "${green}• Battery care: Charging limited to 80% to extend battery life${no_color}"
# echo ""
# echo -e "${yellow}Reboot recommended to ensure all settings take effect.${no_color}"

echo -e "${blue}==================================================\n==================================================${no_color}"

echo -e "${green}Installing and configuring Qemu/Libvirt for virtualization${no_color}"
sudo pacman -S --needed --noconfirm qemu-full # Full QEMU package with all features
sudo pacman -S --needed --noconfirm qemu-img # QEMU disk image utility: provides create, convert, modify, and snapshot, offline disk images
sudo pacman -S --needed --noconfirm libvirt # Libvirt for managing virtualization: provides a unified interface for managing virtual machines
sudo pacman -S --needed --noconfirm virt-install # Tool for installing virtual machines: CLI tool to create guest VMs
sudo pacman -S --needed --noconfirm virt-manager # GUI for managing virtual machines: GUI tool to create and manage guest VMs
sudo pacman -S --needed --noconfirm virt-viewer # Viewer for virtual machines
sudo pacman -S --needed --noconfirm edk2-ovmf # UEFI firmware for virtual machines
sudo pacman -S --needed --noconfirm dnsmasq # DNS and DHCP server: lightweight DNS forwarder and DHCP server
sudo pacman -S --needed --noconfirm swtpm # Software TPM emulator
sudo pacman -S --needed --noconfirm guestfs-tools # Tools for managing guest file systems
sudo pacman -S --needed --noconfirm libosinfo # Library for managing OS information
sudo pacman -S --needed --noconfirm tuned # system tuning service for linux allows us to optimise the hypervisor for speed.
sudo pacman -S --needed --noconfirm spice-vdagent # SPICE agent for guest OS
sudo pacman -S --needed --noconfirm bridge-utils # Utilities for managing network bridges
sudo pacman -S --needed --noconfirm linux-headers # for vfio modules
sudo pacman -S --needed --noconfirm linux-zen-headers # for zen kernel vfio modules

echo -e "${green}Enabling and starting libvirtd service${no_color}"
sudo systemctl enable libvirtd || true
sudo systemctl start libvirtd || true
sleep 2  # Give libvirtd a moment to fully start

echo -e "${green}Adding current user to libvirt group${no_color}"
sudo usermod -aG libvirt $(whoami) || true
echo -e "${green}Adding libvirt-qemu user to input group${no_color}"
sudo usermod -aG input libvirt-qemu || true

#TODO: does not work and needs to be applied after the reboot ...
echo -e "${green}Starting and autostarting the default network for libvirt${no_color}"
sudo virsh net-start default || true
sudo virsh net-autostart default || true

echo -e "${blue}==================================================\n==================================================${no_color}"

#bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/sway/hugepages.sh)

echo -e "${blue}==================================================\n==================================================${no_color}"

bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/sway/gpu-passthrough.sh)

echo -e "${blue}==================================================\n==================================================${no_color}"

echo -e "${green}Nested Virtualization Setup${no_color}"
echo -e "${green}Detecting CPU type and enabling nested virtualization${no_color}"

enable_nested_virtualization(){

    echo -e "${green}Detecting CPU vendor...${no_color}"
    local cpu_type=""
    local cpu_vendor
    cpu_vendor=$(grep -m1 "vendor_id" /proc/cpuinfo | cut -d: -f2 | tr -d ' ')
    case "$cpu_vendor" in
        "GenuineIntel")
            cpu_type="intel"
            ;;
        "AuthenticAMD")
            cpu_type="amd"
            ;;
        *)
            echo -e "${red}Unknown CPU vendor: $cpu_vendor${no_color}"
            echo -e "${red}Supported vendors: Intel, AMD${no_color}"
            return 1
            ;;
    esac
    echo -e "${green}Detected CPU: $(echo "$cpu_type" | tr '[:lower:]' '[:upper:]')${no_color}"

    echo -e "${green}Checking KVM modules...${no_color}"
    if ! lsmod | grep -q "^kvm "; then
        echo -e "${red}KVM module is not loaded${no_color}"
        echo -e "${red}Please install KVM first: sudo pacman -S qemu-full${no_color}"
        return 1
    fi
    local kvm_module=""
    case "$cpu_type" in
        "intel")
            kvm_module="kvm_intel"
            ;;
        "amd")
            kvm_module="kvm_amd"
            ;;
    esac
    if ! lsmod | grep -q "^$kvm_module "; then
        echo -e "${red}$kvm_module module is not loaded${no_color}"
        echo -e "${green}Loading $kvm_module module...${no_color}"
        sudo modprobe "$kvm_module"
    fi
    echo -e "${green}KVM modules are loaded${no_color}"

    check_nested_status() {
        local cpu_type=$1
        echo -e "${green}Checking current nested virtualization status...${no_color}"
        local nested_file=""
        case "$cpu_type" in
            "intel")
                nested_file="/sys/module/kvm_intel/parameters/nested"
                ;;
            "amd")
                nested_file="/sys/module/kvm_amd/parameters/nested"
                ;;
        esac

        if [[ -f "$nested_file" ]]; then
            local status
            status=$(cat "$nested_file")
            case "$status" in
                "Y"|"1")
                    echo -e "${green}Nested virtualization is already enabled, but continuing with requested action...${no_color}"
                    ;;
                "N"|"0")
                    echo -e "${yellow}Nested virtualization is currently disabled${no_color}"
                    ;;
                *)
                    echo -e "${yellow}Unknown nested virtualization status: $status${no_color}"
                    ;;
            esac
        else
            echo -e "${yellow}Cannot determine nested virtualization status${no_color}"
        fi
    }
    check_nested_status "$cpu_type" || true

    echo -e "${green}Enabling nested virtualization for current session...${no_color}"
    case "$cpu_type" in
        "intel")
            sudo modprobe -r kvm_intel
            sudo modprobe kvm_intel nested=1
            ;;
        "amd")
            sudo modprobe -r kvm_amd
            sudo modprobe kvm_amd nested=1
            ;;
    esac
    echo -e "${green}Nested virtualization enabled for current session${no_color}"

    echo -e "${green}Enabling persistent nested virtualization...${no_color}"
    local conf_file=""
    local module_name=""
    case "$cpu_type" in
        "intel")
            conf_file="/etc/modprobe.d/kvm-intel.conf"
            module_name="kvm_intel"
            ;;
        "amd")
            conf_file="/etc/modprobe.d/kvm-amd.conf"
            module_name="kvm_amd"
            ;;
    esac
    echo -e "${green}Check if the configuration file exists${no_color}"
    if [[ -f "$conf_file" ]] && grep -q "nested=1" "$conf_file"; then
        echo -e "${green}Persistent nested virtualization is already configured${no_color}"
    else
        echo "options $module_name nested=1" | sudo tee "$conf_file"
        echo -e "${green}Persistent nested virtualization configuration created: $conf_file${no_color}"
    fi

    echo -e "${green}Verifying nested virtualization...${no_color}"
    check_nested_status "$cpu_type"

    echo -e "${green}Nested virtualization setup completed${no_color}"
    echo -e "${green}Note: Persistent configuration will take effect after the next reboot${no_color}"
    echo -e "${green}or when the KVM modules are reloaded.${no_color}"
}

echo -e "${green}Checking virtualization support...${no_color}"
if ! grep -q -E "(vmx|svm)" /proc/cpuinfo; then
    echo -e "${yellow}CPU does not support virtualization (VT-x/AMD-V)${no_color}"
    echo -e "${yellow}Please enable virtualization in your BIOS/UEFI settings${no_color}"
else
    echo -e "${green}CPU supports virtualization${no_color}"
    enable_nested_virtualization || true
fi

echo -e "${blue}==================================================\n==================================================${no_color}"

echo -e "${green}KVM ACL Setup Sets up ACL permissions for the libvirt images directory${no_color}"
# Default KVM images directory
KVM_IMAGES_DIR="/var/lib/libvirt/images"
target_user="$USER"
backup_file="/tmp/kvm_acl_backup_$(date +%Y%m%d_%H%M%S).txt"

kvm_acl_setup() {

    echo -e "${green}Checking if ACL tools are installed...${no_color}"
    if ! command -v getfacl &> /dev/null; then
        echo -e "${red}getfacl command not found. ACL tools are not installed.${no_color}"
        echo -e "${green}Install ACL tools:${no_color}"
        echo -e "${green}  Ubuntu/Debian: sudo apt install acl${no_color}"
        echo -e "${green}  CentOS/RHEL: sudo yum install acl${no_color}"
        echo -e "${green}  Fedora: sudo dnf install acl${no_color}"
        return
    fi
    if ! command -v setfacl &> /dev/null; then
        echo -e "${red}setfacl command not found. ACL tools are not installed.${no_color}"
        echo -e "${green}Install ACL tools first.${no_color}"
        return
    fi
    echo -e "${green}ACL tools are installed${no_color}"

    echo -e "${green}Checking if directory exists: $KVM_IMAGES_DIR${no_color}"
    if [[ ! -d "$KVM_IMAGES_DIR" ]]; then
        echo -e "${red}Directory does not exist: $KVM_IMAGES_DIR${no_color}"
        echo -e "${green}Please install libvirt first or create the directory manually.${no_color}"
        return
    fi
    echo -e "${green}Directory exists: $KVM_IMAGES_DIR${no_color}"

    echo -e "${green}Checking ACL support for filesystem...${no_color}"
    # Try to read ACL - if it fails, ACL might not be supported
    if ! sudo getfacl "$KVM_IMAGES_DIR" &>/dev/null; then
        echo -e "${red}ACL is not supported on this filesystem${no_color}"
        echo -e "${green}Make sure the filesystem is mounted with ACL support${no_color}"
        echo -e "${green}For ext4: mount -o remount,acl /mount/point${no_color}"
        return
    fi
    echo -e "${green}Filesystem supports ACL${no_color}"

    echo -e "${green}Current ACL permissions for $KVM_IMAGES_DIR:${no_color}"
    echo "----------------------------------------"
    sudo getfacl "$KVM_IMAGES_DIR" 2>/dev/null || {
        echo -e "${red}Failed to read ACL permissions${no_color}"
        return
    }
    echo "----------------------------------------"

    echo -e "${green}Backing up current ACL permissions to: $backup_file${no_color}"
    if sudo getfacl -R "$KVM_IMAGES_DIR" > "$backup_file" 2>/dev/null; then
        echo -e "${green}ACL permissions backed up to: $backup_file${no_color}"
        echo "$backup_file"
    else
        echo -e "${yellow}Failed to backup ACL permissions, continuing anyway...${no_color}"
        echo ""
    fi

    echo -e "${green}Setting up ACL permissions for user: $target_user${no_color}"
    
    if ! id "$target_user" &>/dev/null; then
        echo -e "${red}User does not exist: $target_user${no_color}"
        return
    fi

    echo -e "${green}Removing existing ACL permissions from $KVM_IMAGES_DIR...${no_color}"
    if sudo setfacl -R -b "$KVM_IMAGES_DIR" 2>/dev/null; then
        echo -e "${green}Existing ACL permissions removed${no_color}"
    else
        echo -e "${red}Failed to remove existing ACL permissions${no_color}"
        return
    fi

    echo -e "${green}Granting permissions to user: $target_user${no_color}"
    if sudo setfacl -R -m "u:${target_user}:rwX" "$KVM_IMAGES_DIR" 2>/dev/null; then
        echo -e "${green}Granted rwX permissions to user: $target_user${no_color}"
    else
        echo -e "${red}Failed to grant permissions to user: $target_user${no_color}"
        return
    fi

    echo -e "${green}Setting default ACL for new files/directories...${no_color}"
    if sudo setfacl -m "d:u:${target_user}:rwx" "$KVM_IMAGES_DIR" 2>/dev/null; then
        echo -e "${green}Default ACL set for user: $target_user${no_color}"
    else
        echo -e "${red}Failed to set default ACL for user: $target_user${no_color}"
        return
    fi

    echo -e "${green}Verifying ACL setup...${no_color}"
    # Check if user has the expected permissions
    local acl_output
    acl_output=$(sudo getfacl "$KVM_IMAGES_DIR" 2>/dev/null)
    if echo "$acl_output" | grep -q "user:$target_user:rwx"; then
        echo -e "${green}User ACL permissions verified${no_color}"
    else
        echo -e "${red}User ACL permissions not found${no_color}"
        echo -e "${red}ACL setup verification failed!${no_color}"
        if [[ -n "$backup_file" ]]; then
            echo -e "${green}You can restore from backup: $backup_file${no_color}"
        fi
        return
    fi
    if echo "$acl_output" | grep -q "default:user:$target_user:rwx"; then
        echo -e "${green}Default ACL permissions verified${no_color}"
    else
        echo -e "${red}Default ACL permissions not found${no_color}"
        echo -e "${red}ACL setup verification failed!${no_color}"
        if [[ -n "$backup_file" ]]; then
            echo -e "${green}You can restore from backup: $backup_file${no_color}"
        fi
        return
    fi
    echo -e "${green}ACL setup completed successfully!${no_color}"

    echo -e "${green}Testing ACL permissions...${no_color}"
    # Test file creation
    local test_file="$KVM_IMAGES_DIR/acl_test_file"
    local test_dir="$KVM_IMAGES_DIR/acl_test_dir"
    # Create test file
    if touch "$test_file" 2>/dev/null; then
        echo -e "${green}Successfully created test file${no_color}"
        rm -f "$test_file"
    else
        echo -e "${red}Failed to create test file${no_color}"
        echo -e "${red}ACL permissions test failed!${no_color}"
        return 1
    fi
    # Create test directory
    if mkdir "$test_dir" 2>/dev/null; then
        echo -e "${green}Successfully created test directory${no_color}"
        rmdir "$test_dir"
    else
        echo -e "${red}Failed to create test directory${no_color}"
        echo -e "${red}ACL permissions test failed!${no_color}"
        return 1
    fi
    echo -e "${green}ACL permissions test passed!${no_color}"

    echo -e "${green}Final ACL permissions for $KVM_IMAGES_DIR:${no_color}"
    echo "========================================"
    sudo getfacl "$KVM_IMAGES_DIR" 2>/dev/null || {
        echo -e "${red}Failed to read final ACL permissions${no_color}"
        return
    }

}

echo -e "${green}Target directory: $KVM_IMAGES_DIR${no_color}"
echo -e "${green}Target user: $target_user${no_color}"

kvm_acl_setup || true

echo -e "${green}KVM ACL setup completed${no_color}"
echo -e "${green}New files and directories should inherit proper permissions.${no_color}"
if [[ -n "$backup_file" ]]; then
    echo -e "${green}Backup file: $backup_file${no_color}"
fi

echo -e "${blue}==================================================\n==================================================${no_color}"

#TODO: Add AMD SEV Support
#TODO: Optimise Host with TuneD
#TODO: Use taskset to pin QEMU emulator thread

echo -e "${blue}==================================================\n==================================================${no_color}"

echo -e "${green}Setting up looking-glass for low latency video streaming${no_color}"
# Create the shared memory directory if it doesn't exist
sudo mkdir -p /dev/shm || true

# Add your user to the kvm group (if not already)
sudo usermod -a -G kvm $USER || true

# Create a udev rule for the shared memory device
#echo "SUBSYSTEM==\"kvmfr\", OWNER=\"$USER\", GROUP=\"kvm\", MODE=\"0660\"" | sudo tee /etc/udev/rules.d/99-looking-glass.rules > /dev/null || true
echo "SUBSYSTEM==\"kvmfr\", GROUP=\"kvm\", MODE=\"0660\", TAG+=\"uaccess\"" | sudo tee /etc/udev/rules.d/99-looking-glass.rules > /dev/null || true

# Reload udev rules
sudo udevadm control --reload-rules || true
sudo udevadm trigger || true

#Edit libvirt configuration:
LIBVIRT_CONF="/etc/libvirt/qemu.conf"
if grep -qE '^\s*#\s*user\s*=' "$LIBVIRT_CONF"; then
    echo -e "${green}Uncommenting user line and setting to $USER in $LIBVIRT_CONF${no_color}"
    sudo sed -i "s|^\s*#\s*user\s*=.*|user = \"$USER\"|" "$LIBVIRT_CONF" || true
elif grep -q 'user = ' "$LIBVIRT_CONF"; then
    echo -e "${green}Changing user in $LIBVIRT_CONF to $USER${no_color}"
    sudo sed -i "s|user = \".*\"|user = \"$USER\"|" "$LIBVIRT_CONF" || true
else
    echo -e "${green}Adding user = \"$USER\" to $LIBVIRT_CONF${no_color}"
    echo "user = \"$USER\"" | sudo tee -a "$LIBVIRT_CONF" > /dev/null
fi

if grep -qE '^\s*#\s*group\s*=' "$LIBVIRT_CONF"; then
    echo -e "${green}Uncommenting group line and setting to kvm in $LIBVIRT_CONF${no_color}"
    sudo sed -i "s|^\s*#\s*group\s*=.*|group = \"kvm\"|" "$LIBVIRT_CONF" || true
elif grep -q 'group = ' "$LIBVIRT_CONF"; then
    echo -e "${green}Changing group in $LIBVIRT_CONF to kvm${no_color}"
    sudo sed -i "s|group = \".*\"|group = \"kvm\"|" "$LIBVIRT_CONF" || true
else
    echo -e "${green}Adding group = \"kvm\" to $LIBVIRT_CONF${no_color}"
    echo "group = \"kvm\"" | sudo tee -a "$LIBVIRT_CONF" > /dev/null
fi

echo -e "${green}Restarting libvirtd service to apply changes...${no_color}"
sudo systemctl restart libvirtd || true

echo -e "${green}Make sure to add the following line to your VM XML configuration:
<shmem name='looking-glass'>
  <model type='ivshmem-plain'/>
  <size unit='M'>128</size>
</shmem>${no_color}"
echo -e "${green}You can also use the following command to check if the shared memory device is created:${no_color}"
echo -e "${green}ls -l /dev/shm/looking-glass*${no_color}"

echo -e "${green}Creating desktop entries for Looking Glass Client to run in fullscreen${no_color}"
sudo mkdir -p ~/.local/share/applications/ || true
sudo tee ~/.local/share/applications/looking-glass-fullscreen.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Looking Glass Client (Fullscreen)
Comment=View KVM guest desktop in fullscreen
Exec=looking-glass-client -F
Icon=looking-glass-client
Terminal=false
Type=Application
Categories=Utility;System;
EOF
sudo chmod +x ~/.local/share/applications/looking-glass-fullscreen.desktop

echo -e "${green}Setting up looking-glass completed${no_color}"

echo -e "${blue}==================================================\n==================================================${no_color}"

echo -e "${green}adding user to necessary groups...${no_color}"

sudo usermod -aG video $USER || true
sudo usermod -aG audio $USER || true
sudo usermod -aG input $USER || true

echo -e "${blue}==================================================\n==================================================${no_color}"

echo -e "${green}Cloning and setting up configuration files${no_color}"

if [ -d ~/swaytemp ]; then
    sudo rm -rf ~/swaytemp
fi
if ! git clone --depth 1 https://github.com/Qaddoumi/linconfig.git ~/swaytemp; then
    echo "Failed to clone repository" >&2
    exit 1
fi
sudo rm -rf ~/.config/sway ~/.config/waybar ~/.config/wofi ~/.config/kitty ~/.config/swaync \
    ~/.config/kanshi ~/.config/oh-my-posh ~/.config/fastfetch ~/.config/mimeapps.list ~/.local/share/applications/mimeapps.list \
    ~/.config/looking-glass ~/.config/gtk-3.0 ~/.config/gtk-4.0
sudo mkdir -p ~/.config && sudo cp -r ~/swaytemp/.config/* ~/.config/
sudo cp -f ~/swaytemp/.config/mimeapps.list ~/.local/share/applications/mimeapps.list
sudo rm -rf ~/swaytemp

echo -e "${green}Setting up permissions for configuration files${no_color}"
sudo chmod +x ~/.config/waybar/scripts/*.sh || true
sudo chmod +x ~/.config/sway/scripts/*.sh || true

sudo chown -R $USER:$USER ~/.config
sudo chown -R $USER:$USER ~/.local

# if ! grep -q 'export PATH="$PATH:$HOME/.local/bin"' ~/.bashrc; then
#     echo 'export PATH="$PATH:$HOME/.local/bin"' >> ~/.bashrc
# fi
if ! sudo grep -q "source ~/.config/oh-my-posh/gmay.omp.json" ~/.bashrc; then
    echo 'eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/gmay.omp.json)"' | sudo tee ~/.bashrc > /dev/null
fi

echo -e "${blue}==================================================\n==================================================${no_color}"

if [[ "$login_manager" == "ly" ]]; then
    echo -e "${green}Installing and configuring ly (a lightweight display manager)${no_color}"

    sudo pacman -S --needed --noconfirm cmatrix
    sudo pacman -S --needed --noconfirm ly
    sudo systemctl disable display-manager.service || true
    sudo systemctl enable ly.service || true
    # Edit the configuration file /etc/ly/config.ini to use matrix for animation
    sudo sed -i 's/^animation = .*/animation = matrix/' /etc/ly/config.ini || true
elif [[ "$login_manager" == "sddm" ]]; then
    echo -e "${green}Installing and configuring SDDM (Simple Desktop Display Manager)${no_color}"

    sudo pacman -S --needed --noconfirm sddm || true
    sudo systemctl disable display-manager.service || true
    sudo systemctl enable sddm.service || true
    echo -e "${green}Setting up my Hacker theme for SDDM${no_color}"
    bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/sddm-hacker-theme/main/install.sh) || echo -e "${red}Failed to install the theme${no_color}"
else
    echo -e "${red}Unsupported login manager: $login_manager${no_color}"
fi

echo -e "${blue}==================================================\n==================================================${no_color}"

echo ""
echo -e "${green}******************* Sway with my configuration Installation Script Completed *******************${no_color}"
echo ""
echo -e "${yellow}REBOOT REQUIRED - Please reboot your system now!${no_color}"
echo -e "${blue}==================================================\n==================================================${no_color}"
