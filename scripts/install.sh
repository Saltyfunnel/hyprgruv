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
    gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome gtk-engine-murrine
    waybar hyprland hyprpaper hypridle hyprlock starship fastfetch wofi
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
copy_configs "$SCRIPT_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch" "Fastfetch"
copy_configs "$SCRIPT_DIR/configs/wofi" "$CONFIG_DIR/wofi" "Wofi"

# Copy the starship.toml file to the root of the .config directory
print_success "Copying starship.toml to $CONFIG_DIR/starship.toml"
if [ -f "$SCRIPT_DIR/configs/starship/starship.toml" ]; then
    if sudo -u "$USER_NAME" cp "$SCRIPT_DIR/configs/starship/starship.toml" "$CONFIG_DIR/starship.toml"; then
        print_success "✅ Copied starship.toml to ~/.config/starship.toml."
    else
        print_warning "Failed to copy starship.toml. The default configuration will be used."
    fi
else
    print_warning "starship.toml not found in the source directory. The default configuration will be used."
fi

# --- Automatic Download of GTK themes and Icons with Git ---
print_header "Downloading and setting up GTK themes and icons with Git"
THEMES_DIR="$USER_HOME/.themes"
ICONS_DIR="$USER_HOME/.icons"
TEMP_DIR="/tmp/gruvbox-setup"

# Clean up old temporary and theme directories
print_success "Cleaning up old theme, icon, and temporary directories..."
sudo -u "$USER_NAME" rm -rf "$THEMES_DIR/gruvbox-gtk" "$ICONS_DIR/Gruvbox" "$TEMP_DIR"
print_success "✅ Old directories removed."

# Clone the GTK theme
GTK_THEME_REPO="https://github.com/Fausto-Korpsvart/Gruvbox-GTK-Theme.git"
print_success "Cloning Gruvbox GTK theme..."
if ! sudo -u "$USER_NAME" git clone --depth 1 "$GTK_THEME_REPO" "$TEMP_DIR/gruvbox-gtk"; then
    print_error "Failed to clone Gruvbox GTK theme from '$GTK_THEME_REPO'."
fi
print_success "✅ GTK theme cloned successfully."

# Move the theme to its final location
print_success "Installing Gruvbox GTK theme..."
sudo -u "$USER_NAME" mkdir -p "$THEMES_DIR"
sudo -u "$USER_NAME" mv "$TEMP_DIR/gruvbox-gtk" "$THEMES_DIR/gruvbox-gtk"
print_success "✅ Gruvbox GTK theme installation completed."

# Clone the icon pack
# CHANGED REPOSITORY TO A DIFFERENT GRUVBOX ICON PACK.
ICONS_REPO="https://github.com/telmo-g/gruvbox-icons.git"
print_success "Cloning Gruvbox Icons..."
if ! sudo -u "$USER_NAME" git clone --depth 1 "$ICONS_REPO" "$TEMP_DIR/Gruvbox"; then
    print_error "Failed to clone Gruvbox Icons from '$ICONS_REPO'."
fi
print_success "✅ Icons cloned successfully."

# Move the icon pack to its final location
print_success "Installing Gruvbox Icons..."
sudo -u "$USER_NAME" mkdir -p "$ICONS_DIR"
sudo -u "$USER_NAME" mv "$TEMP_DIR/Gruvbox" "$ICONS_DIR/Gruvbox"
print_success "✅ Gruvbox Icons installation completed."

# Update the icon cache to ensure icons are found by applications like Thunar.
if command -v gtk-update-icon-cache &>/dev/null; then
    print_success "Updating the GTK icon cache for a smooth user experience..."
    sudo -u "$USER_NAME" gtk-update-icon-cache -f -t "$ICONS_DIR/Gruvbox"
    print_success "✅ GTK icon cache updated successfully."
else
    print_warning "gtk-update-icon-cache not found. Icons may not appear correctly until a reboot."
fi

GTK3_CONFIG="$CONFIG_DIR/gtk-3.0"
GTK4_CONFIG="$CONFIG_DIR/gtk-4.0"
sudo -u "$USER_NAME" mkdir -p "$GTK3_CONFIG" "$GTK4_CONFIG"

GTK_SETTINGS="[Settings]\ngtk-theme-name=gruvbox-gtk\ngtk-icon-theme-name=Gruvbox\ngtk-font-name=JetBrainsMono 10"
sudo -u "$USER_NAME" bash -c "echo -e \"$GTK_SETTINGS\" | tee \"$GTK3_CONFIG/settings.ini\" \"$GTK4_CONFIG/settings.ini\" >/dev/null"

