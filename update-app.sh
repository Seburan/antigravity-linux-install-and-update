#!/usr/bin/env bash
# ==============================================================================
# Antigravity App - Linux Install & Update Script (Ubuntu / Debian)
# Repository: https://github.com/Seburan/antigravity-linux-install-and-update
# ==============================================================================

set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

INSTALL_DIR="/opt/antigravity-app"
DESKTOP_ENTRY_DIR="$HOME/.local/share/applications"
DESKTOP_ENTRY_FILE="$DESKTOP_ENTRY_DIR/antigravity-app.desktop"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPT_NAME=$(basename "$0")
if [[ "$SCRIPT_NAME" == "install-app.sh" ]] || [[ ! -d "$INSTALL_DIR" ]]; then
    ACTION_TYPE="Install"
else
    ACTION_TYPE="Update"
fi

echo -e "${BLUE}${BOLD}=== Antigravity App Linux ${ACTION_TYPE}r ===${NC}\n"

# 1. Locate Archive
ARCHIVE_PATH="${1:-}"

if [[ -z "$ARCHIVE_PATH" ]]; then
    # Look for matching archive in ~/Downloads (excluding IDE archives)
    DEFAULT_ARCHIVE=$(ls -t "$HOME"/Downloads/Antigravity*.tar.gz "$HOME"/Downloads/antigravity*.tar.gz 2>/dev/null | grep -i -v "ide" | head -n 1 || true)
    if [[ -n "$DEFAULT_ARCHIVE" && -f "$DEFAULT_ARCHIVE" ]]; then
        ARCHIVE_PATH="$DEFAULT_ARCHIVE"
        echo -e "${BLUE}Found archive:${NC} $ARCHIVE_PATH"
    fi
fi

if [[ -z "$ARCHIVE_PATH" || ! -f "$ARCHIVE_PATH" ]]; then
    echo -e "${RED}Error: No Antigravity App archive (.tar.gz) found.${NC}"
    echo -e "Usage: $0 [path/to/Antigravity.tar.gz]"
    echo -e "Or place the downloaded archive into ~/Downloads"
    exit 1
fi

echo -e "${GREEN}Using package archive:${NC} $ARCHIVE_PATH"

# 2. Extract Archive to Temporary Staging Directory
TEMP_STAGING=$(mktemp -d /tmp/antigravity_app_staging_XXXXXX)
cleanup() {
    rm -rf "$TEMP_STAGING"
}
trap cleanup EXIT

echo -e "\n${BLUE}[1/6] Extracting archive...${NC}"
tar -xzf "$ARCHIVE_PATH" -C "$TEMP_STAGING"

# Determine extracted folder name
EXTRACTED_DIR=""
if [[ -d "$TEMP_STAGING/Antigravity-x64" ]]; then
    EXTRACTED_DIR="$TEMP_STAGING/Antigravity-x64"
elif [[ -d "$TEMP_STAGING/Antigravity" ]]; then
    EXTRACTED_DIR="$TEMP_STAGING/Antigravity"
elif [[ -d "$TEMP_STAGING/antigravity" ]]; then
    EXTRACTED_DIR="$TEMP_STAGING/antigravity"
else
    EXTRACTED_DIR=$(find "$TEMP_STAGING" -mindepth 1 -maxdepth 1 -type d | head -n 1)
fi

if [[ -z "$EXTRACTED_DIR" || ! -f "$EXTRACTED_DIR/antigravity" ]]; then
    echo -e "${RED}Error: Invalid archive structure. Could not find 'antigravity' binary in archive.${NC}"
    exit 1
fi

