#!/usr/bin/env bash

set -e # Exit on error

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
bold="\e[1m"
no_color='\033[0m' # reset the color to default


# to get a list of installed packages, you can use:
# pacman -Qqe
# or to get a list of all installed packages with their installation time and dependencies:
# grep "installed" /var/log/pacman.log

# # Check if running as root
# if [[ $EUID -eq 0 ]]; then
#    echo -e "${red}This script should not be run as root. Please run as a regular user with sudo privileges.${no_color}"
#    exit 1
# fi

backup_file() {
    local file="$1"
    if sudo test -f "$file"; then
        sudo cp -an "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${green}Backed up $file${no_color}"
    else
        echo -e "${yellow}File $file does not exist, skipping backup${no_color}"
    fi
}

cd ~ || echo -e "${red}Failed to change directory to home${no_color}"

echo -e "${green}\n\n ******************* Packages Installation Script ******************* ${no_color}"


# Parse named arguments
is_vm=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --is-vm)
            is_vm="$2"
            shift 2
            ;;
        *)
            echo -e "${red}Unknown argument: $1${no_color}"
            exit 1
            ;;
    esac
done

echo -e "${green}Username to be used      : $USER${no_color}"

if [ -n "$is_vm" ]; then
    echo -e "${green}is_vm manually set to: $is_vm${no_color}"
else
    echo -e "${green}is_vm not set, detecting system type...${no_color}"
    # the -v flag is used to get the type of virtualization ignoring containers/chroots.
    systemType="$(systemd-detect-virt -v 2>/dev/null || echo "none")"
    if [[ "$systemType" == "none" ]]; then
        echo -e "${green}Not running in a VM${no_color}"
        is_vm=false
    else
        echo -e "${green}Running in a VM: systemtype = $systemType${no_color}"
        is_vm=true
    fi
fi

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Updating databases and upgrading packages...${no_color}"
sudo pacman -Syy --noconfirm || echo -e "${yellow}Failed to update package databases${no_color}"
sudo pacman -Syu --noconfirm || echo -e "${yellow}Failed to upgrade packages${no_color}"

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Installing yay (Yet Another Yaourt)${no_color}"

sudo pacman -S --needed --noconfirm git base-devel go || true
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm jq || true # JSON processor
echo -e "${blue}--------------------------------------------------\n${no_color}"

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

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"
# Yay Configuration Optimizer ...
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/quickshell/pkgs/optimize_makepkg_and_yay.sh)

# echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

# echo -e "${green}Setting up aria2 to speed up downlaod for pacman and yay...${no_color}"

# sudo pacman -S --needed --noconfirm aria2

# # Backup pacman.conf
# echo -e "${green}Backing up /etc/pacman.conf...${no_color}"
# backup_file "/etc/pacman.conf"

# # Configure pacman to use aria2
# echo -e "${green}Configuring pacman to use aria2...${no_color}"

# # Remove any existing uncommented XferCommand line
# sudo sed -i '/^[[:space:]]*XferCommand[[:space:]]*=/d' /etc/pacman.conf

# # Add XferCommand after the [options] section
# sudo sed -i '/^\[options\]/a XferCommand = /usr/bin/aria2c --allow-overwrite=true --continue=true --file-allocation=none --log-level=error --max-tries=2 --max-connection-per-server=2 --max-file-not-found=5 --min-split-size=5M --no-conf --remote-time=true --summary-interval=60 --timeout=5 --dir=/ --out %o %u' /etc/pacman.conf

# echo -e "${green}Setup complete! pacman (and yay) will now use aria2 for faster downloads.${no_color}"
# echo -e "${green}Your original pacman.conf has been backed up to /etc/pacman.conf.backup.${no_color}"

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Installing Chaotic-AUR repository...${no_color}"
if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    echo -e "${green}Chaotic-AUR repository not found. Proceeding with installation...${no_color}"
    # install and enable Chaotic-AUR
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || true
    sudo pacman-key --lsign-key 3056513887B78AEB || true
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' || true
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || true
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf > /dev/null || true
    sudo pacman -Syu --noconfirm || true
    # Print message indicating Chaotic-AUR has been installed and enabled
    echo -e "${green}Chaotic-AUR repository installed and enabled${no_color}"
