#!/bin/bash

# ==============================================================================
# Project: Termux Scrcpy X11 Controller PRO
# Version: 2.2.0 (Bug Fix Edition)
# ==============================================================================

# --- [ Configuration ] ---
CONFIG_FILE="$HOME/.scrcpy_config"
LOG_FILE="$HOME/scrcpy_manager.log"

# --- [ Colors ] ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- [ Helper Functions ] ---

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

error() {
    echo -e "${RED}[ERR]${NC} $1"
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

header() {
    clear
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║      TERMUX SCRCPY X11 CONTROLLER PRO          ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo -e " ${YELLOW}Status Check:${NC}"
}

# --- [ Core Functions ] ---

install_dependencies() {
    log "Configuring repositories..."
    pkg install termux-x11-repo -y >/dev/null 2>&1
    pkg update -y
    
    local deps=("android-tools" "scrcpy" "termux-x11" "pulseaudio" "x11-repo" "tur-repo")
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null && ! dpkg -s $dep &> /dev/null; then
            log "Installing $dep..."
            pkg install $dep -y >/dev/null 2>&1 &
            spinner $!
        fi
    done
    success "All dependencies installed."
    read -p "Press Enter to continue..."
}

connect_device() {
    [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
    local def_ip=${LAST_IP:-"192.168.1.100"}
    local def_port=${LAST_PORT:-"5555"}

    read -p "Target IP [$def_ip]: " INPUT_IP
    INPUT_IP=${INPUT_IP:-$def_ip}
    read -p "Port [$def_port]: " INPUT_PORT
    INPUT_PORT=${INPUT_PORT:-$def_port}

    echo "LAST_IP=$INPUT_IP" > "$CONFIG_FILE"
    echo "LAST_PORT=$INPUT_PORT" >> "$CONFIG_FILE"

    log "Restarting ADB Server..."
    adb kill-server
    adb start-server

    log "Connecting to $INPUT_IP:$INPUT_PORT..."
    adb connect "$INPUT_IP:$INPUT_PORT" &
    spinner $!
    
    sleep 2
    if adb devices | grep -q "$INPUT_IP:$INPUT_PORT.*device"; then
        success "Fully Connected!"
    elif adb devices | grep -q "unauthorized"; then
        error "Device Unauthorized! Check your phone screen and allow debugging."
    else
        error "Connection failed or timed out."
    fi
    read -p "Press Enter to continue..."
}

start_stream() {
    export DISPLAY=:1
    if ! pgrep -x "termux-x11" > /dev/null; then
        termux-x11 :1 &
        sleep 2
    fi

    if ! adb devices | grep -q "device$"; then
        error "No active authorized device found!"
        read -p "Press Enter..."
        return
    fi

    log "Launching Scrcpy..."
    scrcpy --always-on-top --video-bit-rate 4M --max-fps 30 --keyboard=uhid
}

# --- [ Main Execution Block ] ---

while true; do
    header
    # Check current ADB status
    ADB_STATUS=$(adb devices | grep -v "List" | grep "device" | awk '{print $1}' | head -n 1)
    if [ -z "$ADB_STATUS" ]; then
        echo -e " Current Device: ${RED}None/Disconnected${NC}"
    else
        echo -e " Current Device: ${GREEN}$ADB_STATUS${NC}"
    fi
    echo "----------------------------------------------------"
    echo "1) Install/Update Dependencies"
    echo "2) Connect via Wireless ADB (TCP/IP)"
    echo "3) Start Streaming to X11"
    echo "4) Disconnect & Kill ADB"
    echo "5) Exit"
    echo "----------------------------------------------------"
    read -p "Select [1-5]: " choice

    case $choice in
        1) install_dependencies ;;
        2) connect_device ;;
        3) start_stream ;;
        4) adb disconnect && adb kill-server && success "ADB reset." ;;
        5) exit 0 ;;
        *) error "Invalid choice" ; sleep 1 ;;
    esac
done
