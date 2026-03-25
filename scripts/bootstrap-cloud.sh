#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# MediClaw cloud bootstrap — installs Docker + delegates to install.sh.
# Works on any fresh Linux VM (DigitalOcean, AWS, GCP, Azure, bare metal).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/vidulpanickan/NemoClaw/main/scripts/bootstrap-cloud.sh | bash

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors (disabled when NO_COLOR is set or stdout is not a TTY)
# ---------------------------------------------------------------------------
if [[ -z "${NO_COLOR:-}" && -t 1 ]]; then
  C_GREEN=$'\033[38;5;32m'
  C_YELLOW=$'\033[1;33m'
  C_CYAN=$'\033[1;36m'
  C_RED=$'\033[1;31m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RESET=$'\033[0m'
else
  C_GREEN='' C_YELLOW='' C_CYAN='' C_RED='' C_BOLD='' C_DIM='' C_RESET=''
fi

info() { printf "${C_CYAN}[INFO]${C_RESET}  %s\n" "$*"; }
warn() { printf "${C_YELLOW}[WARN]${C_RESET}  %s\n" "$*"; }
error() {
  printf "${C_RED}[ERROR]${C_RESET} %s\n" "$*" >&2
  exit 1
}
ok() { printf "  ${C_GREEN}✓${C_RESET}  %s\n" "$*"; }

command_exists() { command -v "$1" &>/dev/null; }

# ---------------------------------------------------------------------------
# Require Linux
# ---------------------------------------------------------------------------
if [[ "$(uname -s)" != "Linux" ]]; then
  error "MediClaw must be installed on a cloud Linux server, not a personal machine.

  To set up MediClaw:
    1. Create a cloud VM (DigitalOcean, AWS, GCP, or Azure)
    2. SSH into the VM
    3. Run this script there"
fi

# ---------------------------------------------------------------------------
# Require cloud/server environment (not personal machines)
# ---------------------------------------------------------------------------
check_environment() {
  # Allow override for IT admins testing locally
  if [[ "${MEDICLAW_ALLOW_LOCAL:-}" == "1" ]]; then
    warn "Local install override enabled (MEDICLAW_ALLOW_LOCAL=1)"
    return
  fi

  local is_cloud=false

  # Check cloud metadata endpoint (AWS, GCP, Azure, DigitalOcean)
  if curl -sf -m 2 http://169.254.169.254/ >/dev/null 2>&1; then
    is_cloud=true
  fi

  # Check virtualization (systemd-detect-virt)
  if command_exists systemd-detect-virt; then
    local virt
    virt=$(systemd-detect-virt 2>/dev/null || echo "none")
    if [[ "$virt" != "none" ]]; then
      is_cloud=true
    fi
  fi

  # Check DMI for cloud provider strings
  if [[ -f /sys/class/dmi/id/product_name ]]; then
    local product
    product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
    if echo "$product" | grep -qiE "droplet|google|virtual|hvm|kvm|ec2|azure|standard"; then
      is_cloud=true
    fi
  fi

  if [[ "$is_cloud" == "false" ]]; then
    echo ""
    printf "  ${C_RED}${C_BOLD}Personal machine detected${C_RESET}\n"
    echo ""
    echo "  MediClaw is designed to run on cloud servers, not personal machines."
    echo "  This protects patient data by keeping the AI assistant in a controlled"
    echo "  server environment, separate from personal devices."
    echo ""
    echo "  To set up MediClaw:"
    echo "    1. Create a cloud VM (DigitalOcean, AWS, GCP, or Azure)"
    echo "    2. SSH into the VM"
    echo "    3. Run this script there"
    echo ""
    echo "  If you are an IT admin testing locally, set:"
    echo "    MEDICLAW_ALLOW_LOCAL=1"
    echo ""
    exit 1
  fi
}

check_environment

# ---------------------------------------------------------------------------
# Require root (or sudo)
# ---------------------------------------------------------------------------
SUDO=""
if [[ "$EUID" -ne 0 ]]; then
  if command_exists sudo; then
    SUDO="sudo"
    info "Not running as root — will use sudo"
  else
    error "This script requires root access. Run as root or install sudo."
  fi
fi

# ---------------------------------------------------------------------------
# 1. Install Docker
# ---------------------------------------------------------------------------
install_docker() {
  if command_exists docker; then
    info "Docker already installed: $(docker --version)"
    return
  fi

  info "Installing Docker..."

  # Use Docker's official convenience script — works on Ubuntu, Debian,
  # Fedora, CentOS, RHEL, SLES, and Amazon Linux.
  curl -fsSL https://get.docker.com | $SUDO sh

  # Start Docker and enable on boot
  $SUDO systemctl enable --now docker

  # If running as non-root, add user to docker group
  if [[ "$EUID" -ne 0 ]]; then
    $SUDO usermod -aG docker "$USER"
    warn "Added $USER to docker group. You may need to log out and back in."
  fi

  ok "Docker installed: $(docker --version)"
}

# ---------------------------------------------------------------------------
# 2. Install essential packages
# ---------------------------------------------------------------------------
install_essentials() {
  # git and curl are needed by install.sh
  if command_exists git && command_exists curl; then
    return
  fi

  info "Installing essential packages (git, curl)..."

  if command_exists apt-get; then
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq git curl
  elif command_exists dnf; then
    $SUDO dnf install -y -q git curl
  elif command_exists yum; then
    $SUDO yum install -y -q git curl
  else
    warn "Unknown package manager — please ensure git and curl are installed."
  fi

  ok "Essential packages ready"
}

# ---------------------------------------------------------------------------
# 3. Verify Docker is running
# ---------------------------------------------------------------------------
verify_docker() {
  if ! docker info &>/dev/null; then
    # Try starting it
    $SUDO systemctl start docker 2>/dev/null || true
    sleep 2
    if ! docker info &>/dev/null; then
      error "Docker is installed but not running. Try: systemctl start docker"
    fi
  fi
  ok "Docker is running"
}

# ---------------------------------------------------------------------------
# 4. Run the MediClaw installer
# ---------------------------------------------------------------------------
run_installer() {
  info "Launching MediClaw installer..."
  echo ""
  curl -fsSL https://raw.githubusercontent.com/vidulpanickan/NemoClaw/main/install.sh | bash
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo ""
  printf "  ${C_GREEN}${C_BOLD}MediClaw Cloud Bootstrap${C_RESET}\n"
  printf "  ${C_DIM}Setting up a fresh Linux VM for MediClaw${C_RESET}\n"
  echo ""

  install_essentials
  install_docker
  verify_docker
  run_installer

  # The installer adds nemoclaw to PATH via ~/.bashrc, but the current
  # shell (from curl|bash) won't have it. Print a clear next-step message.
  echo ""
  echo "  ================================================"
  echo "  IMPORTANT: Run this command to start using MediClaw:"
  echo ""
  echo "    source ~/.bashrc"
  echo ""
  echo "  Then connect to your sandbox:"
  echo ""
  echo "    nemoclaw medical-assistant connect"
  echo "  ================================================"
  echo ""
}

main "$@"
