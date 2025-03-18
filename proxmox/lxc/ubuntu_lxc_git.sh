# !/bin/bash
# Description: Proxmox LXC setup script for Ubuntu with optional GitHub script fetching
# Tested: Proxmox VE 8.0+ (Bookworm)
# Version: 1.0
# Created by: Clark Industries IO

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "Whiptail is required but not installed. Install it using: apt-get install whiptail"
    exit 1
fi

# Ensure template list is updated
pveam update > /dev/null

# Get available Ubuntu templates
TEMPLATES=$(pveam available | awk '/ubuntu/ {print $2}')
if [[ -z "$TEMPLATES" ]]; then
    echo "No Ubuntu templates found. Run 'pveam update' and ensure Ubuntu templates are available."
    exit 1
fi

# Format the options for whiptail
TEMPLATE_OPTIONS=()
for template in $TEMPLATES; do
    TEMPLATE_OPTIONS+=("$template" "$template")
done

# Let the user select a Ubuntu version
SELECTED_TEMPLATE=$(whiptail --title "Select Ubuntu Version" --menu "Choose a Ubuntu LXC Template:" 30 140 10 "${TEMPLATE_OPTIONS[@]}" 3>&1 1>&2 2>&3)

if [[ -z "$SELECTED_TEMPLATE" ]]; then
    whiptail --title "Error" --msgbox "No template selected. Exiting." 8 50
    exit 1
fi

# Ask the user if the LXC should be privileged or unprivileged
PRIVILEGED_OPTION=$(whiptail --title "LXC Privilege Mode" --radiolist \
"Most LXC containers are unprivileged.\n\n\
⚠️ WARNING: Privileged containers run with elevated permissions.\n\
Only use this if you fully understand the security risks!" \
15 60 2 \
"Unprivileged" "" ON \
"Privileged" "" OFF \
3>&1 1>&2 2>&3)

# Check if user pressed "Cancel"
EXIT_STATUS=$?
# Exit on Cancel
if [ $EXIT_STATUS -ne 0 ]; then
    echo "User cancelled. Exiting..."
    exit 1
fi

# Determine Privileged Flag
if [[ "$PRIVILEGED_OPTION" == "Privileged" ]]; then
    PRIVILEGED_FLAG="1"
    FEATURES="nesting=1,fuse=1"  # Exclude keyctl
else
    PRIVILEGED_FLAG="0"
    FEATURES="nesting=1,keyctl=1,fuse=1"  # Include keyctl for unprivileged containers
fi

# Get available storage options
storage_options=$(pvesm status | awk 'NR>1 {print $1}' | xargs)
default_storage=$(echo $storage_options | awk '{print $1}')

# Convert storage options into a format suitable for whiptail menu
STORAGE_SELECTION=""
for s in $storage_options; do
    STORAGE_SELECTION+="$s Storage  "  # Correctly format without "off"
done

# GUI for LXC configuration

# Function to find the next available LXC ID (starting from 101)
get_next_lxc_id() {
    local START_ID=101
    local NEXT_ID=$START_ID

    while pct list | awk 'NR>1 {print $1}' | grep -q "^$NEXT_ID$"; do
        ((NEXT_ID++))
    done

    echo "$NEXT_ID"
}

# Get the next available LXC ID
AUTO_CT_ID=$(get_next_lxc_id)

# Prompt the user with the default auto-selected LXC ID
CT_ID=$(whiptail --inputbox "Enter Container ID (default: $AUTO_CT_ID):" 8 50 "$AUTO_CT_ID" --title "LXC Configuration" 3>&1 1>&2 2>&3)
# Check if user pressed "Cancel"
EXIT_STATUS=$?
# Exit on Cancel
if [ $EXIT_STATUS -ne 0 ]; then
    echo "User cancelled. Exiting..."
    exit 1
fi

HOSTNAME=$(whiptail --inputbox "Enter Hostname:" 8 50 "ubuntu-lxc" --title "LXC Configuration" 3>&1 1>&2 2>&3)
# Check if user pressed "Cancel"
EXIT_STATUS=$?
# Exit on Cancel
if [ $EXIT_STATUS -ne 0 ]; then
    echo "User cancelled. Exiting..."
    exit 1
