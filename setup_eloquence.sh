#!/data/data/com.termux/files/usr/bin/bash

# --- IBMTTS (Eloquence) Termux Setup Script (v3.0) ---

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== IBMTTS Android Setup Wizard (v3.0) ===${NC}"

# 1. Base packages
echo -e "${GREEN}[1/5] Installing base packages...${NC}"
pkg update -y
pkg install -y proot-distro wget pulseaudio

# 2. Hard Reset Debian
echo -e "${GREEN}[2/5] Cleaning and Resetting Debian environment...${NC}"
proot-distro remove debian 2>/dev/null
proot-distro install debian

# 3. Enter Debian to install Box86 and Wine
echo -e "${GREEN}[3/5] Installing Box86 and Wine (Using Modern Repos)...${NC}"
proot-distro login debian -- bash <<EOF
    apt update
    apt install -y wget gnupg2 ca-certificates
    
    # Enable 32-bit architecture
    dpkg --add-architecture i386
    apt update

    # Install Wine and dependencies first
    apt install -y wine wine32 libwine:i386

    # Install Box86 using the official RyanFortner build (very stable)
    wget https://ryanfortner.github.io/box86-debs/box86.list -O /etc/apt/sources.list.d/box86.list
    wget -qO- https://ryanfortner.github.io/box86-debs/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box86.gpg
    
    apt update
    apt install -y box86
    
    if command -v box86 >/dev/null; then
        echo "Box86 installed successfully."
    else
        # Fallback: Install via direct download if repo fails
        echo "Repo failed, trying direct download..."
        wget https://github.com/ptitSeb/box86/releases/download/v0.3.2/box86-generic_0.3.2_arm64.deb -O box86.deb
        apt install ./box86.deb -y
    fi
EOF

# 4. Download the IBMTTS Bridge Server
REPO_URL="https://github.com/ashu-choudhury/IBMTTS-go-server"
SERVER_URL="${REPO_URL}/releases/latest/download/ibmtts_server_32bit.exe"

echo -e "${GREEN}[4/5] Downloading IBMTTS Server...${NC}"
mkdir -p $HOME/ibmtts
wget -q "$SERVER_URL" -O $HOME/ibmtts/ibmtts_server_32bit.exe

# 5. Create the startup shortcut
echo -e "${GREEN}[5/5] Creating startup script...${NC}"
cat <<EOF > $PREFIX/bin/start-eloquence
#!/data/data/com.termux/files/usr/bin/bash
echo "Starting IBMTTS Bridge Server..."
# Disable wine debug logs for better performance
proot-distro login debian -- bash -c "WINEDEBUG=-all box86 wine $HOME/ibmtts/ibmtts_server_32bit.exe"
EOF
chmod +x $PREFIX/bin/start-eloquence

echo -e "${BLUE}=== SETUP COMPLETE ===${NC}"
echo -e "Try typing: ${GREEN}start-eloquence${NC}"
