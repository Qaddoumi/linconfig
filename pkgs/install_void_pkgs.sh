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
# xbps-query -l
# or to get a list of manually installed packages:
# xbps-query -m

# Find what installed a package (dependencies)
# xbps-query -x <package_name>
# or reverse dependencies:
# xbps-query -X <package_name>

# To find what other packages <package_name> installed (its dependencies), use:
# xbps-query -Rx <package_name>

# # Check if running as root
# if [[ $EUID -eq 0 ]]; then
#	echo -e "${red}This script should not be run as root. Please run as a regular user with root privileges.${no_color}"
#	exit 1
# fi

for tool in sudo doas pkexec; do
	if command -v "${tool}" >/dev/null 2>&1; then
		ESCALATION_TOOL="${tool}"
		echo -e "${cyan}Using ${tool} for privilege escalation${no_color}"
		which "${tool}"
		break
	fi
done
if [ -z "${ESCALATION_TOOL}" ]; then
	echo -e "${red}Error: This script requires root privileges. Please install sudo, doas, or pkexec.${no_color}"
	exit 1
fi

backup_file() {
	local file="$1"
	if "${ESCALATION_TOOL}" test -f "$file"; then
		"${ESCALATION_TOOL}" cp -an "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
		echo -e "${green}Backed up $file${no_color}"
	else
		echo -e "${yellow}File $file does not exist, skipping backup${no_color}"
	fi
}

cd ~ || echo -e "${red}Failed to change directory to home${no_color}"

echo -e "${green}\n\n ******************* VOID Packages Installation Script ******************* ${no_color}"


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

echo -e "${green}Username to be used	  : $USER${no_color}"

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Updating databases and upgrading packages...${no_color}"
"${ESCALATION_TOOL}" xbps-install -Syu virt-what || echo -e "${yellow}Failed to update and upgrade packages${no_color}"

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

if [ -n "$is_vm" ]; then
	echo -e "${green}is_vm manually set to: $is_vm${no_color}"
else
	echo -e "${green}is_vm not set, detecting system type...${no_color}"
	if command -v virt-what &>/dev/null; then
		systemType="$(${ESCALATION_TOOL} virt-what 2>/dev/null | head -1)"
	else
		systemType=""
	fi
	if [[ -z "$systemType" ]]; then
		echo -e "${green}Not running in a VM${no_color}"
		is_vm=false
	else
		echo -e "${green}Running in a VM: systemtype = $systemType${no_color}"
		is_vm=true
	fi
fi

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Installing base development tools${no_color}"

"${ESCALATION_TOOL}" xbps-install -y git base-devel || true
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y jq || true # JSON processor
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y curl wget || true # Download utilities

# Note: Void Linux doesn't have AUR helpers like yay.
# Packages not in void-packages repo need to be built from source or obtained elsewhere.
echo -e "${yellow}Note: Void Linux uses xbps. AUR packages are not available.${no_color}"
echo -e "${yellow}Some packages may need to be built from source or installed via flatpak.${no_color}"

# echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

# echo -e "${green}Setting up aria2 to speed up downloads for xbps...${no_color}"

# "${ESCALATION_TOOL}" xbps-install -y aria2

# # Note: xbps doesn't have a built-in mechanism for external download managers
# # You would need to use xdeb or similar tools

# echo -e "${green}aria2 installed. Note: xbps doesn't natively support external download managers.${no_color}"

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Installing window managers and related packages...${no_color}"
echo ""

# Hyprland is NOT in official Void repos. It requires adding a third-party repository.
# See: https://github.com/Makrennel/hyprland-void for installation instructions.
echo -e "${green}Installing Hyprland...${no_color}"
echo -e "${yellow}Hyprland is NOT in official Void repos. Adding third-party repository...${no_color}"

# Add hyprland-void repository
if ! grep -q "hyprland-void" /etc/xbps.d/*.conf 2>/dev/null; then
	echo "repository=https://raw.githubusercontent.com/Makrennel/hyprland-void/repository-x86_64-glibc" | "${ESCALATION_TOOL}" tee /etc/xbps.d/hyprland-void.conf > /dev/null
	"${ESCALATION_TOOL}" xbps-install -Sy -y || true
fi
"${ESCALATION_TOOL}" xbps-install -y hyprland || echo -e "${red}Failed to install hyprland. You may need to manually add the repo.${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"
# uwsm is not in void repos, may need to build from source
# "${ESCALATION_TOOL}" xbps-install -y uwsm # A standalone Wayland session manager
echo -e "${yellow}uwsm is not available in Void repos. Consider building from source if needed.${no_color}"

if [ -f "/usr/share/wayland-sessions/hyprland.desktop" ]; then
	echo -e "${green}Hiding hyprland from session menu...${no_color}"
	if grep -q "^NoDisplay=" "/usr/share/wayland-sessions/hyprland.desktop"; then
		"${ESCALATION_TOOL}" sed -i 's/^NoDisplay=.*/NoDisplay=true/' "/usr/share/wayland-sessions/hyprland.desktop"
	else
		echo "NoDisplay=true" | "${ESCALATION_TOOL}" tee -a "/usr/share/wayland-sessions/hyprland.desktop" > /dev/null
	fi
fi

# if [ ! -f /usr/share/wayland-sessions/hyprland-uwsm.desktop ]; then
# 	echo -e "${green}Creating hyprland-uwsm.desktop...${no_color}"
# 	"${ESCALATION_TOOL}" tee /usr/share/wayland-sessions/hyprland-uwsm.desktop > /dev/null << 'EOF'
# [Desktop Entry]
# Name=Hyprland (uwsm-managed)
# Comment=An intelligent dynamic tiling Wayland compositor
# Exec=uwsm start -e -D Hyprland hyprland.desktop
# TryExec=uwsm
# Icon=hyprland
# DesktopNames=Hyprland
# Type=Application
# Categories=WindowManager;DisplayManager;
# EOF
# fi

echo -e "${blue}--------------------------------------------------\n${no_color}"
echo -e "${green}Installing Sway...${no_color}"
echo ""
"${ESCALATION_TOOL}" xbps-install -y sway # Sway window manager

echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y swayidle # Idle management for sway/hyprland
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y swaylock # Screen locker for sway/hyprland
# echo -e "${blue}--------------------------------------------------\n${no_color}"
#"${ESCALATION_TOOL}" xbps-install -y autotiling # Auto-tiling for sway

# echo -e "${blue}--------------------------------------------------\n${no_color}"
# echo -e "${green}Installing awesome an X11 window manager...${no_color}"
# echo ""

