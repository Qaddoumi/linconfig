#!/usr/bin/env bash

# Add these sections to your performance.sh script

echo -e "${green}Setting up thermal management...${no_color}"

# Install thermal management tools
sudo pacman -S --needed --noconfirm thermald     # Intel thermal daemon
# Note: fancontrol and pwmconfig are included in lm_sensors package (already installed)

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
Description=Run thermal protection every 30 seconds
Requires=thermal-monitor.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=30sec

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