#!/bin/bash
# Description: Update Keycloak to the latest version
# Version: 1.0
# Created by: Clark Industries IO

# Set variables
KEYCLOAK_DIR="/opt/keycloak"
BACKUP_DIR="/root/keycloak_backup_$(date +%Y%m%d_%H%M%S)"
LATEST_VERSION=$(curl -s https://api.github.com/repos/keycloak/keycloak/releases/latest | jq -r '.tag_name')

# Stop Keycloak service
echo "Stopping Keycloak..."
systemctl stop keycloak

# Backup current Keycloak installation
echo "Backing up existing Keycloak to $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"
cp -r "$KEYCLOAK_DIR" "$BACKUP_DIR"

# Download latest Keycloak release
echo "Downloading Keycloak $LATEST_VERSION..."
cd /opt
wget -q wget "https://github.com/keycloak/keycloak/releases/download/$LATEST_VERSION/keycloak-$LATEST_VERSION.tar.gz"
unzip -q "keycloak-$LATEST_VERSION.zip"
mv "keycloak-$LATEST_VERSION" keycloak-new
rm "keycloak-$LATEST_VERSION.zip"

# Copy old configurations
echo "Copying configuration files..."
cp -r "$KEYCLOAK_DIR/conf" "keycloak-new/"
cp -r "$KEYCLOAK_DIR/data" "keycloak-new/"
cp -r "$KEYCLOAK_DIR/themes" "keycloak-new/"
cp -r "$KEYCLOAK_DIR/providers" "keycloak-new/"

# Apply database migrations Comment out unless needed!
#echo "Running database migrations..."
#/opt/keycloak-new/bin/kc.sh start --optimized --auto-build

# Replace old Keycloak version
echo "Replacing old Keycloak version..."
mv "$KEYCLOAK_DIR" "${KEYCLOAK_DIR}_old"
mv "keycloak-new" "$KEYCLOAK_DIR"

# Restart Keycloak
echo "Restarting Keycloak..."
systemctl start keycloak

# Clean up old files
echo "Cleaning up old files..."
rm -rf "${KEYCLOAK_DIR}_old"

echo "Keycloak successfully updated to $LATEST_VERSION!"