# "${ESCALATION_TOOL}" xbps-install -y awesome # X11 window manager
# # the next lines is needed to setup variables like $XDG_CURRENT_DESKTOP and $XDG_SESSION_DESKTOP by sddm
# if grep -q "DesktopNames" "/usr/share/xsessions/awesome.desktop"; then
# 	echo "Existing 'DesktopNames' found. Updating/Uncommenting to 'awesome'..."
# 	"${ESCALATION_TOOL}" sed -i "s/^#*\s*DesktopNames=.*/DesktopNames=awesome/" "/usr/share/xsessions/awesome.desktop" || echo -e "${red}Failed to update DesktopNames${no_color}"
# else
# 	echo "'DesktopNames' not found. Appending to /usr/share/xsessions/awesome.desktop."
# 	echo "DesktopNames=awesome" | "${ESCALATION_TOOL}" tee -a "/usr/share/xsessions/awesome.desktop" || echo -e "${red}Failed to append DesktopNames${no_color}"
# fi

echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y xinit xorg-server dbus # X11 display server, initialization and dbus
echo -e "${blue}Enabling dbus (message bus)\n${no_color}"
"$ESCALATION_TOOL" ln -sf /etc/sv/dbus "/etc/runit/runsvdir/default/dbus" || echo -e "${yellow}Failed to enable dbus${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y libX11-devel libXft-devel libXinerama-devel imlib2-devel # dwm/dmenu headers
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y xrandr # Xrandr for X11 (used for screen resolution, and monitors configuration)
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y picom # Compositor for X11 (used for animation, transparency and blur, "it helps with screen tearing")
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y xscreensaver # Screen saver for X11
echo -e "${green}Setting Auth for xscreensaver...${no_color}"
if grep -q "password include system-auth" "/etc/pam.d/xscreensaver" 2>/dev/null; then
	echo -e "${green}Auth already set in /etc/pam.d/xscreensaver${no_color}"
else
	echo -e "${green}Adding Auth's to /etc/pam.d/xscreensaver${no_color}"
	echo "" | "${ESCALATION_TOOL}" tee -a "/etc/pam.d/xscreensaver" > /dev/null || true
	echo -e "auth	   include	  system-auth\naccount	include	  system-auth\npassword   include	  system-auth\nsession	include	  system-auth" | "${ESCALATION_TOOL}" tee -a "/etc/pam.d/xscreensaver" > /dev/null || true
fi
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y xprop xdotool # Dependencies for x11_workspaces.sh in quickshell
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y xset # xset for X11 (needed for powersaving script)
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y wmctrl # Control EWMH compliant window manager from command line (x11)

echo -e "\n\n"

echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y gnome-keyring # Authentication agent for privileged operations
echo -e "${blue}--------------------------------------------------\n${no_color}"
# nwg-displays is not in void repos
# "${ESCALATION_TOOL}" xbps-install -y nwg-displays # Display configuration GUI for hyprland and sway
echo -e "${yellow}nwg-displays is not available in Void repos. Consider building from source.${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"
# quickshell is not in void repos
# "${ESCALATION_TOOL}" xbps-install -y quickshell # a shell for both wayland and x11
echo -e "${yellow}quickshell is not available in Void repos. Consider building from source or using flatpak.${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y rofi rofi-emoji # Application launcher
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y playerctl # Media control used in quickshell
echo -e "${blue}--------------------------------------------------\n${no_color}"
# "${ESCALATION_TOOL}" xbps-install -y dex # Autostart manager (Autostart apps in /etc/xdg/autostart/ or ~/.config/autostart/)
# echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y dunst # Notification daemon for X11 and wayland
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y libayatana-appindicator # AppIndicator support for tray
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y kitty # Terminal emulator
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y tmux # Terminal multiplexer
echo -e "${green}TMUX explanation tree${no_color}"
echo -e "${green}\nYour Terminal (Kitty/Ghostty/etc)${no_color}"
echo -e "${green}	└── tmux session${no_color}"
echo -e "${green}		  ├── Window 1 (like a tab)${no_color}"
echo -e "${green}		  │	 ├── Pane 1 (split screen)${no_color}"
echo -e "${green}		  │	 └── Pane 2${no_color}"
echo -e "${green}		  ├── Window 2${no_color}"
echo -e "${green}		  └── Window 3\n${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y xorg-server-xwayland # XWayland for compatibility with X11 applications
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y xdg-desktop-portal xdg-user-dirs xdg-desktop-portal-gtk # XDG Portal for Wayland and X11
echo -e "${blue}--------------------------------------------------\n${no_color}"
# xdg-desktop-portal-hyprland comes from the hyprland-void repo if it was added
"${ESCALATION_TOOL}" xbps-install -y xdg-desktop-portal-hyprland || echo -e "${yellow}xdg-desktop-portal-hyprland not found, install from hyprland-void repo${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y xdg-desktop-portal-wlr # Portal for other Waylands
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y pavucontrol # PulseAudio volume control
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y bluez bluez-alsa # Bluetooth support
"${ESCALATION_TOOL}" xbps-install -y bluetui || echo -e "${yellow}bluetui not found, installing blueman instead${no_color}" # Bluetooth TUI
"${ESCALATION_TOOL}" ln -sf /etc/sv/bluetoothd /etc/runit/runsvdir/default/bluetoothd || echo -e "${yellow}Failed to enable bluetoothd${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y btop # System monitor TUI
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y nvtop # GPU monitor TUI
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y gnome-system-monitor # System monitor GUI
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y swaybg # Background setting utility for sway and hyprland
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y feh # Wallpaper setter for X11
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y Thunar # File manager
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y thunar-media-tags-plugin # Plugin for editing audio/video metadata tags for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y thunar-archive-plugin # Plugin for creating/extracting archives (zip, tar, etc.) for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y thunar-volman # Automatic management of removable drives and media for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y tumbler # Thumbnail service for generating image previews for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y ffmpegthumbnailer # Video thumbnails for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y poppler-glib # PDF thumbnails for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y libgsf # Office document thumbnails for thunar
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y udisks2 gvfs gvfs-mtp # Required for thunar to handle external drives and MTP devices
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" ln -sf /etc/sv/udisks2 /etc/runit/runsvdir/default/udisks2 || echo -e "${yellow}Failed to enable udisks2${no_color}"
"${ESCALATION_TOOL}" usermod -aG storage $USER || true
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y zenity # Dialogs from terminal,(used for thunar)
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y nano # Text editor
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y neovim # Neovim text editor
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y gnome-calculator # Calculator
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y brightnessctl # Brightness control
echo -e "${blue}--------------------------------------------------\n${no_color}"
# hyprpolkitagent is not in void repos
# "${ESCALATION_TOOL}" xbps-install -y hyprpolkitagent # PolicyKit authentication agent (give root access to GUI apps)
echo -e "${yellow}hyprpolkitagent is not available in Void repos. Using polkit-gnome instead.${no_color}"
"${ESCALATION_TOOL}" xbps-install -y polkit-gnome # PolicyKit authentication agent
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y mate-polkit # Authentication agent for privileged operations (used for x11)
echo -e "${blue}--------------------------------------------------\n${no_color}"
# "${ESCALATION_TOOL}" xbps-install -y s-tui # Terminal UI for monitoring CPU
# echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y gdu # Disk usage analyzer
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y bc # Arbitrary precision calculator language
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y fastfetch # Fast system information tool
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y less # Pager program for viewing text files
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y man-db man-pages # Manual pages and database
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y mpv # video player
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y celluloid # frontend for mpv video player
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y imv # image viewer
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y xarchiver # Lightweight archive manager
# Optional dependencies for xarchiver
#	 arj: ARJ support
#	 binutils: deb support [installed]
#	 bzip2: bzip2 support [installed]
#	 cpio: RPM support
#	 gzip: gzip support [installed]
#	 lha: LHA support
#	 lrzip: lrzip support
#	 lz4: LZ4 support [installed]
#	 lzip: lzip support
#	 lzop: LZOP support
#	 p7zip: 7z support
#	 tar: tar support [installed]
#	 unarj: ARJ support
#	 unrar: RAR support
#	 unzip: ZIP support
#	 xdg-utils: recognize more file types to open [installed]
#	 xz: xz support [installed]
#	 zip: ZIP support
#	 zstd: zstd support [installed]
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y unzip # Unzip utility
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y trash-cli # Command line trash management
"${ESCALATION_TOOL}" mkdir -p ~/.local/share/Trash/{files,info}
"${ESCALATION_TOOL}" chmod 700 ~/.local/share/Trash
"${ESCALATION_TOOL}" chown -R $USER:$USER ~/.local
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y libxml2 # XML parsing library
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y pv # progress bar in terminal
echo -e "${blue}--------------------------------------------------\n${no_color}"
# "${ESCALATION_TOOL}" xbps-install -y network-manager-applet # Network management applet
# echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y flameshot # Screenshot utility with annotation tools
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y grim # Screenshot tool
"${ESCALATION_TOOL}" mkdir -p ~/Pictures || true
"${ESCALATION_TOOL}" chown -R $USER:$USER ~/Pictures || true
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y slurp # Selection tool for Wayland
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y wl-clipboard # Clipboard management for Wayland
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y CopyQ # Clipboard history manager with tray
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y xclip # Clipboard management used by X11 (used to sync clipboard between vms and host)

echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y flatpak # Flatpak package manager
# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo > /dev/null 2>&1 || true
echo -e "${blue}--------------------------------------------------\n${no_color}"
flatpak install -y --user flathub org.dupot.easyflatpak || echo -e "${red}Failed to install easyflatpak\n${no_color}" # Flatpak application manager (GUI store)

echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y fuse fuse3 # require for AppImages pkgs

echo -e "${blue}--------------------------------------------------\n${no_color}"
# cpupower equivalent in void
"${ESCALATION_TOOL}" xbps-install -y cpufrequtils # CPU frequency scaling utility ==> change powersave to performance mode.
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y tlp # TLP for power management
"${ESCALATION_TOOL}" ln -sf /etc/sv/tlp /etc/runit/runsvdir/default/tlp || echo -e "${yellow}Failed to enable tlp${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y lm_sensors # Hardware monitoring
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y thermald # Intel thermal daemon
"${ESCALATION_TOOL}" ln -sf /etc/sv/thermald /etc/runit/runsvdir/default/thermald || echo -e "${yellow}Failed to enable thermald${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y dmidecode # Desktop Management Interface table related utilities
echo -e "${blue}--------------------------------------------------\n${no_color}"

"${ESCALATION_TOOL}" xbps-install -y python3 # Python
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y python3-pip # Python package manager
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y python3-pipx # Python package manager
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y python3-virtualenv # Python virtual environment
echo -e "${blue}--------------------------------------------------\n${no_color}"

"${ESCALATION_TOOL}" xbps-install -y obs # live streaming and recording
echo -e "${blue}--------------------------------------------------\n${no_color}"


# Packages that need flatpak or manual installation (not in void repos)
# yay -S --needed --noconfirm 12to11-git || echo -e "${red}Failed to install 12to11-git${no_color}" # run wayland apps on xorg
# echo -e "${blue}--------------------------------------------------\n${no_color}"

echo -e "${green}Installing Google Chrome via flatpak...${no_color}"
flatpak install -y --user flathub com.google.Chrome || echo -e "${red}Failed to install google-chrome via flatpak${no_color}" # Web browser
echo -e "${blue}--------------------------------------------------\n${no_color}"

# antigravity is not available - skip or use alternative
echo -e "${yellow}antigravity (AI IDE) is not available in Void repos. Consider using flatpak or downloading directly.${no_color}"
# flatpak install -y --user flathub ... || echo -e "${red}Failed to install antigravity${no_color}" # AI IDE
echo -e "${blue}--------------------------------------------------\n${no_color}"

echo -e "${green}Installing Brave Browser via flatpak...${no_color}"
flatpak install -y --user flathub com.brave.Browser || echo -e "${red}Failed to install brave via flatpak${no_color}" # Brave browser
echo -e "${blue}--------------------------------------------------\n${no_color}"

echo -e "${green}Installing Visual Studio Code via flatpak...${no_color}"
flatpak install -y --user flathub com.visualstudio.code || echo -e "${red}Failed to install vscode via flatpak${no_color}" # Visual Studio Code
# Install extensions
flatpak run com.visualstudio.code --install-extension Continue.continue || true # for local ai and agent in vscode
flatpak run com.visualstudio.code --install-extension sdras.night-owl || true # dark theme
flatpak run com.visualstudio.code --install-extension Gruntfuggly.todo-tree || true # todo tree
echo -e "${blue}--------------------------------------------------\n${no_color}"

# anythingllm is not in repos - skip
echo -e "${yellow}anythingllm is not available in Void repos. Download AppImage directly from their website.${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"

# PowerShell
echo -e "${yellow}PowerShell is not available in Void repos. Install manually from Microsoft.${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"

