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

print_header "Running Pre-run Checks"

if [ ! -d "$SCRIPT_DIR/configs" ]; then
    print_error "Required 'configs' directory not found in: $SCRIPT_DIR"
fi
print_success "✅ File structure confirmed."

if ! command -v git &>/dev/null; then
    print_error "git is not installed. Please install it."
fi
if ! command -v curl &>/dev/null; then
    print_error "curl is not installed. Please install it."
fi
print_success "✅ Required tools confirmed."

print_header "Starting System-Level Setup"

PACKAGES=(
    git base-devel pipewire wireplumber pamixer brightnessctl
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
    sddm kitty nano tar unzip gnome-disk-utility code mpv dunst pacman-contrib exo firefox cava steam
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
    waybar hyprland hyprpaper hypridle hyprlock starship fastfetch wofi
    gnome-themes-extra
)
pacman -Syu --noconfirm "${PACKAGES[@]}"
print_success "✅ System updated and packages installed."

print_header "Installing GPU Drivers"

GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
elif echo "$GPU_INFO" | grep -qi "amd"; then
    pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau
elif echo "$GPU_INFO" | grep -qi "intel"; then
    pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel
else
    print_warning "No supported GPU detected. Info: $GPU_INFO"
fi
print_success "✅ GPU driver installation complete."

print_header "Enabling system services"
systemctl enable --now polkit.service
systemctl enable sddm.service
print_success "✅ System services enabled."

print_header "Copying configuration files"
copy_configs() {
    local source_dir="$1"
    local dest_dir="$2"
    local config_name="$3"

    print_success "Copying $config_name from '$source_dir' to '$dest_dir'."
    sudo -u "$USER_NAME" mkdir -p "$dest_dir"
    sudo -u "$USER_NAME" cp -r "$source_dir/." "$dest_dir"
    print_success "✅ Copied $config_name."
}

copy_configs "$SCRIPT_DIR/configs/waybar" "$CONFIG_DIR/waybar" "Waybar"
copy_configs "$SCRIPT_DIR/configs/hypr" "$CONFIG_DIR/hypr" "Hyprland"
copy_configs "$SCRIPT_DIR/configs/kitty" "$CONFIG_DIR/kitty" "Kitty"
copy_configs "$SCRIPT_DIR/configs/dunst" "$CONFIG_DIR/dunst" "Dunst"
copy_configs "$SCRIPT_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch" "Fastfetch"
# Starship.toml is a file, so copy it directly:
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"
sudo -u "$USER_NAME" cp "$SCRIPT_DIR/configs/starship/starship.toml" "$CONFIG_DIR/starship.toml"
print_success "✅ Copied Starship configuration."
copy_configs "$SCRIPT_DIR/configs/wofi" "$CONFIG_DIR/wofi" "Wofi"

print_header "Installing GTK theme from local zip"

sudo -u "$USER_NAME" mkdir -p "$THEMES_DIR"
TMP_THEME_DIR=$(mktemp -d)
unzip -q "$THEME_ZIP" -d "$TMP_THEME_DIR"
EXTRACTED_THEME_DIR=$(find "$TMP_THEME_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)
if [ -z "$EXTRACTED_THEME_DIR" ]; then
    print_error "Could not find extracted theme folder inside zip."
fi
rm -rf "$THEMES_DIR/$THEME_NAME"
mv "$EXTRACTED_THEME_DIR" "$THEMES_DIR/$THEME_NAME"
chown -R "$USER_NAME":"$USER_NAME" "$THEMES_DIR/$THEME_NAME"
rm -rf "$TMP_THEME_DIR"
print_success "✅ GTK theme installed to $THEMES_DIR/$THEME_NAME"

print_header "Installing icon theme from local tarball"

sudo -u "$USER_NAME" mkdir -p "$ICONS_DIR"
TMP_ICON_DIR=$(mktemp -d)
tar -xf "$ICON_TAR" -C "$TMP_ICON_DIR"
EXTRACTED_ICON_DIR=$(find "$TMP_ICON_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)
if [ -z "$EXTRACTED_ICON_DIR" ]; then
    print_error "Could not find extracted icon folder inside tarball."
fi
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

print_header "Setting up Thunar custom action"

UCA_DIR="$CONFIG_DIR/Thunar"
UCA_FILE="$UCA_DIR/uca.xml"
sudo -u "$USER_NAME" mkdir -p "$UCA_DIR"
sudo -u "$USER_NAME" chmod 700 "$UCA_DIR"

if [ ! -f "$UCA_FILE" ]; then
    sudo -u "$USER_NAME" tee "$UCA_FILE" >/dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<actions>
    <action>
        <icon>utilities-terminal</icon>
        <name>Open Kitty Here</name>
        <command>kitty --directory=%d</command>
        <description>Open kitty terminal in the current folder</description>
        <patterns>*</patterns>
        <directories_only>true</directories_only>
        <startup_notify>true</startup_notify>
    </action>
</actions>
EOF
fi

pkill thunar &>/dev/null || true
sudo -u "$USER_NAME" env GTK_THEME="$THEME_NAME" GTK_ICON_THEME="$ICONS_NAME" thunar & disown &>/dev/null

print_success "✅ Thunar restarted with Gruvbox theme."

print_success "\n🎉 Installation complete. Reboot or relogin to fully apply changes."
