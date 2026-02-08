#!/bin/bash

# ==============================================================================
# Project: Termux Scrcpy X11 Controller
# Description: Advanced ADB & Scrcpy automation tool for Termux users.
#              Stream android screen over TCP/IP to Termux-X11.
# Version: 3.2.0 Pro (Stable Edition)
# ==============================================================================

# --- [ Configuration & Globals ] ---
CONFIG_FILE="$HOME/.scrcpy_config"
LOG_FILE="$HOME/scrcpy_manager.log"

# --- [ Colors & Styling ] ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- [ Helper Functions ] ---

trap cleanup SIGINT

cleanup() {
    echo -e "\n${RED}[!] Force exit detected. Cleaning up...${NC}"
    exit 1
}

log() {
    local type=$1
    local message=$2
    local timestamp=$(date "+%H:%M:%S")
    case $type in
        INFO) echo -e "${BLUE}[INFO]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[OK]${NC} $message" ;;
        WARN) echo -e "${YELLOW}[WARN]${NC} $message" ;;
        ERROR) echo -e "${RED}[ERR]${NC} $message" ;;
    esac
    echo "[$timestamp] [$type] $message" >> "$LOG_FILE"
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
    echo -e "${CYAN}${BOLD}"
    echo "  ██╗  ██╗██╗   ██╗██████╗ ██████╗  █████╗ "
    echo "  ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗"
    echo "  ███████║ ╚████╔╝ ██║  ██║██████╔╝███████║"
    echo "  ██╔══██║  ╚██╔╝  ██║  ██║██╔══██╗██╔══██║"
    echo "  ██║  ██║   ██║   ██████╔╝██║  ██║██║  ██║"
    echo "  ╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "  ${PURPLE}System:${NC} $(uname -o) | ${PURPLE}X11 Display:${NC} ${DISPLAY:-:1}"
    echo "----------------------------------------------------"
}

# --- [ Core Logic ] ---

check_and_install() {
    local pkg_name=$1
    if ! dpkg -s "$pkg_name" >/dev/null 2>&1 && ! command -v "$pkg_name" >/dev/null 2>&1; then
        log INFO "Installing missing package: $pkg_name..."
        pkg install "$pkg_name" -y >/dev/null 2>&1 &
        spinner $!
        log SUCCESS "$pkg_name installed."
    fi
}

install_dependencies() {
    header
    log INFO "Configuring repositories..."
    pkg install termux-x11-repo -y >/dev/null 2>&1
    pkg update -y
    
    local dependencies=("android-tools" "scrcpy" "termux-x11" "pulseaudio" "x11-repo" "tur-repo" "virglrenderer-android")
    
    for dep in "${dependencies[@]}"; do
        check_and_install "$dep"
    done
    
    log SUCCESS "All dependencies are ready!"
    read -n 1 -s -r -p "Press any key to continue..."
}

