# Antigravity IDE - Linux (Ubuntu/Debian) Installation & Update Guide

This repository provides scripts, documentation, and reference configurations to perform both **first-time installation** and **routine upgrades** of Google Antigravity IDE on Linux (Ubuntu / Debian).

---

## Table of Contents

- [First-Time Installation](#first-time-installation)
- [Updating an Existing Installation](#updating-an-existing-installation)
- [Step-by-Step Manual Installation & Upgrade](#step-by-step-manual-installation--upgrade)
- [Crucial Fix: Chromium SUID Sandbox Permissions](#crucial-fix-chromium-suid-sandbox-permissions)
- [Command Line CLI Integration](#command-line-cli-integration)
- [Desktop Launcher & Protocol Handler](#desktop-launcher--protocol-handler)
- [Rollback / Restoring from Backup](#rollback--restoring-from-backup)
- [Directory Layout](#directory-layout)

---

## First-Time Installation

### 1. Download Antigravity IDE
Download the Linux tarball archive (`Antigravity IDE.tar.gz`) into your `~/Downloads` folder.

### 2. Clone and Run Installer
```bash
git clone https://github.com/Seburan/antigravity-ide-linux-update.git
cd antigravity-ide-linux-update
chmod +x install.sh
./install.sh
```

**What the installer does automatically:**
1. Creates `/opt/antigravity` target directory with proper user ownership.
2. Extracts and installs the IDE files.
3. Fixes Chromium sandbox helper permissions (`chrome-sandbox` owned by `root:root` with mode `4755`).
4. Creates CLI symlinks `/usr/local/bin/antigravity` and `/usr/local/bin/antigravity-ide` so you can launch it directly from any terminal.
5. Installs the desktop application launcher and registers URL schemes (`antigravity://`).

---

## Updating an Existing Installation

When a new version is released:

1. Download the new `Antigravity IDE.tar.gz` to `~/Downloads`.
2. Run the update script:
   ```bash
   cd antigravity-ide-linux-update
   ./update.sh
   ```

The script will automatically create a timestamped backup in `~/.antigravity_backup_<timestamp>`, sync the updated files, re-apply sandbox permissions, and verify the installed build version.

---

## Step-by-Step Manual Installation & Upgrade

To perform the installation or upgrade manually without using the script:

### 1. Extract the tarball
```bash
mkdir -p /tmp/antigravity_staging
tar -xzf "$HOME/Downloads/Antigravity IDE.tar.gz" -C /tmp/antigravity_staging
```

### 2. Backup existing installation (if updating)
```bash
if [ -d "/opt/antigravity" ]; then
    mkdir -p "$HOME/.antigravity_backup_$(date +%Y%m%d_%H%M%S)"
    cp -a /opt/antigravity/. "$HOME/.antigravity_backup_$(date +%Y%m%d_%H%M%S)/"
fi
```

### 3. Install/Update files to `/opt/antigravity`
```bash
sudo mkdir -p /opt/antigravity
sudo chown -R $USER:$USER /opt/antigravity
rsync -a --delete "/tmp/antigravity_staging/Antigravity IDE/" /opt/antigravity/
rm -rf /tmp/antigravity_staging
```

### 4. Configure `chrome-sandbox` permissions
> [!IMPORTANT]
> **This step is mandatory.** Without this, Chromium's sandbox aborts startup with a fatal SUID error.
```bash
sudo chown root:root /opt/antigravity/chrome-sandbox
sudo chmod 4755 /opt/antigravity/chrome-sandbox
```

### 5. Create CLI symlinks
```bash
sudo ln -sf /opt/antigravity/bin/antigravity-ide /usr/local/bin/antigravity
sudo ln -sf /opt/antigravity/bin/antigravity-ide /usr/local/bin/antigravity-ide
```

### 6. Install Desktop Launcher
```bash
mkdir -p ~/.local/share/applications
cp antigravity-ide.desktop ~/.local/share/applications/
chmod +x ~/.local/share/applications/antigravity-ide.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null || true
```

---

## Crucial Fix: Chromium SUID Sandbox Permissions

### The Error
When launching Antigravity IDE after unpacking an update without root permissions, you may encounter:

```text
[182198:0902/231221.244564:FATAL:sandbox/linux/suid/client/setuid_sandbox_host.cc:166] The SUID sandbox helper binary was found, but is not configured correctly. Rather than run without sandboxing I'm aborting now. You need to make sure that /opt/antigravity/chrome-sandbox is owned by root and has mode 4755.
Trace/breakpoint trap (core dumped) ./antigravity-ide
```

### Cause
Chromium/Electron requires a setuid sandbox binary (`chrome-sandbox`) on Linux to spawn sandboxed renderer and worker processes. When extracting `.tar.gz` archives as a standard user, file ownership defaults to the current user and the SUID bit (`4000`) is omitted.

### Solution
```bash
sudo chown root:root /opt/antigravity/chrome-sandbox
sudo chmod 4755 /opt/antigravity/chrome-sandbox
```

Verify permissions:
```bash
ls -la /opt/antigravity/chrome-sandbox
# Output: -rwsr-xr-x 1 root root ... /opt/antigravity/chrome-sandbox
```

---

## Command Line CLI Integration

Once installed, you can launch the IDE directly from any terminal:

- Open current folder:
  ```bash
  antigravity .
  ```
- Open specific file or project:
  ```bash
  antigravity path/to/project
  ```

---

## Desktop Launcher & Protocol Handler

The provided [`antigravity-ide.desktop`](./antigravity-ide.desktop) file registers:
- Application launcher in GNOME / Ubuntu Dash.
- MIME type handler for `antigravity://` deep links.

---

## Rollback / Restoring from Backup

If an update needs to be reverted, restore from the automatic backup:

```bash
# List available backups
ls -d ~/.antigravity_backup_*

# Restore backup
rsync -a --delete ~/.antigravity_backup_YYYYMMDD_HHMMSS/ /opt/antigravity/
sudo chown root:root /opt/antigravity/chrome-sandbox
sudo chmod 4755 /opt/antigravity/chrome-sandbox
```

---

## Directory Layout

| Path | Purpose |
| :--- | :--- |
| `/opt/antigravity` | Installed Antigravity IDE application binary & runtime |
| `/opt/antigravity/chrome-sandbox` | Chromium SUID sandbox binary (requires `4755` `root:root`) |
| `/usr/local/bin/antigravity` | Command line CLI launcher symlink |
| `~/.local/share/applications/antigravity-ide.desktop` | Desktop launcher & URL scheme handler |
| `~/.config/Antigravity IDE` | User configuration and settings |
| `~/.antigravity-ide/extensions` | Installed extensions |
| `~/.gemini/antigravity-ide` | Antigravity AI agent state and workspace data |
