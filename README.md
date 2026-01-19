[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?logo=arch-linux&logoColor=fff)](https://archlinux.org)
[![Void Linux](https://img.shields.io/badge/Void%20Linux-1793D1?logo=void-linux&logoColor=fff)](https://voidlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-1793D1?logo=hyprland&logoColor=fff)](https://hyprland.org)
[![Sway](https://img.shields.io/badge/Sway-1793D1?logo=sway&logoColor=fff)](https://swaywm.org)
[![DWM](https://img.shields.io/badge/DWM-1793D1?logo=dwm&logoColor=fff)](https://dwm.suckless.org)
[![QuickShell](https://img.shields.io/badge/QuickShell-1793D1?logo=quickshell&logoColor=fff)](https://github.com/quickshell-mirror/quickshell)
[![SDDM](https://img.shields.io/badge/SDDM-1793D1?logo=sddm&logoColor=fff)](https://github.com/sddm/sddm)

# 🌟 LinConfig - My Linux Configuration Suite

An automated configuration suite for Arch|Void Linux featuring Sway/Hyprland/DWM setup, QuickShell and SDDM login manager, with VM GPU passthrough capabilities.

## ⚠️⚠️ Important Notice and Disclaimer

This project is currently in active development. While functional, it may not work as expected in all environments and could potentially cause system issues, The authors are not responsible for any data loss or system and hardware damages. **Please backup your data and use at your own risk, I take no responsibility for any damage that may occur.**

- Note 0.1 :- This setup build for laptops with iGPU and dGPU
- Note 0.2 :- And it has not been tested on AMD cpus or gpus and needs some adjustments for it to work
- Note 0.3 :- This is not meant to be a minimal setup

## 🚀 Installation

### Complete Arch Linux Installation
Install Arch Linux with advanced configuration options:
```bash
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/linux_system/archinstall.sh)
```
### Complete Void Linux Installation
Install Void Linux with advanced configuration options:
```bash
sudo xbps-install -Syu xbps libssh2 curl; curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/linux_system/voidinstall.sh -o /tmp/voidinstall.sh; sudo bash /tmp/voidinstall.sh
```

### Configuration Files Only
Install only the configuration files without system packages:
```bash
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/pkgs/installconfig.sh)
```

## Post-Installation
After installation, you can:
1. Log out and select Sway/Hyprland/DWM from your display manager
2. Use `Super + Enter` to open a kitty terminal
3. Use `Super + d` to open the application launcher (rofi)


---

# Credit
- [linutil](https://github.com/ChrisTitusTech/linutil)
- [dwm-titus](https://github.com/ChrisTitusTech/dwm-titus)
- [yahr-quickshell](https://github.com/bgibson72/yahr-quickshell)
- [night-owl-vscode-theme](https://github.com/sdras/night-owl-vscode-theme)
