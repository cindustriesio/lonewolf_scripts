#!/bin/bash
# Description: Update Komga in a Proxmox LXC container
# Version: .1
# ProjectL: Lonewolf Scripts
# Created by: Clark Industries IO

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

msg_info "Updating Komga in LXC $CTID..."

msg_info "Stopping Komga container..."
pct exec "$CTID" -- bash -c "cd /opt/komga && docker-compose down"

msg_info "Pulling latest Komga image..."
pct exec "$CTID" -- bash -c "docker pull gotson/komga:latest"

msg_info "Starting Komga container..."
pct exec "$CTID" -- bash -c "cd /opt/komga && docker-compose up -d"

msg_info "Removing old unused Docker images..."
pct exec "$CTID" -- bash -c "docker image prune -f"

msg_ok "Komga has been updated successfully!"
msg_info "Access it at http://<LXC_IP>:25600"
