by#!/bin/bash
# One-shot NVIDIA-ready Hyprland + Pywal + Tofi bootstrap (Arch Linux)
# Fully automatic: installs packages, drivers, configs, and helper scripts

set -euo pipefail

# --- Helpers ----------------------------------------------------------------
ce() { echo -e "\e[1;34m[SETUP]\e[0m $*"; }
ok() { echo -e "\e[32m[OK]\e[0m $*"; }
warn() { echo -e "\e[33m[WARN]\e[0m $*"; }

# Elevate if not root
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    ce "Elevating with sudo..."
    exec sudo -E bash "$0" "$@"
fi

# Detect real user
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
as_user() { sudo -u "$USER_NAME" bash -lc "$*"; }

# ---------------------------------------------------------------------------
# NVIDIA driver setup
# ---------------------------------------------------------------------------
ce "Checking for NVIDIA GPU..."
GPU_INFO=$(lspci | grep -Ei "VGA|3D")

if echo "$GPU_INFO" | grep -qi "nvidia"; then
    ce "NVIDIA GPU detected. Installing drivers..."
    pacman -S --needed --noconfirm nvidia nvidia-utils libglvnd vulkan-icd-loader lib32-nvidia-utils

    # Hybrid laptop check
    if echo "$GPU_INFO" | grep -qi "intel"; then
        warn "Hybrid Intel + NVIDIA detected. Installing nvidia-prime..."
        pacman -S --needed --noconfirm nvidia-prime
    fi

    ce "Setting environment variables for NVIDIA + Wayland..."
    PROFILE_FILE="$USER_HOME/.profile"
    grep -qxF 'export WLR_NO_HARDWARE_CURSORS=1' "$PROFILE_FILE" || echo 'export WLR_NO_HARDWARE_CURSORS=1' >> "$PROFILE_FILE"
    grep -qxF 'export WLR_DRM_DEVICES=/dev/dri/card1' "$PROFILE_FILE" || echo 'export WLR_DRM_DEVICES=/dev/dri/card1' >> "$PROFILE_FILE"

    ok "NVIDIA drivers installed and WLR variables set. Reboot required for full effect."
else
    ok "No NVIDIA GPU detected. Skipping NVIDIA driver setup."
fi

# ---------------------------------------------------------------------------
# 1. Install official packages
# ---------------------------------------------------------------------------
ce "Installing official packages..."
pacman -Sy --needed --noconfirm \
  hyprland waybar kitty dunst starship \
  pipewire wireplumber swww python-pywal \
  xdg-desktop-portal xdg-desktop-portal-hyprland \
  git base-devel firefox mpv wget
ok "Official packages installed."

# ---------------------------------------------------------------------------
# 2. Bootstrap yay (AUR helper)
# ---------------------------------------------------------------------------
if ! as_user 'command -v yay >/dev/null'; then
    ce "Bootstrapping yay (AUR)..."
    as_user 'rm -rf ~/yay && git clone https://aur.archlinux.org/yay.git ~/yay'
    as_user 'cd ~/yay && makepkg -si --noconfirm'
    ok "yay installed."
else
    ok "yay already present."
fi

# ---------------------------------------------------------------------------
# 3. Install AUR packages
# ---------------------------------------------------------------------------
ce "Installing AUR packages (tofi + fonts)..."
as_user 'yay -S --needed --noconfirm tofi ttf-jetbrains-mono-nerd'
ok "AUR packages installed."

# ---------------------------------------------------------------------------
# 4. Create directory structure
# ---------------------------------------------------------------------------
ce "Creating config directories..."
as_user "mkdir -p $CONFIG_DIR/{hypr,waybar,kitty,dunst,tofi,starship,gtk-3.0,scripts,assets} $USER_HOME/Pictures/wallpapers"
ok "Directories ready."

# ---------------------------------------------------------------------------
# 5. Default wallpaper
# ---------------------------------------------------------------------------
ce "Setting default wallpaper..."
as_user "wget -qO '$CONFIG_DIR/assets/wallpaper.jpg' https://picsum.photos/1920/1080"
ok "Wallpaper placed."

