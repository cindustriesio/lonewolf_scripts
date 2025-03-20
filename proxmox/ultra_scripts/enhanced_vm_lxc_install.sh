#!/bin/bash
# Description: Proxmox LXC or VM Creation Script
# Version: 1.1
# ProjectL: Lonewolf Scripts
# Created by: Clark Industries IO

# Ensure whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "Whiptail is required but not installed. Install it using: apt-get install whiptail"
    exit 1
fi

# Choose instance type
CHOSEN_TYPE=$(whiptail --title "Choose VM or LXC" --menu "Select the type of instance to create:" 15 50 2 \
"VM" "Create a Virtual Machine" \
"LXC" "Create a Linux Container" 3>&1 1>&2 2>&3)

if [[ $? -ne 0 ]]; then
    whiptail --title "Operation Cancelled" --msgbox "Instance creation cancelled." 8 50
    exit 1
fi

# Get the next available ID
AUTO_ID=$(pvesh get /cluster/nextid)
if [[ $? -ne 0 ]]; then
    whiptail --title "Error" --msgbox "Failed to get next available ID." 8 50
    exit 1
fi
# Part 1: Common Configuration
whiptail --title "Custom Configuration: Part 1" --msgbox "Enter common configuration for $CHOSEN_TYPE" 8 50
if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi

# Select Instance ID
INSTANCE_ID=$(whiptail --inputbox "Enter Instance ID (default: $AUTO_ID):" 8 50 "$AUTO_ID" --title "$CHOSEN_TYPE Configuration" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
# Select Hostname
INSTANCE_NAME=$(whiptail --inputbox "Enter Hostname:" 8 50 "${CHOSEN_TYPE,,}-$INSTANCE_ID" --title "$CHOSEN_TYPE Configuration" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
# Select Disk Size
DISK_SIZE=$(whiptail --inputbox "Enter Disk Size (GB):" 8 50 10 --title "$CHOSEN_TYPE Configuration" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
# Select CPU Cores
CPU_CORES=$(whiptail --inputbox "Enter Number of CPU Cores:" 8 50 2 --title "$CHOSEN_TYPE Configuration" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
# Select Memory Size
MEMORY=$(whiptail --inputbox "Enter Memory Size (MB):" 8 50 2048 --title "$CHOSEN_TYPE Configuration" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi

# Get available storage from Proxmox
STORAGE_OPTIONS=$(pvesm status | awk 'NR>1 {print $1}')
DEFAULT_STORAGE=$(echo "$STORAGE_OPTIONS" | awk '{print $1}')

STORAGE=$(whiptail --menu "Select Storage:" 15 50 5 $(for s in $STORAGE_OPTIONS; do echo "$s _"; done) --default-item "$DEFAULT_STORAGE" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi

# Handle VM Creation
if [[ "$CHOSEN_TYPE" == "VM" ]]; then
    whiptail --title "Custom Configuration: Part 2" --msgbox "$CHOSEN_TYPE Specifc Configuration Settings, Please Contiune." 8 50
    if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
    # Get ISO Images
    ISO_IMAGES=$(ls /var/lib/vz/template/iso | xargs)
    DEFAULT_ISO=$(echo "$ISO_IMAGES" | awk '{print $1}')
    ISO=$(whiptail --menu "Select ISO Image:" 15 60 5 $(for i in $ISO_IMAGES; do echo "$i [_]"; done) --default-item "$DEFAULT_ISO" 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
    # Create VM using qm command
    qm create $INSTANCE_ID --name $INSTANCE_NAME --memory $MEMORY \
        --net0 "virtio,bridge=vmbr0" \
        --cdrom local:iso/$ISO --scsihw virtio-scsi-pci \
        --boot c --agent 1 --sockets 1 --cores $CPU_CORES --cpu host \
        --scsi0 $STORAGE:$DISK_SIZE --ide2 $STORAGE:cloudinit
    # Ask if user wants to start the VM
    if whiptail --yesno "Do you want to start the VM now?" 8 50 --title "Start VM"; then
        qm start $INSTANCE_ID
        whiptail --title "VM Started" --msgbox "VM ID $INSTANCE_ID has been started!" 8 50
    fi
fi

# Handle LXC Creation
if [[ "$CHOSEN_TYPE" == "LXC" ]]; then
    whiptail --title "Custom Configuration: Part 2" --msgbox "$CHOSEN_TYPE Specifc Configuration Settings, Please Contiune." 8 50
    if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
    # Get LXC templates
    pveam update > /dev/null
    DISTRO=$(whiptail --menu "Choose LXC Base OS:" 15 50 2 "Debian" "Use a Debian template" "Ubuntu" "Use an Ubuntu template" 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
    TEMPLATE_LIST=$(pveam available | grep -i "$DISTRO" | awk '{print $2}')
    TEMPLATE=$(whiptail --menu "Select a $DISTRO template:" 30 110 6 $(for t in $TEMPLATE_LIST; do echo "$t _"; done) 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi

    PRIVILEGED=$(whiptail --yesno "Enable Privileged Mode? Most LXCs are unprivileged." 12 50 --title "LXC Privileged Mode" 3>&1 1>&2 2>&3)
    [[ $? -eq 0 ]] && LXC_PRIV="1" || LXC_PRIV="0"
    [[ "$LXC_PRIV" == "0" ]] && LXC_KEYCTL="on" || LXC_KEYCTL="off"
    # Password Configuration
    while true; do
        PASSWORD=$(whiptail --passwordbox "Enter Root Password:" 8 50 --title "LXC Configuration" 3>&1 1>&2 2>&3)
        if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
        CONFIRM_PASSWORD=$(whiptail --passwordbox "Confirm Root Password:" 8 50 --title "LXC Configuration" 3>&1 1>&2 2>&3)
        if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
        if [[ "$PASSWORD" == "$CONFIRM_PASSWORD" ]]; then
            break
        else
            whiptail --title "Error" --msgbox "Passwords do not match. Please try again." 8 50
        fi
    done
    
    # Network Configuration for LXC only
    NET_TYPE=$(whiptail --title "Network Configuration" --menu "Choose Network Type:" 15 50 2 \
    "dhcp" "Use DHCP (Automatic IP)" \
    "static" "Set Static IP Address" 3>&1 1>&2 2>&3)

    if [[ "$NET_TYPE" == "static" ]]; then
        IP_ADDR=$(whiptail --inputbox "Enter Static IP Address (e.g., 192.168.1.100/24):" 10 60 "192.168.1.100/24" --title "Static IP Configuration" 3>&1 1>&2 2>&3)
        if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
        GATEWAY=$(whiptail --inputbox "Enter Gateway (default: 192.168.1.1):" 10 60 "192.168.1.1" --title "Gateway Configuration" 3>&1 1>&2 2>&3)
        if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
        DNS_OPTION=$(whiptail --title "DNS Configuration" --menu "Choose DNS Configuration:" 15 50 2 \
            "auto" "Use Default DNS (Proxmox Resolver)" \
            "manual" "Enter Custom DNS" 3>&1 1>&2 2>&3)
        if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
        if [[ "$DNS_OPTION" == "manual" ]]; then
            DNS_SERVERS=$(whiptail --inputbox "Enter DNS Servers (e.g., 8.8.8.8 1.1.1.1):" 10 60 "8.8.8.8 1.1.1.1" --title "DNS Configuration" 3>&1 1>&2 2>&3)
            if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
        else
            DNS_SERVERS=""
        fi
    else
        IP_ADDR="dhcp"
        GATEWAY=""
        DNS_SERVERS=""
    fi
    # Confirm LXC settings 
    whiptail --title "Confirm Settings" --yesno "Container ID: $INSTANCE_ID\nHostname: $INSTANCE_NAME\n$DISTRO Version: $TEMPLATE\nDisk Size: ${DISK_SIZE}G\nMemory: ${MEMORY}MB\nStorage: $STORAGE\nNetwork: $NET_TYPE\nStatic IP: $IP_ADDR\nGateway: ${GATEWAY:-Auto}\nDNS: ${DNS_SERVERS:-Auto}\n\nProceed?" 20 60
        if [ $? -ne 0 ]; then
        echo "Code Red. Abort. Abort. Abort."
        exit 1
        fi
    echo "Forging LXC Container..."
    pct create $INSTANCE_ID local:vztmpl/$TEMPLATE -hostname $INSTANCE_NAME -storage $STORAGE -rootfs ${STORAGE}:${DISK_SIZE} -cores $CPU_CORES -memory $MEMORY -password $PASSWORD -net0 "name=eth0,bridge=vmbr0,ip=$IP_ADDR$( [[ -n "$GATEWAY" ]] && echo ",gw=$GATEWAY")" -features keyctl=$LXC_KEYCTL -unprivileged $LXC_PRIV
    # Apply DNS settings if set
    if [[ -n "$DNS_SERVERS" ]]; then
        echo "Setting custom DNS servers..."
        echo "nameserver $DNS_SERVERS" > /etc/pve/lxc/${INSTANCE_ID}.conf
    fi
    pct start $INSTANCE_ID
    
    # Ask whether to fetch scripts from GitHub
    USE_GITHUB=$(whiptail --title "External Scripts" --yesno "Do you want to fetch additional scripts from GitHub?" 8 50 3>&1 1>&2 2>&3)
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
        rm -rf "$EXTERNAL_SCRIPTS_DIR"
        echo "Removed downloaded scripts."
        else
        echo "No scripts found in $EXTERNAL_SCRIPTS_DIR. Skipping execution."
        fi
    whiptail --title "LXC Created" --msgbox "LXC Container $INSTANCE_ID has been created and started!" 8 50
fi
exit 0