else
    echo -e "${green}Chaotic-AUR repository already exists. Skipping installation.${no_color}"
fi

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Installing Hyprland...${no_color}"
echo ""
sudo pacman -S --needed --noconfirm hyprland # Hyprland window manager
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm hypridle # Idle management for hyprland
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm hyprlock # Screen locker for hyprland

echo -e "${green}Installing Sway...${no_color}"
echo ""
sudo pacman -S --needed --noconfirm sway # Sway window manager
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm swayidle # Idle management for sway
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm swaylock # Screen locker for sway
# echo -e "${blue}--------------------------------------------------\n${no_color}"
#sudo pacman -S --needed --noconfirm autotiling # Auto-tiling for sway


echo -e "${green}Installing awesome an X11 window manager...${no_color}"
echo ""

sudo pacman -S --needed --noconfirm awesome # X11 window manager
# the next lines is needed to setup variables like $XDG_CURRENT_DESKTOP and $XDG_SESSION_DESKTOP by sddm
if grep -q "DesktopNames" "/usr/share/xsessions/awesome.desktop"; then
    echo "Existing 'DesktopNames' found. Updating/Uncommenting to 'awesome'..."
    sed -i "s/^#*\s*DesktopNames=.*/DesktopNames=awesome/" "/usr/share/xsessions/awesome.desktop" || echo -e "${red}Failed to update DesktopNames${no_color}"
else
    echo "'DesktopNames' not found. Appending to /usr/share/xsessions/awesome.desktop."
    echo "DesktopNames=awesome" | sudo tee -a "/usr/share/xsessions/awesome.desktop" || echo -e "${red}Failed to append DesktopNames${no_color}"
fi

echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm xorg-xinit xorg-server # X11 display server and initialization
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm picom # Compositor for X11 (used for animation, transparency and blur)
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm xscreensaver # Screen saver for X11

echo -e "\n\n"

echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm nwg-look # GTK theme configuration GUI
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm kvantum kvantum-qt5 # Qt theme configuration GUI
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm gnome-keyring # Authentication agent for privileged operations
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm quickshell # a shell for both wayland and x11
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm waybar # Status bar for wayland
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm wofi # Application launcher for wayland
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm rofi # Application launcher for X11
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm dex # Autostart manager (i dont't know why, but it make spice runs without issues in vm)
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm swaync # Notification daemon and system tray for wayland
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm dunst # Notification daemon for X11
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm libappindicator-gtk3 libayatana-appindicator # AppIndicator support for swaync tray
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm kitty # Terminal emulator
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm tmux # Terminal multiplexer
echo -e "${green}TMUX explanation tree${no_color}"
echo -e "${green}\nYour Terminal (Kitty/Ghostty/etc)${no_color}"
echo -e "${green}    └── tmux session${no_color}"
echo -e "${green}          ├── Window 1 (like a tab)${no_color}"
echo -e "${green}          │     ├── Pane 1 (split screen)${no_color}"
echo -e "${green}          │     └── Pane 2${no_color}"
echo -e "${green}          ├── Window 2${no_color}"
echo -e "${green}          └── Window 3\n${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm xorg-server-xwayland # XWayland for compatibility with X11 applications
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm xdg-desktop-portal xdg-desktop-portal-wlr # Portal for Wayland
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm xdg-user-dirs xdg-desktop-portal-gtk # User directories and portal
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm pavucontrol # PulseAudio volume control
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm htop # System monitor
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm wget # Download utility
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm hyprpaper # Background setting utility for hyprland
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm swaybg # Background setting utility for sway
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm feh # Wallpaper setter for X11
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm thunar # File manager
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm thunar-media-tags-plugin # Plugin for editing audio/video metadata tags for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm thunar-archive-plugin # Plugin for creating/extracting archives (zip, tar, etc.) for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm thunar-volman # Automatic management of removable drives and media for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm tumbler # Thumbnail service for generating image previews for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm ffmpegthumbnailer # Video thumbnails for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm poppler-glib # PDF thumbnails for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm libgsf # Office document thumbnails for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm udisks2 gvfs gvfs-mtp # Required for thunar to handle external drives and MTP devices
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo systemctl enable udisks2.service || true
sudo systemctl start udisks2.service || true
sudo usermod -aG storage $USER || true
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm zenity # Dialogs from terminal,(used for thunar)
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm kanshi # Automatic Display manager for Wayland
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm nano # Text editor
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm neovim # Neovim text editor
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm brightnessctl # Brightness control
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm hyprpolkitagent # PolicyKit authentication agent (give sudo access to GUI apps)
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm mate-polkit # Authentication agent for privileged operations
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm s-tui # Terminal UI for monitoring CPU
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm gdu # Disk usage analyzer
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm bc # Arbitrary precision calculator language
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm fastfetch # Fast system information tool
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm less # Pager program for viewing text files
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm man-db man-pages # Manual pages and database
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm mpv # video player
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm celluloid # frontend for mpv video player
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm imv # image viewer
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm xarchiver # Lightweight archive manager
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm trash-cli # Command line trash management
sudo mkdir -p ~/.local/share/Trash/{files,info}
sudo chmod 700 ~/.local/share/Trash
sudo chown -R $USER:$USER ~/.local
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm libxml2 # XML parsing library
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm pv # progress bar in terminal
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm network-manager-applet # Network management applet
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm flameshot # Screenshot utility with annotation tools
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm grim # Screenshot tool
sudo mkdir -p ~/Screenshots || true
sudo chown -R $USER:$USER ~/Screenshots || true
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm slurp # Selection tool for Wayland
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm wl-clipboard # Clipboard management for Wayland
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm copyq # Clipboard history manager with tray
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm xclip # Clipboard management used by X11 (used to sync clipboard between vms and host)

echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm flatpak # Flatpak package manager
# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null 2>&1 || true

echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm cpupower # CPU frequency scaling utility ==> change powersave to performance mode.
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm tlp # TLP for power management
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm lm_sensors # Hardware monitoring
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm thermald # Intel thermal daemon
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm dmidecode # Desktop Management Interface table related utilities
echo -e "${blue}--------------------------------------------------\n${no_color}"

# yay -S --needed --noconfirm 12to11-git || echo -e "${red}Failed to install 12to11-git${no_color}" # run wayland apps on xorg
# echo -e "${blue}--------------------------------------------------\n${no_color}"
yay -S --needed --noconfirm google-chrome || echo -e "${red}Failed to install google-chrome${no_color}" # Web browser
echo -e "${blue}--------------------------------------------------\n${no_color}"
yay -S --needed --noconfirm antigravity-bin || echo -e "${red}Failed to install antigravity-bin${no_color}" # AI IDE
echo -e "${blue}--------------------------------------------------\n${no_color}"
yay -S --needed --noconfirm brave-bin || echo -e "${red}Failed to install brave-bin${no_color}" # Brave browser
echo -e "${blue}--------------------------------------------------\n${no_color}"
yay -S --needed --noconfirm visual-studio-code-bin || echo -e "${red}Failed to install visual-studio-code-bin${no_color}" # Visual Studio Code
echo -e "${blue}--------------------------------------------------\n${no_color}"
yay -S --needed --noconfirm powershell-bin || echo -e "${red}Failed to install powershell-bin${no_color}" # PowerShell
echo -e "${blue}--------------------------------------------------\n${no_color}"
yay -S --needed --noconfirm oh-my-posh || echo -e "${red}Failed to install oh-my-posh${no_color}" # Theme engine for terminal
echo -e "${blue}--------------------------------------------------\n${no_color}"
if [ "$is_vm" = true ]; then
    echo -e "${yellow}Running in a VM, skipping looking-glass installation${no_color}"
else
    yay -S --needed --noconfirm looking-glass || echo -e "${red}Failed to install looking-glass${no_color}" # Low latency video streaming tool
fi


echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Setting up environment variable for Electron apps so they lunch in wayland mode${no_color}"
ENV_FILE="/etc/environment"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${green}Creating $ENV_FILE${no_color}"
    sudo touch "$ENV_FILE"
fi

if grep -q "export PATH" "$ENV_FILE"; then
    echo -e "${green}PATHs already set in $ENV_FILE${no_color}"
else
    echo -e "${green}Adding PATHs to $ENV_FILE${no_color}"
    echo "" | sudo tee -a "$ENV_FILE" > /dev/null || true
    echo "export PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin:/var/lib/flatpak/exports/bin:/.local/share/flatpak/exports/bin" | sudo tee -a "$ENV_FILE" > /dev/null || true
fi

if grep -q "ELECTRON_OZONE_PLATFORM_HINT" "$ENV_FILE"; then
    echo "${green}ELECTRON_OZONE_PLATFORM_HINT already exists in $ENV_FILE${no_color}"
else
    echo -e "${green}Adding ELECTRON_OZONE_PLATFORM_HINT to $ENV_FILE...${no_color}"
    echo "" | sudo tee -a "$ENV_FILE" > /dev/null || true
    echo "ELECTRON_OZONE_PLATFORM_HINT=wayland" | sudo tee -a "$ENV_FILE" > /dev/null || true
fi
echo -e "${yellow}You'll need to restart your session for this to take effect system-wide${no_color}"

# add this to fix an issue with gtk apps not working
#Gtk-CRITICAL **: 10:43:17.835: gtk_native_get_surface: assertion 'GTK_IS_NATIVE (self)' failed
#Gdk-Message: 10:43:18.010: Error 22 (Invalid argument) dispatching to Wayland display.
if grep -q "GSK_RENDERER" "$ENV_FILE"; then
    echo -e "${green}GSK_RENDERER already exists in $ENV_FILE${no_color}"
else
    echo -e "${green}Adding GSK_RENDERER to $ENV_FILE...${no_color}"
    echo "" | sudo tee -a "$ENV_FILE" > /dev/null || true
    echo "GSK_RENDERER=ngl" | sudo tee -a "$ENV_FILE" > /dev/null || true
fi

# Check if running in vm
if [ "$is_vm" = true ]; then
    echo -e "${green}Running in a VM:${no_color}"
    echo -e "${green}Setting the cursor rendering${no_color}"

    if grep -q "WLR_NO_HARDWARE_CURSORS" "$ENV_FILE"; then 
        echo -e "${green}Cursor is already set in $ENV_FILE${no_color}"
    else
        echo -e "${green}Adding cursor to "$ENV_FILE"...${no_color}"
        echo "" | sudo tee -a "$ENV_FILE" > /dev/null || true
        echo "WLR_NO_HARDWARE_CURSORS=1" | sudo tee -a "$ENV_FILE" > /dev/null || true
    fi
else
    echo -e "${green}Not running in a VM, no need to set the cursor${no_color}"
fi

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

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
    echo -e "${green}Adding XDG_RUNTIME_DIR to .bashrc${no_color}"
    echo "" >> "$BASHRC_FILE"
    echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)' >> "$BASHRC_FILE"
    echo -e "${green}Successfully added to .bashrc${no_color}"
fi

if ! grep -q '^gitpush()' "$BASHRC_FILE"; then
    echo -e "${green}Adding gitpush and gitbranch functions to $BASHRC_FILE${no_color}"
    cat >> "$BASHRC_FILE" <<'EOF'

gitpush() {
    echo -e "\n\033[0;32mAdding changes\033[0m"
    git add . || true
    echo -e "\n\033[0;32mCommitting changes\033[0m"
    git commit --allow-empty-message -m "" || true
    echo -e "\n\033[0;32mPushing changes\033[0m"
    git push || true
}

gitbranch () {
    echo -e "\n\033[0;32mCreating and switching to branch \033[0;34m'$1'\033[0m"
    git switch -c "$1" && \
    echo -e "\033[0;32mSuccessfully switched to branch \033[0;34m'$1'\n\033[0m" || \
    echo -e "\033[0;31mFailed to switch to branch \033[0;34m'$1'\n\033[0m"
    echo -e "\n\033[0;32mPushing changes\033[0m"
    git push -u origin "$1" || echo -e "\033[0;31mFailed to push changes\n\033[0m"
}

