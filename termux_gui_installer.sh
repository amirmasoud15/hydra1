#!/bin/bash

# Advanced GUI Screen Mirroring Installer for Termux
# Created with love for seamless phone-to-phone mirroring

# Colors for beautiful UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# UI Elements
BOX_TOP="┌─────────────────────────────────────────────────────┐"
BOX_BOTTOM="└─────────────────────────────────────────────────────┘"
BOX_SIDE="│"
BOX_EMPTY="                                                     "

# Clear screen and set up
clear
setup_terminal() {
    echo -e "${CYAN}"
    if command -v tput >/dev/null 2>&1; then
        tput civis  # Hide cursor
        stty -echo  # Hide input
    fi
}

cleanup() {
    echo -e "${NC}"
    if command -v tput >/dev/null 2>&1; then
        tput cnorm  # Show cursor
        stty echo   # Show input
    fi
    clear
}

trap cleanup EXIT

# Draw box function
draw_box() {
    local title="$1"
    local content="$2"
    local color="$3"
    
    echo -e "${color}"
    echo -e "${BOX_TOP}"
    echo -e "${BOX_SIDE}${WHITE} $title${BOX_EMPTY:${#title}} ${BOX_SIDE}"
    echo -e "${BOX_SIDE}${BOX_EMPTY}${BOX_SIDE}"
    
    while IFS= read -r line; do
        printf "${BOX_SIDE}${WHITE} %-51s ${BOX_SIDE}\n" "$line"
    done <<< "$content"
    
    echo -e "${BOX_SIDE}${BOX_EMPTY}${BOX_SIDE}"
    echo -e "${BOX_BOTTOM}"
    echo -e "${NC}"
}

# Loading animation
loading_animation() {
    local text="$1"
    local duration="$2"
    local chars="/-\|"
    
    for i in $(seq 1 $duration); do
        printf "\r${YELLOW}${text} ${chars:$((i%4)):1}${NC}"
        sleep 0.1
    done
    printf "\r${GREEN}✓ ${text} completed!${NC}\n"
    sleep 0.5
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    
    printf "\r${BLUE}["
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $((width - filled)) | tr ' ' '░'
    printf "] %d%%${NC}" $percentage
}

# Check internet connection
check_internet() {
    draw_box "🌐 Checking Internet Connection" \
"Testing network connectivity..." \
"Ping: google.com" \
"This may take a few seconds..." "$CYAN"
    
    if ping -c 1 google.com >/dev/null 2>&1; then
        echo -e "\n${GREEN}✓ Internet connection available${NC}"
        return 0
    else
        echo -e "\n${RED}✗ No internet connection${NC}"
        return 1
    fi
}

# Update packages
update_packages() {
    draw_box "📦 Updating Package Lists" \
"Refreshing package repositories..." \
"This ensures latest versions..." \
"Please be patient..." "$YELLOW"
    
    pkg update -y >/dev/null 2>&1 &
    local pid=$!
    
    while kill -0 $pid 2>/dev/null; do
        progress_bar 1 2
        sleep 0.5
    done
    progress_bar 2 2
    echo
    
    if wait $pid; then
        echo -e "${GREEN}✓ Packages updated successfully${NC}"
    else
        echo -e "${RED}✗ Failed to update packages${NC}"
        return 1
    fi
}

# Install core packages
install_core_packages() {
    draw_box "🔧 Installing Core Dependencies" \
"Installing essential packages:" \
"• git - Version control" \
"• wget - File downloader" \
"• python - Programming language" \
"• python-pip - Python package manager" \
"• openssh - SSH client/server" \
"• curl - Data transfer tool" \
"• unzip - Archive extractor" "$PURPLE"
    
    local packages="git wget python python-pip openssh curl unzip"
    local total=7
    local current=0
    
    for package in $packages; do
        current=$((current + 1))
        printf "\r${YELLOW}Installing $package...${NC}"
        progress_bar $current $total
        
        if pkg install -y $package >/dev/null 2>&1; then
            sleep 0.3
        else
            echo -e "\n${RED}✗ Failed to install $package${NC}"
            return 1
        fi
    done
    echo
    echo -e "${GREEN}✓ Core packages installed successfully${NC}"
}

