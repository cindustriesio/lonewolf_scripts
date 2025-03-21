#!/bin/bash

# Configuration
CTID="$1"  # Container ID passed as an argument
CONF_FILE="/etc/pve/lxc/${CTID}.conf"

# Logging Functions
msg_info() {
    echo -e "\e[1;34m[INFO]\e[0m $1"
}
msg_ok() {
    echo -e "\e[1;32m[OK]\e[0m $1"
}
msg_error() {
    echo -e "\e[1;31m[ERROR]\e[0m $1"
}

# Ensure CTID is provided
if [[ -z "$CTID" ]]; then
    msg_error "Usage: $0 <LXC_CONTAINER_ID>"
    exit 1
fi

# Ensure the LXC container exists
if [[ ! -f "$CONF_FILE" ]]; then
    msg_error "LXC container with ID $CTID not found!"
    exit 1
fi

msg_info "Updating Container..."
pct exec "$CTID" -- bash -c "apt update && apt upgrade -y"

msg_info "Installing Dependencies..."
pct exec "$CTID" -- bash -c "apt install -y curl wget gnupg software-properties-common"

msg_info "Installing Docker & Docker-Compose..."
pct exec "$CTID" -- bash -c "apt install -y docker.io docker-compose"
pct exec "$CTID" -- bash -c "systemctl enable --now docker"

msg_info "Creating Komga Directory..."
pct exec "$CTID" -- bash -c "mkdir -p /opt/komga && cd /opt/komga"
pct exec "$CTID" -- bash -c "mkdir -p /mnt/media"  # Directory for comics/manga

msg_info "Setting Up Docker-Compose File..."
pct exec "$CTID" -- bash -c "cat <<EOF > /opt/komga/docker-compose.yml
version: '3'
services:
  komga:
    image: gotson/komga:latest
    container_name: komga
    restart: unless-stopped
    ports:
      - '25600:25600'
    volumes:
      - ./config:/config
      - /mnt/media:/books
    environment:
      - TZ=\$(cat /etc/timezone)
EOF"

msg_info "Starting Komga..."
pct exec "$CTID" -- bash -c "cd /opt/komga && docker-compose up -d"

msg_info "Storing Info in /root/komga_credentials.txt..."
pct exec "$CTID" -- bash -c "cat <<EOF > /root/komga_credentials.txt
Komga Installation Info:
------------------------
Access Komga at: http://\$(hostname -I | awk '{print $1}'):25600

Default Login:
- Username: admin
- Password: (Set on first login)

Media Directory:
- /mnt/media (Mount or add your comics/manga here)

EOF"

pct exec "$CTID" -- bash -c "chmod 600 /root/komga_credentials.txt"

msg_ok "Komga Installation Complete!"
msg_info "You can access Komga at http://<LXC_IP>:25600"
msg_info "Default admin login is created on first access."
msg_info "Check /root/komga_credentials.txt for details."
