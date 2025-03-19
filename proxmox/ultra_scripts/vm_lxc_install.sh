# !/bin/bash
# Description: Proxmox LXC or VM Creation Script with git pull
# Tested: Proxmox VE 8.0+ (Bookworm)
# Version: 0.1
# Created by: Clark Industries IO

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "Whiptail is required but not installed. Install it using: sudo apt-get install whiptail"
    exit 1
fi

# Prompt user to choose between VM or LXC
CHOSEN_TYPE=$(whiptail --title "Choose VM or LXC" --menu "Select the type of instance to create:" 15 50 2 \
"VM" "Create a Virtual Machine" \
"LXC" "Create a Linux Container" 3>&1 1>&2 2>&3)

if [[ $? -ne 0 ]]; then
    whiptail --title "Operation Cancelled" --msgbox "Instance creation cancelled." 8 50
    exit 1
fi

# Get the next available ID
AUTO_ID=$(pvesh get /cluster/nextid)
# Get common settings
INSTANCE_ID=$(whiptail --inputbox "Enter Instance ID (default: $AUTO_ID):" 8 50 "$AUTO_ID" --title "$CHOSEN_TYPE Configuration" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then exit 1; fi

INSTANCE_NAME=$(whiptail --inputbox "Enter Hostname:" 8 50 "${CHOSEN_TYPE,,}-$INSTANCE_ID" --title "$CHOSEN_TYPE Configuration" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then exit 1; fi

DISK_SIZE=$(whiptail --inputbox "Enter Disk Size (in GB):" 8 50 10 --title "$CHOSEN_TYPE Configuration" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then exit 1; fi

MEMORY=$(whiptail --inputbox "Enter Memory Size (in MB):" 8 50 2048 --title "$CHOSEN_TYPE Configuration" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then exit 1; fi

# Get available storage from Proxmox
STORAGE_OPTIONS=$(pvesm status | awk 'NR>1 {print $1}' | xargs)
DEFAULT_STORAGE=$(echo "$STORAGE_OPTIONS" | awk '{print $1}')

STORAGE=$(whiptail --menu "Select Storage:" 15 50 5 $(for s in $STORAGE_OPTIONS; do echo "$s [X]"; done) --default-item "$DEFAULT_STORAGE" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then exit 1; fi

# Convert storage options into a format suitable for whiptail menu
STORAGE_SELECTION=""
for s in $STORAGE_OPTIONS; do
    STORAGE_SELECTION+="$s Storage  "  # Correctly format without "off"
done

# Network Configuration
NETWORK_TYPE=$(whiptail --menu "Choose Network Type:" 15 50 2 \
"DHCP" "Automatically assign IP address" \
"Static" "Manually configure IP settings" 3>&1 1>&2 2>&3)

if [[ "$NETWORK_TYPE" == "Static" ]]; then
    IP_ADDRESS=$(whiptail --inputbox "Enter Static IP (e.g., 192.168.1.100/24):" 8 50 --title "Network Configuration" 3>&1 1>&2 2>&3)
    GATEWAY=$(whiptail --inputbox "Enter Gateway (e.g., 192.168.1.1):" 8 50 --title "Network Configuration" 3>&1 1>&2 2>&3)
    DNS=$(whiptail --inputbox "Enter DNS Server (e.g., 8.8.8.8):" 8 50 --title "Network Configuration" 3>&1 1>&2 2>&3)
    NET_CONFIG="ip=$IP_ADDRESS,gw=$GATEWAY"
else
    NET_CONFIG="ip=dhcp"
fi

# VM Creation
if [[ "$CHOSEN_TYPE" == "VM" ]]; then
    ISO_IMAGES=$(ls /var/lib/vz/template/iso | xargs)
    DEFAULT_ISO=$(echo "$ISO_IMAGES" | awk '{print $1}')

    ISO=$(whiptail --menu "Select ISO Image:" 15 60 5 $(for i in $ISO_IMAGES; do echo "$i [X]"; done) --default-item "$DEFAULT_ISO" 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then exit 1; fi

    whiptail --title "Creating VM" --msgbox "Creating VM ID $INSTANCE_ID..." 8 50
    qm create $INSTANCE_ID --name $INSTANCE_NAME --memory $MEMORY --net0 virtio,bridge=vmbr0,$NET_CONFIG \
        --ostype l26 --cdrom local:iso/$ISO --scsihw virtio-scsi-pci --boot c --agent 1 \
        --sockets 1 --cores 2 --cpu host --scsi0 $STORAGE:$DISK_SIZE --ide2 $STORAGE:cloudinit

    qm start $INSTANCE_ID
    whiptail --title "VM Created" --msgbox "VM ID $INSTANCE_ID has been created and started!" 8 50
fi

#LXC Creation
if [[ "$CHOSEN_TYPE" == "LXC" ]]; then

    # Ensure template list is updated
    pveam update > /dev/null

    # Choose between Ubuntu and Debian
    DISTRO=$(whiptail --title "Choose LXC Base OS" --menu "Select the base OS for the LXC:" 15 50 2 \
    "Debian" "Use a Debian template" \
    "Ubuntu" "Use an Ubuntu template" 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then exit 1; fi

    # Get available templates based on selection
    TEMPLATE_LIST=$(pveam available | grep -i "$DISTRO" | awk '{print $2}')
    
    if [ -z "$TEMPLATE_LIST" ]; then
        whiptail --title "Error" --msgbox "No $DISTRO templates found. Run 'pveam update' to refresh." 8 50
        exit 1
    fi

    # User selection of template
    TEMPLATE=$(whiptail --title "Choose LXC Template" --menu "Select a $DISTRO template:" 15 60 6 \
    $(for t in $TEMPLATE_LIST; do echo "$t [X]"; done) 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then exit 1; fi

    # Format the options for whiptail
    TEMPLATE_OPTIONS=()
    for template in $TEMPLATE_LIST; do
    TEMPLATE_OPTIONS+=("$template" "$template")
    done

    # Privileged or Unprivileged LXC
    PRIVILEGED=$(whiptail --yesno "Do you want to create a Privileged container? \n\n⚠️ WARNING: Most LXCs are unprivileged for security.\nProceed with caution if enabling privileged mode." 12 50 --title "LXC Privileged Mode" 3>&1 1>&2 2>&3)
    if [[ $? -eq 0 ]]; then
        LXC_PRIV="1"
        LXC_KEYCTL="off"
    else
        LXC_PRIV="0"
        LXC_KEYCTL="on"
    fi

    # Password for root user
    PASSWORD=$(whiptail --passwordbox "Enter Root Password:" 8 50 --title "LXC Configuration" 3>&1 1>&2 2>&3)
    PASSWORD_CONFIRM=$(whiptail --passwordbox "Confirm Root Password:" 8 50 --title "LXC Configuration" 3>&1 1>&2 2>&3)

    if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
        whiptail --title "Error" --msgbox "Passwords do not match! Please restart." 8 50
        exit 1
    fi

    # Confirm settings
    whiptail --title "Confirm Settings" --yesno "Container ID: $INSTANCE_ID\nHostname: $INSTANCE_NAME\nDebian Version: $SELECTED_TEMPLATE\nDisk Size: ${DISK_SIZE}G\nMemory: ${MEMORY}MB\nStorage: $STORAGE\nNetwork: $NET_TYPE\nStatic IP: $IP_ADDR\nGateway: $GATEWAY\nDNS: ${DNS_SERVERS:-Auto}\n\nProceed?" 20 60
    if [ $? -ne 0 ]; then
    echo "Aborted."
    exit 1
    fi

    # Check if template exists locally, download if missing
    if ! pveam list local | grep -q "$TEMPLATE"; then
    echo "Template $TEMPLATE not found locally. Downloading..."
    pveam download local $TEMPLATE
    if [[ $? -ne 0 ]]; then
    echo "Failed to download $TEMPLATE. Exiting."
    exit 1
    fi
    fi

    # Create LXC container
    echo "Creating LXC container..."
    pct create $INSTANCE_ID local:vztmpl/$TEMPLATE \
    -hostname $INSTANCE_NAME \
    -storage $STORAGE \
    -rootfs ${STORAGE}:${DISK_SIZE} \
    -memory $MEMORY \
    -password $PASSWORD \
    -net0 name=eth0,bridge=vmbr0,$NET_CONFIG \
    -features keyctl=$LXC_KEYCTL \
    -unprivileged $LXC_PRIV

    echo "Starting LXC container..."
    pct start $INSTANCE_ID

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
    bash "$script" "$INSTANCE_ID"
    done

    # Optional: Clean up scripts after execution
    if [ "$(ls -A "$EXTERNAL_SCRIPTS_DIR"/*.sh 2>/dev/null)" ]; then
    rm -rf "$EXTERNAL_SCRIPTS_DIR"
    fi
    echo "Removed downloaded scripts."

    # Remove the installer script itself
    rm -- "$0"

    echo "LXC Container $INSTANCE_ID setup complete!"
    whiptail --title "Setup Complete" --msgbox "LXC Container $INSTANCE_ID setup is complete!" 8 50
    fi
exit 0