# --- New, robust block to handle gsettings and Thunar restart ---
print_header "Applying GTK themes with gsettings and restarting Thunar"
sudo -u "$USER_NAME" bash <<EOF_GSETTINGS
    set -euo pipefail
    
    # Get the user's UID and DBUS path in the correct context
    USER_UID=$(id -u)
    DBUS_PATH="unix:path=/run/user/${USER_UID}/bus"
    
    # GSettings commands
    if command -v gsettings &>/dev/null; then
        echo 'Using gsettings to apply GTK themes.'
        env DBUS_SESSION_BUS_ADDRESS="${DBUS_PATH}" gsettings set org.gnome.desktop.interface gtk-theme "gruvbox-gtk"
        env DBUS_SESSION_BUS_ADDRESS="${DBUS_PATH}" gsettings set org.gnome.desktop.interface icon-theme "Gruvbox"
        echo '✅ Themes applied with gsettings.'
    else
        echo 'gsettings not found. Themes may not apply correctly to all applications.'
    fi
    
    # Thunar restart commands
    if command -v thunar &>/dev/null; then
        echo 'Restarting Thunar to apply changes'
        env DBUS_SESSION_BUS_ADDRESS="${DBUS_PATH}" pkill thunar || true
        env DBUS_SESSION_BUS_ADDRESS="${DBUS_PATH}" thunar &
        echo '✅ Thunar restarted successfully.'
    else
        echo 'Thunar not found, skipping restart.'
    fi
EOF_GSETTINGS
# --- End of new block ---

# Configure starship and fastfetch prompt
print_header "Configuring Starship and Fastfetch prompt"
if [ -f "$USER_HOME/.bashrc" ]; then
    # Starship
    if ! sudo -u "$USER_NAME" grep -q "eval \"\$(starship init bash)\"" "$USER_HOME/.bashrc"; then
        sudo -u "$USER_NAME" echo -e "\n# Starship prompt\neval \"\$(starship init bash)\"" >> "$USER_HOME/.bashrc"
        print_success "✅ Added starship to .bashrc."
    else
        print_success "✅ Starship already configured in .bashrc, skipping."
    fi

    # Fastfetch
    if ! sudo -u "$USER_NAME" grep -q "fastfetch" "$USER_HOME/.bashrc"; then
        sudo -u "$USER_NAME" echo -e "\n# Run fastfetch on terminal startup\nfastfetch" >> "$USER_HOME/.bashrc"
        print_success "✅ Added fastfetch to .bashrc."
    else
        print_success "✅ Fastfetch already configured in .bashrc, skipping."
    fi
else
    print_warning ".bashrc not found, skipping starship and fastfetch configuration. Please add them to your shell's config file."
fi

# We are going to make sure that the hyprland.conf file sources all of the necessary configs that we are providing,
# and also launches the required apps that we installed with pacman.
print_header "Updating hyprland.conf with necessary 'exec-once' commands and keybindings"
HYPR_CONF="$CONFIG_DIR/hypr/hyprland.conf"
# Sourced by the setup script to set GTK and icon themes
HYPR_VARS_FILE="$CONFIG_DIR/hypr/hypr-vars.conf"
sudo -u "$USER_NAME" tee "$HYPR_VARS_FILE" >/dev/null <<'EOF_HYPR_VARS'
# Set GTK theme and icon theme
env = GTK_THEME,gruvbox-gtk
env = ICON_THEME,Gruvbox
# Set XDG desktop to Hyprland
env = XDG_CURRENT_DESKTOP,Hyprland
EOF_HYPR_VARS
if [ -f "$HYPR_CONF" ] && ! grep -q "source = $HYPR_VARS_FILE" "$HYPR_CONF"; then
    sudo -u "$USER_NAME" echo -e "\n# Sourced by the setup script to set GTK and icon themes\nsource = $HYPR_VARS_FILE" >> "$HYPR_CONF"
fi
# Launch hyprpaper for wallpaper management
if [ -f "$HYPR_CONF" ] && ! grep -q "exec-once = hyprpaper" "$HYPR_CONF"; then
    sudo -u "$USER_NAME" echo -e "\n# Launch hyprpaper for wallpaper management\nexec-once = hyprpaper" >> "$HYPR_CONF"
fi
# Launch waybar in the background so it doesn't block Hyprland
if [ -f "$HYPR_CONF" ] && ! grep -q "exec-once = waybar &" "$HYPR_CONF"; then
    # Check for and remove the old line if it exists
    sudo -u "$USER_NAME" sed -i '/^exec-once = waybar/d' "$HYPR_CONF"
    sudo -u "$USER_NAME" echo -e "\n# Launch waybar, the status bar\nexec-once = waybar &" >> "$HYPR_CONF"
fi
# Launch dunst for notifications
if [ -f "$HYPR_CONF" ] && ! grep -q "exec-once = dunst" "$HYPR_CONF"; then
    sudo -u "$USER_NAME" echo -e "\n# Launch dunst, the notification daemon\nexec-once = dunst" >> "$HYPR_CONF"
fi
# Launch hypridle for power management and locking
if [ -f "$HYPR_CONF" ] && ! grep -q "exec-once = hypridle" "$HYPR_CONF"; then
    sudo -u "$USER_NAME" echo -e "\n# Launch hypridle for power management and locking\nexec-once = hypridle" >> "$HYPR_CONF"
fi
# Wofi Keybinding
if [ -f "$HYPR_CONF" ] && ! grep -q "bind = \$mainMod, D, exec, wofi --show drun" "$HYPR_CONF"; then
    sudo -u "$USER_NAME" echo -e "\n# Wofi App Launcher keybinding\nbind = \$mainMod, D, exec, wofi --show drun" >> "$HYPR_CONF"
fi
print_success "✅ hyprland.conf updated with core components and keybindings."


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
