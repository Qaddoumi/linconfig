#!/usr/bin/env bash

set -e  # Exit on any error

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
no_color='\033[0m' # reset the color to default

backup_file() {
    local file="$1"
    if sudo test -f "$file"; then
        sudo cp -an "$file" "$file.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${green}Backed up $file${no_color}"
    else
        echo -e "${yellow}File $file does not exist, skipping backup${no_color}"
    fi
}

echo -e "${green}Performance Mode Setup ${no_color}"

sudo pacman -S --needed --noconfirm cpupower # CPU frequency scaling utility ==> change powersave to performance mode.
sudo pacman -S --needed --noconfirm tlp # TLP for power management
sudo pacman -S --needed --noconfirm lm_sensors # Hardware monitoring
sudo pacman -S --needed --noconfirm thermald     # Intel thermal daemon
sudo pacman -S --needed --noconfirm dmidecode # Desktop Management Interface table related utilities
echo -e "${green} Note: fancontrol and pwmconfig are included in lm_sensors package (already installed)${no_color}"

echo -e "${green}The tools that installed with lm_sensors:${no_color}"
pacman -Ql lm_sensors | grep bin || true

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
    echo powersave > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
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

# Add thermal status check function
thermal_status() {
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
}

# Run thermal status check
thermal_status

echo -e "${green}Thermal management setup complete!${no_color}"
echo -e "${yellow}Monitor temperatures with: watch sensors${no_color}"
echo -e "${yellow}Check thermal protection: systemctl status thermal-monitor.timer${no_color}"


echo -e "${yellow}Reboot recommended to ensure all settings take effect.${no_color}"