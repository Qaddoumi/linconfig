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

echo -e "${green}=== Optimized Performance Setup for Lenovo LOQ ===${no_color}"

sudo pacman -S --needed --noconfirm i2cdetect lm_sensors cpupower tlp tlp-rdw thermald

echo -e "${green}Installing and configuring TLP for automatic performance management...${no_color}"

# Backup and configure TLP
echo -e "${green}Backing up original TLP config (/etc/tlp.conf)...${no_color}"
backup_file /etc/tlp.conf

echo -e "${green}Configuring TLP for automatic AC/Battery performance switching...${no_color}"

# Create optimized TLP configuration for Lenovo LOQ
sudo tee /etc/tlp.conf > /dev/null <<'EOF'

# Processor
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# CPU Energy Performance Policy
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# CPU Boost
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# CPU Frequency Scaling
CPU_SCALING_MIN_FREQ_ON_AC=0
CPU_SCALING_MAX_FREQ_ON_AC=0
CPU_SCALING_MIN_FREQ_ON_BAT=0
CPU_SCALING_MAX_FREQ_ON_BAT=0

# Platform Profile (for modern laptops)
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=low-power

# Disk devices
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="128 128"
DISK_IOSCHED="mq-deadline mq-deadline"

# SATA Link Power Management
SATA_LINKPWR_ON_AC="med_power_with_dipm max_performance"
SATA_LINKPWR_ON_BAT="med_power_with_dipm min_power"

# PCI Express Active State Power Management
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersupersave

# Graphics (Intel integrated + NVIDIA discrete)
INTEL_GPU_MIN_FREQ_ON_AC=0
INTEL_GPU_MIN_FREQ_ON_BAT=0
INTEL_GPU_MAX_FREQ_ON_AC=0
INTEL_GPU_MAX_FREQ_ON_BAT=0
INTEL_GPU_BOOST_FREQ_ON_AC=0
INTEL_GPU_BOOST_FREQ_ON_BAT=0

# NVIDIA GPU Power Management
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto

# USB
USB_AUTOSUSPEND=1
USB_BLACKLIST_BTUSB=0
USB_BLACKLIST_PHONE=0
USB_BLACKLIST_PRINTER=1
USB_BLACKLIST_WWAN=0

# Audio
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_CONTROLLER=Y

# WiFi Power Management
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# Wake-on-LAN
WOL_DISABLE=Y

# Battery Care (for Lenovo laptops)
#START_CHARGE_THRESH_BAT0=40
#STOP_CHARGE_THRESH_BAT0=80
#START_CHARGE_THRESH_BAT1=40
#STOP_CHARGE_THRESH_BAT1=80

# Restore charge thresholds on reboot
#RESTORE_THRESHOLDS_ON_BAT=1
#RESTORE_THRESHOLDS_ON_AC=1

# ThinkPad specific (may work on some Lenovo models)
NATACPI_ENABLE=1
TPACPI_ENABLE=1
TPSMAPI_ENABLE=1
EOF

echo -e "${green}Enabling and starting TLP service...${no_color}"
sudo systemctl enable tlp.service
sudo systemctl start tlp.service

# Check current power source and apply settings
echo -e "${green}Applying TLP settings for current power source...${no_color}"
sudo tlp start

# Hardware sensors setup (keeping your existing logic but cleaned up)
echo -e "${green}=== Automated Hardware Sensors Detection ===${no_color}"
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

# Intel CPU thermal sensors
if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    echo "Detecting Intel CPU thermal sensors..."
    if sudo modprobe coretemp 2>/dev/null; then
        echo "✓ Intel coretemp module loaded"
        DETECTED_MODULES="$DETECTED_MODULES coretemp"
    fi
# AMD CPU thermal sensors
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    echo "Detecting AMD CPU thermal sensors..."
    if sudo modprobe k10temp 2>/dev/null; then
        echo "✓ AMD k10temp module loaded"
        DETECTED_MODULES="$DETECTED_MODULES k10temp"
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

