#!/bin/bash
# A one-stop script for installing a Gruvbox-themed Hyprland setup on Arch Linux.
# This version uses a prebuilt GTK theme and icon set.

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

print_bold_blue() {
    echo -e "\e[1m\e[34m$1\e[0m"
}

run_command() {
    local command="$1"
    local description="$2"
    local confirm_needed="${3:-"yes"}"

    if [ "$confirm_needed" == "yes" ] && [ "$CONFIRMATION" == "yes" ]; then
        read -p "Install '$description'? Press Enter to continue..."
    fi

    echo -e "\nRunning: $command"
    if ! eval "$command"; then
        print_error "Failed to '$description'."
    fi
    print_success "✅ Success: '$description'"
}

# --- Main Execution Logic ---
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root. Please run with 'sudo bash $0'."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
CONFIRMATION="yes"

if [[ $# -eq 1 && "$1" == "--noconfirm" ]]; then
    CONFIRMATION="no"
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--noconfirm]"
    exit 1
fi

# --- Pre-run checks ---
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

# --- System-level setup ---
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
pacman -Syu "${PACKAGES[@]}" --noconfirm
print_success "✅ System updated and packages installed."

# --- GPU drivers ---
print_header "Installing GPU Drivers"
GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers"
else
    print_warning "No supported GPU detected. Info: $GPU_INFO"
fi
print_success "✅ GPU driver installation complete."

# --- Enable services ---
systemctl enable --now polkit.service
systemctl enable sddm.service
print_success "✅ System services enabled."

# --- Copy user configs ---
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

# --- GTK Themes and Icons ---
print_header "Installing GTK themes and icons"
THEMES_DIR="$USER_HOME/.themes"
ICONS_DIR="$USER_HOME/.icons"
THEME_NAME="Gruvbox-Dark"
ICONS_NAME="Gruvbox-Plus-Dark"

sudo -u "$USER_NAME" mkdir -p "$THEMES_DIR" "$ICONS_DIR"

# Clone GTK theme (alternative repo)
TEMP_THEME_DIR=$(sudo -u "$USER_NAME" mktemp -d)
THEME_REPO_ALT="https://gitlab.com/bryos/gruvbox-gtk-theme.git"
sudo -u "$USER_NAME" git clone "$THEME_REPO_ALT" "$TEMP_THEME_DIR/gruvbox-gtk-theme"
sudo -u "$USER_NAME" cp -r "$TEMP_THEME_DIR/gruvbox-gtk-theme" "$THEMES_DIR/$THEME_NAME"
rm -rf "$TEMP_THEME_DIR"

# Clone icon theme
TEMP_ICON_DIR=$(sudo -u "$USER_NAME" mktemp -d)
ICONS_REPO="https://github.com/SylEleuth/gruvbox-plus-icon-pack.git"
sudo -u "$USER_NAME" git clone "$ICONS_REPO" "$TEMP_ICON_DIR/gruvbox-plus-icon-pack"
sudo -u "$USER_NAME" cp -r "$TEMP_ICON_DIR/gruvbox-plus-icon-pack/Gruvbox-Plus-Dark" "$ICONS_DIR/"
rm -rf "$TEMP_ICON_DIR"

if command -v gtk-update-icon-cache &>/dev/null; then
    sudo -u "$USER_NAME" gtk-update-icon-cache -f -t "$ICONS_DIR/$ICONS_NAME"
fi

GTK3_CONFIG="$CONFIG_DIR/gtk-3.0"
GTK4_CONFIG="$CONFIG_DIR/gtk-4.0"
sudo -u "$USER_NAME" mkdir -p "$GTK3_CONFIG" "$GTK4_CONFIG"
echo -e "[Settings]\ngtk-theme-name=$THEME_NAME\ngtk-icon-theme-name=$ICONS_NAME\ngtk-font-name=JetBrainsMono 10" | sudo -u "$USER_NAME" tee "$GTK3_CONFIG/settings.ini" "$GTK4_CONFIG/settings.ini" >/dev/null

echo -e "gtk-theme-name=\"$THEME_NAME\"\ngtk-icon-theme-name=\"$ICONS_NAME\"" | sudo -u "$USER_NAME" tee "$USER_HOME/.gtkrc-2.0" >/dev/null

if command -v gsettings &>/dev/null; then
    sudo -u "$USER_NAME" gsettings set org.gnome.desktop.interface gtk-theme "$THEME_NAME"
    sudo -u "$USER_NAME" gsettings set org.gnome.desktop.interface icon-theme "$ICONS_NAME"
fi

# --- Hyprland vars ---
HYPR_VARS_FILE="$CONFIG_DIR/hypr/hypr-vars.conf"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/hypr"
sudo -u "$USER_NAME" tee "$HYPR_VARS_FILE" >/dev/null <<EOF
export GTK_THEME=$THEME_NAME
export ICON_THEME=$ICONS_NAME
export XDG_CURRENT_DESKTOP=Hyprland
EOF

# --- Hyprland config updates ---
HYPR_CONF="$CONFIG_DIR/hypr/hyprland.conf"
append_once() {
    local line="$1"
    grep -qxF "$line" "$HYPR_CONF" || echo "$line" | sudo -u "$USER_NAME" tee -a "$HYPR_CONF" >/dev/null
}

append_once "source = $HYPR_VARS_FILE"
# Remove exec-once waybar to avoid double instances:
# append_once "exec-once = waybar"
append_once "exec-once = dunst"
append_once "exec-once = hypridle"
append_once "exec-once = wofi --show drun -i"
append_once "exec-once = starship init bash"

# --- Thunar custom actions ---
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
# Start thunar with environment variables so GTK theme applies correctly
sudo -u "$USER_NAME" env GTK_THEME="$THEME_NAME" GTK_ICON_THEME="$ICONS_NAME" thunar & disown &>/dev/null

print_success "✅ Thunar restarted with Gruvbox theme."

print_success "\n🎉 Installation complete. Reboot to fully apply changes."
