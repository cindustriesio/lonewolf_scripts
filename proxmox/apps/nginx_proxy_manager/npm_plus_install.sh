#!/bin/bash
# Description: Proxmox install for NPMplus
# Version: .1
# ProjectL: Lonewolf Scripts
# Created by: Clark Industries IO

# Configuration
CTID="$1"  # Container ID passed as an argument
CONF_FILE="/etc/pve/lxc/${CTID}.conf"

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
if [[ -z "$CTID" ]]; then
    msg_error "Usage: $0 <LXC_CONTAINER_ID>"
    exit 1
fi

# Ensure the LXC container exists
if [[ ! -f "$CONF_FILE" ]]; then
    msg_error "LXC container with ID $CTID not found!"
    exit 1
fi

# Generate random passwords
DB_ROOT_PASS=$(openssl rand -base64 24)
DB_USER_PASS=$(openssl rand -base64 24)

msg_info "Generated secure database credentials."

msg_info "Updating Container..."
pct exec "$CTID" -- bash -c "apt update && apt upgrade -y"

msg_info "Installing Dependencies..."
pct exec "$CTID" -- bash -c "apt install -y curl wget gnupg software-properties-common"

msg_info "Installing Docker & Docker-Compose..."
pct exec "$CTID" -- bash -c "apt install -y docker.io docker-compose"
pct exec "$CTID" -- bash -c "systemctl enable --now docker"

msg_info "Creating NPMplus Directory..."
pct exec "$CTID" -- bash -c "mkdir -p /opt/npmplus && cd /opt/npmplus"

msg_info "Setting Up Docker-Compose File..."
pct exec "$CTID" -- bash -c "cat <<"EOF" > /opt/npmplus/docker-compose.yml
version: '3'
services:
  app:
    image: 'ghcr.io/zoeyvid/npmplus:latest'
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    environment:
      DB_MYSQL_HOST: 'db'
      DB_MYSQL_PORT: '3306'
      DB_MYSQL_USER: 'npm'
      DB_MYSQL_PASSWORD: '$DB_USER_PASS'
      DB_MYSQL_NAME: 'npm'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt

  db:
    image: 'mysql:8'
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: '$DB_ROOT_PASS'
      MYSQL_DATABASE: 'npm'
      MYSQL_USER: 'npm'
      MYSQL_PASSWORD: '$DB_USER_PASS'
    volumes:
      - ./mysql:/var/lib/mysql
EOF"

msg_info "Starting NPMplus..."
pct exec "$CTID" -- bash -c "cd /opt/npmplus && docker-compose up -d"

msg_info "Storing Credentials in /root/npmplus_credentials.txt..."
pct exec "$CTID" -- bash -c "cat <<EOF > /root/npmplus_credentials.txt
NPMplus Installation Info:
--------------------------
Admin Login: http://\$(hostname -I | awk '{print $1}'):81
Default Email: admin@example.com
Default Password: changeme

Database Credentials:
---------------------
MySQL Root Password: $DB_ROOT_PASS
MySQL User: npm
MySQL User Password: $DB_USER_PASS

These credentials were auto-generated. 
Change them if necessary.
EOF"

pct exec "$CTID" -- bash -c "chmod 600 /root/npmplus_credentials.txt"

msg_ok "NPMplus Installation Complete!"
msg_info "You can access NPMplus at http://<LXC_IP>:81"
msg_info "Default Login: admin@example.com / changeme"
msg_info "Database credentials are stored in /root/npmplus_credentials.txt"
