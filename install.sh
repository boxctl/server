#!/usr/bin/env bash

# Boxctl server
# Copyright 2026 Boxctl (https://github.com/boxctl)
# Licensed under the Apache License, Version 2.0
# https://github.com/boxctl/server

# Usage:
# curl -fsSLo- "https://raw.githubusercontent.com/boxctl/server/refs/heads/main/setup.sh" | bash

set -euo pipefail

ANGIE_DIR="$HOME/boxctl/angie"
DOMAIN=""

BOLD='\033[1m'
RED='\033[38;2;239;68;68m'
GREEN='\033[38;2;16;185;129m'
PURPLE='\033[38;2;168;85;247m'
YELLOW='\033[38;2;250;204;21m'
ACCENT='\033[38;2;234;88;12m'
RESET='\033[0m'

step() { echo -e "${BOLD}▶ ${PURPLE}$1${RESET}"; }
error() { echo -e "${BOLD}${RED}▶ [ERROR]: $1${RESET}"; }
warn() { echo -e "${BOLD}${YELLOW}▶ [WARNING]: $1${RESET}"; }

if [[ ! -f /etc/os-release ]]; then
	error "/etc/os-release not found!"
	exit 1
fi
source /etc/os-release

if ! sudo -v; then
	error "sudo auth failed!"
	exit 1
fi
if [[ "$EUID" -eq 0 ]]; then
	error "Do not run this script as root. create a normal user instead."
	exit 1
fi
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo -e "${ACCENT}
  ▄█▄▄▄█▄    
▄█       █▄  ${RESET}█▄▄ ▄▄▄ ▄ ▄  ▄▄ █▄ █ ${ACCENT}
██ ▐▌ ▐▌ ██  ${RESET}█ █ █ █  █  █   █  █ ${ACCENT}
 ▀▄▄▄▄▄▄▄▀   ${RESET}▀▀▀ ▀▀▀ ▀ ▀ ▀▀▀ ▀▀  ▀${RESET}
"
echo -e "${BOLD}${ACCENT}
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                                ┃
┃   Boxctl server installation   ┃
┃                                ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
${RESET}"

echo -e "${ACCENT}▶ ${RESET}${BOLD}Provide permanent domain name for Boxctl GUI.${RESET}"
echo -e "${ACCENT}▶ ${RESET}${BOLD}Preferred: non-www domain or subdomain.${RESET}"
while true; do
	read -rp "DOMAIN: " DOMAIN < /dev/tty
	[[ -z "$DOMAIN" ]] && error "Domain cannot be empty." && continue
	break
done

echo ""
echo -e "${BOLD}${ACCENT}SERVER OS : ${RESET}${PRETTY_NAME}"
echo -e "${BOLD}${ACCENT}ANGIE_DIR : ${RESET}${ANGIE_DIR}"
echo -e "${BOLD}${ACCENT}DOMAIN    : ${RESET}${DOMAIN}"
echo ""

step "Updating repo"
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq

step "Installing essential packages"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq build-essential git podman

step "Enabling ip_unprivileged_port_start"
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/99-boxctl-unprivileged-ports.conf > /dev/null
sudo sysctl --system > /dev/null

step "Enabling linger"
sudo loginctl enable-linger "$USER"

step "Creating default directories"
mkdir -p "$ANGIE_DIR/http.d"
mkdir -p "$ANGIE_DIR/logs"
mkdir -p "$ANGIE_DIR/acme"
mkdir -p "$ANGIE_DIR/html/default"

step "Extracting angie.conf"
podman run --rm docker.angie.software/angie:minimal cat /etc/angie/angie.conf > "$ANGIE_DIR/angie.conf"

step "Creating boxctl network"
podman network exists boxctl || podman network create boxctl

step "Downloading required files"
rm -rf "$HOME/.boxctl"
git clone -q --depth 1 https://github.com/boxctl/server "$HOME/.boxctl"

step "Writing default files"
cp -rf "$HOME/.boxctl/src/angie/html/default/." "$ANGIE_DIR/html/default/"
cp -rf "$HOME/.boxctl/src/angie/html/default/." "$ANGIE_DIR/html/default/"
cp -rf "$HOME/.boxctl/src/systemd/." "$HOME/.config/containers/systemd/"

step "Loading systemd units"
systemctl --user daemon-reload
systemctl --user start boxctl-angie
