#!/usr/bin/env bash

set -e # Exit on error

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
no_color='\033[0m' # reset the color to default

# makepkg.conf optimization script
# This script checks and optionally updates makepkg.conf for better performance

backup_file() {
    local file="$1"
    if sudo test -f "$file"; then
        sudo cp "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${green}Backed up $file${no_color}"
    else
        echo -e "${yellow}File $file does not exist, skipping backup${no_color}"
    fi
}

MAKEPKG_CONF="/etc/makepkg.conf"
backup_file "$MAKEPKG_CONF"


echo -e "${blue}=== makepkg.conf Optimization Checker ===${no_color}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${red}Error: This script must be run as root (use sudo)${no_color}"
    exit 1
fi

# Check if makepkg.conf exists
if [ ! -f "$MAKEPKG_CONF" ]; then
    echo -e "${red}Error: $MAKEPKG_CONF not found${no_color}"
    exit 1
fi

# Function to check if a setting exists and is enabled
check_setting() {
    local setting=$1
    local description=$2
    
    if grep -q "^${setting}" "$MAKEPKG_CONF"; then
        echo -e "${green}✓${no_color} $description: ${green}ENABLED${no_color}"
        return 0
    elif grep -q "^#${setting}" "$MAKEPKG_CONF"; then
        echo -e "${yellow}⚠${no_color} $description: ${yellow}COMMENTED OUT${no_color}"
        return 1
    else
        echo -e "${red}✗${no_color} $description: ${red}NOT FOUND${no_color}"
        return 2
    fi
}

echo "Current configuration status:"
echo "─────────────────────────────"

# Check MAKEFLAGS
check_setting "MAKEFLAGS=" "Parallel compilation (MAKEFLAGS)"
makeflags_status=$?

# Check compression settings
check_setting "COMPRESSGZ=(pigz" "Parallel gzip compression"
gz_status=$?

check_setting "COMPRESSBZ2=(pbzip2" "Parallel bzip2 compression"
bz2_status=$?

check_setting "COMPRESSXZ=(xz.*--threads" "Parallel xz compression"
xz_status=$?

check_setting "COMPRESSZST=(zstd.*--threads" "Parallel zstd compression"
zst_status=$?

echo ""

# Determine if changes are needed
needs_changes=false
if [ $makeflags_status -ne 0 ] || [ $gz_status -ne 0 ] || [ $bz2_status -ne 0 ] || [ $xz_status -ne 0 ] || [ $zst_status -ne 0 ]; then
    needs_changes=true
fi

if [ "$needs_changes" = false ]; then
    echo -e "${green}All optimizations are already enabled!${no_color}"
    exit 0
fi

# Ask if user wants to apply changes
echo -e "${yellow}Would you like to apply the optimizations? (y/n)${no_color}"
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "No changes made."
    exit 0
fi

# Check for required packages
echo -e "\n${blue}Checking for required compression tools...${no_color}"
missing_packages=()

for pkg in pigz pbzip2 xz zstd; do
    if ! command -v $pkg &> /dev/null; then
        echo -e "${yellow}⚠${no_color} $pkg not found"
        missing_packages+=($pkg)
    else
        echo -e "${green}✓${no_color} $pkg installed"
    fi
done

if [ ${#missing_packages[@]} -ne 0 ]; then
    echo -e "\n${yellow}Missing packages: ${missing_packages[*]}${no_color}"
    echo -e "${yellow}Install them with: sudo pacman -S ${missing_packages[*]}${no_color}"
    echo -e "${yellow}Continue anyway? (y/n)${no_color}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Create backup
echo -e "\n${blue}Creating backup...${no_color}"
cp "$MAKEPKG_CONF" "$BACKUP_FILE"
echo -e "${green}Backup created: $BACKUP_FILE${no_color}"

# Apply optimizations
echo -e "\n${blue}Applying optimizations...${no_color}"

# Function to update or add setting
update_setting() {
    local pattern=$1
    local replacement=$2
    local description=$3
    
    if grep -q "^${pattern%%=*}=" "$MAKEPKG_CONF" || grep -q "^#${pattern%%=*}=" "$MAKEPKG_CONF"; then
        # Setting exists, update it
        sed -i "s|^#\?${pattern%%=*}=.*|$replacement|" "$MAKEPKG_CONF"
        echo -e "${green}✓${no_color} Updated: $description"
    else
        # Setting doesn't exist, add it
        echo "$replacement" >> "$MAKEPKG_CONF"
        echo -e "${green}✓${no_color} Added: $description"
    fi
}

# Update MAKEFLAGS
update_setting "MAKEFLAGS=" "MAKEFLAGS=\"-j\$(nproc)\"" "Parallel compilation"

# Update compression settings
update_setting "COMPRESSGZ=" "COMPRESSGZ=(pigz -c -f -n)" "Parallel gzip"
update_setting "COMPRESSBZ2=" "COMPRESSBZ2=(pbzip2 -c -f)" "Parallel bzip2"
update_setting "COMPRESSXZ=" "COMPRESSXZ=(xz -c -z - --threads=0)" "Parallel xz"
update_setting "COMPRESSZST=" "COMPRESSZST=(zstd -c -z -q - --threads=0)" "Parallel zstd"

echo -e "\n${green}═══════════════════════════════════════${no_color}"
echo -e "${green}Optimizations applied successfully!${no_color}"
echo -e "${green}═══════════════════════════════════════${no_color}"
echo -e "\nYour makepkg.conf has been optimized for:"
echo -e "  • Parallel compilation using all CPU cores"
echo -e "  • Faster multi-threaded compression"
echo -e "\nBackup saved at: $BACKUP_FILE"
echo -e "\nTo revert changes, run:"
echo -e "  sudo cp $BACKUP_FILE $MAKEPKG_CONF"