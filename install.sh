#!/usr/bin/env bash

# Boxctl server
# Copyright 2026 Boxctl (https://github.com/boxctl)
# Licensed under the Apache License, Version 2.0
# https://github.com/boxctl/server

# Usage:
# curl -fsSLo- "https://raw.githubusercontent.com/boxctl/server/refs/heads/main/install.sh" | bash

set -euo pipefail

DOMAIN=""

BOLD='\033[1m'
RED='\033[38;2;239;68;68m'
GREEN='\033[38;2;16;185;129m'
PURPLE='\033[38;2;168;85;247m'
YELLOW='\033[38;2;250;204;21m'
ACCENT='\033[38;2;234;88;12m'
RESET='\033[0m'

step() { echo -e "${BOLD}${ACCENT}▶ ${PURPLE}$1${RESET}"; }
error() { echo -e "${BOLD}${RED}▶ [ERROR]: $1${RESET}"; }
warn() { echo -e "${BOLD}${YELLOW}▶ [WARNING]: $1${RESET}"; }

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

if [[ ! -f /etc/os-release ]]; then
	error "/etc/os-release not found!"
	exit 1
fi
source /etc/os-release

case "$ID-$VERSION_ID" in
ubuntu-22.04 | ubuntu-24.04 | fedora-43 | debian-13) ;;
*)
	error "Unsupported OS: $PRETTY_NAME"
	error "Supported: Ubuntu 22.04, Ubuntu 24.04, Fedora 43, Debian 13"
	exit 1
	;;
esac

if ! sudo -v; then
	error "sudo auth failed!"
	exit 1
fi
if [[ "$EUID" -eq 0 ]]; then
	error "Do not run this script as root user. Run it with a normal user with sudo access."
	exit 1
fi
while true; do
	sudo -n true
	sleep 60
	kill -0 "$$" || exit
done 2>/dev/null &

step "Provide permanent domain name for Boxctl GUI."
step "Only non-www domains or subdomains are supported."
step "You can set www domain after the setup through GUI."

while true; do
	read -rp "DOMAIN: " DOMAIN </dev/tty
	DOMAIN="${DOMAIN// /}"
	[[ -z "$DOMAIN" ]] && error "Domain cannot be empty." && continue
	[[ "$DOMAIN" == www.* ]] && error "Use non-www domain." && continue
	break
done

echo ""
echo -e "${BOLD}${ACCENT}SERVER OS : ${RESET}${PRETTY_NAME}"
echo -e "${BOLD}${ACCENT}DOMAIN    : ${RESET}${DOMAIN}"
echo -e "${BOLD}${ACCENT}HOME      : ${RESET}${HOME}"
echo ""

install_ubuntu_debian() {
	sudo DEBIAN_FRONTEND=noninteractive apt-get update -q
	sudo curl -fsSLo /etc/apt/trusted.gpg.d/angie-signing.gpg https://angie.software/keys/angie-signing.gpg
	echo "deb https://download.angie.software/angie/$ID/$VERSION_ID $VERSION_CODENAME main" |
		sudo tee /etc/apt/sources.list.d/angie.list >/dev/null
	sudo DEBIAN_FRONTEND=noninteractive apt-get update -q
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q git podman jq angie acl
}

install_fedora() {
	sudo tee /etc/yum.repos.d/angie.repo >/dev/null <<'EOF'
[angie]
name=Angie repo
baseurl=https://download.angie.software/angie/fedora/$releasever/
gpgcheck=1
enabled=1
gpgkey=https://angie.software/keys/angie-signing.gpg.asc
EOF
	sudo dnf install -y -q git podman jq angie acl
}

install_pnpm() {
	curl -fsSL https://get.pnpm.io/install.sh | sh -
	export PNPM_HOME="$HOME/.local/share/pnpm"
	export PATH="$PNPM_HOME:$PATH"
	pnpm env use --global lts
}

step "Installing required packages for $PRETTY_NAME"
case "$ID" in
ubuntu | debian) install_ubuntu_debian ;;
fedora) install_fedora ;;
esac

step "Installing pnpm"
install_pnpm

step "Downloading required files"
rm -rf "$HOME/.boxctl"
git clone -q --depth 1 https://github.com/boxctl/server "$HOME/.boxctl"

step "Creating default directories"
sudo mkdir -p "/etc/angie/web/boxctl"
mkdir -p "$HOME/.config/systemd/user"

step "Setting permissions"
sudo setfacl -R -m u:$(id -un):rwX /etc/angie/web/boxctl
sudo setfacl -d -m u:$(id -un):rwX /etc/angie/web/boxctl
sudo setfacl -R -m u:$(id -un):rwX /etc/angie/http.d/
sudo setfacl -d -m u:$(id -un):rwX /etc/angie/http.d/

step "Writing default files"
sudo cp -rf "$HOME/.boxctl/src/etc/angie/web/boxctl/." "/etc/angie/web/boxctl/"
sudo cp -rf "$HOME/.boxctl/src/etc/angie/http.d/." "/etc/angie/http.d/"
cp -rf "$HOME/.boxctl/src/home/boxadmin/.config/systemd/user/." "$HOME/.config/systemd/user/"

step "Processing default files"
sudo sed -i "s/__UPSTREAM__/127.0.0.1:8008/g" "/etc/angie/http.d/__DOMAIN__.conf"
sudo sed -i "s/__DOMAIN__/$DOMAIN/g" "/etc/angie/http.d/__DOMAIN__.conf"
sed -i "s|__PATH__|$PATH|g" "$HOME/.config/systemd/user/boxctl.service"
sudo mv "/etc/angie/http.d/__DOMAIN__.conf" "/etc/angie/http.d/$DOMAIN.conf"

step "Enabling linger"
sudo loginctl enable-linger "$(id -un)"
sudo systemctl start "user@$(id -u).service"

step "Starting services"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user daemon-reload
systemctl --user enable boxctl.service --now
sudo systemctl enable angie --now