# Install Android tools
install_android_tools() {
    draw_box "🤖 Installing Android Tools" \
"Installing ADB and Fastboot:" \
"• android-tools - ADB & Fastboot" \
"• scrcpy - Screen mirroring tool" \
"This enables phone connectivity..." "$BLUE"
    
    loading_animation "Installing Android Tools" 20
    
    if pkg install -y android-tools scrcpy >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Android tools installed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to install Android tools${NC}"
        return 1
    fi
}

# Install X11 packages for graphical display
install_x11_packages() {
    draw_box "🖥️ Installing X11 Environment" \
"Setting up graphical environment:" \
"• x11-repo - X11 repository" \
"• xorg-server - X11 server" \
"• tigervnc - VNC server" \
"• x11-utils - X11 utilities" \
"• feh - Image viewer" "$PURPLE"
    
    # Add X11 repository
    echo -e "${YELLOW}Adding X11 repository...${NC}"
    pkg install -y x11-repo >/dev/null 2>&1
    loading_animation "Repository setup" 15
    
    # Install X11 packages
    local packages="xorg-server tigervnc x11-utils feh"
    local total=4
    local current=0
    
    for package in $packages; do
        current=$((current + 1))
        printf "\r${YELLOW}Installing $package...${NC}"
        progress_bar $current $total
        
        if pkg install -y $package >/dev/null 2>&1; then
            sleep 0.3
        else
            echo -e "\n${RED}✗ Failed to install $package${NC}"
            return 1
        fi
    done
    echo
    echo -e "${GREEN}✓ X11 packages installed successfully${NC}"
}

# Setup X11 environment
setup_x11_environment() {
    draw_box "🔧 Setting Up X11 Environment" \
"Configuring graphical environment:" \
"• Creating VNC configuration" \
"• Setting up display server" \
"• Configuring startup scripts" \
"• Initializing X11 session" "$CYAN"
    
    # Create VNC directory
    mkdir -p ~/.vnc
    
    # Create VNC startup script
    cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
export XKL_XMODMAP_DISABLE=1
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR
EOF
    
    chmod +x ~/.vnc/xstartup
    
    # Create VNC password file
    echo -e "${YELLOW}Setting VNC password (termux):${NC}"
    echo "termux" | vncpasswd -f > ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
    
    echo -e "${GREEN}✓ X11 environment configured${NC}"
}

# Start X11 server
start_x11_server() {
    draw_box "🚀 Starting X11 Server" \
"Initializing graphical environment:" \
"• Starting X11 server" \
"• Setting up display" \
"• Configuring environment" \
"• Ready for applications" "$GREEN"
    
    export DISPLAY=:0
    export XDG_RUNTIME_DIR=/tmp/runtime-root
    mkdir -p $XDG_RUNTIME_DIR
    chmod 700 $XDG_RUNTIME_DIR
    
    # Start X11 server in background
    Xvfb :0 -screen 0 1920x1080x24 >/dev/null 2>&1 &
    X11_PID=$!
    
    sleep 2
    
    if kill -0 $X11_PID 2>/dev/null; then
        echo -e "${GREEN}✓ X11 server started (PID: $X11_PID)${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to start X11 server${NC}"
        return 1
    fi
}

# Start VNC server
start_vnc_server() {
    draw_box "🌐 Starting VNC Server" \
"Launching VNC for remote access:" \
"• Port: 5901" \
"• Password: termux" \
"• Resolution: 1920x1080" \
"• Ready for connection" "$BLUE"
    
    vncserver :1 -geometry 1920x1080 -depth 24 >/dev/null 2>&1 &
    VNC_PID=$!
    
    sleep 3
    
    if pgrep -f "vncserver :1" >/dev/null; then
        echo -e "${GREEN}✓ VNC server started on port 5901${NC}"
        echo -e "${YELLOW}Connect with VNC viewer to localhost:5901${NC}"
        echo -e "${YELLOW}Password: termux${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to start VNC server${NC}"
        return 1
    fi
}

