#!/bin/bash
# Description: Arrr in a Proxmox LXC container
# Version: .1
# ProjectL: Lonewolf Scripts
# Created by: Clark Industries IO

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

# Install Docker if not installed
install_docker() {
    if ! command -v docker &> /dev/null; then
        log "Docker not found. Installing..."
        apt-get update && apt-get install -y \
            ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common
        curl -fsSL https://download.docker.com/linux/debian/gpg | tee /etc/apt/keyrings/docker.asc > /dev/null
        chmod a+r /etc/apt/keyrings/docker.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        systemctl enable --now docker
    fi
}

# Ensure whiptail is installed
if ! command -v whiptail &> /dev/null; then
    log "whiptail not found. Installing..."
    apt-get update && apt-get install -y whiptail
fi

# Ensure Docker network exists
setup_network() {
    if ! docker network inspect "$DOCKER_NETWORK" >/dev/null 2>&1; then
        docker network create "$DOCKER_NETWORK"
        log "Created Docker network: $DOCKER_NETWORK"
    fi
}

# Prompt for storage location
setup_storage() {
    MEDIA_DIR=$(whiptail --inputbox "Enter media storage directory (default: $MEDIA_DIR)" 10 60 "$MEDIA_DIR" 3>&1 1>&2 2>&3)
    mkdir -p "$MEDIA_DIR"
    log "Media directory set to: $MEDIA_DIR"
}

# Prompt for VPN container
setup_vpn() {
    VPN_CONTAINER=$(whiptail --inputbox "Enter VPN container name (leave empty for none)" 10 60 "" 3>&1 1>&2 2>&3)
    if [ -n "$VPN_CONTAINER" ]; then
        log "Using VPN container: $VPN_CONTAINER"
    else
        log "No VPN container selected."
    fi
}

# Install selected *arr apps
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

# Select apps
select_apps() {
    OPTIONS=(
        "sonarr" "Sonarr" OFF
        "radarr" "Radarr" OFF
        "lidarr" "Lidarr" OFF
        "prowlarr" "Prowlarr" OFF
        "readarr" "Readarr" OFF
        "bazarr" "Bazarr" OFF
        "whisparr" "Whisparr" OFF
        "qbittorrent" "Qbittorrent" OFF
        "jackett" "Jackett" OFF
        "mylar3" "Mylar3" OFF
        "transmission" "Transmission" OFF
        "deluge" "Deluge" OFF
        "flexget" "Flexget" OFF
        "lazylibrarian" "LazyLibrarian" OFF
        "medusa" "Medusa" OFF
        "couchpotato" "CouchPotato" OFF
        "tautulli" "Tautulli" OFF
        "ombi" "Ombi" OFF
        "filebot" "FileBot" OFF
    )

    SELECTED=$(whiptail --checklist "Select *arr apps to install:" 25 80 15 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$SELECTED" ]; then
        log "No apps selected. Exiting..."
        exit 0
    fi

    for app in $SELECTED; do
        case $app in
            "sonarr") install_arr_app "Sonarr" "sonarr" "lscr.io/linuxserver/sonarr" 8989 ;;
            "radarr") install_arr_app "Radarr" "radarr" "lscr.io/linuxserver/radarr" 7878 ;;
            "lidarr") install_arr_app "Lidarr" "lidarr" "lscr.io/linuxserver/lidarr" 8686 ;;
            "prowlarr") install_arr_app "Prowlarr" "prowlarr" "lscr.io/linuxserver/prowlarr" 9696 ;;
            "readarr") install_arr_app "Readarr" "readarr" "lscr.io/linuxserver/readarr" 8787 ;;
            "bazarr") install_arr_app "Bazarr" "bazarr" "lscr.io/linuxserver/bazarr" 6767 ;;
            "whisparr") install_arr_app "Whisparr" "whisparr" "lscr.io/linuxserver/whisparr" 8181 ;;
            "qbittorrent") install_arr_app "Qbittorrent" "qbittorrent" "lscr.io/linuxserver/qbittorrent" 8080 ;;
            "jackett") install_arr_app "Jackett" "jackett" "lscr.io/linuxserver/jackett" 9117 ;;
            "mylar3") install_arr_app "Mylar3" "mylar3" "lscr.io/linuxserver/mylar3" 8090 ;;
            "transmission") install_arr_app "Transmission" "transmission" "lscr.io/linuxserver/transmission" 9091 ;;
            "deluge") install_arr_app "Deluge" "deluge" "lscr.io/linuxserver/deluge" 8112 ;;
            "flexget") install_arr_app "Flexget" "flexget" "flexget/flexget" 5050 ;;
            "lazylibrarian") install_arr_app "LazyLibrarian" "lazylibrarian" "lscr.io/linuxserver/lazylibrarian" 5299 ;;
            "medusa") install_arr_app "Medusa" "medusa" "lscr.io/linuxserver/medusa" 8081 ;;
            "couchpotato") install_arr_app "CouchPotato" "couchpotato" "lscr.io/linuxserver/couchpotato" 5050 ;;
            "tautulli") install_arr_app "Tautulli" "tautulli" "lscr.io/linuxserver/tautulli" 8181 ;;
            "ombi") install_arr_app "Ombi" "ombi" "lscr.io/linuxserver/ombi" 5000 ;;
            "filebot") install_arr_app "FileBot" "filebot" "lscr.io/linuxserver/filebot" 8080 ;;
        esac
    done
}

# Main execution
log "Starting *arr installation..."
install_docker
setup_storage
setup_network
setup_vpn
select_apps
log "Installation complete!"
