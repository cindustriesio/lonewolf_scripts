#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Function to configure Proxmox repository
configure_repository() {
    REPO_CHOICE=$(whiptail --title "Proxmox Repository Selection" --menu \
    "Choose which Proxmox repository to use:\n(Only one will be active)" 15 80 3 \
    "no-subscription" "Default: No-Subscription Repository (Recommended)" \
    "enterprise" "Enterprise Repository (Requires a valid subscription)" \
    "test" "Test Repository (Use with caution!)" 3>&1 1>&2 2>&3)

    # If the user cancels, exit
    if [[ $? -ne 0 ]]; then
        whiptail --title "Operation Cancelled" --msgbox "Repository selection cancelled. Exiting." 8 50
        exit 1
    fi

    # Define repo paths
    NO_SUBSCRIPTION_REPO="/etc/apt/sources.list.d/pve-no-subscription.list"
    ENTERPRISE_REPO="/etc/apt/sources.list.d/pve-enterprise.list"
    TEST_REPO="/etc/apt/sources.list.d/pve-test.list"

    # Define repository entries
    NO_SUBSCRIPTION_ENTRY="deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription"
    ENTERPRISE_ENTRY="deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise"
    TEST_ENTRY="deb http://download.proxmox.com/debian/pve bookworm pvetest"

    # Function to enable selected repo and disable others
    set_active_repo() {
        local active_file="$1"
        local active_entry="$2"

        # Disable other repos
        for repo in "$NO_SUBSCRIPTION_REPO" "$ENTERPRISE_REPO" "$TEST_REPO"; do
            if [[ -f "$repo" && "$repo" != "$active_file" ]]; then
                echo "[INFO] Disabling repository: $repo"
                mv "$repo" "$repo.disabled"
            fi
        done

        # Enable selected repo
        if [[ -f "$active_file.disabled" ]]; then
            echo "[INFO] Re-enabling repository: $active_file"
            mv "$active_file.disabled" "$active_file"
        fi

        # Add repo if missing
        if ! grep -qxF "$active_entry" "$active_file" 2>/dev/null; then
            echo "[INFO] Adding repository: $active_entry"
            echo "$active_entry" | tee "$active_file" > /dev/null
        else
            echo "[INFO] Repository already active: $active_file"
        fi
    }

    # Apply the selected repository
    case "$REPO_CHOICE" in
        "no-subscription") set_active_repo "$NO_SUBSCRIPTION_REPO" "$NO_SUBSCRIPTION_ENTRY" ;;
        "enterprise") set_active_repo "$ENTERPRISE_REPO" "$ENTERPRISE_ENTRY" ;;
        "test") set_active_repo "$TEST_REPO" "$TEST_ENTRY" ;;
    esac

    # Update package list
    echo "Updating package lists..."
    apt update

    whiptail --title "Repository Configured" --msgbox "The Proxmox repository has been set to '$REPO_CHOICE'.\nUnused repositories have been disabled.\nPackages updated successfully!" 10 60
}

# Run the function
configure_repository

# Confirm settings
whiptail --title "Confirm Settings" --yesno "Are you sure you want to update ProxmoxVE?" 20 60

# Check if user pressed "no"
if [[ $? -ne 0 ]]; then
    whiptail --title "Operation Cancelled" --msgbox "Exited Update." 8 50
    exit 1
fi

whiptail --title "Updating" --infobox "Updating ProxmoxVE...please wait..." 8 40

# updating to latest version
echo "Upgrading installed packages..."
apt-get upgrade -y

# updating to latest version
echo "Performing dist-upgrade..."
apt-get dist-upgrade -y

# removes old files
echo "Removing unused packages..."
apt-get autoremove -y

# Clean up update files
echo "Cleaning up package cache..."
apt-get clean

# completed update confirmation
whiptail --title "Update Complete" --msgbox "Proxmox has been from '$REPO_CHOICE'.\nPackages updated successfully!" 10 60

echo "Yay, you did it! Rebooting in 10 seconds..."
sleep 10
reboot
