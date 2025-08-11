[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?logo=arch-linux&logoColor=fff)](https://archlinux.org)

# SWAY/SDDM and vm gpu passthrough

SwayWM Configuration files. used with Arch Linux.

## ⚠️ Warning ⚠️
This project is not ready yet, it is a work in progress. It may not work as expected and may cause issues with your system. Use it at your own risk.


## 🏔️ Installation 🏔️

- Run :

An automated script for installing Arch Linux with advanced configuration options.
```shell

```

### For Sway and SDDM installation
``` shell
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/sway/main/install.sh) --login-manager sddm
```

### For Sway and Ly installation
``` shell
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/sway/main/install.sh) --login-manager ly
```

- Or for only the config files :

``` shell
bash <(curl -sL https://raw.githubusercontent.com/Qaddoumi/sway/main/installconfig.sh)
```


## Credit
- [arkboix/sway](https://github.com/arkboix/sway)


## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This script modifies system partitions and configurations. Always backup your data before using it.
