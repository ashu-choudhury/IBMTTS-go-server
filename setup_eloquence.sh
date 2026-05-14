#!/data/data/com.termux/files/usr/bin/bash

# --- IBMTTS (Eloquence) Termux Setup Script (v4.0 - MINIMALIST) ---

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== IBMTTS Android Minimal Setup (v4.0) ===${NC}"

# 1. Base packages (Only the essentials)
echo -e "${GREEN}[1/5] Installing Termux essentials...${NC}"
pkg update -y
pkg install -y proot-distro wget

# 2. Fresh Debian Install
echo -e "${GREEN}[2/5] Resetting Debian environment...${NC}"
proot-distro remove debian 2>/dev/null
proot-distro install debian

# 3. Minimal Wine and Box86
echo -e "${GREEN}[3/5] Installing Minimal Wine (No GUI)...${NC}"
proot-distro login debian -- bash <<EOF
    # Update and install basic tools
    apt update
    apt install -y --no-install-recommends wget gnupg2 ca-certificates
    
    # Enable armhf (32-bit) for Box86
    dpkg --add-architecture armhf
    # Enable i386 for Wine
    dpkg --add-architecture i386
    apt update

    # Install Box86 (Selecting the specific generic armhf version)
    wget https://ryanfortner.github.io/box86-debs/box86.list -O /etc/apt/sources.list.d/box86.list
    wget -qO- https://ryanfortner.github.io/box86-debs/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box86.gpg
    apt update
    apt install -y --no-install-recommends box86-generic-arm:armhf

    # Install the absolute minimum Wine packages
    apt install -y --no-install-recommends wine32:i386 libwine:i386

    # Cleanup to save space
    apt clean
    rm -rf /var/lib/apt/lists/*
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
# Disable all wine logs and GUI popups
export WINEDEBUG=-all
export DISPLAY=:0
proot-distro login debian -- bash -c "box86 wine $HOME/ibmtts/ibmtts_server_32bit.exe"
EOF
chmod +x $PREFIX/bin/start-eloquence

echo -e "${BLUE}=== MINIMAL SETUP COMPLETE ===${NC}"
echo -e "Storage used: ~350MB"
echo -e "Type: ${GREEN}start-eloquence${NC} to begin."