# Detect Version Information
TARGET_VERSION=$(python3 -c "
import struct, json
try:
    with open('$EXTRACTED_DIR/resources/app.asar', 'rb') as f:
        magic = f.read(16)
        u1, u2, u3, header_len = struct.unpack('<IIII', magic)
        header = json.loads(f.read(header_len).decode('utf-8'))
        base_offset = (16 + header_len + 3) & ~3
        pkg_info = header['files']['package.json']
        f.seek(base_offset + int(pkg_info['offset']))
        pkg = json.loads(f.read(pkg_info['size']).decode('utf-8'))
        print(pkg.get('version', ''))
except Exception:
    pass
" 2>/dev/null || true)

ELECTRON_VERSION=$(cat "$EXTRACTED_DIR/version" 2>/dev/null || true)
if [[ -n "$TARGET_VERSION" ]]; then
    VERSION_INFO="v${TARGET_VERSION}"
    if [[ -n "$ELECTRON_VERSION" ]]; then
        VERSION_INFO="${VERSION_INFO} (Electron v${ELECTRON_VERSION})"
    fi
    echo -e "${GREEN}Detected package version:${NC} ${BOLD}${VERSION_INFO}${NC}"
fi

# 3. Prepare Target Directory / Backup Current Installation
if [[ -d "$INSTALL_DIR" ]]; then
    CURRENT_VERSION=$(python3 -c "
import struct, json
try:
    with open('$INSTALL_DIR/resources/app.asar', 'rb') as f:
        magic = f.read(16)
        u1, u2, u3, header_len = struct.unpack('<IIII', magic)
        header = json.loads(f.read(header_len).decode('utf-8'))
        base_offset = (16 + header_len + 3) & ~3
        pkg_info = header['files']['package.json']
        f.seek(base_offset + int(pkg_info['offset']))
        pkg = json.loads(f.read(pkg_info['size']).decode('utf-8'))
        print(pkg.get('version', ''))
except Exception:
    pass
" 2>/dev/null || true)
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="$HOME/.antigravity_app_backup_$TIMESTAMP"
    if [[ -n "$CURRENT_VERSION" ]]; then
        echo -e "\n${BLUE}[2/6] Backing up existing installation (v${CURRENT_VERSION}) to:${NC} $BACKUP_DIR"
    else
        echo -e "\n${BLUE}[2/6] Backing up existing installation to:${NC} $BACKUP_DIR"
    fi
    mkdir -p "$BACKUP_DIR"
    cp -a "$INSTALL_DIR/." "$BACKUP_DIR/"
else
    echo -e "\n${BLUE}[2/6] First-time install: Preparing target directory $INSTALL_DIR (requires sudo)...${NC}"
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown -R "$USER:$USER" "$INSTALL_DIR"
fi

# Ensure target directory is owned by the current user
if [[ ! -w "$INSTALL_DIR" ]]; then
    echo -e "\n${BLUE}Adjusting ownership of $INSTALL_DIR (requires sudo)...${NC}"
    sudo chown -R "$USER:$USER" "$INSTALL_DIR"
fi

# Remove existing chrome-sandbox before syncing because it is setuid root (mode 4755)
# from the previous install, which prevents rsync as a standard user from updating its metadata.
if [[ -f "$INSTALL_DIR/chrome-sandbox" ]]; then
    rm -f "$INSTALL_DIR/chrome-sandbox" 2>/dev/null || sudo rm -f "$INSTALL_DIR/chrome-sandbox"
fi

# 4. Sync Files into /opt/antigravity-app
echo -e "\n${BLUE}[3/6] Installing files into $INSTALL_DIR...${NC}"
rsync -a --delete --no-owner --no-group "$EXTRACTED_DIR/" "$INSTALL_DIR/"

# Extract or copy application icon
if [[ -f "$SCRIPT_DIR/antigravity-app.png" ]]; then
    cp "$SCRIPT_DIR/antigravity-app.png" "$INSTALL_DIR/icon.png"
else
    python3 -c "
import struct, json
try:
    with open('$INSTALL_DIR/resources/app.asar', 'rb') as f:
        magic = f.read(16)
        u1, u2, u3, header_len = struct.unpack('<IIII', magic)
        header = json.loads(f.read(header_len).decode('utf-8'))
        base_offset = (16 + header_len + 3) & ~3
        icon_info = header['files']['icon.png']
        f.seek(base_offset + int(icon_info['offset']))
        data = f.read(icon_info['size'])
        with open('$INSTALL_DIR/icon.png', 'wb') as out:
            out.write(data)
except Exception:
    pass
" 2>/dev/null || true
fi

# 5. Fix Chromium SUID Sandbox Permissions
echo -e "\n${BLUE}[4/6] Configuring chrome-sandbox SUID permissions (requires sudo)...${NC}"
if [[ -f "$INSTALL_DIR/chrome-sandbox" ]]; then
    sudo chown root:root "$INSTALL_DIR/chrome-sandbox"
    sudo chmod 4755 "$INSTALL_DIR/chrome-sandbox"
    echo -e "${GREEN}✓ Configured $INSTALL_DIR/chrome-sandbox (owner root:root, mode 4755)${NC}"
else
    echo -e "${YELLOW}! chrome-sandbox binary not found in $INSTALL_DIR, skipping SUID configuration.${NC}"
fi

# 6. Configure CLI Terminal Command (/usr/local/bin)
echo -e "\n${BLUE}[5/6] Setting up CLI command in /usr/local/bin...${NC}"
if [[ -f "$INSTALL_DIR/antigravity" ]]; then
    sudo ln -sf "$INSTALL_DIR/antigravity" /usr/local/bin/antigravity-app
    echo -e "${GREEN}✓ Created CLI command: 'antigravity-app' in /usr/local/bin${NC}"
fi

# 7. Setup Desktop Launcher, Icons & MIME Handlers
echo -e "\n${BLUE}[6/6] Configuring desktop launcher and application menu...${NC}"
mkdir -p "$DESKTOP_ENTRY_DIR"
mkdir -p "$HOME/.local/share/icons/hicolor/512x512/apps"

if [[ -f "$INSTALL_DIR/icon.png" ]]; then
    cp "$INSTALL_DIR/icon.png" "$HOME/.local/share/icons/hicolor/512x512/apps/antigravity.png"
    cp "$INSTALL_DIR/icon.png" "$HOME/.local/share/icons/hicolor/512x512/apps/antigravity-app.png"
    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi

if [[ -f "$SCRIPT_DIR/antigravity-app.desktop" ]]; then
    cp "$SCRIPT_DIR/antigravity-app.desktop" "$DESKTOP_ENTRY_FILE"
else
    cat << 'DESKTOP_EOF' > "$DESKTOP_ENTRY_FILE"
[Desktop Entry]
Name=Antigravity
Comment=Antigravity Agentic Desktop Application
Exec=/opt/antigravity-app/antigravity %U
Terminal=false
Type=Application
Icon=/opt/antigravity-app/icon.png
Categories=Development;
StartupNotify=true
StartupWMClass=antigravity
MimeType=x-scheme-handler/antigravity;
DESKTOP_EOF
fi

chmod +x "$DESKTOP_ENTRY_FILE"
ln -sf "$DESKTOP_ENTRY_FILE" "$DESKTOP_ENTRY_DIR/antigravity.desktop"
update-desktop-database "$DESKTOP_ENTRY_DIR" 2>/dev/null || true
echo -e "${GREEN}✓ Desktop launcher installed at $DESKTOP_ENTRY_FILE${NC}"

# Summary Output
echo -e "\n${GREEN}${BOLD}=== ${ACTION_TYPE} Completed Successfully! ===${NC}"
if [[ -n "$TARGET_VERSION" ]]; then
    echo -e "Installed Version: ${BOLD}v${TARGET_VERSION}${NC} (Electron: ${ELECTRON_VERSION:-N/A})"
fi

echo -e "\nYou can launch Antigravity App via:"
echo -e "  - Application Menu (Search for '${BOLD}Antigravity${NC}')"
echo -e "  - Terminal: ${BOLD}antigravity-app${NC}\n"
