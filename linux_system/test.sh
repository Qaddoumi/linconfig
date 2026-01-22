#!/bin/bash

# Color codes
red="\033[0;31m"
green="\033[0;32m"
yellow="\033[1;33m"
blue="\033[0;34m"
cyan="\033[0;36m"
bold="\e[1m"
no_color="\033[0m" # reset the color to default
error() { echo -e "${red}[ERROR] $*${no_color}" >&2; exit 1; }
info() { echo -e "${cyan}[*]${green} $*${no_color}"; }
newTask() { echo -e "${blue}$*${no_color}"; }
warn() { echo -e "${yellow}[WARN] $*${no_color}"; }

info "Running post-install script..."
	
# Re-mount virtual filesystems for post-install
info "Mounting virtual filesystems for post-install..."
mount --rbind /dev /mnt/dev && mount --make-rslave /mnt/dev || error "Failed to mount /dev"
mount --rbind /proc /mnt/proc && mount --make-rslave /mnt/proc || error "Failed to mount /proc"
mount --rbind /sys /mnt/sys && mount --make-rslave /mnt/sys || error "Failed to mount /sys"

chroot /mnt /bin/bash -s -- "amoh" <<'POSTINSTALLEOF' || error "Post-install script failed to run"

USER_NAME="$1"

echo -e "\n"

# These symlinks should already exist from the initial /dev mount, but just in case:
[[ -L /dev/fd ]] || ln -sf /proc/self/fd /dev/fd
[[ -L /dev/stdin ]] || ln -sf /proc/self/fd/0 /dev/stdin
[[ -L /dev/stdout ]] || ln -sf /proc/self/fd/1 /dev/stdout
[[ -L /dev/stderr ]] || ln -sf /proc/self/fd/2 /dev/stderr

echo "Temporarily disabling doas password for wheel group"
echo "permit nopass :wheel" >> /etc/doas.conf

pkgs=( hyprland hyprutils aquamarine hyprlang )

su "$USER_NAME" <<USEREOF
	echo "Running post-install script as user $USER_NAME..."
	echo "Checking for unavailable packages..."

    if ! grep -q "hyprland-void" /etc/xbps.d/*.conf 2>/dev/null; then
        echo "repository=https://raw.githubusercontent.com/Makrennel/hyprland-void/repository-x86_64-glibc" | doas tee /etc/xbps.d/hyprland-void.conf > /dev/null
        doas xbps-install -Sy -y || true
    fi

	params=( ${pkgs[@]} )
	unavailable_pkgs=()
	for pkg in "\${params[@]}"; do
		if ! xbps-query -R "\$pkg" >/dev/null 2>&1; then
			unavailable_pkgs+=("\$pkg")
		fi
	done

	if [ \${#unavailable_pkgs[@]} -ne 0 ]; then
		echo "The following packages are NOT available in the repository:"
		for pkg in "\${unavailable_pkgs[@]}"; do
			echo "  - \$pkg"
		done
	else
		echo "All packages are available."
	fi
USEREOF

echo "Restoring doas password requirement for wheel group"
sed -i '/^permit nopass :wheel/d' /etc/doas.conf
POSTINSTALLEOF

# Clean up: unmount virtual filesystems after post-install
info "Unmounting virtual filesystems after post-install..."
umount -R /mnt/dev 2>/dev/null || true
umount -R /mnt/proc 2>/dev/null || true
umount -R /mnt/sys 2>/dev/null || true