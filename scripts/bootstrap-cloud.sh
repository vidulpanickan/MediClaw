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
  error "This script is for Linux only. On macOS, install Docker Desktop and run install.sh directly."
fi

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
}

main "$@"
