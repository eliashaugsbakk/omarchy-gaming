#!/bin/bash
#
# omarchy-gaming install script
#
# Installs a one-keybind gaming mode on Omarchy Linux.
# Auto-detects CPU to pick the right CachyOS kernel repo tier.
#
# Usage:
#   ./install.sh              # Full install (interactive)
#   ./install.sh --no-cachyos # Skip CachyOS kernel/repo setup
#   ./install.sh --uninstall  # Remove everything this script installed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="$SCRIPT_DIR/files"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { printf "${BLUE}::${NC} %s\n" "$*"; }
success() { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn()    { printf "${YELLOW}⚠${NC} %s\n" "$*"; }
error()   { printf "${RED}✗${NC} %s\n" "$*" >&2; }
header()  { printf "\n${BOLD}%s${NC}\n" "$*"; }

# ---------------------------------------------------------------------------
# CPU detection — pick the right CachyOS repo tier
# ---------------------------------------------------------------------------
detect_cachyos_tier() {
  local vendor family model flags
  vendor=$(grep -m1 "^vendor_id" /proc/cpuinfo | awk '{print $NF}')
  family=$(grep -m1 "^cpu family" /proc/cpuinfo | awk '{print $NF}')
  model=$(grep -m1 "^model[[:space:]]" /proc/cpuinfo | awk '{print $NF}')
  flags=$(grep -m1 "^flags" /proc/cpuinfo)

  if [[ "$vendor" == "AuthenticAMD" ]]; then
    # Zen 4 / Zen 5 (family 25 model ≥ 96, or family 26)
    if (( family == 26 )) || { (( family == 25 )) && (( model >= 96 )); }; then
      echo "znver4"
      return
    fi
    # Zen 3 (family 25 model < 96)
    if (( family == 25 )); then
      echo "znver3"
      return
    fi
  fi

  # Intel or older AMD — check instruction set level
  if echo "$flags" | grep -qw "avx512f"; then
    echo "x86-64-v4"
    return
  fi
  if echo "$flags" | grep -qw "avx2"; then
    echo "x86-64-v3"
    return
  fi

  echo "generic"
}

# Map tier to mirrorlist variable and repo suffix
tier_to_mirror_var() {
  case "$1" in
    znver4|znver3|x86-64-v4|x86-64-v3)
      echo "\$arch_v4"  # CachyOS v4 mirrorlist
      ;;
    *)
      echo "\$arch"
      ;;
  esac
}

tier_mirrorlist_file() {
  case "$1" in
    znver4|znver3|x86-64-v4|x86-64-v3)
      echo "/etc/pacman.d/cachyos-v4-mirrorlist"
      ;;
    *)
      echo "/etc/pacman.d/cachyos-mirrorlist"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
do_uninstall() {
  header "Uninstalling omarchy-gaming"

  rm -f ~/.local/bin/omarchy-gaming-toggle && success "Removed toggle script" || true
  rm -f ~/.local/state/omarchy/toggles/hypr/gaming.lua && success "Removed gaming.lua" || true
  rm -f ~/.local/state/omarchy/toggles/gaming && success "Removed gaming flag" || true
  rm -f ~/.config/gamemode.ini && success "Removed gamemode.ini" || true
  rm -f ~/.config/environment.d/gaming.conf && success "Removed gaming.conf" || true

  # Remove the keybinding block from bindings.lua
  if [[ -f ~/.config/hypr/bindings.lua ]] && grep -q "omarchy-gaming-toggle" ~/.config/hypr/bindings.lua; then
    sed -i '/-- \[omarchy-gaming\]/,/-- \[\/omarchy-gaming\]/d' ~/.config/hypr/bindings.lua
    success "Removed keybinding from bindings.lua"
  fi

  hyprctl reload &>/dev/null || true
  success "Done. Gaming mode fully removed."
  exit 0
}

