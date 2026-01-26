# 🔄 Idempotency Guide - Running the Script Multiple Times

## What is Idempotency?

**Idempotency** means you can run the script multiple times and get the same result without negative side effects. The script intelligently detects what's already installed and skips it, while still updating what needs updating.

## ✅ Safe to Run Multiple Times

This script is **fully idempotent**. You can:
- Run it on a fresh system
- Run it again after partial completion (if interrupted)
- Run it months later to check/update your setup
- Run it by accident without breaking anything

## 🔍 How Each Component Handles Multiple Runs

### 1. System Updates (`update_system`)
**Behavior:** Always runs but harmless
- `apt-get update` - Always safe, just refreshes package lists
- `apt-get upgrade` - Only upgrades if updates available
- `apt-get autoremove` - Only removes if there's something to remove

**Result:** System stays up-to-date

---

### 2. Zsh Installation (`install_zsh`)
**First Run:**
```
[INFO] Installing zsh...
[SUCCESS] zsh installed
```

**Subsequent Runs:**
```
[INFO] Installing zsh...
[WARNING] zsh already installed: zsh 5.8
[INFO] zsh version: zsh 5.8
```

**What's checked:**
- `command -v zsh` - Checks if zsh binary exists
- If found, skips installation
- Still verifies and displays version

---

### 3. Oh My Zsh (`install_oh_my_zsh`)
**First Run:**
```
[INFO] Installing Oh My Zsh...
[WARNING] Backing up existing .zshrc to .zshrc.backup.20260126_153045
[SUCCESS] Oh My Zsh installed
```

**Subsequent Runs:**
```
[INFO] Installing Oh My Zsh...
[WARNING] Oh My Zsh already installed, skipping...
```

**What's checked:**
- `[ -d "$HOME/.oh-my-zsh" ]` - Checks if directory exists
- Backs up `.zshrc` with **timestamp** (no overwrite risk)
- Skips installation if already present

---

### 4. Themes and Plugins (`install_zsh_themes_and_plugins`)
**First Run:**
```
[INFO] Installing Powerlevel10k theme...
[SUCCESS] Powerlevel10k installed
[INFO] Installing zsh-autosuggestions...
[SUCCESS] zsh-autosuggestions installed
...
```

**Subsequent Runs:**
```
[WARNING] Powerlevel10k already installed, skipping...
[WARNING] zsh-autosuggestions already installed, skipping...
[WARNING] zsh-syntax-highlighting already installed, skipping...
[WARNING] zsh-completions already installed, skipping...
[SUCCESS] All themes and plugins checked
```

**What's checked:**
- Each plugin directory is checked individually
- Git clone only happens if directory doesn't exist
- Safe to run even if some plugins exist

---

### 5. Zshrc Configuration (`configure_zshrc`)
**First Run:**
```
[INFO] Configuring .zshrc...
[SUCCESS] Theme updated to Powerlevel10k
[SUCCESS] Plugins updated
[SUCCESS] Completion path added
[SUCCESS] .zshrc configuration complete
```

**Subsequent Runs:**
```
[INFO] Configuring .zshrc...
[WARNING] Powerlevel10k theme already configured
[WARNING] Plugins already configured
[WARNING] Completion path already configured
[SUCCESS] .zshrc configuration complete
```

**What's checked:**
- `grep -q` checks for existing configuration
- Creates backup with `.bak` extension before modifications
- Only modifies if configuration not already present
- No duplicate entries added

---

### 6. Default Shell (`change_default_shell`)
**First Run:**
```
[INFO] Changing default shell to zsh...
[SUCCESS] Default shell changed to zsh (will take effect on next login)
```

**Subsequent Runs:**
```
[INFO] Changing default shell to zsh...
[WARNING] Default shell is already zsh
```

**What's checked:**
- `[ "$SHELL" != "$(which zsh)" ]` - Compares current shell
- Only runs `chsh` if needed

---

### 7. Java Installation (`install_java`)
**First Run:**
```
[INFO] Checking Java installation...
[INFO] Installing Java...
[SUCCESS] Java installed
[INFO] Java version: openjdk version "17.0.6"
```

