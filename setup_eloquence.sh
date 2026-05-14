#!/data/data/com.termux/files/usr/bin/bash

# --- IBMTTS (Eloquence) Termux Setup Script ---
# This script sets up Box86 + Wine inside a proot-distro to run the 32-bit engine.

# Colors for better visibility
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== IBMTTS Android Setup Wizard ===${NC}"

# 1. Update and install base requirements
echo -e "${GREEN}[1/5] Installing base packages...${NC}"
pkg update -y
pkg install -y proot-distro wget pulseaudio

# 2. Setup Debian-Slim container (Lightweight)
echo -e "${GREEN}[2/5] Setting up Debian environment...${NC}"
if ! proot-distro list | grep -q "debian"; then
    proot-distro install debian
fi

# 3. Enter Debian to install Box86 and Wine
echo -e "${GREEN}[3/5] Configuring Box86 and Wine inside Debian...${NC}"
# We use a heredoc to run commands inside the proot
proot-distro login debian -- bash <<EOF
    apt update
    apt install -y wget gnupg2 software-properties-common
    
    # Add Box86 repository (optimized for ARM)
    wget https://itai-nelken.github.io/weekly-box86-repo/debian/box86.list -O /etc/apt/sources.list.d/box86.list
    wget -qO- https://itai-nelken.github.io/weekly-box86-repo/debian/KEY.gpg | apt-key add -
    
    # Enable 32-bit architecture
    dpkg --add-architecture i386
    apt update
    
    # Install Box86 and a minimal Wine build
    apt install -y box86 wine i386-wine-stable
    
    echo "Box86 and Wine installed successfully."
EOF

# 4. Download the IBMTTS Bridge Server
# NOTE: Replace the URL below with your GitHub release link
SERVER_URL="PASTE_YOUR_GITHUB_RELEASE_URL_HERE"
echo -e "${GREEN}[4/5] Downloading IBMTTS Server...${NC}"
mkdir -p $HOME/ibmtts
# For now, we assume you will copy the ibmtts_server_32bit.exe to $HOME/ibmtts manually 
# if you haven't uploaded it to GitHub yet.

# 5. Create the startup shortcut
echo -e "${GREEN}[5/5] Creating startup script...${NC}"
cat <<EOF > $PREFIX/bin/start-eloquence
#!/data/data/com.termux/files/usr/bin/bash
echo "Starting IBMTTS Bridge Server..."
# We run headless: No X11, No logs, Background mode
proot-distro login debian -- bash -c "WINEDEBUG=-all box86 wine $HOME/ibmtts/ibmtts_server_32bit.exe"
EOF
chmod +x $PREFIX/bin/start-eloquence

echo -e "${BLUE}=== SETUP COMPLETE ===${NC}"
echo -e "You can now start the engine by typing: ${GREEN}start-eloquence${NC}"
echo -e "Make sure your Android App connects to ${GREEN}127.0.0.1:5555${NC}"