# ---------------------------------------------------------------------------
# 6. Hyprland config
# ---------------------------------------------------------------------------
ce "Creating Hyprland config..."
cat > "$CONFIG_DIR/hypr/hyprland.conf" <<'EOF'
monitor=,preferred,auto,auto

# Autostart services
exec-once = swww-daemon
exec-once = ~/.config/scripts/apply-pywal.sh -R
exec-once = waybar
exec-once = dunst

# Keybinds
bind = SUPER, RETURN, exec, kitty
bind = SUPER, E, exec, ~/.config/scripts/switch-wallpaper.sh
bind = SUPER, R, exec, tofi-drun | xargs -r hyprctl dispatch exec --

# Basic look
general {
  gaps_in = 6
  gaps_out = 10
  border_size = 2
}

# Colors sourced from apply-pywal.sh
source = ~/.config/hypr/colors-hypr.conf
EOF
chown "$USER_NAME":"$USER_NAME" "$CONFIG_DIR/hypr/hyprland.conf"
ok "Hyprland config done."

# ---------------------------------------------------------------------------
# 7. Waybar config
# ---------------------------------------------------------------------------
ce "Creating Waybar config..."
cat > "$CONFIG_DIR/waybar/config" <<'EOF'
{
  "layer": "top",
  "position": "top",
  "modules-left": ["clock"],
  "modules-right": ["cpu", "memory", "pulseaudio", "tray"]
}
EOF

cat > "$CONFIG_DIR/waybar/style.css" <<EOF
@import url("$USER_HOME/.config/waybar/colors.css");
* { font-family: "JetBrainsMono Nerd Font"; }
window#waybar { background: @background; color: @foreground; }
EOF
chown -R "$USER_NAME":"$USER_NAME" "$CONFIG_DIR/waybar"
ok "Waybar config done."

# ---------------------------------------------------------------------------
# 8. Kitty config
# ---------------------------------------------------------------------------
ce "Creating Kitty config..."
cat > "$CONFIG_DIR/kitty/kitty.conf" <<'EOF'
include ~/.cache/wal/colors-kitty.conf
font_family JetBrainsMono Nerd Font
EOF
chown -R "$USER_NAME":"$USER_NAME" "$CONFIG_DIR/kitty"
ok "Kitty config done."

# ---------------------------------------------------------------------------
# 9. Dunst config
# ---------------------------------------------------------------------------
ce "Creating Dunst config..."
cat > "$CONFIG_DIR/dunst/dunstrc" <<'EOF'
[global]
    font = JetBrainsMono Nerd Font 10
    frame_width = 2
[urgency_low]
    background = "#222222"
    foreground = "#dddddd"
[urgency_normal]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
[urgency_critical]
    background = "#ff5555"
    foreground = "#ffffff"
EOF
chown -R "$USER_NAME":"$USER_NAME" "$CONFIG_DIR/dunst"
ok "Dunst config done."

# ---------------------------------------------------------------------------
# 10. Tofi config
# ---------------------------------------------------------------------------
ce "Creating Tofi config..."
cat > "$CONFIG_DIR/tofi/config" <<'EOF'
text-color="#ffffff"
background-color="#111111cc"
selection-color="#5e81ac"
selection-text-color="#ffffff"
EOF
chown -R "$USER_NAME":"$USER_NAME" "$CONFIG_DIR/tofi"
ok "Tofi config done."

# ---------------------------------------------------------------------------
# 11. Starship config
# ---------------------------------------------------------------------------
ce "Creating Starship config..."
cat > "$CONFIG_DIR/starship/starship.toml" <<'EOF'
format = "$directory$git_branch$character"
[directory]
truncation_length = 3
[character]
success_symbol = "➜ "
error_symbol = "✗ "
EOF
chown -R "$USER_NAME":"$USER_NAME" "$CONFIG_DIR/starship"
ok "Starship config done."

# ---------------------------------------------------------------------------
# 12. GTK links
# ---------------------------------------------------------------------------
ce "Linking GTK to pywal..."
ln -sf "$USER_HOME/.cache/wal/colors-gtk.css" "$CONFIG_DIR/gtk-3.0/gtk.css"
ln -sf "$USER_HOME/.cache/wal/colors-gtk.css" "$CONFIG_DIR/gtk-3.0/gtk-dark.css"
chown -R "$USER_NAME":"$USER_NAME" "$CONFIG_DIR/gtk-3.0"
ok "GTK linked."