EOF
else
    echo -e "${yellow}gitpush and gitbranch functions already present in $BASHRC_FILE, skipping${no_color}"
fi

if grep -q "fastfetch" "$BASHRC_FILE"; then
    echo -e "${green}fastfetch is already set in .bashrc${no_color}"
else
    echo -e "${green}Adding fastfetch to .bashrc${no_color}"
    cat >> "$BASHRC_FILE" <<'EOF'

if [ -n "$TMUX" ]; then
    fastfetch
fi

EOF
    echo -e "${green}Successfully added fastfetch in tmux to .bashrc${no_color}"
fi

source ~/.bashrc || true

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Installing fonts${no_color}"

sudo pacman -S --needed --noconfirm font-manager # a gui to manage fonts, and review them
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm ttf-jetbrains-mono-nerd # Nerd font for JetBrains Mono
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm noto-fonts noto-fonts-emoji # Noto fonts (English + Arabic) and Emoji font
echo -e "${blue}--------------------------------------------------\n${no_color}"

echo -e "${green}Creating fontconfig directory...${no_color}"
mkdir -p ~/.config/fontconfig > /dev/null || true

FONTCONF=~/.config/fontconfig/fonts.conf
echo -e "${green}Writing fonts.conf...${no_color}"
cat > "$FONTCONF" <<'EOF'
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <!-- Defaults -->
  <alias>
    <family>serif</family>
    <prefer>
      <family>Noto Serif</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>
  <alias>
    <family>sans</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>JetBrainsMono Nerd Font Mono</family>
      <family>Noto Sans Mono</family>
    </prefer>
  </alias>
  <!-- Arial -->
  <alias>
    <family>Arial</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>
</fontconfig>
EOF
echo -e "${green}fonts.conf written to $FONTCONF${no_color}"

echo -e "${green}Refreshing font cache${no_color}"
fc-cache -fv

echo -e "\n${green}✅ Setup complete!${no_color}"
echo -e "${green}Test with:\n  fc-match 'Noto Sans Arabic'\n  fc-match 'JetBrainsMono Nerd Font Mono'\n${no_color}"

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Setting Dark theme for GTK applications${no_color}"
sudo pacman -S --needed --noconfirm materia-gtk-theme # Material Design GTK theme
echo -e "${blue}--------------------------------------------------\n${no_color}"
#sudo pacman -S --needed --noconfirm papirus-icon-theme # Icon theme
# echo -e "${blue}--------------------------------------------------\n${no_color}"
# sudo pacman -S --needed --noconfirm capitaine-cursors # Cursor theme
# echo -e "${blue}--------------------------------------------------\n${no_color}"

echo -e "${green}Showing available themes${no_color}"
ls /usr/share/themes/
# echo -e "${green}Available icon and cursor themes:${no_color}"
# ls /usr/share/icons/

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

if [ "$is_vm" = true ]; then
    echo -e "${green}Skipping Performance Mode Setup in VM environment${no_color}"
else
    echo -e "${green}Setting up Performance Mode for physical machine${no_color}"
    # bash <(curl -s https://raw.githubusercontent.com/Qaddoumi/linconfig/quickshell/pkgs/performance.sh)
