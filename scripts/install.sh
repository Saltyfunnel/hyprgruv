#!/bin/bash
# A one-stop script for installing a Gruvbox-themed Hyprland setup on Arch Linux.
# This version uses local zipped GTK theme and icon archives.

set -euo pipefail

# --- Global Helper Functions ---
print_header() {
    echo -e "\n--- \e[1m\e[34m$1\e[0m ---"
}

print_success() {
    echo -e "\e[32m$1\e[0m"
}

print_warning() {
    echo -e "\e[33mWarning: $1\e[0m" >&2
}

print_error() {
    echo -e "\e[31mError: $1\e[0m" >&2
    exit 1
}

# --- Main Execution Logic ---
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root. Please run with 'sudo bash $0'."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
THEMES_DIR="$USER_HOME/.themes"
ICONS_DIR="$USER_HOME/.icons"

# Paths to your local theme and icon archives inside repo
THEME_ZIP="$SCRIPT_DIR/assets/themes/Gruvbox-Dark-B-MB.zip"
ICON_TAR="$SCRIPT_DIR/assets/themes/gruvbox-dark-icons-gtk-1.0.0.tar.gz"

THEME_NAME="Gruvbox-Dark-B-MB"
ICONS_NAME="Gruvbox-Dark-Icons"

print_header "Checking required files"
if [ ! -f "$THEME_ZIP" ]; then
    print_error "GTK theme zip not found at $THEME_ZIP"
fi
if [ ! -f "$ICON_TAR" ]; then
    print_error "Icon tarball not found at $ICON_TAR"
fi

print_header "Installing GTK theme from local zip"

# Create themes dir if missing
sudo -u "$USER_NAME" mkdir -p "$THEMES_DIR"

# Extract theme zip to temp dir as root
TMP_THEME_DIR=$(mktemp -d)
unzip -q "$THEME_ZIP" -d "$TMP_THEME_DIR"

# Find extracted folder (should be one folder inside)
EXTRACTED_THEME_DIR=$(find "$TMP_THEME_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)
if [ -z "$EXTRACTED_THEME_DIR" ]; then
    print_error "Could not find extracted theme folder inside zip."
fi

# Remove any existing theme folder and move extracted one into ~/.themes
rm -rf "$THEMES_DIR/$THEME_NAME"
mv "$EXTRACTED_THEME_DIR" "$THEMES_DIR/$THEME_NAME"
chown -R "$USER_NAME":"$USER_NAME" "$THEMES_DIR/$THEME_NAME"
rm -rf "$TMP_THEME_DIR"

print_success "✅ GTK theme installed to $THEMES_DIR/$THEME_NAME"

print_header "Installing icon theme from local tarball"

# Create icons dir if missing
sudo -u "$USER_NAME" mkdir -p "$ICONS_DIR"

TMP_ICON_DIR=$(mktemp -d)
tar -xf "$ICON_TAR" -C "$TMP_ICON_DIR"

# Find extracted icon folder
EXTRACTED_ICON_DIR=$(find "$TMP_ICON_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)
if [ -z "$EXTRACTED_ICON_DIR" ]; then
    print_error "Could not find extracted icon folder inside tarball."
fi

# Remove existing icons and move extracted icons into ~/.icons
rm -rf "$ICONS_DIR/$ICONS_NAME"
mv "$EXTRACTED_ICON_DIR" "$ICONS_DIR/$ICONS_NAME"
chown -R "$USER_NAME":"$USER_NAME" "$ICONS_DIR/$ICONS_NAME"
rm -rf "$TMP_ICON_DIR"

print_success "✅ Icon theme installed to $ICONS_DIR/$ICONS_NAME"

print_header "Updating GTK and icon theme settings"

GTK3_CONFIG="$CONFIG_DIR/gtk-3.0"
GTK4_CONFIG="$CONFIG_DIR/gtk-4.0"
sudo -u "$USER_NAME" mkdir -p "$GTK3_CONFIG" "$GTK4_CONFIG"

echo -e "[Settings]\ngtk-theme-name=$THEME_NAME\ngtk-icon-theme-name=$ICONS_NAME\ngtk-font-name=JetBrainsMono 10" | sudo -u "$USER_NAME" tee "$GTK3_CONFIG/settings.ini" "$GTK4_CONFIG/settings.ini" >/dev/null

echo -e "gtk-theme-name=\"$THEME_NAME\"\ngtk-icon-theme-name=\"$ICONS_NAME\"" | sudo -u "$USER_NAME" tee "$USER_HOME/.gtkrc-2.0" >/dev/null

if command -v gtk-update-icon-cache &>/dev/null; then
    sudo -u "$USER_NAME" gtk-update-icon-cache -f -t "$ICONS_DIR/$ICONS_NAME"
fi

if command -v gsettings &>/dev/null; then
    sudo -u "$USER_NAME" gsettings set org.gnome.desktop.interface gtk-theme "$THEME_NAME"
    sudo -u "$USER_NAME" gsettings set org.gnome.desktop.interface icon-theme "$ICONS_NAME"
fi

print_success "✅ GTK and icon themes applied."

print_success "\n🎉 Theme installation complete. Please reboot or relogin to see changes."