**Subsequent Runs:**
```
[INFO] Checking Java installation...
[WARNING] Java already installed: openjdk version "17.0.6"
```

**What's checked:**
- `command -v java` - Checks if java binary exists
- Returns early if already installed
- Skips entire installation process

---

### 8. Java Environment Configuration (`configure_java_environment`)
**First Run:**
```
[INFO] Adding JAVA_HOME to .zshrc...
[SUCCESS] JAVA_HOME added to .zshrc
[INFO] Adding JAVA_HOME to /etc/environment...
[SUCCESS] JAVA_HOME added to /etc/environment
```

**Subsequent Runs:**
```
[WARNING] JAVA_HOME already exists in .zshrc
[WARNING] JAVA_HOME already exists in /etc/environment
[INFO] Creating /etc/profile.d/java.sh...
[SUCCESS] Java environment configured system-wide
```

**What's checked:**
- `grep -q "JAVA_HOME"` in each configuration file
- Only adds if not already present
- `/etc/profile.d/java.sh` is overwritten (safe, identical content)

---

### 9. Docker Installation (`install_docker`)
**First Run:**
```
[INFO] Checking Docker installation...
[INFO] Installing Docker...
[SUCCESS] Docker installed
[INFO] Adding current user to docker group...
[SUCCESS] User added to docker group
```

**Subsequent Runs:**
```
[INFO] Checking Docker installation...
[WARNING] Docker already installed: Docker version 24.0.7
[WARNING] User already in docker group
```

**What's checked:**
- `command -v docker` - Checks if docker binary exists
- `groups "$USER" | grep docker` - Checks group membership
- Ensures service is enabled even if already installed
- Returns early if Docker already present

---

### 10. Docker Compose (`install_docker_compose`)
**First Run:**
```
[INFO] Checking Docker Compose installation...
[INFO] Installing Docker Compose v2.24.6...
[SUCCESS] Docker Compose installed
```

**Subsequent Runs:**
```
[INFO] Checking Docker Compose installation...
[WARNING] Docker Compose plugin already available: v2.24.6
[WARNING] Docker Compose standalone already installed: v2.24.6
```

**What's checked:**
- `docker compose version` - Plugin availability
- `[ -f /usr/local/bin/docker-compose ]` - Standalone binary
- Returns early if both are present

---

### 11. Portainer (`install_portainer`)
**First Run:**
```
[INFO] Checking Portainer installation...
[INFO] Installing Portainer...
[SUCCESS] Portainer installed and started
```

**Subsequent Runs - Container Running:**
```
[INFO] Checking Portainer installation...
[WARNING] Portainer container already running
[INFO] Portainer is accessible at:
  • HTTP:  http://192.168.1.100:9000
  • HTTPS: https://192.168.1.100:9443
```

**Subsequent Runs - Container Stopped:**
```
[INFO] Checking Portainer installation...
[WARNING] Portainer container exists but is stopped. Starting it...
[SUCCESS] Portainer started
```

**What's checked:**
- `docker ps --format '{{.Names}}' | grep portainer` - Running check
- `docker ps -a --format '{{.Names}}' | grep portainer` - Exists check
- Starts if stopped, skips if running
- Creates docker-compose.yml if doesn't exist (safe, can be overwritten)

---

## 📊 Visual Summary

```
Run 1 (Fresh System):
├─ System: Update ✓
├─ zsh: Install ✓
├─ Oh My Zsh: Install ✓
├─ Themes: Clone ✓
├─ Java: Install ✓
├─ Docker: Install ✓
├─ Portainer: Deploy ✓
└─ Result: Full Setup Complete ✓

Run 2 (Already Configured):
├─ System: Update ✓
├─ zsh: Skip (exists) ⊘
├─ Oh My Zsh: Skip (exists) ⊘
├─ Themes: Skip (exists) ⊘
├─ Java: Skip (exists) ⊘
├─ Docker: Skip (exists) ⊘
├─ Portainer: Skip (running) ⊘
└─ Result: All Checks Pass ✓

Run 3 (Interrupted Previously):
├─ System: Update ✓
├─ zsh: Skip (exists) ⊘
├─ Oh My Zsh: Install ✓ (was missing)
├─ Themes: Partial ✓ (installs missing ones)
├─ Java: Skip (exists) ⊘
├─ Docker: Install ✓ (was interrupted)
├─ Portainer: Deploy ✓ (was missing)
└─ Result: Completes Missing Parts ✓
```

