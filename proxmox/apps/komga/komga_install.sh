#!/bin/bash

set -e

# LXC Configuration
LXC_ID="$1"  # LXC Container ID
INSTALL_DIR="/opt/komga"
USER="komga"
SERVICE_FILE="/etc/systemd/system/komga.service"

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
    apt update && apt install -y curl openjdk-17-jre && \
    useradd -r -s /bin/false $USER || true && \
    mkdir -p $INSTALL_DIR && chown $USER:$USER $INSTALL_DIR && \
    LATEST_VERSION=\$(curl -s https://api.github.com/repos/gotson/komga/releases/latest | grep 'tag_name' | cut -d '"' -f4 | sed 's/v//') && \
    if [[ -z \"\$LATEST_VERSION\" ]]; then echo \"[ERROR] Failed to fetch Komga version!\"; exit 1; fi && \
    DOWNLOAD_URL=\"https://github.com/gotson/komga/releases/download/v\$LATEST_VERSION/komga-\$LATEST_VERSION.jar\" && \
    echo \"Downloading Komga v\$LATEST_VERSION...\" && \
    curl -Lo $INSTALL_DIR/komga.jar \$DOWNLOAD_URL || { echo \"[ERROR] Download failed!\"; exit 1; } && \
    FILE_SIZE=\$(stat -c %s $INSTALL_DIR/komga.jar) && \
    if [[ \$FILE_SIZE -lt 1000000 ]]; then echo \"[ERROR] Downloaded file is too small, possibly corrupted!\"; exit 1; fi && \
    chown $USER:$USER $INSTALL_DIR/komga.jar && chmod 755 $INSTALL_DIR/komga.jar && \
    echo '[Unit]' > $SERVICE_FILE && \
    echo 'Description=Komga Server' >> $SERVICE_FILE && \
    echo 'After=network.target' >> $SERVICE_FILE && \
    echo '' >> $SERVICE_FILE && \
    echo '[Service]' >> $SERVICE_FILE && \
    echo 'User=$USER' >> $SERVICE_FILE && \
    echo 'Group=$USER' >> $SERVICE_FILE && \
    echo 'WorkingDirectory=$INSTALL_DIR' >> $SERVICE_FILE && \
    echo 'ExecStart=/usr/bin/java -jar $INSTALL_DIR/komga.jar --server.address=0.0.0.0' >> $SERVICE_FILE && \
    echo 'Restart=always' >> $SERVICE_FILE && \
    echo 'RestartSec=10' >> $SERVICE_FILE && \
    echo '' >> $SERVICE_FILE && \
    echo '[Install]' >> $SERVICE_FILE && \
    echo 'WantedBy=multi-user.target' >> $SERVICE_FILE && \
    systemctl daemon-reload && systemctl enable --now komga
"

echo "Komga installation in LXC $LXC_ID completed successfully!"

echo "Access Komga at http://<LXC_IP>:25600"