# oh-my-posh
echo -e "${green}Installing oh-my-posh...${no_color}"
curl -s https://ohmyposh.dev/install.sh | bash -s || echo -e "${red}Failed to install oh-my-posh${no_color}"

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

ENV_FILE="/etc/environment"
if [ ! -f "$ENV_FILE" ]; then
	echo -e "${green}Creating $ENV_FILE${no_color}"
	"${ESCALATION_TOOL}" touch "$ENV_FILE"
fi

if grep -q "PATH" "$ENV_FILE"; then
	echo -e "${green}PATHs already set in $ENV_FILE${no_color}"
else
	echo -e "${green}Adding PATHs to $ENV_FILE${no_color}"
	echo "" | "${ESCALATION_TOOL}" tee -a "$ENV_FILE" > /dev/null || true
	echo "PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin:/var/lib/flatpak/exports/bin:/.local/share/flatpak/exports/bin" | "${ESCALATION_TOOL}" tee -a "$ENV_FILE" > /dev/null || true
fi

echo -e "${green}Setting up environment variable for Electron apps so they lunch in wayland mode${no_color}"
if grep -q "ELECTRON_OZONE_PLATFORM_HINT" "$ENV_FILE"; then
	echo "${green}ELECTRON_OZONE_PLATFORM_HINT already exists in $ENV_FILE${no_color}"
else
	echo -e "${green}Adding ELECTRON_OZONE_PLATFORM_HINT to $ENV_FILE...${no_color}"
	echo "" | "${ESCALATION_TOOL}" tee -a "$ENV_FILE" > /dev/null || true
	echo "ELECTRON_OZONE_PLATFORM_HINT=wayland" | "${ESCALATION_TOOL}" tee -a "$ENV_FILE" > /dev/null || true
fi
echo -e "${yellow}You'll need to restart your session for this to take effect system-wide${no_color}"

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
	git add -A || true
	echo -e "\n\033[0;32mCommitting changes\033[0m"
	#git commit --allow-empty-message -m "" || true
	git commit -m "$*" || true
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

"${ESCALATION_TOOL}" xbps-install -y fontmanager # a gui to manage fonts, and review them
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y nerd-fonts-ttf || "${ESCALATION_TOOL}" xbps-install -y nerd-fonts # Nerd fonts (includes JetBrains Mono)
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y noto-fonts-ttf noto-fonts-emoji # Noto fonts (English + Arabic) and Emoji font
echo -e "${blue}--------------------------------------------------\n${no_color}"

echo -e "${green}Creating fontconfig directory...${no_color}"
mkdir -p ~/.config/fontconfig > /dev/null || true

FONTCONF=~/.config/fontconfig/fonts.conf
echo -e "${green}Writing fonts.conf...${no_color}"
cat <<EOF > "$FONTCONF"
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>

  <!-- 1. THE ARABIC FIX: Force high-quality Arabic when 'ar' text is detected -->
  <match target="pattern">
    <test name="lang" compare="contains">
      <string>ar</string>
    </test>
    <edit name="family" mode="prepend" binding="strong">
      <string>Noto Sans Arabic</string>
    </edit>
  </match>

  <!-- 2. SANS-SERIF: Noto Sans for Latin, fallback to Arabic if needed -->
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>

  <!-- 3. SERIF: Noto Serif for Latin, fallback to Arabic -->
  <alias>
    <family>serif</family>
    <prefer>
      <family>Noto Serif</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>

  <!-- 4. MONOSPACE: Your preferred coding font -->
  <alias>
    <family>monospace</family>
    <prefer>
      <family>JetBrainsMono Nerd Font Propo</family>
      <family>Noto Sans Mono</family>
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
"${ESCALATION_TOOL}" xbps-install -y nwg-look # GTK theme configuration GUI
echo -e "${blue}--------------------------------------------------\n${no_color}"
# materia-gtk-theme is not in void repos, use Adapta or build from source
# "${ESCALATION_TOOL}" xbps-install -y materia-gtk-theme # Material Design GTK theme
"${ESCALATION_TOOL}" xbps-install -y Adapta || echo -e "${yellow}Adapta theme installed as alternative to materia${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y papirus-icon-theme # Icon theme
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y breeze-icons # Icon theme (papirus does not have icons for some applications)
echo -e "${blue}--------------------------------------------------\n${no_color}"
# capitaine-cursors is not in void repos
# "${ESCALATION_TOOL}" xbps-install -y capitaine-cursors # Cursor theme
"${ESCALATION_TOOL}" xbps-install -y xcursor-themes || echo -e "${yellow}xcursor-themes installed as alternative to capitaine-cursors${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"

if grep -q "GTK_THEME" "$ENV_FILE"; then
	echo -e "${green}GTK_THEME already set in $ENV_FILE${no_color}"
else
	echo -e "${green}Adding GTK_THEME to $ENV_FILE${no_color}"
	echo "" | "${ESCALATION_TOOL}" tee -a "$ENV_FILE" > /dev/null || true
	echo "GTK_THEME=Adapta-Nokto" | "${ESCALATION_TOOL}" tee -a "$ENV_FILE" > /dev/null || true
fi

echo -e "${green}Showing available themes${no_color}"
ls /usr/share/themes/
echo -e "${green}Available icon and cursor themes:${no_color}"
ls /usr/share/icons/

## GTK Theming setup
# do not use gsettings set org.gnome.desktop.interface... as it does not work in chroot
# and dont use dbus-launch --exit-with-session gsettings... as it does not work in chroot too.

# Create the local schema overrides directory
"${ESCALATION_TOOL}" mkdir -p /usr/share/glib-2.0/schemas/

# Create the override file (sets defaults for ALL users)
cat <<EOF | "${ESCALATION_TOOL}" tee /usr/share/glib-2.0/schemas/99_ext_settings.gschema.override
[org.gnome.desktop.interface]
gtk-theme='Adapta-Nokto'
icon-theme='Papirus-Dark'
cursor-theme='DMZ-White'
color-scheme='prefer-dark'
enable-animations=false
EOF

# Compile the schemas so the system recognizes the new defaults
"${ESCALATION_TOOL}" glib-compile-schemas /usr/share/glib-2.0/schemas/

echo -e "${blue}--------------------------------------------------\n${no_color}"


echo -e "${green}Setting Dark theme for Qt applications${no_color}"
"${ESCALATION_TOOL}" xbps-install -y kvantum # Qt theme configuration GUI
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y qt5ct qt6ct # Qt theme configuration GUI
echo -e "${blue}--------------------------------------------------\n${no_color}"
# kvantum-theme-materia may not be in repos
# kvantum-theme-materia is not in void repos
# "${ESCALATION_TOOL}" xbps-install -y kvantum-theme-materia # Material Design Qt theme
echo -e "${yellow}kvantum-theme-materia is not available in Void repos. Configure kvantum manually.${no_color}"
echo -e "${blue}--------------------------------------------------\n${no_color}"

