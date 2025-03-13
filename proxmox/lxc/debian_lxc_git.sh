#!/bin/bash

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "Whiptail is required but not installed. Install it using: sudo apt-get install whiptail"
    exit 1
fi

# Ensure template list is updated
pveam update > /dev/null

# Get available Debian templates
TEMPLATES=$(pveam available | awk '/debian/ {print $2}')
if [[ -z "$TEMPLATES" ]]; then
    echo "No Debian templates found. Run 'pveam update' and ensure Debian templates are available."
    exit 1
fi

# Format the options for whiptail
TEMPLATE_OPTIONS=()
for template in $TEMPLATES; do
    TEMPLATE_OPTIONS+=("$template" "$template")
done

# Let the user select a Debian version
SELECTED_TEMPLATE=$(whiptail --title "Select Debian Version" --menu "Choose a Debian LXC Template:" 30 140 10 "${TEMPLATE_OPTIONS[@]}" 3>&1 1>&2 2>&3)

if [[ -z "$SELECTED_TEMPLATE" ]]; then
    whiptail --title "Error" --msgbox "No template selected. Exiting." 8 50
    exit 1
fi

# Get storage options
storage_options=$(pvesm status | awk 'NR>1 {print $1}' | xargs)
default_storage=$(echo $storage_options | awk '{print $1}')

# GUI for LXC configuration
CT_ID=$(whiptail --inputbox "Enter Container ID (e.g., 100):" 8 50 100 --title "LXC Configuration" 3>&1 1>&2 2>&3)
HOSTNAME=$(whiptail --inputbox "Enter Hostname:" 8 50 "debian-lxc" --title "LXC Configuration" 3>&1 1>&2 2>&3)
DISK_SIZE=$(whiptail --inputbox "Enter Disk Size (in GB):" 8 50 4 --title "LXC Configuration" 3>&1 1>&2 2>&3)
MEMORY=$(whiptail --inputbox "Enter Memory Size (in MB):" 8 50 512 --title "LXC Configuration" 3>&1 1>&2 2>&3)
STORAGE=$(whiptail --menu "Select Storage:" 15 50 5 $(for s in $storage_options; do echo "$s [X]"; done) --default-item "$default_storage" 3>&1 1>&2 2>&3)

# Password input with confirmation
while true; do
    PASSWORD=$(whiptail --passwordbox "Enter Root Password:" 8 50 --title "LXC Configuration" 3>&1 1>&2 2>&3)
    CONFIRM_PASSWORD=$(whiptail --passwordbox "Confirm Root Password:" 8 50 --title "LXC Configuration" 3>&1 1>&2 2>&3)

    if [ "$PASSWORD" == "$CONFIRM_PASSWORD" ]; then
        break
    else
        whiptail --title "Error" --msgbox "Passwords do not match. Please try again." 8 50
    fi
done

# Network Configuration
NET_TYPE=$(whiptail --title "Network Configuration" --menu "Choose Network Type:" 15 50 2 \
    "dhcp" "Use DHCP (Automatic IP)" \
    "static" "Set Static IP Address" 3>&1 1>&2 2>&3)

if [[ "$NET_TYPE" == "static" ]]; then
    IP_ADDR=$(whiptail --inputbox "Enter Static IP Address (e.g., 192.168.1.100/24):" 10 60 "192.168.1.100/24" --title "Static IP Configuration" 3>&1 1>&2 2>&3)
    
    GATEWAY=$(whiptail --inputbox "Enter Gateway (default: 192.168.1.1):" 10 60 "192.168.1.1" --title "Gateway Configuration" 3>&1 1>&2 2>&3)
    
    DNS_OPTION=$(whiptail --title "DNS Configuration" --menu "Choose DNS Configuration:" 15 50 2 \
        "auto" "Use Default DNS (Proxmox Resolver)" \
        "manual" "Enter Custom DNS" 3>&1 1>&2 2>&3)

    if [[ "$DNS_OPTION" == "manual" ]]; then
        DNS_SERVERS=$(whiptail --inputbox "Enter DNS Servers (e.g., 8.8.8.8 1.1.1.1):" 10 60 "8.8.8.8 1.1.1.1" --title "DNS Configuration" 3>&1 1>&2 2>&3)
    else
        DNS_SERVERS=""
    fi
else
    IP_ADDR="dhcp"
    GATEWAY=""
    DNS_SERVERS=""
fi

# Confirm settings
whiptail --title "Confirm Settings" --yesno "Container ID: $CT_ID\nHostname: $HOSTNAME\nDebian Version: $SELECTED_TEMPLATE\nDisk Size: ${DISK_SIZE}G\nMemory: ${MEMORY}MB\nStorage: $STORAGE\nNetwork: $NET_TYPE\nStatic IP: $IP_ADDR\nGateway: $GATEWAY\nDNS: ${DNS_SERVERS:-Auto}\n\nProceed?" 20 60
if [ $? -ne 0 ]; then
    echo "Aborted."
    exit 1
fi

# Check if template exists locally, download if missing
if ! pveam list local | grep -q "$SELECTED_TEMPLATE"; then
    echo "Template $SELECTED_TEMPLATE not found locally. Downloading..."
    pveam download local $SELECTED_TEMPLATE
    if [[ $? -ne 0 ]]; then
        echo "Failed to download $SELECTED_TEMPLATE. Exiting."
        exit 1
    fi
fi

# Create LXC container
echo "Creating LXC container..."
pct create $CT_ID local:vztmpl/$SELECTED_TEMPLATE \
    -hostname $HOSTNAME \
    -storage $STORAGE \
    -rootfs ${STORAGE}:${DISK_SIZE} \
    -memory $MEMORY \
    -password $PASSWORD \
    -net0 "name=eth0,bridge=vmbr0,ip=$IP_ADDR$( [[ -n "$GATEWAY" ]] && echo ",gw=$GATEWAY")"

# Apply DNS settings if set
if [[ -n "$DNS_SERVERS" ]]; then
    echo "Setting custom DNS servers..."
    echo "nameserver $DNS_SERVERS" > /etc/pve/lxc/${CT_ID}.conf
fi

echo "Starting LXC container..."
pct start $CT_ID

# Fetch external scripts from GitHub
USE_GITHUB=$(whiptail --title "External Scripts" --yesno "Do you want to fetch installation scripts from GitHub?" 8 50 3>&1 1>&2 2>&3)
if [[ $? -eq 0 ]]; then
    GITHUB_URLS=$(whiptail --inputbox "Enter GitHub script URLs (space-separated):" 10 60 --title "GitHub Script Fetch" 3>&1 1>&2 2>&3)
    EXTERNAL_SCRIPTS_DIR="/root/lxc-scripts"

    mkdir -p $EXTERNAL_SCRIPTS_DIR
    for url in $GITHUB_URLS; do
        script_name=$(basename $url)
        wget -q $url -O $EXTERNAL_SCRIPTS_DIR/$script_name
        chmod +x $EXTERNAL_SCRIPTS_DIR/$script_name
    done
fi

# Run scripts in LXC
for script in $EXTERNAL_SCRIPTS_DIR/*.sh; do
    echo "Running $(basename $script) on LXC $CT_ID..."
    pct exec $CT_ID -- bash < "$script"
done

echo "LXC Container $CT_ID setup complete!"
whiptail --title "Setup Complete" --msgbox "LXC Container $CT_ID setup is complete!" 8 50
