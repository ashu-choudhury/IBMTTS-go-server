#!/data/data/com.termux/files/usr/bin/bash

# --- IBMTTS (Eloquence) Termux Setup Script (Fixed) ---
# This version uses Debian Bookworm for stability and a corrected Box86 repo.

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== IBMTTS Android Setup Wizard (v2.0) ===${NC}"

# 1. Base packages
echo -e "${GREEN}[1/5] Installing base packages...${NC}"
pkg update -y
pkg install -y proot-distro wget pulseaudio

# 2. Setup Debian (Bookworm is more stable for this)
echo -e "${GREEN}[2/5] Setting up Debian environment...${NC}"
if proot-distro list | grep -q "debian"; then
    proot-distro remove debian -y
fi
proot-distro install debian

# 3. Enter Debian to install Box86 and Wine
echo -e "${GREEN}[3/5] Installing Box86 and Wine...${NC}"
proot-distro login debian -- bash <<EOF
    apt update
    apt install -y wget gnupg2 software-properties-common ca-certificates
    
    # Enable i386 (required for 32-bit Wine)
    dpkg --add-architecture i386
    apt update

    # Install Box86 from the most reliable current source
    wget https://itai-nelken.github.io/weekly-box86-repo/debian/box86.list -O /etc/apt/sources.list.d/box86.list
    # Note: If the above 404s again, we will use the manual build or a different mirror
    wget -qO- https://itai-nelken.github.io/weekly-box86-repo/debian/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box86.gpg
    
    apt update
    
    # Install Box86 and a minimal Wine
    apt install -y box86-generic:arm64 wine wine32
    
    # Verify installation
    if command -v box86 >/dev/null; then
        echo "Box86 installed successfully."
    else
        echo "Box86 installation failed."
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
echo -e "You can now start the engine by typing: ${GREEN}start-eloquence${NC}"