echo -e "${green}Setting Qt to use qt5ct which uses kvantum...${no_color}"
if grep -q "QT_QPA_PLATFORMTHEME" "$ENV_FILE"; then
	echo -e "${yellow}QT_QPA_PLATFORMTHEME already exists in $ENV_FILE, updating...${no_color}"
	"${ESCALATION_TOOL}" sed -i 's/^QT_QPA_PLATFORMTHEME=.*/QT_QPA_PLATFORMTHEME=qt5ct/' "$ENV_FILE"
else
	echo -e "${green}Adding QT_QPA_PLATFORMTHEME to $ENV_FILE...${no_color}"
	echo "" | "${ESCALATION_TOOL}" tee -a "$ENV_FILE" > /dev/null || true
	echo "QT_QPA_PLATFORMTHEME=qt5ct" | "${ESCALATION_TOOL}" tee -a "$ENV_FILE" > /dev/null || true
fi

echo -e "${green}Qt theming configured. Please log out and log back in for changes to take effect.${no_color}"


echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

if [ "$is_vm" = true ]; then
	echo -e "${green}Skipping Performance Mode Setup in VM environment${no_color}"
else
	echo -e "${green}Setting up Performance Mode for physical machine${no_color}"
	# bash <(curl -s https://raw.githubusercontent.com/Qaddoumi/linconfig/main/pkgs/performance.sh)
fi

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Installing and configuring Qemu/Libvirt for virtualization${no_color}"
"${ESCALATION_TOOL}" xbps-install -y qemu # QEMU package
echo -e "${blue}--------------------------------------------------\n${no_color}"
# qemu-img is included in qemu package on Void
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y libvirt # Libvirt for managing virtualization: provides a unified interface for managing virtual machines
echo -e "${blue}--------------------------------------------------\n${no_color}"
# "${ESCALATION_TOOL}" xbps-install -y virt-install # Tool for installing virtual machines: CLI tool to create guest VMs
# echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y virt-manager # GUI for managing virtual machines: GUI tool to create and manage guest VMs
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y virt-viewer # Viewer for virtual machines
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y edk2-ovmf # UEFI firmware for virtual machines
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y dnsmasq # DNS and DHCP server: lightweight DNS forwarder and DHCP server
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y swtpm # Software TPM emulator
echo -e "${blue}--------------------------------------------------\n${no_color}"
# "${ESCALATION_TOOL}" xbps-install -y guestfs-tools || echo -e "${yellow}guestfs-tools not found${no_color}" # Tools for managing guest file systems
# echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y libosinfo # Library for managing OS information
echo -e "${blue}--------------------------------------------------\n${no_color}"
#TODO: Optimise Host with TuneD , for now tlp is conflic with tuned, so we only can use one of them.
# "${ESCALATION_TOOL}" xbps-install -y tuned || true # system tuning service for linux allows us to optimise the hypervisor for speed.
# "${ESCALATION_TOOL}" ln -sf /etc/sv/tuned /etc/runit/runsvdir/default/tuned || echo -e "${yellow}Failed to enable tuned${no_color}"
# "${ESCALATION_TOOL}" tuned-adm profile virtual-host # or throughput-performance
# echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y bridge-utils # Utilities for managing network bridges
echo -e "${blue}--------------------------------------------------\n${no_color}"
"${ESCALATION_TOOL}" xbps-install -y linux-headers # for vfio modules
echo -e "${blue}--------------------------------------------------\n${no_color}"

echo -e "${green}Enabling and starting libvirtd service${no_color}"
"${ESCALATION_TOOL}" ln -sf /etc/sv/libvirtd /etc/runit/runsvdir/default/libvirtd || echo -e "${yellow}Failed to enable libvirtd${no_color}"
"${ESCALATION_TOOL}" ln -sf /etc/sv/virtlogd /etc/runit/runsvdir/default/virtlogd || echo -e "${yellow}Failed to enable virtlogd${no_color}"

echo -e "${green}Adding current user to libvirt group${no_color}"
"${ESCALATION_TOOL}" usermod -aG libvirt $(whoami) || true
echo -e "${green}Adding libvirt-qemu user to input group${no_color}"
"${ESCALATION_TOOL}" usermod -aG input libvirt-qemu || true

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Setting up virt-manager one-time network configuration script${no_color}"

"${ESCALATION_TOOL}" mkdir -p ~/.local/share/applications/ || true
"${ESCALATION_TOOL}" chown -R $USER:$USER ~/.local/share/applications/ || true
echo -e "${green}Creating ~/.config/virt-manager-oneshot.sh${no_color}"
"${ESCALATION_TOOL}" tee ~/.config/virt-manager-oneshot.sh > /dev/null << 'EOF'
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

"${ESCALATION_TOOL}" chmod +x ~/.config/virt-manager-oneshot.sh || true

echo -e "${green}Creating /usr/local/bin/virt-manager wrapper script${no_color}"
"${ESCALATION_TOOL}" tee /usr/local/bin/virt-manager > /dev/null << 'EOF'
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

"${ESCALATION_TOOL}" chmod +x /usr/local/bin/virt-manager || true

echo -e "${green}Creating desktop entry for virt-manager wrapper${no_color}"
cp /usr/share/applications/virt-manager.desktop ~/.local/share/applications/ 2>/dev/null || true

echo -e "${green}Modifying desktop entry to use wrapper script${no_color}"
"${ESCALATION_TOOL}" sed -i 's|^Exec=virt-manager|Exec=/usr/local/bin/virt-manager|g' ~/.local/share/applications/virt-manager.desktop 2>/dev/null || true

echo -e "${green}Setting up virt-manager one-time network configuration completed${no_color}"

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Setting up virt-manager default settings${no_color}"
"${ESCALATION_TOOL}" mkdir -p /usr/share/glib-2.0/schemas/ 
mkdir -p "/home/$USER/VM_Images" "/home/$USER/ISOs" "/home/$USER/Pictures/VM_Screenshots"
cat <<EOF | "${ESCALATION_TOOL}" tee /usr/share/glib-2.0/schemas/99_virt_manager_custom.gschema.override
[org.virt-manager.virt-manager]
system-tray=true
xmleditor-enabled=true
enable-libguestfs-vm-inspection=true

