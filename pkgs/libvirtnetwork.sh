#!/usr/bin/env bash

set -e # Exit on error

# Color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
no_color='\033[0m' # rest the color to default


sudo mkdir -p ~/.local/share/applications/ || true
sudo chown -R $USER:$USER ~/.local/share/applications/ || true
echo -e "${green}Setting up virt-manager one-time network configuration script${no_color}"
echo -e "${green}Creating ~/.config/virt-manager-oneshot.sh${no_color}"
sudo tee ~/.config/virt-manager-oneshot.sh > /dev/null << 'EOF'
#!/usr/bin/env bash

# 1. Your custom command goes here
# Example: Notify user or run a configuration tool
notify-send "Virt-Manager" "setting libvirt network"
# Wait for libvirtd to be ready (max 30 seconds)
for i in {1..30}; do
    if virsh list >/dev/null 2>&1; then
        break
    fi
    sleep 1
done
virsh net-start default 2>/dev/null || true
virsh net-autostart default 2>/dev/null || true

# 2. Self-Destruct Mechanism
# This deletes the script file itself so it never runs again.
rm -- "$0"
EOF

sudo chmod +x ~/.config/virt-manager-oneshot.sh || true

echo -e "${green}Creating /usr/local/bin/virt-manager wrapper script${no_color}"
sudo tee /usr/local/bin/virt-manager > /dev/null << 'EOF'
#!/usr/bin/env bash

# Define where the one-time payload lives
PAYLOAD="$HOME/.config/virt-manager-oneshot.sh"

# Start a background subshell that waits 5 seconds
(
    sleep 5
    # Check if the payload still exists
    if [ -f "$PAYLOAD" ] && [ -x "$PAYLOAD" ]; then
        "$PAYLOAD"
    fi
) &

# Disown the background job so it doesn't spam the terminal
disown

# Launch the REAL virt-manager and replace this script with it
# This ensures the terminal behaves exactly as expected
exec /usr/bin/virt-manager "$@"
EOF

sudo chmod +x /usr/local/bin/virt-manager || true

echo -e "${green}Creating desktop entry for virt-manager wrapper${no_color}"
cp /usr/share/applications/virt-manager.desktop ~/.local/share/applications/

echo -e "${green}Modifying desktop entry to use wrapper script${no_color}"
sudo sed -i 's|^Exec=virt-manager|Exec=/usr/local/bin/virt-manager|g' ~/.local/share/applications/virt-manager.desktop

echo -e "${green}Setting up virt-manager one-time network configuration completed${no_color}"