# Setup Python dependencies
setup_python() {
    draw_box "🐍 Setting Up Python Environment" \
"Installing Python packages:" \
"• numpy - Numerical computing" \
"• opencv-python - Computer vision" \
"• requests - HTTP library" \
"• pillow - Image processing" "$GREEN"
    
    pip install --upgrade pip >/dev/null 2>&1
    local packages="numpy opencv-python requests pillow"
    
    for package in $packages; do
        printf "\r${YELLOW}Installing $package...${NC}"
        if pip install $package >/dev/null 2>&1; then
            echo -e "\r${GREEN}✓ $package installed${NC}"
        else
            echo -e "\r${RED}✗ Failed to install $package${NC}"
        fi
        sleep 0.3
    done
}

# Create main GUI script
create_gui_script() {
    draw_box "🎨 Creating GUI Interface" \
"Building beautiful graphical interface..." \
"• Interactive menu system" \
"• Real-time status display" \
"• One-click connectivity" \
"• Advanced configuration options" "$PURPLE"
    
    cat > screen_mirror_gui.sh << 'EOF'
#!/bin/bash

# GUI for Screen Mirroring with X11 Support
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# X11 environment setup
setup_x11_display() {
    export DISPLAY=:1
    export XDG_RUNTIME_DIR=/tmp/runtime-root
    mkdir -p $XDG_RUNTIME_DIR
    chmod 700 $XDG_RUNTIME_DIR
}

show_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      📱 X11 SCREEN MIRRORING CONTROL PANEL         ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE}  1. 🔄 Start ADB Server                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}  2. 📡 Enable TCP/IP Mode                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}  3. 🔗 Connect to Phone                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}  4. �️  Start X11 Mirroring (Window)          ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}  5. 📺 Start X11 Mirroring (Fullscreen)       ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}  6. 🎥 Record Screen (X11)                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}  7. 📊 Show Connection Status                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}  8. ⚙️  X11 Settings                          ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}  9. ❓ Help & Instructions                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 10. 🚪 Exit                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo -e "\n${YELLOW}Enter your choice (1-10):${NC} "
}

get_ip() {
    ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 || \
    ip addr show eth0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 || \
    echo "127.0.0.1"
}

start_adb_server() {
    echo -e "${BLUE}Starting ADB server...${NC}"
    adb start-server
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ADB server started successfully${NC}"
    else
        echo -e "${RED}✗ Failed to start ADB server${NC}"
    fi
    sleep 2
}

enable_tcp() {
    echo -e "${BLUE}Enabling TCP/IP mode on port 5555...${NC}"
    adb tcpip 5555
    if [ $? -eq 0 ]; then
        local ip=$(get_ip)
        echo -e "${GREEN}✓ TCP/IP mode enabled${NC}"
        echo -e "${YELLOW}Your IP: $ip${NC}"
    else
        echo -e "${RED}✗ Failed to enable TCP/IP mode${NC}"
    fi
    sleep 2
}

connect_phone() {
    echo -e "${YELLOW}Enter target phone IP address:${NC}"
    read -r target_ip
    echo -e "${BLUE}Connecting to $target_ip:5555...${NC}"
    adb connect "$target_ip:5555"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Connected successfully${NC}"
    else
        echo -e "${RED}✗ Connection failed${NC}"
    fi
    sleep 2
}

start_x11_windowed_mirroring() {
    setup_x11_display
    echo -e "${BLUE}Starting X11 windowed screen mirroring...${NC}"
    echo -e "${YELLOW}Choose quality:${NC}"
    echo -e "1. High (8Mbps)"
    echo -e "2. Medium (2Mbps)"
    echo -e "3. Low (1Mbps)"
    read -r quality_choice
    
    case $quality_choice in
        1) DISPLAY=:1 scrcpy --window-title="Phone Screen" --max-size=800 --stay-awake -b 8M -m 1920 & ;;
        2) DISPLAY=:1 scrcpy --window-title="Phone Screen" --max-size=800 --stay-awake -b 2M -m 800 & ;;
        3) DISPLAY=:1 scrcpy --window-title="Phone Screen" --max-size=800 --stay-awake -b 1M -m 480 & ;;
        *) DISPLAY=:1 scrcpy --window-title="Phone Screen" --max-size=800 --stay-awake -b 2M -m 800 & ;;
    esac
    
    echo -e "${GREEN}✓ X11 windowed mirroring started${NC}"
    echo -e "${YELLOW}Connect to VNC: localhost:5901 (password: termux)${NC}"
    sleep 2
}