[org.virt-manager.virt-manager.paths]
# Note: Strings must be wrapped in single quotes
image-default='/home/$USER/VM_Images'
media-default='/home/$USER/ISOs'
screenshot-default='/home/$USER/Pictures/VM_Screenshots'
EOF
# Compile the schemas so the system recognizes the new defaults
"${ESCALATION_TOOL}" glib-compile-schemas /usr/share/glib-2.0/schemas/

echo -e "${green}Setting up virt-manager default settings completed${no_color}"
echo -e "${green}If changes did not apply, you need to remove ~/.config/dconf/user then apply the settings again${no_color}"

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

#bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/pkgs/hugepages.sh)
# echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

if [ "$is_vm" = true ]; then
	echo -e "${green}System is detected to be running in a VM, skipping GPU passthrough setup${no_color}"
else
	echo -e "${green}System is not detected to be running in a VM, proceeding with GPU passthrough setup${no_color}"
	bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/pkgs/gpu-passthrough.sh)
fi

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Installing QEMU Guest Agents and enabling their services${no_color}"
"${ESCALATION_TOOL}" xbps-install -y qemu-ga spice-vdagent # QEMU Guest Agent and SPICE agent for better VM integration

"${ESCALATION_TOOL}" ln -sf /etc/sv/qemu-guest-agent /etc/runit/runsvdir/default/qemu-guest-agent || echo -e "${yellow}Failed to enable qemu-guest-agent${no_color}"
"${ESCALATION_TOOL}" ln -sf /etc/sv/spice-vdagentd /etc/runit/runsvdir/default/spice-vdagentd || echo -e "${yellow}Failed to enable spice-vdagentd${no_color}"

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
		echo -e "${red}Please install KVM first: ${ESCALATION_TOOL} xbps-install qemu${no_color}"
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
		"${ESCALATION_TOOL}" modprobe "$kvm_module"
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
			"${ESCALATION_TOOL}" modprobe -r kvm_intel
			"${ESCALATION_TOOL}" modprobe kvm_intel nested=1
			;;
		"amd")
			"${ESCALATION_TOOL}" modprobe -r kvm_amd
			"${ESCALATION_TOOL}" modprobe kvm_amd nested=1
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
		echo "options $module_name nested=1" | "${ESCALATION_TOOL}" tee "$conf_file"
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
acl_backup_file="/tmp/kvm_acl_backup_$(date +%Y%m%d_%H%M%S).txt"

kvm_acl_setup() {

	echo -e "${green}Checking if ACL tools are installed...${no_color}"
	if ! command -v getfacl &> /dev/null; then
		echo -e "${red}getfacl command not found. ACL tools are not installed.${no_color}"
		echo -e "${green}Install ACL tools:${no_color}"
		echo -e "${green}  Void Linux: ${ESCALATION_TOOL} xbps-install acl-progs${no_color}"
		"${ESCALATION_TOOL}" xbps-install -y acl-progs || return
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
	if ! "${ESCALATION_TOOL}" getfacl "$KVM_IMAGES_DIR" &>/dev/null; then
		echo -e "${red}ACL is not supported on this filesystem${no_color}"
		echo -e "${green}Make sure the filesystem is mounted with ACL support${no_color}"
		echo -e "${green}For ext4: mount -o remount,acl /mount/point${no_color}"
		return
	fi
	echo -e "${green}Filesystem supports ACL${no_color}"

	echo -e "${green}Current ACL permissions for $KVM_IMAGES_DIR:${no_color}"
	echo "----------------------------------------"
	"${ESCALATION_TOOL}" getfacl "$KVM_IMAGES_DIR" 2>/dev/null || {
		echo -e "${red}Failed to read ACL permissions${no_color}"
		return
	}
	echo "----------------------------------------"

	echo -e "${green}Backing up current ACL permissions to: $acl_backup_file${no_color}"
	if "${ESCALATION_TOOL}" getfacl -R "$KVM_IMAGES_DIR" > "$acl_backup_file" 2>/dev/null; then
		echo -e "${green}ACL permissions backed up to: $acl_backup_file${no_color}"
		echo "$acl_backup_file"
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
	if "${ESCALATION_TOOL}" setfacl -R -b "$KVM_IMAGES_DIR" 2>/dev/null; then
		echo -e "${green}Existing ACL permissions removed${no_color}"
	else
		echo -e "${red}Failed to remove existing ACL permissions${no_color}"
		return
	fi

	echo -e "${green}Granting permissions to user: $target_user${no_color}"
	if "${ESCALATION_TOOL}" setfacl -R -m "u:${target_user}:rwX" "$KVM_IMAGES_DIR" 2>/dev/null; then
		echo -e "${green}Granted rwX permissions to user: $target_user${no_color}"
	else
		echo -e "${red}Failed to grant permissions to user: $target_user${no_color}"
		return
	fi

	echo -e "${green}Setting default ACL for new files/directories...${no_color}"
	if "${ESCALATION_TOOL}" setfacl -m "d:u:${target_user}:rwx" "$KVM_IMAGES_DIR" 2>/dev/null; then
		echo -e "${green}Default ACL set for user: $target_user${no_color}"
	else
		echo -e "${red}Failed to set default ACL for user: $target_user${no_color}"
		return
	fi

	echo -e "${green}Verifying ACL setup...${no_color}"
	# Check if user has the expected permissions
	local acl_output
	acl_output=$("${ESCALATION_TOOL}" getfacl "$KVM_IMAGES_DIR" 2>/dev/null)
	if echo "$acl_output" | grep -q "user:$target_user:rwx"; then
		echo -e "${green}User ACL permissions verified${no_color}"
	else
		echo -e "${red}User ACL permissions not found${no_color}"
		echo -e "${red}ACL setup verification failed!${no_color}"
		if [[ -n "$acl_backup_file" ]]; then
			echo -e "${green}You can restore from backup: $acl_backup_file${no_color}"
		fi
		return
	fi
	if echo "$acl_output" | grep -q "default:user:$target_user:rwx"; then
		echo -e "${green}Default ACL permissions verified${no_color}"
	else
		echo -e "${red}Default ACL permissions not found${no_color}"
		echo -e "${red}ACL setup verification failed!${no_color}"
		if [[ -n "$acl_backup_file" ]]; then
			echo -e "${green}You can restore from backup: $acl_backup_file${no_color}"
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
	"${ESCALATION_TOOL}" getfacl "$KVM_IMAGES_DIR" 2>/dev/null || {
		echo -e "${red}Failed to read final ACL permissions${no_color}"
		return
	}

}

echo -e "${green}Target directory: $KVM_IMAGES_DIR${no_color}"
echo -e "${green}Target user: $target_user${no_color}"

