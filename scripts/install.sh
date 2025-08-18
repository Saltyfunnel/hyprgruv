#!/bin/bash
# A one-stop script for installing a Gruvbox-themed Hyprland setup on Arch Linux.
# This script handles both system-level and user-level tasks in a single run,
# using only official Arch Linux repositories via pacman.
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

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root. Please run with 'sudo bash $0'."
fi

# Define variables
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
    print_error "Required 'configs' directory not found in the script's directory: $SCRIPT_DIR.
    Please ensure the entire repository is cloned and you are running the script from its root directory."
fi
print_success "✅ File structure confirmed."

if ! command -v git &>/dev/null; then
    print_error "git is not installed. Please install it with 'sudo pacman -S git'."
fi
if ! command -v curl &>/dev/null; then
    print_error "curl is not installed. Please install it with 'sudo pacman -S curl'."
fi
print_success "✅ Required tools (git, curl) confirmed."

# --- System-level tasks ---
print_header "Starting System-Level Setup"

# Update system and install required packages with pacman
if [ "$CONFIRMATION" == "yes" ]; then
    read -p "Update system and install packages? Press Enter to continue..."
fi
PACKAGES=(
    git base-devel pipewire wireplumber pamixer brightnessctl
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
    sddm kitty nano tar unzip gnome-disk-utility code mpv dunst pacman-contrib exo firefox cava steam
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
    waybar hyprland hyprpaper hypridle hyprlock starship fastfetch
)
if ! pacman -Syu "${PACKAGES[@]:-}" --noconfirm; then
    print_error "Failed to install system packages."
fi
print_success "✅ System updated and packages installed."

# --- GPU Driver Installation ---
print_header "Installing GPU Drivers"
GPU_INFO=$(lspci | grep -Ei "VGA|3D")

if echo "$GPU_INFO" | grep -qi "nvidia"; then
    print_bold_blue "NVIDIA GPU detected."
    run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    print_bold_blue "AMD GPU detected."
    run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    print_bold_blue "Intel GPU detected."
    run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers"
else
    print_warning "No supported GPU detected. Info: $GPU_INFO"
    if [ "$CONFIRMATION" == "yes" ]; then
        read -p "Try installing NVIDIA drivers anyway? [Y/n]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers (forced)"
        fi
    fi
fi
print_success "✅ GPU driver installation complete."

# Enable services
if [ "$CONFIRMATION" == "yes" ]; then
    read -p "Enable system services? Press Enter to continue..."
fi
systemctl enable --now polkit.service
systemctl enable sddm.service
print_success "✅ System services enabled."

print_success "\n✅ System-level setup is complete! Now starting user-level setup."

# --- User-level tasks (executed as the user via sudo) ---
print_header "Starting User-Level Setup"

# No AUR packages to install in this version of the script.

copy_configs() {
    local source_dir="$1"
    local dest_dir="$2"
    local config_name="$3"

    print_success "Copying $config_name from '$source_dir' to '$dest_dir'."
    if ! sudo -u "$USER_NAME" mkdir -p "$dest_dir"; then
        print_warning "Failed to create destination directory for $config_name: '$dest_dir'."
        return 1
    fi
    if ! sudo -u "$USER_NAME" cp -r "$source_dir/." "$dest_dir"; then
        print_warning "Failed to copy $config_name."
        return 1
    fi
    print_success "✅ Copied $config_name."
    return 0
}

print_header "Copying configuration files"
copy_configs "$SCRIPT_DIR/configs/waybar" "$CONFIG_DIR/waybar" "Waybar"
copy_configs "$SCRIPT_DIR/configs/hypr" "$CONFIG_DIR/hypr" "Hyprland"
copy_configs "$SCRIPT_DIR/configs/kitty" "$CONFIG_DIR/kitty" "Kitty"
copy_configs "$SCRIPT_DIR/configs/dunst" "$CONFIG_DIR/dunst" "Dunst"

# --- Setting up GTK themes and icons from their git repositories ---
print_header "Installing GTK themes and icons"

# --- Variables ---
THEME_REPO="https://github.com/Fausto-Korpsvart/Gruvbox-GTK-Theme.git"
ICONS_REPO="https://github.com/SylEleuth/gruvbox-plus-icon-pack.git"

THEMES_DIR="$USER_HOME/.themes"
ICONS_DIR="$USER_HOME/.icons"

# Create a temporary directory for cloning
TEMP_DIR=$(mktemp -d)
print_success "Created temporary directory: $TEMP_DIR"

