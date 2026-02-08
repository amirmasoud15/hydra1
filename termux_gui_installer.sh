#!/bin/bash

# ==============================================================================
# Project: Termux Scrcpy X11 Controller
# Description: Advanced ADB & Scrcpy automation tool for Termux users.
#              Stream android screen over TCP/IP to Termux-X11.
# License: MIT
# Version: 2.1.0 Pro
# ==============================================================================

# --- [ Configuration & Globals ] ---
CONFIG_FILE="$HOME/.scrcpy_config"
TERMUX_X11_PKG="termux-x11" 
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

# Trap Ctrl+C to exit gracefully
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
    echo "  ╔════════════════════════════════════════════════╗"
    echo "  ║      TERMUX SCRCPY X11 CONTROLLER PRO          ║"
    echo "  ╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${PURPLE}Author:${NC} GitHub Community"
    echo -e "  ${PURPLE}System:${NC} $(uname -o) | ${PURPLE}X11 Display:${NC} ${DISPLAY:-:1}"
    echo -e "  ${PURPLE}Log:${NC} $LOG_FILE"
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
    else
        echo -e "${GREEN}✔${NC} $pkg_name is already installed."
    fi
}

install_dependencies() {
    header
    log INFO "Configuring repositories..."
    
    # اضافه کردن مخزن X11 به صورت اختصاصی برای اطمینان از وجود دستور termux-x11
    pkg install termux-x11-repo -y >/dev/null 2>&1
    pkg update -y >/dev/null 2>&1
    
    # لیست پکیج‌های مورد نیاز با نام دقیق برای مخازن ترموکس
    local dependencies=("termux-x11-repo" "tur-repo" "android-tools" "scrcpy" "termux-x11" "virglrenderer-android" "pulseaudio" "xterm")
    
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
    if ! command -v termux-x11 &> /dev/null; then
        log ERROR "Command 'termux-x11' not found. Please run Option 1 first."
        return 1
    fi

    if ! pgrep -x "termux-x11" > /dev/null; then
        log INFO "Starting X11 Server (:1)..."
        termux-x11 :1 &
        sleep 3
    else
        log INFO "X11 Server is already running."
    fi
}

connect_device() {
    header
    load_config
    
    echo -e "${BOLD}Setup Wireless Connection${NC}"
    echo -e "Make sure 'Wireless Debugging' is ON in Developer Options.\n"
    
    local default_ip=${LAST_IP:-"192.168.1.100"}
    local default_port=${LAST_PORT:-"5555"}
    
    read -p "$(echo -e "${YELLOW}Target IP [${default_ip}]: ${NC}")" INPUT_IP
    INPUT_IP=${INPUT_IP:-$default_ip}
    
    read -p "$(echo -e "${YELLOW}Port [${default_port}]: ${NC}")" INPUT_PORT
    INPUT_PORT=${INPUT_PORT:-$default_port}
    
    save_config "$INPUT_IP" "$INPUT_PORT"
    
    log INFO "Attempting connection to $INPUT_IP:$INPUT_PORT..."
    adb disconnect >/dev/null 2>&1
    adb connect "$INPUT_IP:$INPUT_PORT" >/dev/null 2>&1 &
    spinner $!
    
    if adb devices | grep -q "$INPUT_IP:$INPUT_PORT"; then
        log SUCCESS "Connected to $INPUT_IP"
    else
        log ERROR "Connection failed! Check IP/Port or Pair code."
    fi
    read -n 1 -s -r -p "Press any key to return..."
}

start_stream() {
    header
    if ! setup_x11; then
        read -n 1 -s -r -p "Press any key to return..."
        return
    fi
    
    if ! adb get-state 1>/dev/null 2>&1; then
        log ERROR "No device connected! Please connect via ADB first."
        read -n 1 -s -r -p "Press any key to return..."
        return
    fi
    
    echo -e "${BOLD}Select Stream Quality:${NC}"
    echo "1) ${GREEN}Performance${NC} (Low Res, High FPS, Low Latency)"
    echo "2) ${YELLOW}Balanced${NC} (720p, Standard Bitrate)"
    echo "3) ${RED}High Quality${NC} (1080p, High Bitrate)"
    echo "4) ${CYAN}Custom${NC} (Edit arguments manually)"
    read -p "Option [1-4]: " quality
    
    local cmd_base="scrcpy --always-on-top --keyboard=uhid"
    
    case $quality in
        1) 
            cmd_args="-m 800 --video-bit-rate 2M --max-fps 60 --no-audio" 
            ;;
        2) 
            cmd_args="-m 1024 --video-bit-rate 4M --max-fps 30" 
            ;;
        3) 
            cmd_args="-m 1920 --video-bit-rate 8M --max-fps 60" 
            ;;
        4)
            read -p "Enter scrcpy args: " cmd_args
            ;;
        *) 
            cmd_args="-m 1024 --video-bit-rate 4M" 
            ;;
    esac
    
    log INFO "Launching Scrcpy..."
    echo -e "${CYAN}> $cmd_base $cmd_args${NC}"
    
    $cmd_base $cmd_args
    
    log INFO "Stream session ended."
    read -n 1 -s -r -p "Press any key to return..."
}

disconnect_all() {
    adb disconnect
    log SUCCESS "All ADB connections killed."
    sleep 1
}

# --- [ Main Loop ] ---

while true; do
    header
    local device_status=$(adb devices | grep -w "device" | awk '{print $1}')
    if [ -z "$device_status" ]; then
        echo -e "Status: ${RED}Disconnected${NC}"
    else
        echo -e "Status: ${GREEN}Connected ($device_status)${NC}"
    fi
    echo "----------------------------------------------------"
    echo -e " ${BOLD}1.${NC} 📦 Check/Install Dependencies"
    echo -e " ${BOLD}2.${NC} 📡 Connect via TCP/IP"
    echo -e " ${BOLD}3.${NC} 📱 Start Scrcpy (Stream)"
    echo -e " ${BOLD}4.${NC} 🔌 Disconnect All"
    echo -e " ${BOLD}5.${NC} 🚪 Exit"
    echo "----------------------------------------------------"
    read -p "Select option: " main_choice
    
    case $main_choice in
        1) install_dependencies ;;
        2) connect_device ;;
        3) start_stream ;;
        4) disconnect_all ;;
        5) echo -e "${CYAN}Good bye!${NC}"; exit 0 ;;
        *) echo "Invalid option" ; sleep 1 ;;
    esac
done
