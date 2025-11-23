#!/usr/bin/env bash

set -e # Exit on error

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
no_color='\033[0m' # reset the color to default

# makepkg.conf optimization
# checks and updates makepkg.conf for better performance

backup_file() {
    local file="$1"
    if sudo test -f "$file"; then
        sudo cp "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${green}Backed up $file${no_color}"
    else
        echo -e "${yellow}File $file does not exist, skipping backup${no_color}"
    fi
}

# Yay Configuration Optimizer
# Optimizes yay settings for better performance and usability

CONFIG_FILE="$HOME/.config/yay/config.json"
CONFIG_DIR="$(dirname "$CONFIG_FILE")"

echo -e "${blue}=== Yay Configuration Optimizer ===${no_color}\n"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Function to display current config
show_current_config() {
    echo -e "${cyan}Current yay configuration:${no_color}"
    echo "─────────────────────────────────────"
    
    if [ -f "$CONFIG_FILE" ]; then
        yay -P -g 2>/dev/null || echo "Could not read config"
    else
        echo -e "${yellow}No config file found - using defaults${no_color}"
    fi
    echo ""
}

# Function to check a setting
check_setting() {
    local setting=$1
    local expected=$2
    local description=$3
    
    current=$(yay -P -g 2>/dev/null | grep "^$setting" | awk '{print $2}')
    
    if [ "$current" = "$expected" ]; then
        echo -e "${green}✓${no_color} $description: ${green}$current${no_color}"
        return 0
    else
        echo -e "${yellow}⚠${no_color} $description: ${yellow}$current${no_color} (recommended: ${green}$expected${no_color})"
        return 1
    fi
}

show_current_config

echo -e "${blue}Checking recommended settings:${no_color}"
echo "─────────────────────────────────────"

needs_changes=0

# Check important settings
check_setting "bottomup" "false" "Top-down search (faster)" || ((needs_changes++))
check_setting "cleanafter" "true" "Auto-clean build files" || ((needs_changes++))
check_setting "batchinstall" "true" "Batch install packages" || ((needs_changes++))
check_setting "sudoloop" "true" "Keep sudo active" || ((needs_changes++))
check_setting "provides" "true" "Search package providers" || ((needs_changes++))
check_setting "removemake" "ask" "Remove make dependencies" || ((needs_changes++))
check_setting "devel" "false" "Check devel updates" || ((needs_changes++))

echo ""

if [ $needs_changes -eq 0 ]; then
    echo -e "${green}All recommended settings are already configured!${no_color}"
    exit 0
fi

# Explain what each setting does
echo -e "${cyan}What these optimizations do:${no_color}\n"
echo -e "${blue}bottomup: false${no_color} - Shows repo packages first (faster, preferred for most users)"
echo -e "${blue}cleanafter: true${no_color} - Automatically removes build files after installation (saves disk space)"
echo -e "${blue}batchinstall: true${no_color} - Builds all packages first, then installs together (faster, safer)"
echo -e "${blue}sudoloop: true${no_color} - Keeps sudo active during long builds (no password re-prompts)"
echo -e "${blue}provides: true${no_color} - Shows packages that provide dependencies (better resolution)"
echo -e "${blue}removemake: ask${no_color} - Asks before removing make dependencies (gives you control)"
echo -e "${blue}devel: false${no_color} - Skips checking -git packages every time (much faster updates)"
echo ""

backup_file "$CONFIG_FILE"

echo -e "\n${blue}Applying optimizations...${no_color}"

# Apply settings one by one
yay --save --bottomup=false && echo -e "${green}✓${no_color} Top-down search enabled"
yay --save --cleanafter && echo -e "${green}✓${no_color} Auto-clean enabled"
yay --save --batchinstall && echo -e "${green}✓${no_color} Batch install enabled"
yay --save --sudoloop && echo -e "${green}✓${no_color} Sudo loop enabled"
yay --save --provides && echo -e "${green}✓${no_color} Provides search enabled"
yay --save --removemake=ask && echo -e "${green}✓${no_color} Remove make dependencies set to ask"
yay --save --nodevel && echo -e "${green}✓${no_color} Devel updates disabled (use 'yay -Syu --devel' when needed)"

echo -e "\n${green}═══════════════════════════════════════${no_color}"
echo -e "${green}Optimizations applied successfully!${no_color}"
echo -e "${green}═══════════════════════════════════════${no_color}"

echo -e "\n${cyan}Additional tips:${no_color}"
echo -e "• Use ${blue}yay -Syu --devel${no_color} to check -git packages when needed"
echo -e "• Use ${blue}yay -Yc${no_color} to clean unneeded dependencies"
echo -e "• Use ${blue}yay -Ps${no_color} to see installation stats"
echo -e "• Use ${blue}yay --aur${no_color} to search only AUR packages"
echo ""

echo -e "\n${cyan}Performance tip:${no_color} If downloads are still slow,"
echo -e "it's usually because of slow upstream servers (GitHub, GitLab, etc.)"
echo -e "Consider using ${blue}-bin${no_color} packages when available for faster installation."