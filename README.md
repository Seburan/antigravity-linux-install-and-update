# Antigravity IDE & App - Linux (Ubuntu/Debian) Installation & Update Guide

This repository provides scripts, documentation, and desktop configurations to perform both **first-time installation** and **routine upgrades** of Google Antigravity on Linux (Ubuntu / Debian).

It supports both applications:
- **Antigravity IDE** — The agentic code editor and IDE environment (packaged as `Antigravity IDE.tar.gz`).
- **Antigravity App** — The agentic desktop application / hub (packaged as `Antigravity.tar.gz`).

---

## Table of Contents

- [Overview & Quick Reference](#overview--quick-reference)
- [Antigravity IDE](#antigravity-ide)
  - [Automated Install & Update](#automated-install--update-ide)
  - [Manual Step-by-Step Installation](#manual-step-by-step-installation-ide)
- [Antigravity App](#antigravity-app)
  - [Automated Install & Update](#automated-install--update-app)
  - [Manual Step-by-Step Installation](#manual-step-by-step-installation-app)
- [Crucial Fix: Chromium SUID Sandbox Permissions](#crucial-fix-chromium-suid-sandbox-permissions)
- [Command Line CLI Integration](#command-line-cli-integration)
- [Desktop Launchers & Protocol Handlers](#desktop-launchers--protocol-handlers)
- [Rollback / Restoring from Backup](#rollback--restoring-from-backup)
- [Directory Layout & Comparison](#directory-layout--comparison)

---

## Overview & Quick Reference

| Feature | Antigravity IDE | Antigravity App |
| :--- | :--- | :--- |
| **Archive File** | `Antigravity IDE.tar.gz` | `Antigravity.tar.gz` |
| **Archive Root** | `Antigravity IDE/` | `Antigravity-x64/` |
| **Install Script** | `./install-ide.sh` *(or `./install.sh`)* | `./install-app.sh` |
| **Update Script** | `./update-ide.sh` *(or `./update.sh`)* | `./update-app.sh` |
| **Target Directory** | `/opt/antigravity-ide` | `/opt/antigravity-app` |
| **Main Executable** | `/opt/antigravity-ide/antigravity-ide` | `/opt/antigravity-app/antigravity` |
| **SUID Sandbox** | `/opt/antigravity-ide/chrome-sandbox` (`4755 root:root`) | `/opt/antigravity-app/chrome-sandbox` (`4755 root:root`) |
| **CLI Commands** | `antigravity-ide` *(and `antigravity`)* | `antigravity-app` |
| **Desktop Entry** | `~/.local/share/applications/antigravity-ide.desktop` | `~/.local/share/applications/antigravity-app.desktop` |
| **Application Icon** | `/opt/antigravity-ide/resources/app/resources/linux/code.png` | `/opt/antigravity-app/icon.png` *(512×512)* |
| **Backup Path** | `~/.antigravity_ide_backup_<timestamp>` | `~/.antigravity_app_backup_<timestamp>` |

---

## Antigravity IDE

### Automated Install & Update (IDE)

1. Download `Antigravity IDE.tar.gz` to your `~/Downloads` folder.
2. Clone this repository and run the installer:

```bash
git clone https://github.com/Seburan/antigravity-linux-install-and-update.git
cd antigravity-linux-install-and-update
chmod +x update-ide.sh update-app.sh
```

- **First-time Install:**
  ```bash
  ./install-ide.sh
  ```
  *(or `./install.sh` for legacy compatibility)*

- **Routine Update:**
  ```bash
  ./update-ide.sh
  ```
  *(or `./update.sh`)*

**What the IDE script does automatically:**
1. Detects `Antigravity IDE.tar.gz` in `~/Downloads` (or accepts a custom archive path via argument `$1`).
2. Extracts files into a temporary staging folder.
3. Automatically migrates legacy `/opt/antigravity` to `/opt/antigravity-ide` if present, creating a timestamped backup before updating.
4. Removes existing `chrome-sandbox` before rsyncing to avoid setuid permission conflicts.
5. Sets `root:root` ownership and `4755` permissions on `/opt/antigravity-ide/chrome-sandbox`.
6. Creates CLI symlinks `/usr/local/bin/antigravity-ide` and `/usr/local/bin/antigravity`.
7. Installs and registers `antigravity-ide.desktop`.
8. Verifies and displays the installed version.

---

### Manual Step-by-Step Installation (IDE)

```bash
# 1. Extract tarball
mkdir -p /tmp/antigravity_ide_staging
tar -xzf "$HOME/Downloads/Antigravity IDE.tar.gz" -C /tmp/antigravity_ide_staging

# 2. Backup existing installation (if updating)
if [ -d "/opt/antigravity-ide" ]; then
    mkdir -p "$HOME/.antigravity_ide_backup_$(date +%Y%m%d_%H%M%S)"
    cp -a /opt/antigravity-ide/. "$HOME/.antigravity_ide_backup_$(date +%Y%m%d_%H%M%S)/"
fi

# 3. Install / sync files
sudo mkdir -p /opt/antigravity-ide
sudo chown -R $USER:$USER /opt/antigravity-ide
rm -f /opt/antigravity-ide/chrome-sandbox
rsync -a --delete --no-owner --no-group "/tmp/antigravity_ide_staging/Antigravity IDE/" /opt/antigravity-ide/
rm -rf /tmp/antigravity_ide_staging

# 4. Configure Chromium SUID sandbox (MANDATORY)
sudo chown root:root /opt/antigravity-ide/chrome-sandbox
sudo chmod 4755 /opt/antigravity-ide/chrome-sandbox

# 5. Create CLI symlinks
sudo ln -sf /opt/antigravity-ide/bin/antigravity-ide /usr/local/bin/antigravity-ide
sudo ln -sf /opt/antigravity-ide/bin/antigravity-ide /usr/local/bin/antigravity

# 6. Install desktop launcher
mkdir -p ~/.local/share/applications
cp antigravity-ide.desktop ~/.local/share/applications/
chmod +x ~/.local/share/applications/antigravity-ide.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null || true
```

---

## Antigravity App

### Automated Install & Update (App)

1. Download `Antigravity.tar.gz` to your `~/Downloads` folder.
2. Run the installer or updater:

- **First-time Install:**
  ```bash
  ./install-app.sh
  ```

- **Routine Update:**
  ```bash
  ./update-app.sh
  ```

**What the App script does automatically:**
1. Detects `Antigravity.tar.gz` in `~/Downloads` without conflicting with IDE archives.
2. Extracts files into a temporary staging folder.
3. Creates a timestamped backup in `~/.antigravity_app_backup_<timestamp>` if an installation already exists.
4. Cleans up existing `chrome-sandbox` and syncs files into `/opt/antigravity-app`.
5. Extracts and installs the 512×512 application icon to `/opt/antigravity-app/icon.png`.
6. Sets `root:root` ownership and `4755` permissions on `/opt/antigravity-app/chrome-sandbox`.
7. Creates the CLI command `/usr/local/bin/antigravity-app`.
8. Installs and registers `antigravity-app.desktop`.
9. Reads and displays package version and Electron runtime version.

---

### Manual Step-by-Step Installation (App)

```bash
# 1. Extract tarball
mkdir -p /tmp/antigravity_app_staging
tar -xzf "$HOME/Downloads/Antigravity.tar.gz" -C /tmp/antigravity_app_staging

# 2. Backup existing installation (if updating)
if [ -d "/opt/antigravity-app" ]; then
    mkdir -p "$HOME/.antigravity_app_backup_$(date +%Y%m%d_%H%M%S)"
    cp -a /opt/antigravity-app/. "$HOME/.antigravity_app_backup_$(date +%Y%m%d_%H%M%S)/"
fi

# 3. Install / sync files
sudo mkdir -p /opt/antigravity-app
sudo chown -R $USER:$USER /opt/antigravity-app
rm -f /opt/antigravity-app/chrome-sandbox
rsync -a --delete --no-owner --no-group "/tmp/antigravity_app_staging/Antigravity-x64/" /opt/antigravity-app/
rm -rf /tmp/antigravity_app_staging

# 4. Copy application icon
cp antigravity-app.png /opt/antigravity-app/icon.png

# 5. Configure Chromium SUID sandbox (MANDATORY)
sudo chown root:root /opt/antigravity-app/chrome-sandbox
sudo chmod 4755 /opt/antigravity-app/chrome-sandbox

# 6. Create CLI symlink
sudo ln -sf /opt/antigravity-app/antigravity /usr/local/bin/antigravity-app

# 7. Install desktop launcher
mkdir -p ~/.local/share/applications
cp antigravity-app.desktop ~/.local/share/applications/
chmod +x ~/.local/share/applications/antigravity-app.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null || true
```

---

## Crucial Fix: Chromium SUID Sandbox Permissions

### The Error
When launching either Antigravity IDE or Antigravity App after unpacking an archive without configuring root setuid permissions, Chromium/Electron aborts with:

```text
[FATAL:sandbox/linux/suid/client/setuid_sandbox_host.cc:166] The SUID sandbox helper binary was found, but is not configured correctly. Rather than run without sandboxing I'm aborting now. You need to make sure that /opt/antigravity-.../chrome-sandbox is owned by root and has mode 4755.
Trace/breakpoint trap (core dumped)
```

### Cause
Chromium requires a setuid root binary (`chrome-sandbox`) on Linux to spawn sandboxed renderer and worker processes securely. When extracting standard `.tar.gz` archives, root ownership and the setuid bit (`4000`) are not preserved.

### Solution
For Antigravity IDE:
```bash
sudo chown root:root /opt/antigravity-ide/chrome-sandbox
sudo chmod 4755 /opt/antigravity-ide/chrome-sandbox
```

For Antigravity App:
```bash
sudo chown root:root /opt/antigravity-app/chrome-sandbox
sudo chmod 4755 /opt/antigravity-app/chrome-sandbox
```

Verify permissions (should show `-rwsr-xr-x 1 root root`):
```bash
ls -la /opt/antigravity-ide/chrome-sandbox
ls -la /opt/antigravity-app/chrome-sandbox
```

---

## Command Line CLI Integration

Once installed, you can launch both tools directly from terminal:

- **Antigravity IDE**:
  ```bash
  # Open current directory in Antigravity IDE
  antigravity-ide .
  antigravity .

  # Open a specific file or folder
  antigravity-ide /path/to/project
  ```

- **Antigravity App**:
  ```bash
  # Launch Antigravity Desktop App
  antigravity-app
  ```

---

## Desktop Launchers & Protocol Handlers

The desktop entry files register both applications with GNOME / Ubuntu Dash and support URL scheme deep links (`antigravity://`):

- **IDE:** `~/.local/share/applications/antigravity-ide.desktop`
- **App:** `~/.local/share/applications/antigravity-app.desktop`

---

## Rollback / Restoring from Backup

If an update needs to be reverted, restore from the automatic timestamped backups:

### Reverting Antigravity IDE
```bash
# List available IDE backups
ls -d ~/.antigravity_ide_backup_*

# Restore backup
rm -f /opt/antigravity-ide/chrome-sandbox
rsync -a --delete --no-owner --no-group ~/.antigravity_ide_backup_YYYYMMDD_HHMMSS/ /opt/antigravity-ide/
sudo chown root:root /opt/antigravity-ide/chrome-sandbox
sudo chmod 4755 /opt/antigravity-ide/chrome-sandbox
```

### Reverting Antigravity App
```bash
# List available App backups
ls -d ~/.antigravity_app_backup_*

# Restore backup
rm -f /opt/antigravity-app/chrome-sandbox
rsync -a --delete --no-owner --no-group ~/.antigravity_app_backup_YYYYMMDD_HHMMSS/ /opt/antigravity-app/
sudo chown root:root /opt/antigravity-app/chrome-sandbox
sudo chmod 4755 /opt/antigravity-app/chrome-sandbox
```

---

## Directory Layout & Comparison

| Path | Purpose |
| :--- | :--- |
| `/opt/antigravity-ide` | Antigravity IDE binary & runtime |
| `/opt/antigravity-ide/chrome-sandbox` | Chromium SUID sandbox binary for IDE (`4755 root:root`) |
| `/opt/antigravity-app` | Antigravity App binary & runtime |
| `/opt/antigravity-app/chrome-sandbox` | Chromium SUID sandbox binary for App (`4755 root:root`) |
| `/opt/antigravity-app/icon.png` | Antigravity App 512×512 application icon |
| `/usr/local/bin/antigravity-ide` | CLI launcher symlink for IDE |
| `/usr/local/bin/antigravity` | CLI launcher symlink (points to IDE) |
| `/usr/local/bin/antigravity-app` | CLI launcher symlink for App |
| `~/.local/share/applications/antigravity-ide.desktop` | Desktop launcher for IDE |
| `~/.local/share/applications/antigravity-app.desktop` | Desktop launcher for App |
| `~/.antigravity_ide_backup_*` | Timestamped backups for IDE |
| `~/.antigravity_app_backup_*` | Timestamped backups for App |