## 🛡️ Safety Features

### 1. Backup Strategy
- **Timestamped backups**: `.zshrc.backup.20260126_153045`
- **Never overwrites**: Each run creates a new backup
- **Easy recovery**: Sorted by timestamp

### 2. Detection Methods
- **Command existence**: `command -v <cmd>`
- **Directory existence**: `[ -d "$path" ]`
- **File content**: `grep -q "pattern" file`
- **Process status**: `docker ps | grep name`
- **Group membership**: `groups | grep docker`

### 3. Error Handling
- **set -euo pipefail**: Stops on errors
- **Return early**: Skip unnecessary operations
- **Clear logging**: Know exactly what's happening
- **Safe defaults**: Non-destructive operations

### 4. Configuration Protection
- **grep before add**: Prevents duplicates
- **sed with backup**: Creates .bak files
- **Overwrites are safe**: Only for generated config files

## 💡 Common Scenarios

### Scenario 1: Network Interruption
**Situation:** Script stops halfway through Docker installation

**What happens on rerun:**
- ✅ Skips zsh (already installed)
- ✅ Skips Java (already installed)
- ✅ Continues Docker installation
- ✅ Installs remaining components

**Result:** Script picks up where it left off

---

### Scenario 2: Manual Modifications
**Situation:** You manually installed vim after running the script

**What happens on rerun:**
- ✅ apt-get install vim - Safe, just confirms it's installed
- ✅ No conflicts or errors
- ✅ Other packages installed normally

**Result:** Works fine, no issues

---

### Scenario 3: Updates Available
**Situation:** New versions of Docker Compose released

**What happens on rerun:**
- ✅ System update runs (gets latest packages)
- ✅ Docker Compose check passes (already installed)
- ⚠️ Doesn't auto-update Docker Compose binary

**To update Docker Compose:**
```bash
# Remove old version first
sudo rm /usr/local/bin/docker-compose
# Then rerun script
./initial-setup.sh
```

---

### Scenario 4: Portainer Stopped
**Situation:** Portainer container was stopped manually

**What happens on rerun:**
```
[WARNING] Portainer container exists but is stopped. Starting it...
[SUCCESS] Portainer started
```

**Result:** Container is automatically restarted

---

## 🎯 Best Practices

### When to Rerun the Script

✅ **Good reasons to rerun:**
- Installation was interrupted
- Want to ensure everything is up-to-date
- Made manual changes and want to verify
- After system update/upgrade
- To install missing optional components

❌ **Don't rerun expecting:**
- To update already-installed binaries to newer versions
- To reset configurations (use manual methods)
- To fix user-created misconfigurations
- To remove packages

### Safe Testing
You can safely test the script by:
```bash
# Run on a VM first
# Run on a fresh SD card
# Run multiple times on test system
# Check the output messages
```

## 📝 Technical Details

### Idempotency Mechanisms Used

1. **Command Checks**
   ```bash
   if command -v docker &> /dev/null; then
       # Already installed, skip
   fi
   ```

2. **Directory Checks**
   ```bash
   if [ ! -d "$HOME/.oh-my-zsh" ]; then
       # Install only if doesn't exist
   fi
   ```

3. **File Content Checks**
   ```bash
   if ! grep -q "JAVA_HOME" "$HOME/.zshrc"; then
       # Add only if not present
   fi
   ```

4. **Container Checks**
   ```bash
   if docker ps --format '{{.Names}}' | grep -q '^portainer$'; then
       # Already running, skip
   fi
   ```

5. **Group Membership Checks**
   ```bash
   if groups "$USER" | grep -q '\bdocker\b'; then
       # Already in group, skip
   fi
   ```

## 🎉 Summary

The script is **production-ready** for multiple runs:
- ✅ No destructive operations
- ✅ Clear feedback on what's skipped
- ✅ Intelligent detection of existing installations
- ✅ Safe backup strategies
- ✅ Proper error handling
- ✅ Tested idempotency patterns

**Run it as many times as you want - it's safe!** 🚀
