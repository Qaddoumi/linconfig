arch-chroot /mnt /bin/bash -s -- "amoh" <<'POSTINSTALLEOF' || error "Post-install script failed to run"

USER_NAME="$1"

echo -e "\n"

echo "Temporarily disabling sudo password for wheel group"
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Create the local schema overrides directory
sudo mkdir -p /usr/share/glib-2.0/schemas/

# Create the override file (sets defaults for ALL users)
cat <<EOF | sudo tee /usr/share/glib-2.0/schemas/99_ext_settings.gschema.override
[org.gnome.desktop.interface]
gtk-theme='Materia-dark-compact'
icon-theme='Papirus-Dark'
cursor-theme='Capitaine-cursors'
color-scheme='prefer-dark'
enable-animations=false
EOF

# Compile the schemas so the system recognizes the new defaults
sudo glib-compile-schemas /usr/share/glib-2.0/schemas/

echo "Restoring sudo password requirement for wheel group"
sed -i '/^%wheel ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers
POSTINSTALLEOF