# ---------------------------------------------------------------------------
# Install CachyOS repos + kernel
# ---------------------------------------------------------------------------
install_cachyos() {
  local tier="$1"

  header "CachyOS Kernel Setup (tier: $tier)"

  # Check if already configured
  if grep -q "cachyos" /etc/pacman.conf 2>/dev/null; then
    success "CachyOS repos already in pacman.conf"
  else
    info "Adding CachyOS repos to /etc/pacman.conf..."
    warn "This requires sudo and modifies your system package manager config."
    read -rp "    Continue? [y/N] " answer
    if [[ "${answer,,}" != "y" ]]; then
      warn "Skipping CachyOS repo setup."
      return
    fi

    # Install CachyOS keyring and mirrorlist first
    info "Installing CachyOS keyring and mirrorlist..."
    local cachyos_url="https://cdn77.cachyos.org/repo/x86_64/cachyos"

    sudo pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key F3B607488DB35A47

    sudo pacman -U --noconfirm \
      "$cachyos_url/cachyos-keyring-20240331-1-any.pkg.tar.zst" \
      "$cachyos_url/cachyos-mirrorlist-19-1-any.pkg.tar.zst" \
      "$cachyos_url/cachyos-v4-mirrorlist-5-1-any.pkg.tar.zst" || {
        error "Failed to install CachyOS keyring/mirrorlist."
        error "Visit https://wiki.cachyos.org for manual instructions."
        return
      }

    # Build the repo block
    local mirrorlist
    mirrorlist=$(tier_mirrorlist_file "$tier")

    local repo_block=""
    repo_block+="# [omarchy-gaming] CachyOS repos for tier: $tier\n"
    repo_block+="[cachyos-$tier]\n"
    repo_block+="Include = $mirrorlist\n\n"
    repo_block+="[cachyos-core-$tier]\n"
    repo_block+="Include = $mirrorlist\n\n"
    repo_block+="[cachyos-extra-$tier]\n"
    repo_block+="Include = $mirrorlist\n\n"
    repo_block+="[cachyos]\n"
    repo_block+="Include = /etc/pacman.d/cachyos-mirrorlist\n"

    # Insert CachyOS repos before [core] so they take priority
    sudo sed -i "/^\[core\]/i\\
$(echo -e "$repo_block")" /etc/pacman.conf
    success "Added CachyOS repos ($tier) to pacman.conf"

    sudo pacman -Sy
  fi

  # Install the kernel
  if pacman -Q linux-cachyos &>/dev/null; then
    success "linux-cachyos already installed ($(pacman -Q linux-cachyos | awk '{print $2}'))"
  else
    info "Installing linux-cachyos kernel..."
    sudo pacman -S --noconfirm linux-cachyos linux-cachyos-headers || {
      error "Kernel install failed. You can install manually: sudo pacman -S linux-cachyos"
      return
    }
    success "linux-cachyos installed"
    warn "You need to update your bootloader and reboot into the CachyOS kernel."
    warn "For systemd-boot: sudo bootctl update"
    warn "For Limine/GRUB: update your boot entries manually."
  fi
}

# ---------------------------------------------------------------------------
# Install gaming files
# ---------------------------------------------------------------------------
install_files() {
  header "Installing Gaming Mode Files"

  # Toggle script
  mkdir -p ~/.local/bin
  cp "$FILES_DIR/omarchy-gaming-toggle" ~/.local/bin/omarchy-gaming-toggle
  chmod +x ~/.local/bin/omarchy-gaming-toggle
  success "Installed omarchy-gaming-toggle → ~/.local/bin/"

  # Hyprland gaming lua
  mkdir -p ~/.local/state/omarchy/toggles/hypr
  cp "$FILES_DIR/gaming.lua" ~/.local/state/omarchy/toggles/hypr/gaming.lua
  success "Installed gaming.lua → ~/.local/state/omarchy/toggles/hypr/"

  # GameMode config
  mkdir -p ~/.config
  if [[ -f ~/.config/gamemode.ini ]]; then
    warn "gamemode.ini already exists — skipping (delete it first to replace)"
  else
    cp "$FILES_DIR/gamemode.ini" ~/.config/gamemode.ini
    success "Installed gamemode.ini → ~/.config/"
  fi

  # Mesa shader cache
  mkdir -p ~/.config/environment.d
  if [[ -f ~/.config/environment.d/gaming.conf ]]; then
    warn "gaming.conf already exists — skipping"
  else
    cp "$FILES_DIR/gaming.conf" ~/.config/environment.d/gaming.conf
    success "Installed gaming.conf → ~/.config/environment.d/"
  fi
}

