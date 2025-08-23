#!/usr/bin/env bash

set -e  # Exit on any error

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
no_color='\033[0m' # rest the color to default

backup_file() {
    local file="$1"
    if sudo test -f "$file"; then
        sudo cp "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${green}Backed up $file${no_color}"
    else
        echo -e "${yellow}File $file does not exist, skipping backup${no_color}"
    fi
}

echo -e "${green}Performance Mode Setup ${no_color}"

sudo pacman -S --needed --noconfirm cpupower # CPU frequency scaling utility ==> change powersave to performance mode.
sudo pacman -S --needed --noconfirm tlp # TLP for power management
sudo pacman -S --needed --noconfirm lm_sensors # Hardware monitoring
sudo pacman -S --needed --noconfirm dmidecode # Desktop Management Interface table related utilities

sudo cpupower frequency-set -g performance && echo -e "${green}CPU performance mode activated successfully${no_color}"|| echo -e "${red}Failed to set CPU performance mode${no_color}"
echo -e "${green}Current CPU frequency info:${no_color}"
cpupower frequency-info | grep -E "(analyzing CPU|current policy|current CPU frequency)"
echo -e "${green}Creating systemd service for persistent performance mode...${no_color}"
sudo tee /etc/systemd/system/cpu-performance.service > /dev/null <<EOF
[Unit]
Description=Set CPU to performance mode
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g performance
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
echo -e "${green}Enabling and starting CPU performance service...${no_color}"
sudo systemctl enable cpu-performance.service > /dev/null || true
sudo systemctl start cpu-performance.service > /dev/null || true


echo -e "${green}Enabling TLP service...${no_color}"
sudo systemctl enable tlp > /dev/null || true
echo -e "${green}Backing up original TLP config (/etc/tlp.conf)...${no_color}"
backup_file /etc/tlp.conf
echo -e "${green}Configuring TLP for performance mode...${no_color}"

if [ ! -f /etc/tlp.conf ]; then
    echo -e "Creating new one TLP config file"
    sudo touch /etc/tlp.conf 
fi
sudo sed -i 's/^#*CPU_SCALING_GOVERNOR_ON_AC=.*/CPU_SCALING_GOVERNOR_ON_AC=performance/' /etc/tlp.conf > /dev/null
sudo sed -i 's/^#*CPU_SCALING_GOVERNOR_ON_BAT=.*/CPU_SCALING_GOVERNOR_ON_BAT=powersave/' /etc/tlp.conf > /dev/null
sudo sed -i 's/^#*CPU_ENERGY_PERF_POLICY_ON_AC=.*/CPU_ENERGY_PERF_POLICY_ON_AC=performance/' /etc/tlp.conf > /dev/null
sudo sed -i 's/^#*CPU_BOOST_ON_AC=.*/CPU_BOOST_ON_AC=1/' /etc/tlp.conf > /dev/null
echo -e "${green}Starting TLP service...${no_color}"
sudo systemctl start tlp > /dev/null || true

echo -e "${green}To check current status:${no_color}"
echo "  cpupower frequency-info"
echo -e "${green}To check service status:${no_color}"
echo "  systemctl status cpu-performance.service"
echo "  systemctl status tlp"


echo -e "${green}Automated Hardware Sensors Detection${no_color}"
echo -e "${green}Backing up existing config (if exists)...${no_color}"
backup_file /etc/conf.d/lm_sensors

echo -e "${green}Detecting system information...${no_color}"
SYSTEM_VENDOR=$(sudo dmidecode -s system-manufacturer 2>/dev/null | head -1)
SYSTEM_MODEL=$(sudo dmidecode -s system-product-name 2>/dev/null | head -1)
CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}' | head -1)
CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
echo -e "${green}System: $SYSTEM_VENDOR $SYSTEM_MODEL${no_color}"
echo -e "${green}CPU: $CPU_VENDOR - $CPU_MODEL${no_color}"

echo -e "${green}Detecting and loading sensor modules...${no_color}"
DETECTED_MODULES=""

# Check for Intel CPU thermal sensors
if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    if [[ "$CPU_MODEL" == *"Core"* ]] || [[ "$CPU_MODEL" == *"Xeon"* ]] || [[ "$CPU_MODEL" == *"Pentium"* ]]; then
        echo "Detecting Intel CPU thermal sensors..."
        if sudo modprobe coretemp 2>/dev/null; then
            echo "✓ Intel coretemp module loaded"
            DETECTED_MODULES="$DETECTED_MODULES coretemp"
        else
            echo "⚠ coretemp module not available"
        fi
    fi
