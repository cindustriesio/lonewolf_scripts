#!/bin/bash
# Description: Proxmox install for RustDesk
# Version: .1
# ProjectL: Lonewolf Scripts
# Created by: Clark Industries IO

set -e

# LXC Configuration
LXC_ID="$1"  # LXC Container ID

# Ensure LXC ID is provided
if [[ -z "$LXC_ID" ]]; then
    echo "[ERROR] Usage: $0 <LXC_CONTAINER_ID>"
    exit 1
fi

# Ensure the LXC exists
if ! pct list | grep -q "^ *$LXC_ID"; then
    echo "[ERROR] LXC $LXC_ID does not exist. Please create it first."
    exit 1
fi

# Run commands inside LXC
pct exec $LXC_ID -- bash -c "
    apt update && apt install -y curl docker.io docker-compose ufw && \
    systemctl enable --now docker && \
    ufw allow 21115/tcp && \
    ufw allow 21116/tcp && \
    ufw allow 21116/udp && \
    ufw allow 21118/tcp && \
    mkdir -p /opt/rustdesk && \
    cat > /opt/rustdesk/docker-compose.yml <<EOF
version: '3.3'
services:
  rustdesk-hbbr:
    image: rustdesk/rustdesk-server:latest
    container_name: rustdesk-hbbr
    restart: unless-stopped
    network_mode: host
    command: hbbr

  rustdesk-hbbs:
    image: rustdesk/rustdesk-server:latest
    container_name: rustdesk-hbbs
    restart: unless-stopped
    network_mode: host
    command: hbbs -r <your-server-ip>
EOF
    docker-compose -f /opt/rustdesk/docker-compose.yml up -d
"

echo "RustDesk Server installation in LXC $LXC_ID completed successfully!"
