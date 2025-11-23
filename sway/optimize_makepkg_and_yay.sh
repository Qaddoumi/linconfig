#!/usr/bin/env bash

set -e # Exit on error

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
no_color='\033[0m' # reset the color to default

# Common backup function
backup_file() {
    local file="$1"
    if sudo test -f "$file"; then
        sudo cp "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${green}Backed up $file${no_color}"
    else
        echo -e "${yellow}File $file does not exist, skipping backup${no_color}"
    fi
}

echo -e "${blue}=== Arch Build System Optimizer ===${no_color}\n"
echo -e "This will optimize both ${cyan}makepkg${no_color} (compilation) and ${cyan}yay${no_color} (AUR helper) settings."

# ==============================================================================
# Part 1: makepkg.conf Optimization
# ==============================================================================

optimize_makepkg() {
    echo -e "\n${blue}>>> Optimizing makepkg.conf (Compilation Settings)${no_color}"
    echo "──────────────────────────────────────────────────"

    local MAKEPKG_CONF="/etc/makepkg.conf"

    # Check if makepkg.conf exists
    if [ ! -f "$MAKEPKG_CONF" ]; then
        echo -e "${red}Error: $MAKEPKG_CONF not found${no_color}"
        return 1
    fi

    # Install required packages first
    echo -e "\n${blue}Checking for required compression tools...${no_color}"
    local missing_packages=()
    for pkg in pigz pbzip2 xz zstd; do
        if ! command -v $pkg &> /dev/null; then
            missing_packages+=($pkg)
        fi
    done

    if [ ${#missing_packages[@]} -ne 0 ]; then
        echo -e "${yellow}Installing missing packages: ${missing_packages[*]}${no_color}"
        sudo pacman -S --needed --noconfirm "${missing_packages[@]}" || true
    else
        echo -e "${green}All compression tools are installed.${no_color}"
    fi

    # Create backup
    echo -e "\n${blue}Creating backup of makepkg.conf...${no_color}"
    backup_file "$MAKEPKG_CONF"

    echo -e "\n${blue}Applying makepkg optimizations...${no_color}"

    # Function to update or add setting
    update_makepkg_setting() {
        local pattern=$1
        local replacement=$2
        local description=$3
        
        if grep -q "^${pattern%%=*}=" "$MAKEPKG_CONF"; then
            # Setting exists and is enabled, check if it matches
            if grep -q "^${replacement}$" "$MAKEPKG_CONF"; then
                 echo -e "${green}✓${no_color} $description: ${green}Already optimized${no_color}"
            else
                 sudo sed -i "s|^${pattern%%=*}=.*|$replacement|" "$MAKEPKG_CONF"
                 echo -e "${green}✓${no_color} Updated: $description"
            fi
        elif grep -q "^#${pattern%%=*}=" "$MAKEPKG_CONF"; then
            # Setting exists but is commented out
            sudo sed -i "s|^#\?${pattern%%=*}=.*|$replacement|" "$MAKEPKG_CONF"
            echo -e "${green}✓${no_color} Uncommented & Updated: $description"
        else
            # Setting doesn't exist, add it
            echo "$replacement" | sudo tee -a "$MAKEPKG_CONF" > /dev/null
            echo -e "${green}✓${no_color} Added: $description"
        fi
    }

    update_makepkg_setting "MAKEFLAGS=" "MAKEFLAGS=\"-j\$(nproc)\"" "Parallel compilation"
    update_makepkg_setting "COMPRESSGZ=" "COMPRESSGZ=(pigz -c -f -n)" "Parallel gzip"
    update_makepkg_setting "COMPRESSBZ2=" "COMPRESSBZ2=(pbzip2 -c -f)" "Parallel bzip2"
    update_makepkg_setting "COMPRESSXZ=" "COMPRESSXZ=(xz -c -z - --threads=0)" "Parallel xz"
    update_makepkg_setting "COMPRESSZST=" "COMPRESSZST=(zstd -c -z -q - --threads=0)" "Parallel zstd"
}

# ==============================================================================
# Part 2: Yay Configuration Optimization
# ==============================================================================

optimize_yay() {
    echo -e "\n${blue}>>> Optimizing Yay Configuration${no_color}"
    echo "──────────────────────────────────────────────────"

    local CONFIG_FILE="$HOME/.config/yay/config.json"
    local CONFIG_DIR="$(dirname "$CONFIG_FILE")"

    # Create config directory if it doesn't exist
    mkdir -p "$CONFIG_DIR"

    # Generate default config if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${yellow}Config file not found. Generating default configuration...${no_color}"
        yay --save > /dev/null 2>&1 || true
    fi

    # Function to check a setting
    check_yay_setting() {
        local setting=$1
        local expected=$2
        local description=$3
        
        local current
        # Try to get from running yay config
        current=$(yay -P -g 2>/dev/null | grep "\"$setting\":" | awk -F': ' '{print $2}' | tr -d ',')
        
        # If empty, try reading from config file directly
        if [ -z "$current" ] && [ -f "$CONFIG_FILE" ]; then
            current=$(grep "\"$setting\":" "$CONFIG_FILE" | awk -F': ' '{print $2}' | tr -d ',')
        fi

        # If still empty, assume it's not set (unknown)
        if [ -z "$current" ]; then
            current="unknown"
        fi
        
        if [ "$current" = "$expected" ]; then
            echo -e "${green}✓${no_color} $description: ${green}$current${no_color}"
            return 0
        else
            echo -e "${yellow}⚠${no_color} $description: ${yellow}$current${no_color} (recommended: ${green}$expected${no_color})"
            return 1
        fi
    }

    local needs_changes=0

    # Check important settings
    check_yay_setting "bottomup" "false" "Top-down search (faster)" || ((needs_changes++))
    check_yay_setting "cleanafter" "true" "Auto-clean build files" || ((needs_changes++))
    check_yay_setting "batchinstall" "true" "Batch install packages" || ((needs_changes++))
    check_yay_setting "sudoloop" "true" "Keep sudo active" || ((needs_changes++))
    # check_yay_setting "devel" "false" "Check devel updates" || ((needs_changes++))
    # check_yay_setting "removemake" "ask" "Remove make dependencies" || ((needs_changes++))
    check_yay_setting "provides" "true" "Search package providers" || ((needs_changes++))

    if [ $needs_changes -eq 0 ]; then
        echo -e "${green}All yay settings are already optimized!${no_color}"
    else
        echo -e "\n${cyan}Planned optimizations:${no_color}"
        echo -e "• ${blue}bottomup: false${no_color} (Shows repo packages first)"
        echo -e "• ${blue}cleanafter: true${no_color} (Saves disk space)"
        echo -e "• ${blue}batchinstall: true${no_color} (Faster/safer installation)"
        echo -e "• ${blue}sudoloop: true${no_color} (Prevents sudo timeouts)"
        # echo -e "• ${blue}devel: false${no_color} (Faster updates, skip git checks)"
        # echo -e "• ${blue}removemake: ask${no_color} (Remove make dependencies)"
        echo -e "• ${blue}provides: true${no_color} (Search package providers)"

        # Backup
        echo -e "\n${blue}Creating backup of yay config...${no_color}"
        backup_file "$CONFIG_FILE"

        echo -e "\n${blue}Applying yay optimizations...${no_color}"
        
        # Apply settings
        yay --save --bottomup=false && echo -e "${green}✓${no_color} Top-down search enabled"
        yay --save --cleanafter && echo -e "${green}✓${no_color} Auto-clean enabled"
        yay --save --batchinstall && echo -e "${green}✓${no_color} Batch install enabled"
        yay --save --sudoloop && echo -e "${green}✓${no_color} Sudo loop enabled"
        # yay --save --nodevel && echo -e "${green}✓${no_color} Devel updates disabled"
        # echo -e "• Use ${blue}yay -Syu --devel${no_color} to update -git packages when needed"
        # yay --save --removemake=ask && echo -e "${green}✓${no_color} Remove make dependencies set to ask"
        yay --save --provides && echo -e "${green}✓${no_color} Provides search enabled"
    fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

optimize_makepkg
optimize_yay

echo -e "\n${green}══════════════════════════════════════════════════════════════${no_color}"
echo -e "${green}Build System Optimization Completed!${no_color}"
echo -e "${green}══════════════════════════════════════════════════════════════${no_color}"
echo -e "\n${cyan}Summary of improvements:${no_color}"
echo -e "1. ${blue}Compilation${no_color}: Uses all CPU cores ($(( $(nproc) )) threads)"
echo -e "2. ${blue}Compression${no_color}: Uses multi-threaded tools (pigz, pbzip2, etc.)"
echo -e "3. ${blue}Workflow${no_color}: Batch installation, auto-cleaning, and sudo persistence"
