#!/usr/bin/env bash

set -e  # Exit on any error

echo "Installing required packages..."
yay -S bdf2psf otf2bdf --needed --noconfirm

echo "Creating custom fontset..."
cat /usr/share/bdf2psf/fontsets/* | sort -u > custom-max.fontset
char_count=$(wc -l < custom-max.fontset)
echo "Custom fontset created with $char_count characters"

echo "Finding JetBrains font..."
jetbrains_location=""
for pattern in "JetBrainsMonoNerdFontPropo-Regular.ttf" "JetBrainsMono-Regular.ttf" "JetBrainsMonoNerdFont-Regular.ttf"; do
    jetbrains_location=$(find /usr/share/fonts /usr/local/share/fonts ~/.local/share/fonts -type f -name "$pattern" 2>/dev/null | head -n 1)
    if [ -n "$jetbrains_location" ]; then
        break
    fi
done

if [ -z "$jetbrains_location" ]; then
    echo "Error: JetBrains font not found! Please install it first."
    echo "Try: yay -S ttf-jetbrains-mono-nerd"
    exit 1
fi

echo "Found font: $jetbrains_location"

echo "Converting font to BDF..."
# Use 16pt size, good for most TTYs
otf2bdf "$jetbrains_location" -p 16 -o jetbrains.bdf

echo "Converting to PSF..."
bdf2psf jetbrains.bdf /usr/share/bdf2psf/standard.equivalents ./custom-max.fontset "$char_count" jetbrains.psf

echo "Installing font..."
font_name="JetBrainsMonoNerdFont"
font_path="/usr/share/kbd/consolefonts/${font_name}.psf"

# Remove old version if exists
if [ -f "${font_path}.gz" ]; then
    sudo rm "${font_path}.gz"
fi

sudo cp jetbrains.psf "$font_path"
sudo gzip "$font_path"

echo "Font installed successfully!"
echo "To use it, run: sudo setfont $font_name"
echo "To make it permanent, add 'FONT=$font_name' to /etc/vconsole.conf"

# Clean up temporary files
rm -f jetbrains.bdf jetbrains.psf custom-max.fontset