# ---------------------------------------------------------------------------
# Install keybinding
# ---------------------------------------------------------------------------
install_keybinding() {
  header "Keybinding"

  local bindings_file="$HOME/.config/hypr/bindings.lua"

  if [[ ! -f "$bindings_file" ]]; then
    warn "No bindings.lua found at $bindings_file — skipping keybinding."
    warn "Add this manually:"
    echo '  o.bind("SUPER + CTRL + G", "Toggle gaming mode", "omarchy-gaming-toggle")'
    return
  fi

  if grep -q "omarchy-gaming-toggle" "$bindings_file"; then
    success "Gaming keybinding already present in bindings.lua"
    return
  fi

  cat >> "$bindings_file" <<'EOF'

-- [omarchy-gaming]
o.bind(
  "SUPER + CTRL + G",
  "Toggle gaming mode",
  "omarchy-gaming-toggle"
)
-- [/omarchy-gaming]
EOF
  success "Added SUPER + CTRL + G keybinding to bindings.lua"
  hyprctl reload &>/dev/null || true
}

# ---------------------------------------------------------------------------
# Install packages
# ---------------------------------------------------------------------------
install_packages() {
  header "Packages"

  local to_install=()

  if ! command -v gamemoderun &>/dev/null; then
    to_install+=(gamemode lib32-gamemode)
  else
    success "gamemode already installed"
  fi

  if (( ${#to_install[@]} > 0 )); then
    info "Installing: ${to_install[*]}"
    if command -v omarchy-pkg-add &>/dev/null; then
      omarchy pkg add "${to_install[@]}"
    else
      sudo pacman -S --noconfirm "${to_install[@]}"
    fi
    success "Packages installed"
  fi
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
  local tier="$1"
  local kernel
  kernel=$(uname -r)

  header "Installation Complete 🎮"
  echo ""
  info "Toggle gaming mode:  SUPER + CTRL + G"
  info "Steam launch opts:   gamemoderun %command% -nojoy +exec autoexec.cfg"
  echo ""

  if [[ ! "$kernel" =~ cachyos ]]; then
    warn "You are running kernel $kernel (not CachyOS)."
    warn "Reboot and select the CachyOS entry for low-latency scheduling."
  else
    success "Running CachyOS kernel ($kernel)"
  fi

  local on_battery
  on_battery=$(busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery 2>/dev/null || echo "")
  if [[ "$on_battery" == "b true" ]]; then
    warn "Currently on battery — plug in before gaming."
  fi

  echo ""
  info "CPU tier detected: $tier"
  info "To uninstall: ./install.sh --uninstall"
  echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  local skip_cachyos=0

  for arg in "$@"; do
    case "$arg" in
      --uninstall) do_uninstall ;;
      --no-cachyos) skip_cachyos=1 ;;
      --help|-h)
        echo "Usage: ./install.sh [--no-cachyos] [--uninstall]"
        exit 0
        ;;
    esac
  done

  header "omarchy-gaming installer"

  local tier
  tier=$(detect_cachyos_tier)
  info "Detected CPU tier: $tier"

  local cpu_name
  cpu_name=$(grep -m1 "model name" /proc/cpuinfo | sed 's/.*: //')
  info "CPU: $cpu_name"

  echo ""

  install_files
  install_keybinding
  install_packages

  if (( !skip_cachyos )); then
    install_cachyos "$tier"
  else
    info "Skipping CachyOS setup (--no-cachyos)"
  fi

  print_summary "$tier"
}

main "$@"
