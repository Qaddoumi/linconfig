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

for tool in sudo doas pkexec; do
	if command -v "${tool}" >/dev/null 2>&1; then
		ESCALATION_TOOL="${tool}"
		echo -e "${cyan}Using ${tool} for privilege escalation${no_color}"
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