save_config() {
    echo "LAST_IP=$1" > "$CONFIG_FILE"
    echo "LAST_PORT=$2" >> "$CONFIG_FILE"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

setup_x11() {
    export DISPLAY=:1
    if ! pgrep -x "termux-x11" > /dev/null; then
        log INFO "Starting X11 Server (:1)..."
        termux-x11 :1 &
        sleep 3
    fi
    
    if ! pgrep -x "pulseaudio" > /dev/null; then
        log INFO "Starting Audio Server..."
        pulseaudio --start --exit-idle-time=-1 >/dev/null 2>&1
    fi
}

connect_device() {
    header
    load_config
    
    echo -e "${BOLD}Setup Wireless Connection${NC}"
    local default_ip=${LAST_IP:-"192.168.1.100"}
    local default_port=${LAST_PORT:-"5555"}
    
    read -p "$(echo -e "${YELLOW}Target IP [${default_ip}]: ${NC}")" INPUT_IP
    INPUT_IP=${INPUT_IP:-$default_ip}
    read -p "$(echo -e "${YELLOW}Port [${default_port}]: ${NC}")" INPUT_PORT
    INPUT_PORT=${INPUT_PORT:-$default_port}
    
    save_config "$INPUT_IP" "$INPUT_PORT"
    
    log INFO "Resetting ADB and connecting to $INPUT_IP:$INPUT_PORT..."
    adb kill-server >/dev/null 2>&1
    adb start-server >/dev/null 2>&1
    
    # Run connect in background to prevent hanging
    adb connect "$INPUT_IP:$INPUT_PORT" > /dev/null 2>&1 &
    spinner $!
    
    sleep 3
    local check_status=$(adb devices | grep "$INPUT_IP:$INPUT_PORT")
    
    if echo "$check_status" | grep -q "device$"; then
        log SUCCESS "Connection established in background!"
    elif echo "$check_status" | grep -q "unauthorized"; then
        log WARN "Device unauthorized! Check phone screen."
    else
        log ERROR "Connection failed. Verify IP/Port."
    fi
    read -n 1 -s -r -p "Press any key to return..."
}

start_stream() {
    header
    
    if ! adb devices | grep -v "List" | grep -q "device$"; then
        log ERROR "No active device! Please connect first (Option 2)."
        read -n 1 -s -r -p "Press any key to return..."
        return
    fi

    setup_x11
    
    echo -e "${BOLD}Select Stream Quality:${NC}"
    echo "1) ${GREEN}Performance${NC} (High FPS)"
    echo "2) ${YELLOW}Balanced${NC} (720p)"
    echo "3) ${RED}Quality${NC} (1080p)"
    read -p "Option [1-3]: " quality
    
    local sc_args="--always-on-top --keyboard=uhid --mouse=uhid --power-off-on-close"
    
    case $quality in
        1) sc_args="$sc_args -m 800 --video-bit-rate 2M --max-fps 60" ;;
        2) sc_args="$sc_args -m 1280 --video-bit-rate 4M --max-fps 30" ;;
        3) sc_args="$sc_args -m 1920 --video-bit-rate 10M --max-fps 60" ;;
        *) sc_args="$sc_args -m 1024" ;;
    esac
    
    log INFO "Launching Scrcpy..."
    scrcpy $sc_args
    
    log INFO "Stream session ended."
    read -n 1 -s -r -p "Press any key to return..."
}

disconnect_all() {
    adb disconnect >/dev/null 2>&1
    adb kill-server >/dev/null 2>&1
    log SUCCESS "All ADB connections reset."
    sleep 1
}

# --- [ Main Loop ] ---

while true; do
    header
    
    # Advanced Status Check for Dashboard
    DEVICE_LINE=$(adb devices | grep -v "List" | grep -v "^$" | head -n 1)
    if [ -z "$DEVICE_LINE" ]; then
        STATUS_STR="${RED}OFFLINE${NC}"
    elif echo "$DEVICE_LINE" | grep -q "unauthorized"; then
        STATUS_STR="${YELLOW}UNAUTHORIZED${NC}"
    else
        DEV_ID=$(echo "$DEVICE_LINE" | awk '{print $1}')
        STATUS_STR="${GREEN}CONNECTED ($DEV_ID)${NC}"
    fi
    
    echo -e " Status: $STATUS_STR"
    echo "----------------------------------------------------"
    echo -e " ${BOLD}1.${NC} 📦 Check/Install Dependencies"
    echo -e " ${BOLD}2.${NC} 📡 Connect via Wireless ADB"
    echo -e " ${BOLD}3.${NC} 📱 Start Scrcpy Stream"
    echo -e " ${BOLD}4.${NC} 🔌 Reset ADB Connections"
    echo -e " ${BOLD}5.${NC} 🚪 Exit"
    echo "----------------------------------------------------"
    read -p "Select option: " main_choice
    
    case $main_choice in
        1) install_dependencies ;;
        2) connect_device ;;
        3) start_stream ;;
        4) disconnect_all ;;
        5) echo -e "${CYAN}Good bye!${NC}"; exit 0 ;;
        *) sleep 0.5 ;;
    esac
done