fi

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Installing and configuring Qemu/Libvirt for virtualization${no_color}"
sudo pacman -S --needed --noconfirm qemu-full # Full QEMU package with all features
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm qemu-img # QEMU disk image utility: provides create, convert, modify, and snapshot, offline disk images
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm libvirt # Libvirt for managing virtualization: provides a unified interface for managing virtual machines
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm virt-install # Tool for installing virtual machines: CLI tool to create guest VMs
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm virt-manager # GUI for managing virtual machines: GUI tool to create and manage guest VMs
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm virt-viewer # Viewer for virtual machines
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm edk2-ovmf # UEFI firmware for virtual machines
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm dnsmasq # DNS and DHCP server: lightweight DNS forwarder and DHCP server
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm swtpm # Software TPM emulator
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm guestfs-tools # Tools for managing guest file systems
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm libosinfo # Library for managing OS information
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm tuned # system tuning service for linux allows us to optimise the hypervisor for speed.
echo -e "${blue}--------------------------------------------------\n${no_color}"
#sudo pacman -S --needed --noconfirm spice-vdagent # SPICE agent for guest OS
# echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm bridge-utils # Utilities for managing network bridges
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm linux-headers # for vfio modules
echo -e "${blue}--------------------------------------------------\n${no_color}"
sudo pacman -S --needed --noconfirm linux-zen-headers # for zen kernel vfio modules
echo -e "${blue}--------------------------------------------------\n${no_color}"

echo -e "${green}Enabling and starting libvirtd service${no_color}"
sudo systemctl enable libvirtd || true
sudo systemctl start libvirtd || true
sudo systemctl enable virtlogd.socket || true
# sleep 2  # Give libvirtd a moment to fully start

echo -e "${green}Adding current user to libvirt group${no_color}"
sudo usermod -aG libvirt $(whoami) || true
echo -e "${green}Adding libvirt-qemu user to input group${no_color}"
sudo usermod -aG input libvirt-qemu || true

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Setting up virt-manager one-time network configuration script${no_color}"

sudo mkdir -p ~/.local/share/applications/ || true
sudo chown -R $USER:$USER ~/.local/share/applications/ || true
echo -e "${green}Creating ~/.config/virt-manager-oneshot.sh${no_color}"
sudo tee ~/.config/virt-manager-oneshot.sh > /dev/null << 'EOF'
#!/usr/bin/env bash

LOG_FILE="$HOME/virt-network-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

notify-send "Virt-Manager" "Setting up libvirt network..."
echo "Starting network setup at $(date)..."

echo "Destroying default network"
virsh -c qemu:///system net-destroy default || true
virsh -c qemu:///system net-undefine default || true

echo "Define network default"

HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
HOST_SUBNET=$(echo "$HOST_IP" | cut -d. -f1-3)
LIBVIRT_SUBNET="192.168.122"

if [ "$HOST_SUBNET" == "192.168.122" ]; then
    LIBVIRT_SUBNET="192.168.150"
    echo "Host is on 192.168.122.x, switching libvirt to $LIBVIRT_SUBNET.x"
fi

cat <<NETXML | virsh -c qemu:///system net-define /dev/stdin
<network>
  <name>default</name>
  <bridge name="virbr0"/>
  <forward/>
  <ip address="$LIBVIRT_SUBNET.1" netmask="255.255.255.0">
    <dhcp>
      <range start="$LIBVIRT_SUBNET.2" end="$LIBVIRT_SUBNET.254"/>
    </dhcp>
  </ip>
</network>
NETXML

echo "Attempting to start default network..."
virsh -c qemu:///system net-start default || echo "Failed to start default network (might be already running)"
virsh -c qemu:///system net-autostart default || echo "Failed to autostart default network"

notify-send "Virt-Manager" "Network setup finished"
echo "Setup finished at $(date)"

# This deletes the script file itself so it never runs again.
rm -- "$0"
EOF

sudo chmod +x ~/.config/virt-manager-oneshot.sh || true

echo -e "${green}Creating /usr/local/bin/virt-manager wrapper script${no_color}"
sudo tee /usr/local/bin/virt-manager > /dev/null << 'EOF'
#!/usr/bin/env bash

# Define where the one-time payload lives
PAYLOAD="$HOME/.config/virt-manager-oneshot.sh"

# Function to wait for libvirt socket
wait_for_libvirt() {
    local max_attempts=30
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if [ -S "/var/run/libvirt/libvirt-sock" ]; then
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    return 1
}

# Start a background subshell to handle the network setup
(
    # Wait for libvirt socket to be ready first
    if wait_for_libvirt; then
        # Give it a tiny bit more time to be fully responsive
        sleep 2
        
        # Check if the payload still exists and run it
        if [ -f "$PAYLOAD" ] && [ -x "$PAYLOAD" ]; then
            "$PAYLOAD"
        fi
    fi
) &