kvm_acl_setup || true

echo -e "${green}KVM ACL setup completed${no_color}"
echo -e "${green}New files and directories should inherit proper permissions.${no_color}"
if [[ -n "$acl_backup_file" ]]; then
	echo -e "${green}Backup file: $acl_backup_file${no_color}"
fi

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

#TODO: Add AMD SEV Support
#TODO: Optimise Host with TuneD
#TODO: Use taskset to pin QEMU emulator thread

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

if [ "$is_vm" = true ]; then
	# TODO: Fix looking-glass host setup for linux vm
	# echo -e "${green}System is detected to be running in a VM, proceeding with looking-glass host setup${no_color}"
	# looking-glass-host is not in void repos
	# echo -e "${yellow}looking-glass-host is not available in Void repos. Build from source if needed.${no_color}"
	echo ""

	# echo -e "${green}Enable virtual display (vkms)${no_color}"
	# if [ ! -f /etc/modules-load.d/vkms.conf ]; then
	#	 "${ESCALATION_TOOL}" touch /etc/modules-load.d/vkms.conf || true
	# fi
	# if ! grep -q "vkms" /etc/modules-load.d/vkms.conf; then
	#	 echo "vkms" | "${ESCALATION_TOOL}" tee -a /etc/modules-load.d/vkms.conf > /dev/null || true
	# fi
else
	echo -e "${green}System is not detected to be running in a VM, proceeding with looking-glass client setup${no_color}"

	echo -e "${green}Setting up looking-glass for low latency video streaming${no_color}"
	# looking-glass is not in void repos
	# "${ESCALATION_TOOL}" xbps-install -y looking-glass # Low latency video streaming tool
	echo -e "${yellow}looking-glass is not available in Void repos. Build from source: https://looking-glass.io${no_color}"

	# Create the shared memory directory if it doesn't exist
	"${ESCALATION_TOOL}" mkdir -p /dev/shm || true

	# Add your user to the kvm group (if not already)
	"${ESCALATION_TOOL}" usermod -a -G kvm $USER || true

	# Create a udev rule for the shared memory device
	#echo "SUBSYSTEM==\"kvmfr\", OWNER=\"$USER\", GROUP=\"kvm\", MODE=\"0660\"" | "${ESCALATION_TOOL}" tee /etc/udev/rules.d/99-looking-glass.rules > /dev/null || true
	echo "SUBSYSTEM==\"kvmfr\", GROUP=\"kvm\", MODE=\"0660\", TAG+=\"uaccess\"" | "${ESCALATION_TOOL}" tee /etc/udev/rules.d/99-looking-glass.rules > /dev/null || true

	# Reload udev rules
	"${ESCALATION_TOOL}" udevadm control --reload-rules || true
	"${ESCALATION_TOOL}" udevadm trigger || true

	#Edit libvirt configuration:
	LIBVIRT_CONF="/etc/libvirt/qemu.conf"
	if grep -qE '^\s*#\s*user\s*=' "$LIBVIRT_CONF"; then
		echo -e "${green}Uncommenting user line and setting to $USER in $LIBVIRT_CONF${no_color}"
		"${ESCALATION_TOOL}" sed -i "s|^\s*#\s*user\s*=.*|user = \"$USER\"|" "$LIBVIRT_CONF" || true
	elif grep -q 'user = ' "$LIBVIRT_CONF"; then
		echo -e "${green}Changing user in $LIBVIRT_CONF to $USER${no_color}"
		"${ESCALATION_TOOL}" sed -i "s|user = \".*\"|user = \"$USER\"|" "$LIBVIRT_CONF" || true
	else
		echo -e "${green}Adding user = \"$USER\" to $LIBVIRT_CONF${no_color}"
		echo "user = \"$USER\"" | "${ESCALATION_TOOL}" tee -a "$LIBVIRT_CONF" > /dev/null
	fi

	if grep -qE '^\s*#\s*group\s*=' "$LIBVIRT_CONF"; then
		echo -e "${green}Uncommenting group line and setting to kvm in $LIBVIRT_CONF${no_color}"
		"${ESCALATION_TOOL}" sed -i "s|^\s*#\s*group\s*=.*|group = \"kvm\"|" "$LIBVIRT_CONF" || true
	elif grep -q 'group = ' "$LIBVIRT_CONF"; then
		echo -e "${green}Changing group in $LIBVIRT_CONF to kvm${no_color}"
		"${ESCALATION_TOOL}" sed -i "s|group = \".*\"|group = \"kvm\"|" "$LIBVIRT_CONF" || true
	else
		echo -e "${green}Adding group = \"kvm\" to $LIBVIRT_CONF${no_color}"
		echo "group = \"kvm\"" | "${ESCALATION_TOOL}" tee -a "$LIBVIRT_CONF" > /dev/null
	fi

	echo -e "${green}Restarting libvirtd service to apply changes...${no_color}"
	"${ESCALATION_TOOL}" sv restart libvirtd || true

	echo -e "${cyan}Make sure to add the following line to your VM XML configuration:
	<shmem name='looking-glass'>
	<model type='ivshmem-plain'/>
	<size unit='M'>128</size>
	</shmem>${no_color}"
	echo -e "${green}You can also use the following command to check if the shared memory device is created:${no_color}"
	echo -e "${green}ls -l /dev/shm/looking-glass*${no_color}"

	echo -e "${green}Setting up looking-glass completed${no_color}"
fi

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Creating udev rules for GPU to get the stable path...${no_color}"
echo -e "${green}This is required for window managers to work on the inegrated gpu or the virtio gpu${no_color}"

gpu_devices=$(lspci -nn | grep -E "(VGA|3D controller)")

if [ -z "$gpu_devices" ]; then
	echo -e "${red}No GPU detected.${no_color}"