start_x11_fullscreen_mirroring() {
    setup_x11_display
    echo -e "${BLUE}Starting X11 fullscreen screen mirroring...${NC}"
    echo -e "${YELLOW}Choose quality:${NC}"
    echo -e "1. High (8Mbps)"
    echo -e "2. Medium (2Mbps)"
    echo -e "3. Low (1Mbps)"
    read -r quality_choice
    
    case $quality_choice in
        1) DISPLAY=:1 scrcpy --fullscreen --stay-awake -b 8M -m 1920 & ;;
        2) DISPLAY=:1 scrcpy --fullscreen --stay-awake -b 2M -m 800 & ;;
        3) DISPLAY=:1 scrcpy --fullscreen --stay-awake -b 1M -m 480 & ;;
        *) DISPLAY=:1 scrcpy --fullscreen --stay-awake -b 2M -m 800 & ;;
    esac
    
    echo -e "${GREEN}✓ X11 fullscreen mirroring started${NC}"
    echo -e "${YELLOW}Connect to VNC: localhost:5901 (password: termux)${NC}"
    sleep 2
}

record_screen_x11() {
    setup_x11_display
    echo -e "${YELLOW}Enter output filename (e.g., screen_record.mp4):${NC}"
    read -r filename
    
    echo -e "${BLUE}Starting X11 screen recording...${NC}"
    DISPLAY=:1 scrcpy --record="$filename" --stay-awake &
    
    echo -e "${GREEN}✓ Recording started. Check VNC for preview.${NC}"
    echo -e "${YELLOW}Press Ctrl+C in this terminal to stop recording.${NC}"
    wait
}

show_status() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              📊 X11 CONNECTION STATUS              ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════╣${NC}"
    
    local ip=$(get_ip)
    echo -e "${CYAN}║${WHITE} Local IP: $ip${CYAN}                              ║${NC}"
    echo -e "${CYAN}║${WHITE} Display: $DISPLAY${CYAN}                              ║${NC}"
    echo -e "${CYAN}║${WHITE} X11 Server: $(pgrep -f Xvfb >/dev/null && echo "Running" || echo "Stopped")${CYAN}                    ║${NC}"
    echo -e "${CYAN}║${WHITE} VNC Server: $(pgrep -f vncserver >/dev/null && echo "Running" || echo "Stopped")${CYAN}                   ║${NC}"
    echo -e "${CYAN}║${WHITE} ADB Devices: $(adb devices | grep -c "device") device(s)${CYAN}                    ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE} Connected Devices:${CYAN}                             ║${NC}"
    adb devices | grep -v "List of devices" | while read -r line; do
        echo -e "${CYAN}║${WHITE} $line${CYAN}                              ║${NC}"
    done
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo -e "\n${YELLOW}VNC Connection: localhost:5901 (password: termux)${NC}"
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read -r
}

