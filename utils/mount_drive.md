sudo pacman -S rclone

mkdir -p ~/GoogleDrive



#######################
How to Configure the "gdrive" Remote
Run rclone config in your terminal and follow these exact steps:
Type n for a new remote.
Type gdrive for the name.
Type drive for the storage type.
Press Enter to skip Client ID.
Press Enter to skip Client Secret.
Type 1 for full access scope.
Press Enter for the root folder ID.
Press Enter for the Service Account file.
Type n to skip advanced config.
Type y to use auto-config.
Complete the Google login in your browser.
Type n for Shared Drive config.
Type y to confirm and save.
Type q to quit the wizard.

#######################



rclone mount gdrive: ~/GoogleDrive --vfs-cache-mode full --dir-cache-time 24h --vfs-cache-max-age 72h --vfs-read-ahead 128M --daemon
