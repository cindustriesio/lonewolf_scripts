#!/bin/bash

# Configuration
LXC_ID="$1"  # LXC Container ID
INSTALL_DIR="/opt/komga"
SERVICE_FILE="/etc/systemd/system/komga.service"
CREDENTIALS_FILE="/root/komga_info.txt"
LATEST_RELEASE_URL="https://api.github.com/repos/gotson/komga/releases/latest"

# Logging Functions
msg_info() { echo -e "\e[1;34m[INFO]\e[0m $1"; }
msg_ok() { echo -e "\e[1;32m[OK]\e[0m $1"; }
msg_error() { echo -e "\e[1;31m[ERROR]\e[0m $1"; }

# Ensure LXC ID is provided
if [[ -z "$LXC_ID" ]]; then
    msg_error "Usage: $0 <LXC_CONTAINER_ID>"
    exit 1
fi

# Check if LXC exists
if ! pct list | awk '{print $1}' | grep -q "^$LXC_ID$"; then
    msg_error "LXC container with ID $LXC_ID not found!"
    exit 1
fi

msg_info "Updating LXC container $LXC_ID..."
pct exec "$LXC_ID" -- bash -c "apt update && apt upgrade -y"

msg_info "Installing required dependencies..."
pct exec "$LXC_ID" -- bash -c "apt install -y openjdk-17-jre wget curl jq"

msg_info "Fetching latest Komga release version..."
LATEST_VERSION=$(curl -s "$LATEST_RELEASE_URL" | jq -r '.tag_name' | sed 's/v//')

if [[ -z "$LATEST_VERSION" || "$LATEST_VERSION" == "null" ]]; then
    msg_error "Failed to retrieve latest Komga version!"
    exit 1
fi

DOWNLOAD_URL="https://github.com/gotson/komga/releases/download/$LATEST_VERSION/komga-$LATEST_VERSION.jar"

msg_info "Latest Komga version: $LATEST_VERSION"
msg_info "Download URL: $DOWNLOAD_URL"

msg_info "Creating Komga user and directories..."
pct exec "$LXC_ID" -- bash -c "useradd -r -s /bin/false komga || true"
pct exec "$LXC_ID" -- bash -c "mkdir -p '$INSTALL_DIR/config' '$INSTALL_DIR/books'"
pct exec "$LXC_ID" -- bash -c "chown -R komga:komga '$INSTALL_DIR'"

msg_info "Downloading latest Komga JAR..."
pct exec "$LXC_ID" -- bash -c "wget -O '$INSTALL_DIR/komga.jar' '$DOWNLOAD_URL'"
pct exec "$LXC_ID" -- bash -c "chown komga:komga '$INSTALL_DIR/komga.jar'"

msg_info "Creating systemd service..."
pct exec "$LXC_ID" -- bash -c "cat <<EOF > '$SERVICE_FILE'
[Unit]
Description=Komga Server
After=network.target

[Service]
User=komga
Group=komga
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/java -jar $INSTALL_DIR/komga.jar
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF"

pct exec "$LXC_ID" -- bash -c "systemctl daemon-reload && systemctl enable --now komga"

msg_info "Retrieving LXC IP Address..."
LXC_IP=$(pct exec "$LXC_ID" -- hostname -I | awk '{print $1}')

msg_info "Storing access info in $CREDENTIALS_FILE..."
pct exec "$LXC_ID" -- bash -c "cat <<EOF > '$CREDENTIALS_FILE'
Komga Server Installation Info:
----------------------------------
Access URL: http://$LXC_IP:25600

Komga runs as a systemd service.
To check status: systemctl status komga
To restart: systemctl restart komga

EOF"

pct exec "$LXC_ID" -- bash -c "chmod 600 '$CREDENTIALS_FILE'"

msg_ok "Komga installation complete!"
msg_info "Access Komga at http://$LXC_IP:25600"
msg_info "Systemd service 'komga' is running."
msg_info "Credentials stored in $CREDENTIALS_FILE"