x11_settings() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  ⚙️ X11 SETTINGS                   ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE} 1. 🔄 Restart X11 Server                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 2. 🌐 Restart VNC Server                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 3. 📱 Change Display Resolution              ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 4. 🔧 Change VNC Password                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 5. 📊 Show X11 Process Status              ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE} 6. 🔙 Back to Main Menu                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo -e "\n${YELLOW}Enter your choice (1-6):${NC} "
    read -r setting_choice
    
    case $setting_choice in
        1) 
            echo -e "${BLUE}Restarting X11 server...${NC}"
            pkill -f Xvfb
            sleep 1
            export DISPLAY=:0
            Xvfb :0 -screen 0 1920x1080x24 >/dev/null 2>&1 &
            echo -e "${GREEN}✓ X11 server restarted${NC}"
            sleep 2
            ;;
        2)
            echo -e "${BLUE}Restarting VNC server...${NC}"
            vncserver -kill :1 >/dev/null 2>&1
            sleep 1
            vncserver :1 -geometry 1920x1080 -depth 24 >/dev/null 2>&1 &
            echo -e "${GREEN}✓ VNC server restarted${NC}"
            sleep 2
            ;;
        3)
            echo -e "${YELLOW}Enter resolution (e.g., 1280x720):${NC}"
            read -r resolution
            echo -e "${BLUE}Changing resolution to $resolution...${NC}"
            vncserver -kill :1 >/dev/null 2>&1
            sleep 1
            vncserver :1 -geometry $resolution -depth 24 >/dev/null 2>&1 &
            echo -e "${GREEN}✓ Resolution changed${NC}"
            sleep 2
            ;;
        4)
            echo -e "${YELLOW}Enter new VNC password:${NC}"
            read -r new_password
            echo "$new_password" | vncpasswd -f > ~/.vnc/passwd
            chmod 600 ~/.vnc/passwd
            echo -e "${GREEN}✓ VNC password changed${NC}"
            sleep 2
            ;;
        5)
            echo -e "${BLUE}X11 Processes:${NC}"
            ps aux | grep -E "(Xvfb|vncserver)" | grep -v grep
            echo -e "\n${YELLOW}Press Enter to continue...${NC}"
            read -r
            ;;
        6) return ;;
        *) echo -e "${RED}Invalid choice!${NC}"; sleep 1 ;;
    esac
}

# Main loop
while true; do
    show_menu
    read -r choice
    
    case $choice in
        1) start_adb_server ;;
        2) enable_tcp ;;
        3) connect_phone ;;
        4) start_x11_windowed_mirroring ;;
        5) start_x11_fullscreen_mirroring ;;
        6) record_screen_x11 ;;
        7) show_status ;;
        8) x11_settings ;;
        9) 
            clear
            echo -e "${BLUE}X11 Screen Mirroring Help:${NC}"
            echo -e "${YELLOW}• Connect to VNC: localhost:5901${NC}"
            echo -e "${YELLOW}• VNC Password: termux${NC}"
            echo -e "${YELLOW}• Make sure both phones are on same WiFi${NC}"
            echo -e "${YELLOW}• Use options 4-5 for graphical display${NC}"
            echo -e "${YELLOW}• Option 6 for recording with preview${NC}"
            echo -e "\n${YELLOW}Press Enter to continue...${NC}"
            read -r
            ;;
        10) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid choice!${NC}"; sleep 1 ;;
    esac
done
EOF
    
    chmod +x screen_mirror_gui.sh
    echo -e "${GREEN}✓ GUI script created successfully${NC}"
}

