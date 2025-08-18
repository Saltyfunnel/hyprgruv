#!/bin/bash
# Helper functions with the Dracula color palette.

# Dracula Color Palette (24-bit RGB)
DRACULA_RED='\033[38;2;255;85;85m'      # #FF5555
DRACULA_GREEN='\033[38;2;80;250;123m'    # #50FA7B
DRACULA_YELLOW='\033[38;2;241;250;140m'   # #F1FA8C
DRACULA_PURPLE='\033[38;2;189;147;249m'   # #BD93F9
DRACULA_CYAN='\033[38;2;139;233;253m'    # #8BE9FD
BOLD='\033[1m'
NC='\033[0m'

print_error()   { echo -e "${DRACULA_RED}$1${NC}"; }
print_success() { echo -e "${DRACULA_GREEN}$1${NC}"; }
print_warning() { echo -e "${DRACULA_YELLOW}$1${NC}"; }
print_info()    { echo -e "${DRACULA_PURPLE}$1${NC}"; }
print_bold_blue() { echo -e "${DRACULA_CYAN}${BOLD}$1${NC}"; }
print_header()  { echo -e "\n${BOLD}${DRACULA_CYAN}==> $1${NC}"; }

ask_confirmation() {
  while true; do
    read -rp "$(print_warning "$1 (y/n): ")" -n 1
    echo
    case $REPLY in
      [Yy]) return 0 ;;
      [Nn]) print_error "Operation cancelled."; return 1 ;;
      *) print_error "Invalid input. Please answer y or n." ;;
    esac
  done
}

run_command() {
  local cmd="$1"
  local description="$2"
  local ask_confirm="${3:-yes}"
  local use_sudo="${4:-yes}" # yes=run as root, no=run as unprivileged user

  local full_cmd=""
  if [[ "$use_sudo" == "no" ]]; then
    full_cmd="sudo -u $SUDO_USER bash -c \"$cmd\""
  else
    full_cmd="$cmd"
  fi

  print_info "\nCommand: $full_cmd"
  if [[ "$ask_confirm" == "yes" ]]; then
    if ! ask_confirmation "$description"; then
      return 1
    fi
  else
    print_info "$description"
  fi

  until eval "$full_cmd"; do
    print_error "Command failed: $cmd"
    if [[ "$ask_confirm" == "yes" ]]; then
      if ! ask_confirmation "Retry $description?"; then
        print_warning "$description not completed."
        return 1
      fi
    else
      print_warning "$description failed, no retry (auto mode)."
      return 1
    fi
  done

  print_success "$description completed successfully."
  return 0
}

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    print_error "Please run as root."
    exit 1
  fi
}

check_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$ID" != "arch" ]]; then
      print_warning "This script is designed for Arch Linux. Detected: $PRETTY_NAME"
      if ! ask_confirmation "Continue anyway?"; then
        exit 1
      fi
    else
      print_success "Arch Linux detected. Proceeding."
    fi
  else
    print_error "/etc/os-release not found. Cannot determine OS."
    if ! ask_confirmation "Continue anyway?"; then
      exit 1
    fi
  fi
}
