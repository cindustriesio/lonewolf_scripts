#!/bin/bash
# Description: Proxmox LXC or VM Creation Script with Fixes
# Version: 0.7
# Created by: Clark Industries IO

# Ensure whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "Whiptail is required but not installed. Install it using: sudo apt-get install whiptail"
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

# Common Configuration
INSTANCE_ID=$(whiptail --inputbox "Enter Instance ID (default: $AUTO_ID):" 8 50 "$AUTO_ID" --title "$CHOSEN_TYPE Configuration" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi

INSTANCE_NAME=$(whiptail --inputbox "Enter Hostname:" 8 50 "${CHOSEN_TYPE,,}-$INSTANCE_ID" --title "$CHOSEN_TYPE Configuration" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi

DISK_SIZE=$(whiptail --inputbox "Enter Disk Size (GB):" 8 50 10 --title "$CHOSEN_TYPE Configuration" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi

MEMORY=$(whiptail --inputbox "Enter Memory Size (MB):" 8 50 2048 --title "$CHOSEN_TYPE Configuration" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi

# Get available storage from Proxmox
STORAGE_OPTIONS=$(pvesm status | awk 'NR>1 {print $1}')
DEFAULT_STORAGE=$(echo "$STORAGE_OPTIONS" | awk '{print $1}')

STORAGE=$(whiptail --menu "Select Storage:" 15 50 5 $(for s in $STORAGE_OPTIONS; do echo "$s -"; done) --default-item "$DEFAULT_STORAGE" 3>&1 1>&2 2>&3)
if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi

# Network Configuration
if [[ "$CHOSEN_TYPE" == "LXC" ]]; then
    # Choose Network Type (Only for LXC)
    NETWORK_TYPE=$(whiptail --menu "Choose Network Type:" 15 50 2 \
        "DHCP" "Automatically assign IP address" \
        "Static" "Manually configure IP settings" 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then 
        echo "User cancelled. Exiting..."
        exit 1
    fi

    # Default LXC Network Configuration
    NET_CONFIG_LXC="name=eth0,bridge=vmbr0"
    IP_CONFIG_LXC=""

    # Static IP Configuration for LXC
    if [[ "$NETWORK_TYPE" == "Static" ]]; then
        IP_ADDRESS=$(whiptail --inputbox "Enter Static IP (e.g., 192.168.1.100/24):" 8 50 --title "Network Configuration" 3>&1 1>&2 2>&3)
        [[ $? -ne 0 ]] && { echo "User cancelled. Exiting..."; exit 1; }

        GATEWAY=$(whiptail --inputbox "Enter Gateway (e.g., 192.168.1.1):" 8 50 --title "Network Configuration" 3>&1 1>&2 2>&3)
        [[ $? -ne 0 ]] && { echo "User cancelled. Exiting..."; exit 1; }

        DNS=$(whiptail --inputbox "Enter DNS Server (e.g., 8.8.8.8):" 8 50 --title "Network Configuration" 3>&1 1>&2 2>&3)
        [[ $? -ne 0 ]] && { echo "User cancelled. Exiting..."; exit 1; }

        IP_CONFIG_LXC="ip=$IP_ADDRESS,gw=$GATEWAY"
    fi
fi

#NETWORK_TYPE=$(whiptail --menu "Choose Network Type:" 15 50 2 \
#"DHCP" "Automatically assign IP address" \
#"Static" "Manually configure IP settings" 3>&1 1>&2 2>&3)
#if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi

#if [[ "$NETWORK_TYPE" == "Static" ]]; then
#    IP_ADDRESS=$(whiptail --inputbox "Enter Static IP (e.g., 192.168.1.100/24):" 8 50 --title "Network Configuration" 3>&1 1>&2 2>&3)
#    if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
#    GATEWAY=$(whiptail --inputbox "Enter Gateway (e.g., 192.168.1.1):" 8 50 --title "Network Configuration" 3>&1 1>&2 2>&3)
#    if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
#    DNS=$(whiptail --inputbox "Enter DNS Server (e.g., 8.8.8.8):" 8 50 --title "Network Configuration" 3>&1 1>&2 2>&3)
#    if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
#    NET_CONFIG="ip=$IP_ADDRESS,gw=$GATEWAY"
#else
#    NET_CONFIG="ip=dhcp"
#fi

# Handle VM Creation
if [[ "$CHOSEN_TYPE" == "VM" ]]; then
    ISO_IMAGES=$(ls /var/lib/vz/template/iso | xargs)
    DEFAULT_ISO=$(echo "$ISO_IMAGES" | awk '{print $1}')
    ISO=$(whiptail --menu "Select ISO Image:" 15 60 5 $(for i in $ISO_IMAGES; do echo "$i [X]"; done) --default-item "$DEFAULT_ISO" 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
    
#    qm create $INSTANCE_ID --name $INSTANCE_NAME --memory $MEMORY --net0 virtio,bridge=vmbr0,$NET_CONFIG \
#        --ostype l26 --cdrom local:iso/$ISO --scsihw virtio-scsi-pci --boot c --agent 1 \
#        --sockets 1 --cores 2 --cpu host --scsi0 $STORAGE:$DISK_SIZE --ide2 $STORAGE:cloudinit
    qm create $INSTANCE_ID --name $INSTANCE_NAME --memory $MEMORY \
        --net0 "virtio,bridge=vmbr0" \
        --cdrom local:iso/$ISO --scsihw virtio-scsi-pci \
        --boot c --agent 1 --sockets 1 --cores 2 --cpu host \
        --scsi0 $STORAGE:$DISK_SIZE --ide2 $STORAGE:cloudinit

    qm start $INSTANCE_ID
    whiptail --title "VM Created" --msgbox "VM ID $INSTANCE_ID has been created and started!" 8 50
fi

# Handle LXC Creation
if [[ "$CHOSEN_TYPE" == "LXC" ]]; then
    pveam update > /dev/null
    DISTRO=$(whiptail --menu "Choose LXC Base OS:" 15 50 2 "Debian" "Use a Debian template" "Ubuntu" "Use an Ubuntu template" 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi
    TEMPLATE_LIST=$(pveam available | grep -i "$DISTRO" | awk '{print $2}')
    TEMPLATE=$(whiptail --menu "Select a $DISTRO template:" 30 110 6 $(for t in $TEMPLATE_LIST; do echo "$t _"; done) 3>&1 1>&2 2>&3)
    if [[ $? -ne 0 ]]; then { echo "User cancelled. Exiting..."; exit 1; } fi

    PRIVILEGED=$(whiptail --yesno "Enable Privileged Mode? Most LXCs are unprivileged." 12 50 --title "LXC Privileged Mode" 3>&1 1>&2 2>&3)
    [[ $? -eq 0 ]] && LXC_PRIV="1" || LXC_PRIV="0"
    [[ "$LXC_PRIV" == "0" ]] && LXC_KEYCTL="on" || LXC_KEYCTL="off"
    
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
#    pct create $INSTANCE_ID local:vztmpl/$TEMPLATE -hostname $INSTANCE_NAME -storage $STORAGE -rootfs ${STORAGE}:${DISK_SIZE} -memory $MEMORY -password $PASSWORD -net0 name=eth0,bridge=vmbr0,$NET_CONFIG -features keyctl=$LXC_KEYCTL -unprivileged $LXC_PRIV
    pct create $INSTANCE_ID local:vztmpl/$TEMPLATE -hostname $INSTANCE_NAME \
        -storage $STORAGE -rootfs ${STORAGE}:${DISK_SIZE} -memory $MEMORY \
        -password $PASSWORD -net0 "$NET_CONFIG_LXC" -ipconfig0 "$IP_CONFIG_LXC" \
        -features keyctl=$LXC_KEYCTL -unprivileged $LXC_PRIV

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