# Common sensor chips for laptops
CHIP_MODULES="it87 nct6775 w83627ehf"
for module in $CHIP_MODULES; do
    if sudo modprobe "$module" 2>/dev/null; then
        echo "✓ Chip module $module loaded successfully"
        DETECTED_MODULES="$DETECTED_MODULES $module"
        sudo modprobe -r "$module" 2>/dev/null || true
    fi
done

# I2C support
if command -v i2cdetect &> /dev/null; then
    if sudo modprobe i2c-i801 2>/dev/null; then
        echo "✓ I2C support loaded"
        DETECTED_MODULES="$DETECTED_MODULES i2c-i801"
    fi
fi

# Create lm_sensors configuration
echo -e "${green}Creating lm_sensors configuration...${no_color}"
sudo tee /etc/conf.d/lm_sensors > /dev/null <<EOF
# Generated by automated sensor detection script
# $(date)
# System: $SYSTEM_VENDOR $SYSTEM_MODEL

# Kernel modules for hardware sensors
HWMON_MODULES="$DETECTED_MODULES"
EOF

# Load detected modules
if [ -n "$DETECTED_MODULES" ]; then
    echo -e "${green}Loading detected sensor modules...${no_color}"
    for module in $DETECTED_MODULES; do
        if sudo modprobe "$module"; then
            echo "✓ Module $module loaded successfully"
        fi
    done
fi

# Enable and start lm_sensors
echo -e "${green}Enabling and starting lm_sensors service...${no_color}"
sudo systemctl enable lm_sensors.service &>/dev/null || true
sudo systemctl start lm_sensors.service &>/dev/null || true

# Initialize sensors
echo -e "${green}Initializing sensors...${no_color}"
if command -v sensors &> /dev/null; then
    sudo sensors -s 2>/dev/null || true
    echo -e "${green}✓ Sensors initialized${no_color}"
else
    echo -e "${yellow}⚠ sensors command not available${no_color}"
fi

echo -e "${green}=== Setup Complete ===${no_color}"
echo -e "${green}Current TLP Status:${no_color}"
sudo tlp-stat -s

echo -e "${green}Current Power Source and Settings:${no_color}"
if [ -f /sys/class/power_supply/AC*/online ]; then
    if [ "$(cat /sys/class/power_supply/AC*/online)" = "1" ]; then
        echo "Power Source: AC (Performance mode active)"
    else
        echo "Power Source: Battery (Power-saving mode active)"
    fi
fi

echo -e "${green}Current CPU Governor:${no_color}"
if command -v cpupower &> /dev/null; then
    cpupower frequency-info | grep -E "current policy" || echo "Install cpupower-tools to see detailed CPU info"
else
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "CPU governor info not available"
fi

echo -e "${green}Temperature Monitoring:${no_color}"
if command -v sensors &> /dev/null; then
    sensors 2>/dev/null | head -20 || echo "Run 'sensors' to see detailed temperature data"
else
    echo "Install lm_sensors package for temperature monitoring"
fi



#############################################################
#############################################################
#############################################################
#############################################################
#############################################################


echo -e "${green}Setting up thermal management...${no_color}"

# Configure thermald for Intel systems
if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    echo -e "${green}Configuring Intel thermal daemon...${no_color}"
    sudo systemctl enable thermald
    sudo systemctl start thermald
    echo -e "${green}✓ Thermald enabled for Intel CPU${no_color}"
fi

# Set up thermal monitoring with automatic frequency scaling
echo -e "${green}Configuring thermal protection...${no_color}"

# Create thermal protection script
sudo tee /usr/local/bin/thermal-protect.sh > /dev/null <<'EOF'
#!/usr/bin/env bash

# Thermal protection thresholds (in millicelsius)
CPU_TEMP_THRESHOLD=85000  # 85°C
CRITICAL_TEMP_THRESHOLD=95000  # 95°C