# Disown the background job
disown

# Wait for libvirt socket before starting virt-manager GUI
# This prevents the "Connecting..." hang
wait_for_libvirt

# Launch the REAL virt-manager
exec /usr/bin/virt-manager "$@"
EOF

sudo chmod +x /usr/local/bin/virt-manager || true

echo -e "${green}Creating desktop entry for virt-manager wrapper${no_color}"
cp /usr/share/applications/virt-manager.desktop ~/.local/share/applications/

echo -e "${green}Modifying desktop entry to use wrapper script${no_color}"
sudo sed -i 's|^Exec=virt-manager|Exec=/usr/local/bin/virt-manager|g' ~/.local/share/applications/virt-manager.desktop

echo -e "${green}Setting up virt-manager one-time network configuration completed${no_color}"

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

#bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/quickshell/pkgs/hugepages.sh)
# echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

if [ "$is_vm" = true ]; then
    echo -e "${green}System is detected to be running in a VM, skipping GPU passthrough setup${no_color}"
else
    echo -e "${green}System is not detected to be running in a VM, proceeding with GPU passthrough setup${no_color}"
    bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/quickshell/pkgs/gpu-passthrough.sh)
fi

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Installing QEMU Guest Agents and enabling their services${no_color}"
sudo pacman -S --needed --noconfirm qemu-guest-agent spice-vdagent # QEMU Guest Agent and SPICE agent for better VM integration

sudo systemctl enable qemu-guest-agent > /dev/null || true
sudo systemctl start qemu-guest-agent > /dev/null || true

sudo systemctl enable spice-vdagentd > /dev/null || true
sudo systemctl start spice-vdagentd > /dev/null || true

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

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

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

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

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

#TODO: Add AMD SEV Support
#TODO: Optimise Host with TuneD
#TODO: Use taskset to pin QEMU emulator thread

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

if [ "$is_vm" = true ]; then
    echo -e "${green}System is detected to be running in a VM, skipping looking-glass-client setup${no_color}"
else
    echo -e "${green}System is not detected to be running in a VM, proceeding with looking-glass setup${no_color}"

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
    sudo chown -R $USER:$USER ~/.local/share/applications/

    echo -e "${green}Setting up looking-glass completed${no_color}"
fi

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}adding user to necessary groups...${no_color}"

sudo usermod -aG video $USER || true
sudo usermod -aG audio $USER || true
sudo usermod -aG input $USER || true

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Cloning and setting up configuration files${no_color}"

touch ~/installconfig.sh
curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/quickshell/pkgs/installconfig.sh > ~/installconfig.sh
chmod +x ~/installconfig.sh

~/installconfig.sh --update-dwm false

echo -e "${green}Adding Neovim (tmux) to applications menu${no_color}"
echo -e "${green}So i can open files in it with thunar${no_color}"
cat >> ~/.local/share/applications/nvim.desktop <<'NVIM_EOF'
[Desktop Entry]
Name=Neovim (tmux)
GenericName=Text Editor
Comment=Edit text files in tmux
Exec=kitty tmux new-session nvim %F
Terminal=false
Type=Application
Icon=nvim
Categories=Utility;TextEditor;
MimeType=text/plain;text/markdown;
NVIM_EOF

update-desktop-database ~/.local/share/applications/ || true

cd ~


echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Installing and configuring SDDM (Simple Desktop Display Manager)${no_color}"

sudo pacman -S --needed --noconfirm sddm || true
sudo systemctl disable display-manager.service || true
sudo systemctl enable sddm.service || true
echo -e "${green}Setting up my Hacker theme for SDDM${no_color}"
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/sddm-hacker-theme/main/install.sh) || { echo -e "${red}Failed to install the theme${no_color}"; true ;}

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo ""
echo -e "${green}******************* My Linux Configuration Script Completed *******************${no_color}"
echo ""
echo -e "${yellow}REBOOT REQUIRED - Please reboot your system now!${no_color}"
echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"
echo ""