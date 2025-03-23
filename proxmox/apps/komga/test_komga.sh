#!/bin/bash

# LXC Configuration
LXC_ID="$1"  # LXC Container ID
INSTALL_DIR="/opt/komga"
USER="komga"
SERVICE_FILE="/etc/systemd/system/komga.service"

# Ensure LXC ID is provided
if [[ -z "$LXC_ID" ]]; then
    msg_error "Usage: $0 <LXC_CONTAINER_ID>"
    exit 1
fi

# Ensure the LXC exists
if ! pct list | grep -q "^ *$LXC_ID"; then
    echo "[ERROR] LXC $LXC_ID does not exist. Please create it first."
    exit 1
fi

# Run commands inside LXC
pct exec $LXC_ID -- bash -c "\
    apt update && apt install -y curl openjdk-17-jre && \
    useradd -r -s /bin/false $USER || true && \
    mkdir -p $INSTALL_DIR && chown $USER:$USER $INSTALL_DIR && \
    LATEST_VERSION=\$(curl -sL https://github.com/gotson/komga/releases/latest | grep -oE 'tag/v[0-9.]+' | head -n1 | cut -d'v' -f2) && \
    if [[ -z \"\$LATEST_VERSION\" ]]; then echo \"[ERROR] Failed to fetch Komga version!\"; exit 1; fi && \
    DOWNLOAD_URL=\"https://github.com/gotson/komga/releases/download/v\$LATEST_VERSION/komga-\$LATEST_VERSION.jar\" && \
    curl -Lo $INSTALL_DIR/komga.jar \$DOWNLOAD_URL && \
    chown $USER:$USER $INSTALL_DIR/komga.jar && chmod 755 $INSTALL_DIR/komga.jar && \
    cat > $SERVICE_FILE <<EOF
[Unit]
Description=Komga Server
After=network.target

[Service]
User=$USER
Group=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/java -jar $INSTALL_DIR/komga.jar --server.address=0.0.0.0
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now komga
"

echo "Komga installation in LXC $LXC_ID completed successfully!"