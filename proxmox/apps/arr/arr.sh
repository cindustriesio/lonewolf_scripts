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
        log "Failed to install $app_name."
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
        "11" "Overseerr" OFF
        "12" "Ombi" OFF
        "13" "Tautulli" OFF
        "14" "Medusa" OFF
        "15" "Nefarious" OFF
        "16" "LazyLibrarian" OFF
        "17" "Headphones" OFF
        "18" "SickChill" OFF
        "19" "Watcher" OFF
        "20" "FlareSolverr" OFF
        "21" "Byparr" OFF
        "22" "Checkrr" OFF
        "23" "CloudSeeder" OFF
        "24" "Unpackerr" OFF
        "25" "Gaps" OFF
        "26" "Sickbeard MP4 Automator" OFF
        "27" "theme.park" OFF
        "28" "Flemarr" OFF
        "29" "Buildarr" OFF
    )

    SELECTED=$(whiptail --checklist "Select *arr apps to install:" 25 80 15 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)

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
            "11") install_arr_app "Overseerr" "overseerr" "lscr.io/linuxserver/overseerr" 5055 ;;
            "12") install_arr_app "Ombi" "ombi" "lscr.io/linuxserver/ombi" 3579 ;;
            "13") install_arr_app "Tautulli" "tautulli" "lscr.io/linuxserver/tautulli" 8181 ;;
            "14") install_arr_app "Medusa" "medusa" "lscr.io/linuxserver/medusa" 8081 ;;
            "15") install_arr_app "Nefarious" "nefarious" "lscr.io/linuxserver/nefarious" 8085 ;;
            "16") install_arr_app "LazyLibrarian" "lazylibrarian" "lscr.io/linuxserver/lazylibrarian" 5299 ;;
            "17") install_arr_app "Headphones" "headphones" "lscr.io/linuxserver/headphones" 8181 ;;
            "18") install_arr_app "SickChill" "sickchill" "lscr.io/linuxserver/sickchill" 8081 ;;
            "19") install_arr_app "Watcher" "watcher" "lscr.io/linuxserver/watcher" 9090 ;;
            "20") install_arr_app "FlareSolverr" "flaresolverr" "lscr.io/linuxserver/flaresolverr" 8191 ;;
            "21") install_arr_app "Byparr" "byparr" "ghcr.io/byparr/byparr" 8191 ;;
        esac
    done
}

# Main script execution
log "Starting *arr installation process..."
setup_storage
setup_network
setup_vpn
select_apps
log "Installation complete!"
