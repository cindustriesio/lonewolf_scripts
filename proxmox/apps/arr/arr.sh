#!/bin/bash

# Default settings
MEDIA_DIR="/mnt/media"
DOCKER_NETWORK="arr_network"
VPN_CONTAINER=""
LOG_FILE="/var/log/arr_install.log"

# Ensure log file exists
touch "$LOG_FILE"

log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

# Function to install Docker if not installed
install_docker() {
    if ! command -v docker &> /dev/null; then
        log "Docker not found. Installing..."

        # Install dependencies
        apt-get update && apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release \
            apt-transport-https \
            software-properties-common

        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/debian/gpg | tee /etc/apt/keyrings/docker.asc > /dev/null
        chmod a+r /etc/apt/keyrings/docker.asc

        # Add Docker repository
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
            $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

        apt-get update && apt-get install -y \
            docker-ce \
            docker-ce-cli \
            containerd.io \
            docker-buildx-plugin \
            docker-compose-plugin

        systemctl enable --now docker

        if command -v docker &> /dev/null; then
            log "Docker installed successfully."
        else
            log "Docker installation failed! Check logs for details."
            exit 1
        fi
    else
        log "Docker is already installed."
    fi
}

# Ensure whiptail is installed
if ! command -v whiptail &> /dev/null; then
    log "whiptail not found. Installing..."
    apt-get update && apt-get install -y whiptail
fi

# Function to create Docker network if it doesn't exist
setup_network() {
    if ! docker network inspect "$DOCKER_NETWORK" >/dev/null 2>&1; then
        docker network create "$DOCKER_NETWORK"
        log "Created Docker network: $DOCKER_NETWORK"
    fi
}

# Function to prompt for external mount
setup_storage() {
    MEDIA_DIR=$(whiptail --inputbox "Enter media storage directory (default: $MEDIA_DIR)" 10 60 "$MEDIA_DIR" 3>&1 1>&2 2>&3)
    mkdir -p "$MEDIA_DIR"
    log "Media directory set to: $MEDIA_DIR"
}

# Function to select VPN container
setup_vpn() {
    VPN_CONTAINER=$(whiptail --inputbox "Enter VPN container name (leave empty for none)" 10 60 "" 3>&1 1>&2 2>&3)
    if [ -n "$VPN_CONTAINER" ]; then
        log "Using VPN container: $VPN_CONTAINER"
    else
        log "No VPN container selected."
    fi
}

# Function to install a *arr app
install_arr_app() {
    local app_name=$1
    local container_name=$2
    local image_name=$3
    local port=$4

    log "Installing $app_name..."

    docker run -d \
        --name "$container_name" \
        --network="$DOCKER_NETWORK" \
        -p "$port:$port" \
        -v "$MEDIA_DIR:/media" \
        ${VPN_CONTAINER:+--network container:$VPN_CONTAINER} \
        --restart unless-stopped \
        "$image_name" &>> "$LOG_FILE"

    if [ $? -eq 0 ]; then
        log "$app_name installed successfully."
    else
        log "Failed to install $app_name. Check $LOG_FILE for details."
    fi
}

# Function to display selection menu
select_apps() {
    OPTIONS=(
        "1" "Sonarr" OFF
        "2" "Radarr" OFF
        "3" "Lidarr" OFF
        "4" "Prowlarr" OFF
        "5" "Readarr" OFF
        "6" "Bazarr" OFF
        "7" "Whisparr" OFF
        "8" "Qbittorrent" OFF
        "9" "Jackett" OFF
        "10" "Mylar3" OFF
        "11" "Transmission" OFF
        "12" "Deluge" OFF
        "13" "Flexget" OFF
        "14" "LazyLibrarian" OFF
        "15" "Lidarr" OFF
        "16" "Medusa" OFF
        "17" "CouchPotato" OFF
        "18" "Tautulli" OFF
        "19" "Ombi" OFF
        "20" "FileBot" OFF
    )

    SELECTED=$(whiptail --checklist "Select *arr apps to install:" 25 80 20 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

    for choice in $SELECTED; do
        case $choice in
            "1") install_arr_app "Sonarr" "sonarr" "lscr.io/linuxserver/sonarr" 8989 ;;
            "2") install_arr_app "Radarr" "radarr" "lscr.io/linuxserver/radarr" 7878 ;;
            "3") install_arr_app "Lidarr" "lidarr" "lscr.io/linuxserver/lidarr" 8686 ;;
            "4") install_arr_app "Prowlarr" "prowlarr" "lscr.io/linuxserver/prowlarr" 9696 ;;
            "5") install_arr_app "Readarr" "readarr" "lscr.io/linuxserver/readarr" 8787 ;;
            "6") install_arr_app "Bazarr" "bazarr" "lscr.io/linuxserver/bazarr" 6767 ;;
            "7") install_arr_app "Whisparr" "whisparr" "lscr.io/linuxserver/whisparr" 8181 ;;
            "8") install_arr_app "Qbittorrent" "qbittorrent" "lscr.io/linuxserver/qbittorrent" 8080 ;;
            "9") install_arr_app "Jackett" "jackett" "lscr.io/linuxserver/jackett" 9117 ;;
            "10") install_arr_app "Mylar3" "mylar3" "lscr.io/linuxserver/mylar3" 8090 ;;
            "11") install_arr_app "Transmission" "transmission" "lscr.io/linuxserver/transmission" 9091 ;;
            "12") install_arr_app "Deluge" "deluge" "lscr.io/linuxserver/deluge" 8112 ;;
            "13") install_arr_app "Flexget" "flexget" "flexget/flexget" 5050 ;;
            "14") install_arr_app "LazyLibrarian" "lazylibrarian" "lscr.io/linuxserver/lazylibrarian" 5299 ;;
            "15") install_arr_app "Lidarr" "lidarr" "lscr.io/linuxserver/lidarr" 8686 ;;
            "16") install_arr_app "Medusa" "medusa" "lscr.io/linuxserver/medusa" 8081 ;;
            "17") install_arr_app "CouchPotato" "couchpotato" "lscr.io/linuxserver/couchpotato" 5050 ;;
            "18") install_arr_app "Tautulli" "tautulli" "lscr.io/linuxserver/tautulli" 8181 ;;
            "19") install_arr_app "Ombi" "ombi" "lscr.io/linuxserver/ombi" 5000 ;;
            "20") install_arr_app "FileBot" "filebot" "lscr.io/linuxserver/filebot" 8080 ;;
        esac
    done
}

# Main script execution
log "Starting *arr installation process..."
install_docker
setup_storage
setup_network
setup_vpn
select_apps
log "Installation complete!"