else
	echo -e "Detected GPUs:\n$gpu_devices\n"

	generate_rule() {
		local bus_id=$1
		local symlink_name=$2
		local gpu_name=$3
		local rule_file="/etc/udev/rules.d/10-hyprland-${symlink_name}.rules"

		# Explanation of the Udev Rule:
		# KERNEL=="card*":
		#   Matches device nodes that start with "card" (e.g., /dev/dri/card0), which are DRM devices.
		# SUBSYSTEM=="drm":
		#   Ensures the rule only applies to devices in the Direct Rendering Manager subsystem.
		# SUBSYSTEMS=="pci":
		#   Matches devices that are part of the PCI bus.
		# KERNELS=="0000:$bus_id":
		#   The specific PCI slot identifier for the GPU. This ensures we target the exact hardware device.
		# SYMLINK+="dri/$symlink_name":
		#   Creates a persistent symlink in /dev/dri/ (e.g., /dev/dri/intel-igpu) that points to the dynamic cardX device.
		#   This effectively "fixes" the card number issue by providing a stable name.
		
		local udev_rule="KERNEL==\"card*\", SUBSYSTEM==\"drm\", SUBSYSTEMS==\"pci\", KERNELS==\"0000:$bus_id\", SYMLINK+=\"dri/$symlink_name\""

		echo -e "${green}Processing $gpu_name ($bus_id)...${no_color}"
		
		echo "$udev_rule" | "${ESCALATION_TOOL}" tee "$rule_file" > /dev/null || true

		"${ESCALATION_TOOL}" chmod 644 "$rule_file" || true
		"${ESCALATION_TOOL}" chown root:root "$rule_file" || true
		
		echo -e "  -> Created udev rule at: $rule_file"
		echo -e "  -> Symlink will be: /dev/dri/$symlink_name"
	}

	"$ESCALATION_TOOL" mkdir -p /etc/udev/rules.d/

	gpu_type="virtio-gpu"

	while IFS= read -r line; do
		# Extract the PCI Bus ID (first field, e.g., 00:02.0)
		bus_id=$(echo "$line" | awk '{print $1}')

		if [[ $line == *"NVIDIA"* ]]; then
			generate_rule "$bus_id" "nvidia-dgpu" "NVIDIA dGPU"
		elif [[ $line == *"Intel"* ]]; then
			generate_rule "$bus_id" "intel-igpu" "Intel iGPU"
			gpu_type="intel-igpu"
		elif [[ $line == *"Red Hat"* ]] || [[ $line == *"Virtio"* ]]; then
			generate_rule "$bus_id" "virtio-gpu" "VirtIO GPU"
			gpu_type="virtio-gpu"
		elif [[ $line == *"AMD"* ]] || [[ $line == *"Advanced Micro Devices"* ]]; then
			# Assuming AMD as iGPU
			# TODO: Add support for AMD dGPU
			generate_rule "$bus_id" "amd-igpu" "AMD GPU"
			gpu_type="amd-igpu"
		else
			echo -e "${red}Unknown GPU: $line${no_color}"
		fi
	done <<< "$gpu_devices"

	"${ESCALATION_TOOL}" udevadm control --reload-rules || true
	"${ESCALATION_TOOL}" udevadm trigger || true

	echo -e "\n${green}Success! Udev rules have been created.${no_color}"
	echo ""
	echo "For Hyprland, you can now use these stable paths in your config:"
	echo "env = AQ_DRM_DEVICES,/dev/dri/intel-igpu:/dev/dri/amd-igpu:/dev/dri/virtio-gpu"

	echo -e "${green}Setting up WLR_DRM_DEVICES for wlroots ...${no_color}"
	mkdir -p ~/.config/environment.d/ || true
	echo "WLR_DRM_DEVICES=/dev/dri/$gpu_type" | tee ~/.config/environment.d/10-wlroots-gpu.conf > /dev/null || true
	if ! grep -q "WLR_DRM_DEVICES" $ENV_FILE; then
		echo "" | "${ESCALATION_TOOL}" tee -a "$ENV_FILE" > /dev/null || true
		echo -e "WLR_DRM_DEVICES=/dev/dri/$gpu_type" | "${ESCALATION_TOOL}" tee -a $ENV_FILE > /dev/null || true
	fi
fi

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}adding user to necessary groups...${no_color}"

"${ESCALATION_TOOL}" usermod -aG video $USER || true
"${ESCALATION_TOOL}" usermod -aG audio $USER || true
"${ESCALATION_TOOL}" usermod -aG input $USER || true

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo -e "${green}Cloning and setting up configuration files${no_color}"

touch ~/installconfig.sh
curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/pkgs/installconfig.sh > ~/installconfig.sh
chmod +x ~/installconfig.sh

~/installconfig.sh

echo -e "${green}Adding Neovim (tmux) to applications menu${no_color}"
echo -e "${green}So i can open files in it with thunar${no_color}"
mkdir -p ~/.local/share/applications/ || true
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

"${ESCALATION_TOOL}" xbps-install -y sddm || true
# Disable any existing display manager
"${ESCALATION_TOOL}" rm -f /var/service/gdm /var/service/lightdm /var/service/lxdm /var/service/ly 2>/dev/null || true
# Enable SDDM
"${ESCALATION_TOOL}" ln -sf /etc/sv/sddm /etc/runit/runsvdir/default/sddm || echo -e "${yellow}Failed to enable sddm${no_color}"
echo -e "${green}Setting up my Hacker theme for SDDM${no_color}"
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/sddm-hacker-theme/main/install.sh) || { echo -e "${red}Failed to install the theme${no_color}"; true ;}

echo -e "${green}Making sddm run on wayland as it runs on x11 by default${no_color}"
"${ESCALATION_TOOL}" xbps-install -y labwc || true # SDDM requires a wayland compositor to run on wayland

if "${ESCALATION_TOOL}" test -f "/etc/sddm.conf" && grep -q "DisplayServer=wayland" "/etc/sddm.conf"; then
	echo -e "${green}SDDM Wayland configuration already exists in /etc/sddm.conf${no_color}"
else
	echo -e "${green}Applying SDDM Wayland configuration...${no_color}"
	config_settings="
[General]
DisplayServer=wayland
[Wayland]
CompositorCommand=labwc
"
	echo -e "${config_settings}" | "${ESCALATION_TOOL}" tee -a /etc/sddm.conf > /dev/null || true
fi

if [ -f "/usr/share/wayland-sessions/labwc.desktop" ]; then
	echo -e "${green}Hiding labwc from session menu...${no_color}"
	if grep -q "^NoDisplay=" "/usr/share/wayland-sessions/labwc.desktop"; then
		"${ESCALATION_TOOL}" sed -i 's/^NoDisplay=.*/NoDisplay=true/' "/usr/share/wayland-sessions/labwc.desktop"
	else
		echo "NoDisplay=true" | "${ESCALATION_TOOL}" tee -a "/usr/share/wayland-sessions/labwc.desktop" > /dev/null
	fi
fi

echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"

echo ""
echo -e "${green}******************* My Linux Configuration Script Completed *******************${no_color}"
echo ""
echo -e "${yellow}REBOOT REQUIRED - Please reboot your system now!${no_color}"
echo -e "${blue}════════════════════════════════════════════════════\n════════════════════════════════════════════════════${no_color}"
echo ""
