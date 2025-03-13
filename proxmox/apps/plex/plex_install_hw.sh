#!/bin/bash

# Configuration

# Ensure an LXC ID is provided
if [ -z "$1" ]; then
    echo "[ERROR] Usage: bash $0 <LXC_CONTAINER_ID>"
    exit 1
fi

CT_ID=$1
echo "Installing Plex on LXC $CT_ID..."

#CTID="$1"  # Container ID passed as an argument
#CONF_FILE="/etc/pve/lxc/${CTID}.conf"

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
#if [[ -z "$CTID" ]]; then
 #   msg_error "Usage: $0 <LXC_CONTAINER_ID>"
  #  exit 1
#fi

# Ensure the LXC container exists
#if [[ ! -f "$CONF_FILE" ]]; then
 #   msg_error "LXC container with ID $CTID not found!"
  #  exit 1
#fi

msg_info "Detecting GPU Type..."

GPU_TYPE=""
if lspci | grep -i 'vga\|display' | grep -iq intel; then
    GPU_TYPE="intel"
elif lspci | grep -i 'vga\|display' | grep -iq amd; then
    GPU_TYPE="amd"
elif lspci | grep -i 'vga\|display' | grep -iq nvidia; then
    GPU_TYPE="nvidia"
else
    msg_error "No compatible GPU found! Exiting..."
    exit 1
fi
msg_ok "Detected $GPU_TYPE GPU."

msg_info "Configuring GPU Passthrough for LXC Container $CTID..."

# Backup existing config
cp "$CONF_FILE" "${CONF_FILE}.backup"

# Ensure it's a privileged container
if ! grep -q "unprivileged=1" "$CONF_FILE"; then
    case "$GPU_TYPE" in
        intel|amd)
            echo -e "\nlxc.cgroup2.devices.allow = c 226:* rwm" >> "$CONF_FILE"
            echo "lxc.mount.entry = /dev/dri dev/dri none bind,optional,create=dir" >> "$CONF_FILE"
            msg_ok "Passthrough added for Intel/AMD (VA-API)."
            ;;
        nvidia)
            echo -e "\nlxc.cgroup2.devices.allow = c 195:* rwm" >> "$CONF_FILE"
            echo "lxc.mount.entry = /dev/nvidia0 dev/nvidia0 none bind,optional,create=file" >> "$CONF_FILE"
            echo "lxc.mount.entry = /dev/nvidiactl dev/nvidiactl none bind,optional,create=file" >> "$CONF_FILE"
            echo "lxc.mount.entry = /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file" >> "$CONF_FILE"
            msg_ok "Passthrough added for NVIDIA (NVENC)."
            ;;
    esac
else
    msg_error "Unprivileged container detected! GPU passthrough requires a privileged LXC."
    exit 1
fi

msg_info "Restarting LXC Container to Apply Changes..."
pct stop "$CTID"
pct start "$CTID"
msg_ok "GPU Passthrough Setup Complete!"

# Wait for LXC to boot up
sleep 5

msg_info "Updating Container..."
pct exec "$CTID" -- bash -c "apt update && apt upgrade -y"

msg_info "Installing Dependencies..."
pct exec "$CTID" -- bash -c "apt install -y curl wget gnupg software-properties-common"

msg_info "Adding Plex Repository..."
pct exec "$CTID" -- bash -c "curl https://downloads.plex.tv/plex-keys/PlexSign.key | gpg --dearmor -o /usr/share/keyrings/plex.gpg"
pct exec "$CTID" -- bash -c "echo 'deb [signed-by=/usr/share/keyrings/plex.gpg] https://downloads.plex.tv/repo/deb public main' | tee /etc/apt/sources.list.d/plexmediaserver.list"

msg_info "Installing Plex Media Server..."
pct exec "$CTID" -- bash -c "apt update && apt install -y plexmediaserver"

msg_info "Enabling Plex Service..."
pct exec "$CTID" -- bash -c "systemctl enable --now plexmediaserver"

msg_info "Setting Up Hardware Acceleration..."
pct exec "$CTID" -- bash -c "apt-get -y install va-driver-all ocl-icd-libopencl1 intel-opencl-icd vainfo intel-gpu-tools"

msg_info "Configuring GPU Permissions Inside LXC..."
pct exec "$CTID" -- bash -c "chgrp video /dev/dri && chmod 755 /dev/dri && chmod 660 /dev/dri/*"
pct exec "$CTID" -- bash -c "adduser plex video && adduser plex render"

msg_ok "Hardware Acceleration Setup Complete!"

# GPU-Specific Packages
case "$GPU_TYPE" in
    intel)
        msg_info "Installing Intel GPU Drivers..."
        pct exec "$CTID" -- bash -c "apt install -y intel-media-va-driver"
        msg_ok "Intel Quick Sync Enabled."
        ;;
    amd)
        msg_info "Installing AMD VA-API Drivers..."
        pct exec "$CTID" -- bash -c "apt install -y mesa-va-drivers libva-drm2 libva-x11-2"
        msg_ok "AMD VA-API Enabled."
        ;;
    nvidia)
        msg_info "Installing NVIDIA VAAPI Driver..."
        pct exec "$CTID" -- bash -c "apt install -y nvidia-vaapi-driver"
        msg_ok "NVIDIA NVENC Enabled."
        ;;
esac

msg_info "Restarting Plex to Apply Changes..."
pct exec "$CTID" -- bash -c "systemctl restart plexmediaserver"
msg_ok "Plex Installation and GPU Setup Complete!"
