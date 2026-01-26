# Raspbian Initial Setup Script

A comprehensive bash script to set up a fresh Raspbian (Raspberry Pi OS) installation with essential development tools.

**✨ Fully idempotent - run it multiple times safely with no negative effects!**

---

## 🚀 Quick Start

```bash
# Make executable
chmod +x initial-setup.sh

# Run with sudo password (REQUIRED)
./initial-setup.sh YourSudoPassword

# After completion, log out and back in
logout
```

**⚠️ Password Required:** The script requires your sudo password as an argument to avoid repeated prompts.

---

## 📦 What Gets Installed


| Component | Description |
|-----------|-------------|
| **System Updates** | Full system update and upgrade |
| **Network Config** | Ethernet priority + WiFi failover (automatic) |
| **zsh + Oh My Zsh** | Modern shell with Powerlevel10k theme |
| **zsh Plugins** | autosuggestions, syntax-highlighting, completions |
| **Java (OpenJDK)** | Latest version with JAVA_HOME configured |
| **Docker** | Latest from official installation script |
| **Docker Compose** | Both plugin and standalone versions |

**Note:** Portainer and Conduit installations are separate - run their setup scripts after initial setup.

---

## 🎯 Key Features

### Network Display
Shows all network interfaces and IP addresses at startup - know how to access your Pi!

### Password Parameter
Provide sudo password as argument to avoid repeated prompts during installation.

### Idempotent Design
Run the script **multiple times safely**:
- Already installed? Skips and shows warning
- Interrupted? Picks up where it left off
- Want to verify? Run again anytime
- Timestamped backups (never overwrites)

### What Happens on Reruns?
```
First run:  Installs everything (~10-15 min)
Second run: Skips all, verifies everything (~2-3 min)
```

---

## 📋 Usage

### Prerequisites
- Raspbian (Raspberry Pi OS) 64-bit
- Internet connection
- Non-root user with sudo privileges

### Installation

### Installation

```bash
# 1. (Optional) Configure WiFi first
nano wifi-config.txt
# Add your SSID and PASSWORD

# 2. Make executable
chmod +x initial-setup.sh

# 3. Run with sudo password (REQUIRED)
./initial-setup.sh YourSudoPassword

# 4. After completion, log out and log back in
logout

# 5. (Optional) Install Portainer for Docker management UI
chmod +x setup-portainer.sh
./setup-portainer.sh YourSudoPassword
```

**⚠️ Password Required:** You must provide your sudo password as the first argument.


### Network Configuration

The script automatically configures **dual network support** with intelligent failover:

**Priority Order:**
1. **Ethernet (eth0)** - Primary connection (metric 100)
2. **WiFi (wlan0)** - Backup/fallback (metric 200)

**How it works:**
- If Ethernet cable is connected → uses Ethernet (faster, more stable)
- If Ethernet disconnected → automatically switches to WiFi
- If Ethernet reconnected → switches back to Ethernet

**WiFi Setup:**
1. Edit `wifi-config.txt` with your WiFi credentials:
   ```
   SSID=YourNetworkName
   PASSWORD=YourPassword
   ```
2. Run the script - WiFi will be configured automatically
3. WiFi connects only when Ethernet is unavailable

**Skip WiFi:** If you don't need WiFi, just run the script without editing `wifi-config.txt`

### Post-Installation

1. **Log out and back in** (for shell and Docker group changes)
2. **Configure Powerlevel10k** (optional):
   ```bash
   p10k configure
   ```
3. **(Optional) Install Portainer**: Run `./setup-portainer.sh YourSudoPassword`

---

## 🐳 Portainer Setup (Optional)

Portainer is a web-based Docker management UI that makes container management easy.

### Install Portainer

```bash
# Run the Portainer setup script
./setup-portainer.sh YourSudoPassword
```

### What It Does

1. **Checks existing installation** - Detects running Portainer containers
2. **Completely removes old setup** - Stops and removes containers/compose stacks
3. **Frees required ports** - Automatically kills processes on ports 9000 and 9443
4. **Deploys fresh instance** - Creates new Portainer container with docker-compose
5. **Shows access URL** - Displays HTTP and HTTPS access links

### Access Portainer

After setup completes:
- **HTTP**: `http://YOUR_PI_IP:9000`
- **HTTPS**: `https://YOUR_PI_IP:9443`

**⚠️ Important:** Create admin account within 5 minutes of first access!

### Manage Portainer

```bash
# Stop Portainer
cd ~/portainer && docker-compose down

# Start Portainer
cd ~/portainer && docker-compose up -d

# View logs
docker logs portainer -f

# Reinstall/Reset Portainer
./setup-portainer.sh YourSudoPassword
# Answer 'y' when asked to remove data volume
```

---

## 🔄 Conduit Setup (Optional)

Conduit is Psiphon's load balancing and traffic management tool.

### Install Conduit

```bash
# Run with default port (8080)
./setup-conduit.sh YourSudoPassword

# Or specify custom port
./setup-conduit.sh YourSudoPassword 9090
```

### What It Does

1. **Force opens port** - Automatically kills any process using the port
2. **Validates Docker** - Ensures Docker is ready
3. **Detects server IP** - Finds your public/local IP
4. **Creates Docker Compose** - Sets up container configuration
5. **Removes old installation** - Cleans up existing Conduit
6. **Configures firewall** - Adds UFW rule if active
7. **Starts Conduit** - Launches the service

### Key Features

- **Automatic port opening** - No manual intervention needed
- **Forced process killing** - Clears port conflicts automatically
- **Configurable workers** - Default: 3 workers
- **Connection limit** - Default: 100 max connections
- **Verbose logging** - Built-in monitoring