# Create quick launch script
create_quick_launch() {
    cat > quick_start.sh << 'EOF'
#!/bin/bash
# Quick Start X11 Screen Mirroring

echo -e "${CYAN}🚀 Quick Start X11 Screen Mirroring${NC}"

# Start X11 and VNC servers
echo -e "${YELLOW}Starting X11 server...${NC}"
export DISPLAY=:0
Xvfb :0 -screen 0 1920x1080x24 >/dev/null 2>&1 &

echo -e "${YELLOW}Starting VNC server...${NC}"
vncserver :1 -geometry 1920x1080 -depth 24 >/dev/null 2>&1 &
sleep 2

echo -e "${YELLOW}Starting ADB server...${NC}"
adb start-server

echo -e "${YELLOW}Enabling TCP/IP mode...${NC}"
adb tcpip 5555

echo -e "${YELLOW}Getting local IP...${NC}"
LOCAL_IP=$(ip addr show wlan0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
echo -e "${GREEN}Your IP: $LOCAL_IP${NC}"

echo -e "${YELLOW}Enter target phone IP:${NC}"
read -r TARGET_IP

echo -e "${BLUE}Connecting to $TARGET_IP:5555...${NC}"
adb connect "$TARGET_IP:5555"

echo -e "${GREEN}Starting X11 screen mirroring...${NC}"
export DISPLAY=:1
scrcpy --window-title="Phone Screen" --max-size=800 --stay-awake -b 2M -m 800 &

echo -e "${CYAN}VNC Connection: localhost:5901 (password: termux)${NC}"
echo -e "${GREEN}Screen mirroring started in X11 environment!${NC}"
EOF
    
    chmod +x quick_start.sh
}

# Create X11 launcher script
create_x11_launcher() {
    cat > start_x11_mirroring.sh << 'EOF'
#!/bin/bash

# X11 Screen Mirroring Launcher
echo -e "${CYAN}🖥️ Starting X11 Screen Mirroring Environment${NC}"

# Setup environment
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR

# Start X11 server if not running
if ! pgrep -f Xvfb >/dev/null; then
    echo -e "${YELLOW}Starting X11 server...${NC}"
    Xvfb :0 -screen 0 1920x1080x24 >/dev/null 2>&1 &
fi

# Start VNC server if not running
if ! pgrep -f "vncserver :1" >/dev/null; then
    echo -e "${YELLOW}Starting VNC server...${NC}"
    vncserver :1 -geometry 1920x1080 -depth 24 >/dev/null 2>&1 &
fi

echo -e "${GREEN}✓ X11 environment ready${NC}"
echo -e "${YELLOW}VNC: localhost:5901 (password: termux)${NC}"
echo -e "${YELLOW}Starting GUI...${NC}"

# Start the GUI
./screen_mirror_gui.sh
EOF
    
    chmod +x start_x11_mirroring.sh
    echo -e "${GREEN}✓ X11 launcher script created${NC}"
}

# Main installation function
main() {
    setup_terminal
    
    # Welcome screen
    draw_box "🎉 Welcome to X11 Screen Mirroring Installer" \
"This installer will set up everything you need:" \
"• Termux packages and dependencies" \
"• Android Debug Bridge (ADB)" \
"• scrcpy for screen mirroring" \
"• X11 server for graphical display" \
"• VNC server for remote access" \
"• Beautiful GUI interface with X11 support" \
"• Quick launch scripts" \
"" \
"Press Enter to begin installation..." "$CYAN"
    read -r
    
    # Installation steps
    if check_internet; then
        loading_animation "Initializing X11 installation" 10
        
        if update_packages && \
           install_core_packages && \
           install_android_tools && \
           install_x11_packages && \
           setup_python && \
           setup_x11_environment && \
           start_x11_server && \
           start_vnc_server && \
           create_gui_script && \
           create_quick_launch && \
           create_x11_launcher; then
            
            clear
            draw_box "🎊 X11 Installation Complete!" \
"✓ All packages installed successfully" \
"✓ X11 server running" \
"✓ VNC server on port 5901" \
"✓ GUI interface created" \
"✓ Quick launch scripts ready" \
"" \
"VNC Connection:" \
"• Address: localhost:5901" \
"• Password: termux" \
"" \
"To start the GUI, run:" \
"./start_x11_mirroring.sh" \
"" \
"For quick start, run:" \
"./quick_start.sh" \
"" \
"Enjoy graphical screen mirroring! �️" "$GREEN"
            
            echo -e "\n${CYAN}Files created:${NC}"
            echo -e "${WHITE}• screen_mirror_gui.sh${NC} - Full GUI interface"
            echo -e "${WHITE}• start_x11_mirroring.sh${NC} - X11 launcher"
            echo -e "${WHITE}• quick_start.sh${NC} - Quick launch script"
            echo -e "${WHITE}• ~/.vnc/xstartup${NC} - VNC config"
            
        else
            draw_box "❌ Installation Failed" \
"Some components failed to install." \
"Please check your internet connection" \
"and try running the installer again." "$RED"
        fi
    else
        draw_box "🌐 No Internet Connection" \
"Please connect to the internet" \
"and run the installer again." "$RED"
    fi
    
    echo -e "\n${YELLOW}Press Enter to exit...${NC}"
    read -r
}

# Run main function
main "$@"
EOF

sudo chmod +x termux_gui_installer.sh