fi

DISK_SIZE=$(whiptail --inputbox "Enter Disk Size (in GB):" 8 50 4 --title "LXC Configuration" 3>&1 1>&2 2>&3)
# Check if user pressed "Cancel"
EXIT_STATUS=$?
# Exit on Cancel
if [ $EXIT_STATUS -ne 0 ]; then
    echo "User cancelled. Exiting..."
    exit 1
fi

MEMORY=$(whiptail --inputbox "Enter Memory Size (in MB):" 8 50 512 --title "LXC Configuration" 3>&1 1>&2 2>&3)
# Check if user pressed "Cancel"
EXIT_STATUS=$?
# Exit on Cancel
if [ $EXIT_STATUS -ne 0 ]; then
    echo "User cancelled. Exiting..."
    exit 1
fi

# GUI for selecting storage
STORAGE=$(whiptail --title "Select Storage" --menu \
"Choose where to store the LXC container:" 20 60 10 \
$STORAGE_SELECTION 3>&1 1>&2 2>&3)

# Check if user pressed "Cancel"
# Check if user pressed "Cancel"
EXIT_STATUS=$?
# Exit on Cancel
if [ $EXIT_STATUS -ne 0 ]; then
    echo "User cancelled. Exiting..."
    exit 1
fi

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
whiptail --title "Confirm Settings" --yesno "Container ID: $CT_ID\nHostname: $HOSTNAME\nUbuntu Version: $SELECTED_TEMPLATE\nDisk Size: ${DISK_SIZE}G\nMemory: ${MEMORY}MB\nStorage: $STORAGE\nNetwork: $NET_TYPE\nStatic IP: $IP_ADDR\nGateway: $GATEWAY\nDNS: ${DNS_SERVERS:-Auto}\n\nProceed?" 20 60
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
    -features $FEATURES \
    -unprivileged $PRIVILEGED_FLAG

# Apply DNS settings if set
if [[ -n "$DNS_SERVERS" ]]; then
    echo "Setting custom DNS servers..."
    echo "nameserver $DNS_SERVERS" > /etc/pve/lxc/${CT_ID}.conf
fi

echo "Starting LXC container..."
pct start $CT_ID

# Ask whether to fetch scripts from GitHub
USE_GITHUB=$(whiptail --title "External Scripts" --yesno "Do you want to fetch installation scripts from GitHub?" 8 50 3>&1 1>&2 2>&3)
if [[ $? -eq 0 ]]; then
    # Ask for GitHub script URLs
    GITHUB_URLS=$(whiptail --inputbox "Enter GitHub script URLs (space-separated):" 10 60 --title "GitHub Script Fetch" 3>&1 1>&2 2>&3)
    EXTERNAL_SCRIPTS_DIR="/root/lxc-scripts"

    # Create the directory if it doesn't exist
    mkdir -p "$EXTERNAL_SCRIPTS_DIR"

    # Download scripts from GitHub
    for url in $GITHUB_URLS; do
        script_name=$(basename "$url")
        script_path="$EXTERNAL_SCRIPTS_DIR/$script_name"

        # Download and make the script executable
        wget -q "$url" -O "$script_path"
        chmod +x "$script_path"
    done
fi

# Run scripts on Proxmox (not inside LXC)
if [ -d "$EXTERNAL_SCRIPTS_DIR" ] && [ "$(ls -A "$EXTERNAL_SCRIPTS_DIR"/*.sh 2>/dev/null)" ]; then
    for script in "$EXTERNAL_SCRIPTS_DIR"/*.sh; do
        echo "Running $(basename "$script") on Proxmox..."
        bash "$script" "$CT_ID"
    done

    # Optional: Clean up scripts after execution
    rm -rf "$EXTERNAL_SCRIPTS_DIR"
    echo "Removed downloaded scripts."
else
    echo "No scripts found in $EXTERNAL_SCRIPTS_DIR. Skipping execution."
fi

# Remove the installer script itself
rm -- "$0"

echo "LXC Container $CT_ID setup complete!"
whiptail --title "Setup Complete" --msgbox "LXC Container $CT_ID setup is complete!" 8 50