# Clone the repositories
print_success "Cloning Gruvbox GTK Theme from $THEME_REPO..."
sudo -u "$USER_NAME" git clone --depth 1 "$THEME_REPO" "$TEMP_DIR/Gruvbox-GTK-Theme"

print_success "Cloning Gruvbox Plus Icon Pack from $ICONS_REPO..."
sudo -u "$USER_NAME" git clone --depth 1 "$ICONS_REPO" "$TEMP_DIR/gruvbox-plus-icon-pack"

# Create destination directories if they don't exist
sudo -u "$USER_NAME" mkdir -p "$THEMES_DIR"
sudo -u "$USER_NAME" mkdir -p "$ICONS_DIR"

# Move the cloned files to their final destinations
print_success "Moving theme files to $THEMES_DIR..."
# The GTK theme repo has multiple variants, we'll move the whole folder.
if [ -d "$TEMP_DIR/Gruvbox-GTK-Theme" ]; then
    sudo -u "$USER_NAME" mv "$TEMP_DIR/Gruvbox-GTK-Theme"/* "$THEMES_DIR"
fi

print_success "Moving icon pack files to $ICONS_DIR..."
# The icon pack repo has a specific folder name to move.
if [ -d "$TEMP_DIR/gruvbox-plus-icon-pack/Gruvbox-Plus-Dark" ]; then
    sudo -u "$USER_NAME" mv "$TEMP_DIR/gruvbox-plus-icon-pack/Gruvbox-Plus-Dark" "$ICONS_DIR"
fi

# Clean up the temporary directory
print_success "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

print_success "✅ Gruvbox GTK theme and icons installed."

# The key addition: Update the icon cache to ensure icons are found by applications like Thunar.
if command -v gtk-update-icon-cache &>/dev/null; then
    print_success "Updating the GTK icon cache for a smooth user experience..."
    sudo -u "$USER_NAME" gtk-update-icon-cache -f -t "$ICONS_DIR/Gruvbox-Plus-Dark"
    print_success "✅ GTK icon cache updated successfully."
else
    print_warning "gtk-update-icon-cache not found. Icons may not appear correctly until a reboot."
fi

GTK3_CONFIG="$CONFIG_DIR/gtk-3.0"
GTK4_CONFIG="$CONFIG_DIR/gtk-4.0"
sudo -u "$USER_NAME" mkdir -p "$GTK3_CONFIG" "$GTK4_CONFIG"

GTK_SETTINGS="[Settings]\ngtk-theme-name=gruvbox-gtk\ngtk-icon-theme-name=Gruvbox\ngtk-font-name=JetBrainsMono 10"
sudo -u "$USER_NAME" bash -c "echo -e \"$GTK_SETTINGS\" | tee \"$GTK3_CONFIG/settings.ini\" \"$GTK4_CONFIG/settings.ini\" >/dev/null"

if command -v gsettings &>/dev/null; then
    print_success "Using gsettings to apply GTK themes."
    sudo -u "$USER_NAME" gsettings set org.gnome.desktop.interface gtk-theme "gruvbox-gtk"
    sudo -u "$USER_NAME" gsettings set org.gnome.desktop.interface icon-theme "Gruvbox"
    print_success "✅ Themes applied with gsettings."
else
    print_warning "gsettings not found. Themes may not apply correctly to all applications."
fi

HYPR_VARS_FILE="$CONFIG_DIR/hypr/hypr-vars.conf"
sudo -u "$USER_NAME" tee "$HYPR_VARS_FILE" >/dev/null <<'EOF_HYPR_VARS'
# Set GTK theme and icon theme
env = GTK_THEME,gruvbox-gtk
env = ICON_THEME,Gruvbox
# Set XDG desktop to Hyprland
env = XDG_CURRENT_DESKTOP,Hyprland
EOF_HYPR_VARS

# We are going to make sure that the hyprland.conf file sources all of the necessary configs that we are providing,
# and also launches the required apps that we installed with pacman.
print_header "Updating hyprland.conf with necessary 'exec-once' commands"
HYPR_CONF="$CONFIG_DIR/hypr/hyprland.conf"
# Sourced by the setup script to set GTK and icon themes
if [ -f "$HYPR_CONF" ] && ! grep -q "source = $HYPR_VARS_FILE" "$HYPR_CONF"; then
    sudo -u "$USER_NAME" echo -e "\n# Sourced by the setup script to set GTK and icon themes\nsource = $HYPR_VARS_FILE" >> "$HYPR_CONF"
fi
# Launch hyprpaper for wallpaper management
if [ -f "$HYPR_CONF" ] && ! grep -q "exec-once = hyprpaper" "$HYPR_CONF"; then
    sudo -u "$USER_NAME" echo -e "\n# Launch hyprpaper for wallpaper management\nexec-once = hyprpaper" >> "$HYPR_CONF"
fi
# Launch waybar
if [ -f "$HYPR_CONF" ] && ! grep -q "exec-once = waybar" "$HYPR_CONF"; then
    sudo -u "$USER_NAME" echo -e "\n# Launch waybar, the status bar\nexec-once = waybar" >> "$HYPR_CONF"
fi
# Launch dunst for notifications
if [ -f "$HYPR_CONF" ] && ! grep -q "exec-once = dunst" "$HYPR_CONF"; then
    sudo -u "$USER_NAME" echo -e "\n# Launch dunst, the notification daemon\nexec-once = dunst" >> "$HYPR_CONF"
fi
# Launch hypridle for power management and locking
if [ -f "$HYPR_CONF" ] && ! grep -q "exec-once = hypridle" "$HYPR_CONF"; then
    sudo -u "$USER_NAME" echo -e "\n# Launch hypridle for power management and locking\nexec-once = hypridle" >> "$HYPR_CONF"
fi
print_success "✅ hyprland.conf updated with core components."


print_header "Creating backgrounds directory"
WALLPAPER_SRC="$SCRIPT_DIR/assets/backgrounds"
WALLPAPER_DEST="$CONFIG_DIR/assets/backgrounds"
if [ ! -d "$WALLPAPER_SRC" ]; then
    print_warning "Source backgrounds directory not found. Creating a placeholder directory at $WALLPAPER_SRC. Please place your wallpapers there."
    sudo -u "$USER_NAME" mkdir -p "$WALLPAPER_SRC"
else
    print_success "✅ Source backgrounds directory exists."
fi

print_success "Copying backgrounds from '$WALLPAPER_SRC' to '$WALLPAPER_DEST'."
sudo -u "$USER_NAME" mkdir -p "$WALLPAPER_DEST"
sudo -u "$USER_NAME" cp -r "$WALLPAPER_SRC/." "$WALLPAPER_DEST"
print_success "✅ Wallpapers copied to $WALLPAPER_DEST."

print_header "Configuring hyprpaper"
HYPRPAPER_CONF="$CONFIG_DIR/hypr/hyprpaper.conf"
if [ ! -f "$HYPRPAPER_CONF" ]; then
    print_warning "hyprpaper.conf not found, creating a new one."
    # Create the file with the correct content
    sudo -u "$USER_NAME" tee "$HYPRPAPER_CONF" >/dev/null <<'EOF_HYPRPAPER'
# Preload your wallpaper
# The path should be an absolute path to your wallpaper file
preload = ~/.config/assets/backgrounds/default.png
# set the wallpaper for a workspace
wallpaper = ,~/.config/assets/backgrounds/default.png
# Or to use a specific wallpaper for a specific monitor:
# wallpaper = HDMI-A-1,~/.config/assets/backgrounds/default.png
EOF_HYPRPAPER
else
    print_success "hyprpaper.conf exists, updating."
    # Add preload and wallpaper lines if they don't exist
    if ! sudo -u "$USER_NAME" grep -q "preload" "$HYPRPAPER_CONF"; then
        sudo -u "$USER_NAME" echo "preload = ~/.config/assets/backgrounds/default.png" >> "$HYPRPAPER_CONF"
    fi
    if ! sudo -u "$USER_NAME" grep -q "wallpaper" "$HYPRPAPER_CONF"; then
        sudo -u "$USER_NAME" echo "wallpaper = ,~/.config/assets/backgrounds/default.png" >> "$HYPR_CONF"
    fi
fi
print_success "✅ hyprpaper configured."


print_header "Setting up Thunar custom action"
UCA_DIR="$CONFIG_DIR/Thunar"
UCA_FILE="$UCA_DIR/uca.xml"
sudo -u "$USER_NAME" mkdir -p "$UCA_DIR"
sudo -u "$USER_NAME" chmod 700 "$UCA_DIR"

if [ ! -f "$UCA_FILE" ]; then
    sudo -u "$USER_NAME" tee "$UCA_FILE" >/dev/null <<'EOF_UCA'
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
EOF_UCA
fi
print_success "✅ Thunar action configured."

sudo -u "$USER_NAME" pkill thunar || true
sudo -u "$USER_NAME" thunar &
print_success "✅ Thunar restarted."

print_success "\n🎉 The installation is complete! Please reboot your system to apply all changes."
