[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?logo=arch-linux&logoColor=fff)](https://archlinux.org)

# 🌟 LinConfig - Arch Linux Configuration Suite

An automated configuration suite for Arch Linux featuring Sway/Hyprland/Awesome/DWM setup, QuickShell and SDDM login manager, with VM GPU passthrough capabilities.

## ⚠️⚠️ Important Notice and Disclaimer

This project is currently in active development. While functional, it may not work as expected in all environments and could potentially cause system issues, The authors are not responsible for any data loss or system and hardware damages. **Please backup your data and use at your own risk, I take no responsibility for any damage that may occur.**

## 🚀 Installation

### Complete Arch Linux Installation
Install Arch Linux with advanced configuration options:
```bash
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/linux_system/archinstall.sh)
```

### Sway/Hyprland/Awesome/DWM + QuickShell + SDDM Setup
Install SwayWM with SDDM login manager:
```bash
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/pkgs/install.sh) --is-vm false
```

### Configuration Files Only
Install only the configuration files without system packages:
```bash
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/pkgs/installconfig.sh)
```

## Post-Installation
After installation, you can:
1. Log out and select Sway/Hyprland/Awesome/DWM from your display manager
2. Use `Super + Enter` to open a kitty terminal
3. Use `Super + d` to open the application launcher (rofi)


---

# Credit
- [yahr-quickshell](https://github.com/bgibson72/yahr-quickshell)
- [linutil](https://github.com/ChrisTitusTech/linutil)
- [dwm-titus](https://github.com/ChrisTitusTech/dwm-titus)