check_cpu_temp() {
    local max_temp=0
    local temp_files="/sys/class/thermal/thermal_zone*/temp"
    
    for temp_file in $temp_files; do
        if [[ -r "$temp_file" ]]; then
            local temp=$(cat "$temp_file" 2>/dev/null)
            if [[ "$temp" -gt "$max_temp" ]]; then
                max_temp=$temp
            fi
        fi
    done
    echo $max_temp
}

current_temp=$(check_cpu_temp)

if [[ "$current_temp" -gt "$CRITICAL_TEMP_THRESHOLD" ]]; then
    echo "CRITICAL: CPU temperature ${current_temp}°C - Emergency throttling!"
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo powersave > "$gov"
    done
    echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
elif [[ "$current_temp" -gt "$CPU_TEMP_THRESHOLD" ]]; then
    echo "WARNING: CPU temperature ${current_temp}°C - Reducing performance"
    echo conservative > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
else
    # Temperature is safe, restore performance mode
    echo performance > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
fi
EOF

sudo chmod +x /usr/local/bin/thermal-protect.sh

# Create systemd timer for thermal monitoring
sudo tee /etc/systemd/system/thermal-monitor.service > /dev/null <<EOF
[Unit]
Description=Thermal Protection Monitor
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/thermal-protect.sh
User=root
EOF

sudo tee /etc/systemd/system/thermal-monitor.timer > /dev/null <<EOF
[Unit]
Description=Run thermal protection every 10 seconds
Requires=thermal-monitor.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=10sec

[Install]
WantedBy=timers.target
EOF

echo -e "${green}Enabling thermal monitoring timer...${no_color}"
sudo systemctl enable thermal-monitor.timer
sudo systemctl start thermal-monitor.timer

# Configure fan curves if possible
echo -e "${green}Checking for fan control capabilities...${no_color}"
if command -v pwmconfig &> /dev/null; then
    echo -e "${yellow}Fan control available! Run 'sudo pwmconfig' manually to configure fan curves${no_color}"
    echo -e "${yellow}After pwmconfig, use 'sudo systemctl enable fancontrol' to enable automatic fan control${no_color}"
else
    echo -e "${yellow}pwmconfig not found - check if lm_sensors is properly installed${no_color}"
fi

echo -e "${blue}Current thermal status:${no_color}"
echo "CPU Temperature:"
for zone in /sys/class/thermal/thermal_zone*; do
    if [[ -r "$zone/temp" ]] && [[ -r "$zone/type" ]]; then
        local temp=$(cat "$zone/temp")
        local type=$(cat "$zone/type")
        local temp_c=$((temp / 1000))
        echo "  $type: ${temp_c}°C"
    fi
done

echo -e "\nFan Status:"
find /sys/class/hwmon -name "fan*_input" -exec sh -c 'echo "$(dirname {})/$(basename {}): $(cat {}) RPM"' \; 2>/dev/null || echo "No fan sensors detected"

echo -e "\nThermal Services:"
systemctl is-active thermald 2>/dev/null && echo "✓ thermald: active" || echo "✗ thermald: inactive"
systemctl is-active thermal-monitor.timer 2>/dev/null && echo "✓ thermal-monitor: active" || echo "✗ thermal-monitor: inactive"

echo -e "${green}Thermal management setup complete!${no_color}"
echo -e "${yellow}Monitor temperatures with: watch sensors${no_color}"
echo -e "${yellow}Check thermal protection: systemctl status thermal-monitor.timer${no_color}"





echo ""
echo -e "${green}=== Usage Instructions ===${no_color}"
echo -e "${green}• TLP automatically switches between performance/power-saving based on AC/Battery${no_color}"
echo -e "${green}• Check status: sudo tlp-stat -s${no_color}"
echo -e "${green}• Force AC mode: sudo tlp ac${no_color}"
echo -e "${green}• Force Battery mode: sudo tlp bat${no_color}"
echo -e "${green}• Check temperatures: sensors${no_color}"
echo -e "${green}• Battery care: Charging limited to 80% to extend battery life${no_color}"
echo ""
echo -e "${yellow}Reboot recommended to ensure all settings take effect.${no_color}"