#!/bin/bash
# Description: Proxmox install for LinkWarden
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
    ufw allow 3000/tcp && \
    mkdir -p /opt/linkwarden && \
    cat > /opt/linkwarden/docker-compose.yml <<"EOF"
version: '3.3'
services:
  linkwarden:
    image: ghcr.io/linkwarden/linkwarden:latest
    container_name: linkwarden
    restart: unless-stopped
    ports:
      - \"3000:3000\"
    volumes:
      - /opt/linkwarden/data:/data
EOF
    docker-compose -f /opt/linkwarden/docker-compose.yml up -d
"

echo "Linkwarden installation in LXC $LXC_ID completed successfully with data stored in /opt/linkwarden!"
