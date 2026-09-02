#!/usr/bin/env bash
# ==============================================================================
# Antigravity IDE - Linux Install & Update Script (Ubuntu / Debian)
# Repository: https://github.com/Seburan/antigravity-ide-linux-update
# ==============================================================================

set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

INSTALL_DIR="/opt/antigravity"
DESKTOP_ENTRY_DIR="$HOME/.local/share/applications"
DESKTOP_ENTRY_FILE="$DESKTOP_ENTRY_DIR/antigravity-ide.desktop"

SCRIPT_NAME=$(basename "$0")
if [[ "$SCRIPT_NAME" == "install.sh" ]] || [[ ! -d "$INSTALL_DIR" ]]; then
    ACTION_TYPE="Install"
else
    ACTION_TYPE="Update"
fi

echo -e "${BLUE}${BOLD}=== Antigravity IDE Linux ${ACTION_TYPE}r ===${NC}\n"

# 1. Locate Archive
ARCHIVE_PATH="${1:-}"

if [[ -z "$ARCHIVE_PATH" ]]; then
    # Look for matching archive in ~/Downloads
    DEFAULT_ARCHIVE=$(ls -t "$HOME"/Downloads/Antigravity*IDE*.tar.gz "$HOME"/Downloads/antigravity*.tar.gz 2>/dev/null | head -n 1 || true)
    if [[ -n "$DEFAULT_ARCHIVE" && -f "$DEFAULT_ARCHIVE" ]]; then
        ARCHIVE_PATH="$DEFAULT_ARCHIVE"
        echo -e "${BLUE}Found archive:${NC} $ARCHIVE_PATH"
    fi
fi

if [[ -z "$ARCHIVE_PATH" || ! -f "$ARCHIVE_PATH" ]]; then
    echo -e "${RED}Error: No Antigravity IDE archive (.tar.gz) found.${NC}"
    echo -e "Usage: $0 [path/to/Antigravity IDE.tar.gz]"
    echo -e "Or place the downloaded archive into ~/Downloads"
    exit 1
fi

echo -e "${GREEN}Using package archive:${NC} $ARCHIVE_PATH"

# 2. Extract Archive to Temporary Staging Directory
TEMP_STAGING=$(mktemp -d /tmp/antigravity_staging_XXXXXX)
cleanup() {
    rm -rf "$TEMP_STAGING"
}
trap cleanup EXIT

echo -e "\n${BLUE}[1/6] Extracting archive...${NC}"
tar -xzf "$ARCHIVE_PATH" -C "$TEMP_STAGING"

# Determine extracted folder name
EXTRACTED_DIR=""
if [[ -d "$TEMP_STAGING/Antigravity IDE" ]]; then
    EXTRACTED_DIR="$TEMP_STAGING/Antigravity IDE"
elif [[ -d "$TEMP_STAGING/antigravity" ]]; then
    EXTRACTED_DIR="$TEMP_STAGING/antigravity"
else
    EXTRACTED_DIR=$(find "$TEMP_STAGING" -mindepth 1 -maxdepth 1 -type d | head -n 1)
fi

if [[ -z "$EXTRACTED_DIR" || ! -f "$EXTRACTED_DIR/antigravity-ide" ]]; then
    echo -e "${RED}Error: Invalid archive structure. Could not find 'antigravity-ide' binary in archive.${NC}"
    exit 1
fi

# 3. Prepare Target Directory / Backup Current Installation
if [[ -d "$INSTALL_DIR" ]]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="$HOME/.antigravity_backup_$TIMESTAMP"
    echo -e "\n${BLUE}[2/6] Backing up existing installation to:${NC} $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    cp -a "$INSTALL_DIR/." "$BACKUP_DIR/"
else
    echo -e "\n${BLUE}[2/6] First-time install: Preparing target directory $INSTALL_DIR (requires sudo)...${NC}"
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown -R "$USER:$USER" "$INSTALL_DIR"
fi

# 4. Sync Files into /opt/antigravity
echo -e "\n${BLUE}[3/6] Installing files into $INSTALL_DIR...${NC}"
rsync -a --delete "$EXTRACTED_DIR/" "$INSTALL_DIR/"

# 5. Fix Chromium SUID Sandbox Permissions
echo -e "\n${BLUE}[4/6] Configuring chrome-sandbox SUID permissions (requires sudo)...${NC}"
if [[ -f "$INSTALL_DIR/chrome-sandbox" ]]; then
    sudo chown root:root "$INSTALL_DIR/chrome-sandbox"
    sudo chmod 4755 "$INSTALL_DIR/chrome-sandbox"
    echo -e "${GREEN}✓ Configured /opt/antigravity/chrome-sandbox (owner root:root, mode 4755)${NC}"
else
    echo -e "${YELLOW}! chrome-sandbox binary not found in $INSTALL_DIR, skipping SUID configuration.${NC}"
fi

# 6. Configure CLI Terminal Command (/usr/local/bin)
echo -e "\n${BLUE}[5/6] Setting up CLI commands in /usr/local/bin...${NC}"
if [[ -f "$INSTALL_DIR/bin/antigravity-ide" ]]; then
    sudo ln -sf "$INSTALL_DIR/bin/antigravity-ide" /usr/local/bin/antigravity-ide
    sudo ln -sf "$INSTALL_DIR/bin/antigravity-ide" /usr/local/bin/antigravity
    echo -e "${GREEN}✓ Created CLI commands: 'antigravity' and 'antigravity-ide' in /usr/local/bin${NC}"
fi

# 7. Setup Desktop Launcher & MIME Handlers
echo -e "\n${BLUE}[6/6] Configuring desktop launcher and application menu...${NC}"
mkdir -p "$DESKTOP_ENTRY_DIR"

cat << 'DESKTOP_EOF' > "$DESKTOP_ENTRY_FILE"
[Desktop Entry]
Name=Antigravity IDE
Comment=Antigravity Agentic IDE
Exec=/opt/antigravity/antigravity-ide %U
Terminal=false
Type=Application
Icon=/opt/antigravity/resources/app/resources/linux/code.png
Categories=Development;IDE;
StartupNotify=true
StartupWMClass=Antigravity
MimeType=x-scheme-handler/antigravity;
DESKTOP_EOF

chmod +x "$DESKTOP_ENTRY_FILE"
update-desktop-database "$DESKTOP_ENTRY_DIR" 2>/dev/null || true
echo -e "${GREEN}✓ Desktop launcher installed at $DESKTOP_ENTRY_FILE${NC}"

# Summary Output
echo -e "\n${GREEN}${BOLD}=== ${ACTION_TYPE} Completed Successfully! ===${NC}"
if [[ -f "$INSTALL_DIR/resources/app/product.json" ]]; then
    python3 -c "import json; p = json.load(open('$INSTALL_DIR/resources/app/product.json')); print('Installed Version:', p.get('version', 'N/A'), '| Commit:', p.get('commit', 'N/A'), '| Date:', p.get('date', 'N/A'))" 2>/dev/null || true
fi

echo -e "\nYou can launch Antigravity IDE via:"
echo -e "  - Application Menu (Search for '${BOLD}Antigravity IDE${NC}')"
echo -e "  - Terminal: ${BOLD}antigravity .${NC} (or ${BOLD}antigravity-ide .${NC})\n"
