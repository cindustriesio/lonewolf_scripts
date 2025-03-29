#!/bin/bash
# Description: Update Komga in a Proxmox LXC container
# Version: .1
# ProjectL: Lonewolf Scripts
# Created by: Clark Industries IO

set -e

# LXC Configuration
CTID="$1"  # LXC Container ID

# Ensure LXC ID is provided
if [[ -z "$CTID" ]]; then
    echo "[ERROR] Usage: $0 <LXC_CONTAINER_ID>"
    exit 1
fi

# Ensure the LXC exists
if ! pct list | grep -q "^ *$CTID"; then
    echo "[ERROR] LXC $CTID does not exist. Please create it first."
    exit 1
fi

# Prompt for media location
read -rp "Enter the path for media storage (e.g., /mnt/media): " MEDIA_PATH

# Run commands inside LXC
pct exec $CTID -- bash -c "
    apt update && apt install -y curl docker.io docker-compose ufw && \
    systemctl enable --now docker && \
    ufw allow 25600/tcp && \
    mkdir -p /opt/komga \"$MEDIA_PATH\" && \
    cat > /opt/komga/docker-compose.yml <<"EOF"
version: '3.3'
services:
  komga:
    image: gotson/komga:latest
    container_name: komga
    restart: unless-stopped
    ports:
      - \"25600:25600\"
    volumes:
      - /opt/komga/config:/config
      - \"$MEDIA_PATH\":/books
EOF
    docker-compose -f /opt/komga/docker-compose.yml up -d
"

echo "Komga Docker installation in LXC $CTID completed successfully with media storage at $MEDIA_PATH!"
