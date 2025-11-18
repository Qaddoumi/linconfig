[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?logo=arch-linux&logoColor=fff)](https://archlinux.org)

# LinConfig - Arch Linux Configuration Suite

An automated configuration suite for Arch Linux featuring SwayWM setup, SDDM/Ly login managers, and VM GPU passthrough capabilities.

## 🌟 Features

- **Automated Arch Linux Installation**: Complete system setup with advanced configuration options
- **SwayWM Configuration**: Pre-configured Sway window manager with optimized settings
- **Multiple Login Managers**: Support for both SDDM and Ly display managers
- **VM GPU Passthrough**: Configuration for virtual machine GPU passthrough
- **Modular Installation**: Install complete system or just configuration files

## ⚠️ Important Notice

This project is currently in active development. While functional, it may not work as expected in all environments and could potentially cause system issues. **Please backup your data and use at your own risk.**

## 🚀 Quick Start

### Complete Arch Linux Installation
Install Arch Linux with advanced configuration options:
```bash
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/linux/archinstall.sh)
```

### Sway + SDDM Setup
Install SwayWM with SDDM login manager:
```bash
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/sway/install.sh) --login-manager sddm --is-vm false
```

### Sway + Ly Setup
Install SwayWM with Ly login manager:
```bash
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/sway/install.sh) --login-manager ly --is-vm false
```

### Configuration Files Only
Install only the configuration files without system packages:
```bash
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/linconfig/main/sway/installconfig.sh)
```

## 🔧 Configuration Details

### Post-Installation
After installation, you can:
1. Log out and select Sway from your display manager
2. Use `Super + Enter` to open a terminal
3. Use `Super + d` to open the application launcher

## 🙏 Acknowledgments

- [arkboix/sway](https://github.com/arkboix/sway) - Original inspiration and configuration base
- Arch Linux community for documentation and support
- Sway development team for the excellent window manager

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This script modifies system partitions and configurations. The authors are not responsible for any data loss or system damage. Always backup your data before using these scripts and test in a virtual machine first if possible.

---

**Made with ❤️, so feel free to take what you like from it**