# Check for AMD CPU thermal sensors
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    echo "Detecting AMD CPU thermal sensors..."
    if sudo modprobe k10temp 2>/dev/null; then
        echo "✓ AMD k10temp module loaded"
        DETECTED_MODULES="$DETECTED_MODULES k10temp"
    else
        echo "⚠ k10temp module not available"
    fi
fi

# Check for ACPI thermal zones
if [ -d /sys/class/thermal ] && [ "$(ls -A /sys/class/thermal/thermal_zone* 2>/dev/null)" ]; then
    echo "✓ ACPI thermal zones detected"
    if sudo modprobe acpi-thermal 2>/dev/null; then
        echo "✓ ACPI thermal module loaded"
    fi
fi

# Check for NVMe drive temperatures
if lspci | grep -i nvme >/dev/null 2>&1; then
    echo "✓ NVMe drives detected"
    if sudo modprobe nvme 2>/dev/null; then
        echo "✓ NVMe temperature monitoring available"
    fi
fi

# Check for common laptop sensor chips (safer approach)
CHIP_MODULES="it87 nct6775 w83627ehf"
for module in $CHIP_MODULES; do
    if sudo modprobe "$module" 2>/dev/null; then
        echo "✓ Chip module $module loaded successfully"
        DETECTED_MODULES="$DETECTED_MODULES $module"
        # Remove it for now, we'll load it properly later
        sudo modprobe -r "$module" 2>/dev/null || true
    fi
done

# Check for i2c tools and load i2c modules if available
if command -v i2cdetect &> /dev/null; then
    echo "Checking for I2C sensors (safe method)..."
    if sudo modprobe i2c-i801 2>/dev/null; then
        echo "✓ I2C support loaded"
        DETECTED_MODULES="$DETECTED_MODULES i2c-i801"
    fi
fi

echo -e "${green}Creating lm_sensors configuration...${no_color}"
# Create the configuration file
sudo tee /etc/conf.d/lm_sensors > /dev/null <<EOF
# Generated by automated sensor detection script
# $(date)
# System: $SYSTEM_VENDOR $SYSTEM_MODEL

# Kernel modules for hardware sensors
HWMON_MODULES="$DETECTED_MODULES"

# I2C/SMBus modules (if any)
#BUS_MODULES=""
EOF

echo -e "${green}Configuration file created${no_color}"

echo -e "${green}Generated configuration:${no_color}"
cat /etc/conf.d/lm_sensors | sed 's/^/  /'

echo -e "${green}Loading detected modules...${no_color}"
if [ -n "$DETECTED_MODULES" ]; then
    for module in $DETECTED_MODULES; do
        echo "Loading module: $module"
        if sudo modprobe "$module"; then
            echo "✓ Module $module loaded successfully"
        else
            echo -e "${yellow}⚠ Failed to load module $module${no_color}"
        fi
    done
else
    echo "⚠ No hardware monitoring modules detected"
fi

echo -e "${green}Enabling and starting lm_sensors service...${no_color}"
if ! systemctl is-enabled lm_sensors.service &>/dev/null; then
    sudo systemctl enable lm_sensors.service
    echo -e "${green}lm_sensors service enabled${no_color}"
else
    echo "${green}✓ lm_sensors service already enabled${no_color}"
fi

sudo systemctl start lm_sensors.service > /dev/null || true
echo -e "${green}lm_sensors service started${no_color}"

echo -e "${green}Initializing sensors...${no_color}"
if command -v sensors &> /dev/null; then
    sudo sensors -s 2>/dev/null || true
    echo -e "${green}✓ Sensors initialized${no_color}"
else
    echo -e "${yellow}⚠ sensors command not available${no_color}"
fi

# Test sensors
echo -e "${green}Current sensor readings:${no_color}"
echo -e "*************************"
if command -v sensors &> /dev/null && [ -n "$DETECTED_MODULES" ]; then
    sensors 2>/dev/null || echo -e "${yellow}Run 'sensors' manually to see detailed sensor data${no_color}"
else
    echo -e "${yellow}No sensors detected or sensors command not available${no_color}"
    echo -e ""
    echo -e "${yellow}You can still check thermal zones directly:${no_color}"
    echo -e "${yellow}  cat /sys/class/thermal/thermal_zone*/temp${no_color}"
fi

echo ""
echo -e "${green}Service status:${no_color}"
echo -e "${green}===============${no_color}"
systemctl status lm_sensors.service --no-pager -l || true

echo -e ""
echo -e "${green}To manually test: sensors${no_color}"
echo -e "${green}To check service: systemctl status lm_sensors.service${no_color}"


echo -e "${yellow}Reboot recommended to ensure all settings take effect.${no_color}"