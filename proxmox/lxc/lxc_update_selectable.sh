#!/bin/bash

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "Whiptail is required but not installed. Install it using: apt-get install whiptail"
    exit 1
fi

# Get a list of existing LXC containers
EXISTING_CONTAINERS=$(pct list | awk 'NR>1 {print $1, $3}' | xargs -n2)

# If no containers exist, exit
if [[ -z "$EXISTING_CONTAINERS" ]]; then
    whiptail --title "No Containers Found" --msgbox "There are no existing LXC containers to update." 8 50
    exit 1
fi

# Format for whiptail checklist (Container ID + Name)
CONTAINER_SELECTION=""
while read -r ID NAME; do
    CONTAINER_SELECTION+="$ID $NAME OFF "
done <<< "$EXISTING_CONTAINERS"

# Show whiptail checklist
SELECTED_CONTAINERS=$(whiptail --title "Select Containers to Update" --checklist \
"Select the containers you want to update:" 20 60 10 $CONTAINER_SELECTION 3>&1 1>&2 2>&3)

# If the user cancels, exit
if [[ $? -ne 0 ]]; then
    whiptail --title "Operation Cancelled" --msgbox "Update cancelled. Exiting." 8 50
    exit 1
fi

# Convert selection to a list
if [[ -n "$SELECTED_CONTAINERS" ]]; then
    for CT_ID in $SELECTED_CONTAINERS; do
        CT_ID=$(echo "$CT_ID" | tr -d '"')  # Remove quotes from whiptail output
        echo "Updating LXC container $CT_ID..."
        pct exec "$CT_ID" -- apt update && apt upgrade -y
        whiptail --title "Update Complete" --msgbox "LXC $CT_ID has been updated successfully!" 8 50
    done
else
    whiptail --title "No Containers Selected" --msgbox "No containers were selected for updating." 8 50
    exit 1
fi