# ---------------------------------------------------------------------------
# 13. Apply Pywal script
# ---------------------------------------------------------------------------
ce "Creating apply-pywal.sh..."
cat > "$CONFIG_DIR/scripts/apply-pywal.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
FLAG="${1:-}"

WALL="$HOME/.config/assets/wallpaper.jpg"
if [[ ! -f "$WALL" ]]; then
  CANDIDATE="$(find "$HOME/Pictures/wallpapers" -type f | head -n1)"
  [[ -n "$CANDIDATE" ]] && cp "$CANDIDATE" "$WALL"
fi

if [[ "$FLAG" == "-R" ]]; then
  wal -R -n || true
else
  wal -i "$WALL" -n
fi

# Waybar
mkdir -p "$HOME/.config/waybar"
ln -sf "$HOME/.cache/wal/colors.css" "$HOME/.config/waybar/colors.css"

# Tofi colors
COLORS="$HOME/.cache/wal/colors.sh"
if [[ -f "$COLORS" ]]; then
  source "$COLORS"
  TOFI="$HOME/.config/tofi/config"
  sed -i \
    -e "s/^text-color=.*/text-color=\"$foreground\"/" \
    -e "s/^background-color=.*/background-color=\"${background}cc\"/" \
    -e "s/^selection-color=.*/selection-color=\"$color3\"/" \
    -e "s/^selection-text-color=.*/selection-text-color=\"$foreground\"/" \
    "$TOFI" || true
fi

# Hyprland colors
mkdir -p "$HOME/.config/hypr"
HYPR_COL="$HOME/.config/hypr/colors-hypr.conf"
{
  echo "# Generated by apply-pywal.sh"
  if [[ -f "$COLORS" ]]; then
    source "$COLORS"
    echo "general { col.active_border = $color4; col.inactive_border = $color8; }"
  else
    echo "general { col.active_border = 0xff89b4fa; col.inactive_border = 0xff444444; }"
  fi
} > "$HYPR_COL"

# Reload Waybar if running
pkill -x waybar >/dev/null 2>&1 || true
(waybar >/dev/null 2>&1 &)

# Reload Hyprland if running
hyprctl reload >/dev/null 2>&1 || true
EOF

chmod +x "$CONFIG_DIR/scripts/apply-pywal.sh"
chown "$USER_NAME":"$USER_NAME" "$CONFIG_DIR/scripts/apply-pywal.sh"
ok "apply-pywal.sh created."

# ---------------------------------------------------------------------------
# 14. Wallpaper switcher script
# ---------------------------------------------------------------------------
ce "Creating switch-wallpaper.sh..."
cat > "$CONFIG_DIR/scripts/switch-wallpaper.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
WALLDIR="$HOME/Pictures/wallpapers"
mkdir -p "$WALLDIR"

SEL="$(find "$WALLDIR" -type f | sort | tofi --prompt-text 'Choose wallpaper:' || true)"
[[ -z "$SEL" ]] && exit 0

# Set wallpaper and re-apply theme
swww img "$SEL" --transition-type any --transition-duration 0.6
wal -i "$SEL" -n
~/.config/scripts/apply-pywal.sh
EOF

chmod +x "$CONFIG_DIR/scripts/switch-wallpaper.sh"
chown "$USER_NAME":"$USER_NAME" "$CONFIG_DIR/scripts/switch-wallpaper.sh"
ok "switch-wallpaper.sh created."

# ---------------------------------------------------------------------------
# 15. Apply initial theme
# ---------------------------------------------------------------------------
ce "Applying initial theme..."
as_user "$CONFIG_DIR/scripts/apply-pywal.sh"
ok "Initial theme applied."

# ---------------------------------------------------------------------------
# 16. Ownership sanity
# ---------------------------------------------------------------------------
chown -R "$USER_NAME":"$USER_NAME" "$CONFIG_DIR" "$USER_HOME/Pictures/wallpapers"

# ---------------------------------------------------------------------------
# Finish
# ---------------------------------------------------------------------------
echo
ok "🎉 All done! Reboot and select Hyprland on login."
echo "Tip: SUPER+E opens the wallpaper switcher (Tofi)."