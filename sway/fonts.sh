#!/usr/bin/env bash
# Arabic + English Noto Fonts + JetBrainsMono Nerd Font setup on Debian (Colorful Version)

set -e

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
BOLD="\e[1m"
RESET="\e[0m"

info()    { echo -e "${BLUE}${BOLD}➤${RESET} $1"; }
success() { echo -e "${GREEN}${BOLD}✔${RESET} $1"; }
warn()    { echo -e "${YELLOW}${BOLD}⚠${RESET} $1"; }
error()   { echo -e "${RED}${BOLD}✖${RESET} $1"; }

# Step 1: Install Noto Fonts
info "Installing Font Awesome and Noto fonts (English + Arabic)..."
sudo apt update
sudo apt install -y fonts-font-awesome fonts-noto-core fonts-noto-unhinted curl
success "Noto fonts installed."

# Step 2: Create fontconfig directory
info "Creating fontconfig directory..."
mkdir -p ~/.config/fontconfig
success "~/.config/fontconfig ready."

# Step 3: Write fonts.conf
FONTCONF=~/.config/fontconfig/fonts.conf
info "Writing fonts.conf..."
cat > "$FONTCONF" <<'EOF'
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <!-- Defaults -->
  <alias>
    <family>serif</family>
    <prefer>
      <family>Noto Serif</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>
  <alias>
    <family>sans</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer>
      <family>JetBrainsMono Nerd Font Mono</family>
      <family>Noto Sans Mono</family>
    </prefer>
  </alias>
  <!-- Arial -->
  <alias>
    <family>Arial</family>
    <prefer>
      <family>Noto Sans</family>
      <family>Noto Sans Arabic</family>
    </prefer>
  </alias>
</fontconfig>
EOF
success "fonts.conf written to $FONTCONF"

# Step 4: Install JetBrainsMono Nerd Font
info "Installing JetBrainsMono Nerd Font..."
mkdir -p ~/.local/share/fonts
pushd ~/.local/share/fonts > /dev/null
curl -sLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
bash -c 'mkdir -p "${1%.tar.xz}" && tar -xf "$1" -C "${1%.tar.xz}"' _ JetBrainsMono.tar.xz
rm JetBrainsMono.tar.xz
popd > /dev/null
success "JetBrainsMono Nerd Font installed."

# Step 5: Refresh font cache
info "Refreshing font cache..."
fc-cache -fv > /dev/null
success "Font cache updated."

echo -e "\n${GREEN}${BOLD}✅ Setup complete!${RESET}"
echo -e "🔍 Test with:\n  fc-match 'Noto Sans Arabic'\n  fc-match 'JetBrainsMono Nerd Font Mono'\n"