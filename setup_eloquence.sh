#!/data/data/com.termux/files/usr/bin/bash

# --- IBMTTS (Eloquence) Termux Setup Script (v5.2 - PORTABLE) ---

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== IBMTTS Portable Setup (v5.2) ===${NC}"

# 1. Base packages
echo -e "${GREEN}[1/5] Installing core tools...${NC}"
pkg update -y
pkg install -y proot-distro wget tar

# 2. Setup Alpine
echo -e "${GREEN}[2/5] Setting up Alpine environment...${NC}"
proot-distro remove alpine 2>/dev/null
proot-distro install alpine

# 3. Download Box86 and Portable Wine
echo -e "${GREEN}[3/5] Installing Portable Emulation Layer...${NC}"
proot-distro login alpine -- sh <<EOF
    apk update
    # binutils provides the 'ar' command needed to extract the .deb
    apk add bash wget ca-certificates tar xz gcompat libgcc libstdc++ binutils
    
    # 1. Install Box86 (Verified Android Build)
    echo "Downloading Box86..."
    wget https://github.com/ryanfortner/box86-debs/raw/master/debian/box86-android_0.3.9%2B20260108.0579f8b-1_armhf.deb -O /tmp/box86.deb
    
    mkdir -p /tmp/extract
    cd /tmp/extract
    ar x /tmp/box86.deb
    tar xf data.tar.xz -C /
    chmod +x /usr/local/bin/box86
    echo "Box86 installed."

    # 2. Download Portable Wine (Minimal Build)
    echo "Downloading Portable Wine..."
    mkdir -p /opt/wine
    wget https://github.com/Kron4ek/Wine-Builds/releases/download/9.0/wine-9.0-x86.tar.xz -O /tmp/wine.tar.xz
    tar xf /tmp/wine.tar.xz -C /opt/wine --strip-components=1
    ln -s /opt/wine/bin/wine /usr/local/bin/wine
    echo "Wine installed."
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
export WINEDEBUG=-all
proot-distro login alpine -- bash -c "box86 wine $HOME/ibmtts/ibmtts_server_32bit.exe"
EOF
chmod +x $PREFIX/bin/start-eloquence

echo -e "${BLUE}=== PORTABLE SETUP COMPLETE ===${NC}"
echo -e "Type: ${GREEN}start-eloquence${NC}"