### Access Conduit

After setup completes:
- **Default URL**: `http://YOUR_IP:8080`
- **Custom Port**: `http://YOUR_IP:YOUR_PORT`

### Manage Conduit

```bash
# View logs
docker logs conduit -f

# Stop
cd ~/conduit && docker-compose down

# Start
cd ~/conduit && docker-compose up -d

# Restart
docker restart conduit

# Check status
docker ps | grep conduit
```

**📖 Full Guide**: See `CONDUIT-SETUP.md` for complete documentation

---

## 🔧 Customization

### Change zsh Theme
Edit `~/.zshrc`:
```bash
ZSH_THEME="agnoster"  # or robbyrussell, af-magic, etc.
```

### Change Portainer Timezone
Edit `~/portainer/docker-compose.yml`:
```yaml
environment:
  - TZ=America/New_York  # Change from UTC
```

### Manage Java Version
```bash
# List available versions
sudo apt-cache search openjdk

# Install specific version
sudo apt-get install openjdk-17-jdk

# Select default
sudo update-alternatives --config java
```

---

## 🔍 Troubleshooting

### Shell Not Changed
```bash
chsh -s $(which zsh)
# Then log out and back in
```

### Docker Permission Denied
```bash
# Verify you're in docker group
groups

# If not, add yourself
sudo usermod -aG docker $USER
# Then log out and back in
```

### Portainer Not Accessible
```bash
# Check if running
docker ps | grep portainer

# Check logs
docker logs portainer

# Restart
cd ~/portainer
docker-compose restart
```

### Port Already in Use (for Portainer)
```bash
# Portainer setup script handles this automatically
./setup-portainer.sh YourPassword

# Or check manually
sudo lsof -i :9000
sudo lsof -i :9443

# Kill process manually
sudo kill -9 <PID>
```

### JAVA_HOME Not Set
```bash
# Reload shell configuration
source ~/.zshrc
# Or log out and back in
```

### Check Network Status
```bash
# View current connections
ip addr show

# Check which interface is active
ip route show

# Check WiFi connection
iwgetid -r

# Test connectivity
ping -c 4 8.8.8.8
```

### WiFi Not Connecting
```bash
# Check WiFi interface
sudo ifconfig wlan0 up

# Check wpa_supplicant config
sudo cat /etc/wpa_supplicant/wpa_supplicant.conf

# Restart WiFi
sudo wpa_cli -i wlan0 reconfigure

# Check logs
sudo journalctl -u wpa_supplicant -n 50
```

### Change Network Priority
```bash
# Edit priority file
sudo nano /etc/dhcpcd.conf.d/40-network-priority.conf

# Lower metric = higher priority
# Ethernet: metric 100
# WiFi: metric 200
```

---

## 💡 Tips & Tricks

### Network Display
```bash
# Just show network info (no installation)
./test-network-info.sh
```

### Verify Installation
```bash
# Run script again - it will skip installed components
./initial-setup.sh
```

### Check Network Status
```bash
# View all network interfaces and IPs
./test-network-info.sh

# Check active connection
ip route | grep default

# Show network metrics (priority)
ip route show table all | grep metric
```

### Reconfigure WiFi
```bash
# Edit credentials
nano ~/wifi-config.txt

# Apply new settings
./initial-setup.sh
```

### Update System
```bash
# Safe to rerun for system updates
./initial-setup.sh
```

---

## 📊 Script Behavior

### Safety Features
- ✅ **Idempotent** - Safe to run multiple times
- ✅ **Timestamped backups** - Never overwrites (`.zshrc.backup.20260126_153045`)
- ✅ **Smart detection** - Skips already installed components
- ✅ **Clear logging** - Color-coded INFO/SUCCESS/WARNING/ERROR messages
- ✅ **Error handling** - Stops on errors (`set -euo pipefail`)

### On Multiple Runs
| Component | First Run | Subsequent Runs |
|-----------|-----------|-----------------|
| System Updates | Full update | Updates if available |
| zsh | Installs | Skips (warns) |
| Oh My Zsh | Installs | Skips (warns) |
| Java | Installs | Skips (warns) |
| Docker | Installs | Verifies, ensures user in group |

---

## 📁 Files

```
raspbian/
├── initial-setup.sh           Main installation script
├── setup-portainer.sh         Portainer setup/management script (optional)
├── setup-conduit.sh           Conduit load balancer script (optional)
├── wifi-config.txt            WiFi credentials (edit before running)
├── portainer-compose.yml      Portainer Docker Compose config (reference)
├── test-network-info.sh       Network info test script
├── NETWORK-CONFIG.md          Network configuration guide
├── CONDUIT-SETUP.md           Conduit setup and management guide
└── README.md                  This file
```

---

## 🎯 What You Get

After running the script successfully:

✅ Updated Raspbian system
✅ zsh as default shell with Powerlevel10k theme
✅ Java with JAVA_HOME configured system-wide
✅ Docker ready to use (after re-login)
✅ Docker Compose (both versions)
✅ Network configured (Ethernet priority, WiFi backup)

**Total setup time:** ~10-15 minutes (first run)

**Optional:** Run `setup-portainer.sh` to add Docker web management UI

---

## 📝 Notes

- Script requires **non-root user** with sudo privileges
- **Log out and back in** after installation for changes to take effect
- **Docker commands** require re-login (or run `newgrp docker`)
- **Portainer URL** will be shown at the end of installation
- **Safe to rerun** anytime - idempotent design ensures no negative effects

---

**Happy Raspberry Pi-ing! 🎉**
