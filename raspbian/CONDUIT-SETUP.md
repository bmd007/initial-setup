# Conduit Setup Guide

## Overview

This script sets up **Conduit** - Psiphon's load balancing and traffic management tool - using Docker.

**Conduit Homepage:** https://conduit.psiphon.ca/

---

## What is Conduit?

Conduit is a load balancer and traffic manager for Psiphon infrastructure. It provides:
- Load balancing across multiple backends
- Traffic management and routing
- Connection pooling
- High availability setup

**Important:** Conduit requires a Psiphon network configuration file (`psiphon_config.json`) to connect to the Psiphon network. This file must be obtained from the Psiphon team. See: https://github.com/Psiphon-Inc/conduit

---

## Installation

### Prerequisites
- Docker and Docker Compose installed
- Raspberry Pi (or any Linux server)
- Port 8080 available (or custom port)
- **Psiphon configuration file** (psiphon_config.json)

### Quick Setup

```bash
# Make executable
chmod +x setup-conduit.sh

# Run setup (default port 8080)
./setup-conduit.sh YourSudoPassword

# Or specify custom port
./setup-conduit.sh YourSudoPassword 9090
```

**⚠️ Note:** After installation, you need to add your `psiphon_config.json` file to `~/conduit/` directory for Conduit to work properly.

---

## What the Script Does

1. **Force Opens Port** - Kills any process using the target port
2. **Validates Docker** - Ensures Docker is installed and running
3. **Detects Server IP** - Finds your public/local IP
4. **Creates Docker Compose** - Sets up container configuration
5. **Removes Old Installation** - Cleans up existing Conduit
6. **Configures Firewall** - Adds UFW rule if active
7. **Pulls Latest Image** - Gets latest Conduit from registry
8. **Starts Container** - Launches Conduit service
9. **Shows Connection Info** - Displays access URL and commands

---

## Configuration

### Default Settings
- **Port**: 8080 (customizable)
- **Workers**: 3 (-b 3)
- **Max Connections**: 100 (-m 100)
- **Logging**: Verbose (-vv)
- **Container Name**: conduit
- **Data Volume**: conduit-data

### Customize Port
```bash
# Use custom port
./setup-conduit.sh YourPassword 9090
```

### Modify Configuration
Edit `~/conduit/docker-compose.yml`:
```yaml
command: ["start", "-b", "5", "-m", "200", "-vv"]
#                   ↑ workers  ↑ max conn  ↑ verbose
```

Then restart:
```bash
cd ~/conduit
docker-compose down
docker-compose up -d
```

---

## File Structure

After installation:
```
~/conduit/
├── docker-compose.yml       # Container configuration
└── data/                    # Data volume (mounted)
```

---

## Server Management

### View Logs
```bash
docker logs conduit -f
```

### Stop/Start/Restart
```bash
cd ~/conduit
docker-compose down          # Stop
docker-compose up -d         # Start
docker restart conduit       # Restart
```

### Check Status
```bash
docker ps | grep conduit
docker stats conduit
```

### Update Conduit
```bash
cd ~/conduit
docker-compose pull
docker-compose up -d
```

---

## Port Management

### Forced Port Opening
The script **automatically** kills any process using the configured port:

```
[INFO] Force opening port 8080...
[WARNING] Port 8080 is in use by process(es): 1234
[INFO] Force killing process(es)...
[WARNING] Killing nginx (PID: 1234)
[SUCCESS] Port 8080 is now free
```

No manual intervention needed!

### Change Port After Installation
```bash
# Edit docker-compose.yml
cd ~/conduit
nano docker-compose.yml

# Change port mapping
ports:
  - "9090:9090"  # New port

# Restart
docker-compose down
docker-compose up -d
```

---

## Firewall Configuration

### Automatic UFW Configuration
If UFW is active, the script automatically adds a rule:
```bash
sudo ufw allow 8080/tcp comment 'Conduit'
```

### Manual Firewall Setup
```bash
# UFW
sudo ufw allow 8080/tcp

# iptables
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
sudo iptables-save > /etc/iptables/rules.v4
```

---

## Troubleshooting

### Port Still In Use
The script force-kills processes, but if issues persist:
```bash
# Find what's using the port
sudo lsof -i :8080

# Kill manually
sudo kill -9 <PID>

# Or stop the service
sudo systemctl stop <service-name>
```

### Container Won't Start
```bash
# Check logs
docker logs conduit

# Check if image pulled correctly
docker images | grep conduit

# Try pulling manually
docker pull ghcr.io/ssmirr/conduit/conduit:latest
```

### Permission Issues
```bash
# Fix ownership
cd ~/conduit
sudo chown -R $USER:$USER .

# Check Docker group
groups | grep docker
# If not in docker group, add yourself:
sudo usermod -aG docker $USER
# Then log out and back in
```

---

## Command Reference

### Docker Commands
```bash
# View running containers
docker ps

# View all containers
docker ps -a

# View logs (follow)
docker logs conduit -f

# View last 100 lines
docker logs conduit --tail 100

# Execute command in container
docker exec -it conduit sh

# View resource usage
docker stats conduit

# Restart container
docker restart conduit

# Remove container
docker rm -f conduit
```

### Docker Compose Commands
```bash
cd ~/conduit

# Start (detached)
docker-compose up -d

# Stop
docker-compose down

# Restart
docker-compose restart

# View logs
docker-compose logs -f

# Pull latest image
docker-compose pull

# Rebuild and start
docker-compose up -d --build
```

---

## Advanced Configuration

### Resource Limits
Add to `docker-compose.yml`:
```yaml
services:
  conduit:
    # ...existing config...
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
        reservations:
          memory: 512M
```

### Environment Variables
```yaml
environment:
  - TZ=America/New_York
  - CONDUIT_LOG_LEVEL=debug
```

### Network Mode
For better performance, use host networking:
```yaml
network_mode: host
```

---

## Monitoring

### Basic Monitoring
```bash
#!/bin/bash
# Save as ~/monitor-conduit.sh

echo "Conduit Status"
echo "=============="
docker ps --filter name=conduit --format "Status: {{.Status}}"
echo ""
echo "Resource Usage:"
docker stats conduit --no-stream
echo ""
echo "Recent Logs:"
docker logs conduit --tail 20
```

### Automated Checks
Add to crontab:
```bash
# Check every 5 minutes
*/5 * * * * docker ps | grep -q conduit || docker start conduit
```

---

## Monitoring

### Real-Time Connection Monitor

Visualize Conduit connections with geographic location tracking:

```bash
# Start monitor with default refresh (3 seconds)
./conduit-monitor.sh

# Custom refresh interval
./conduit-monitor.sh 5  # Update every 5 seconds
```

### Monitor Features

**📊 Statistics Dashboard:**
- Total connections logged
- Currently active connections
- Warning and error counts

**🌍 IP Geolocation:**
- Automatic source IP detection
- City and country lookup
- GPS coordinates
- Visual geographic distribution

**📈 Visualizations:**
- Top 20 source IPs with connection counts
- Country-based connection distribution
- Recent activity log
- Color-coded output

**🔄 Live Updates:**
- Configurable refresh rate
- Real-time log parsing
- Automatic cache management

### Monitor Display

```
╔════════════════════════════════════════════════════════════════════════════╗
║                    Conduit Connection Monitor                              ║
╚════════════════════════════════════════════════════════════════════════════╝

Container: conduit
Refresh: Every 3s | Press Ctrl+C to exit

═══ Connection Statistics ═══
● Total Connections (logged): 1234
● Active Connections: 45
● Warnings: 12
● Errors: 2

═══ Active Source IPs ═══
Count   IP Address       Location
─────────────────────────────────────────────────────────────────────────
23      185.220.101.45   Berlin, Germany (DE) [52.52,13.40]
18      104.244.74.89    San Francisco, USA (US) [37.77,-122.41]
15      51.75.144.43     Paris, France (FR) [48.86,2.34]

═══ Geographic Distribution ═══
Top Countries:
(US)   ████████████████ 125
(DE)   ████████████ 98
(FR)   ████████ 67
```

### Monitor Requirements

```bash
# Install dependencies
sudo apt-get install -y curl jq

# Ensure Conduit is running
docker ps | grep conduit
```

**📖 Complete Monitoring Guide**: See `CONDUIT-MONITOR.md` for full documentation

---

## Backup & Restore

### Backup Data Volume
```bash
# Create backup
docker run --rm -v conduit-data:/data -v $(pwd):/backup alpine tar czf /backup/conduit-backup-$(date +%Y%m%d).tar.gz /data

# List backups
ls -lh conduit-backup-*.tar.gz
```

### Restore Data Volume
```bash
# Stop Conduit
cd ~/conduit && docker-compose down

# Restore from backup
docker run --rm -v conduit-data:/data -v $(pwd):/backup alpine sh -c "cd / && tar xzf /backup/conduit-backup-YYYYMMDD.tar.gz"

# Start Conduit
docker-compose up -d
```

---

## Uninstall

### Complete Removal
```bash
# Stop and remove container
cd ~/conduit
docker-compose down

# Remove image
docker rmi ghcr.io/ssmirr/conduit/conduit:latest

# Remove volume
docker volume rm conduit-data

# Remove files
rm -rf ~/conduit

# Remove firewall rule (if UFW)
sudo ufw delete allow 8080/tcp
```

---

## Performance Tips

### 1. Adjust Worker Count
Based on CPU cores:
```bash
# Edit docker-compose.yml
command: ["start", "-b", "4", "-m", "200", "-vv"]
#                        ↑ workers = CPU cores
```

### 2. Increase Connection Limit
For high traffic:
```bash
command: ["start", "-b", "3", "-m", "500", "-vv"]
#                                ↑ max connections
```

### 3. Reduce Logging
For production:
```bash
command: ["start", "-b", "3", "-m", "100"]
# Remove -vv for less verbose logging
```

---

## FAQ

**Q: What port does Conduit use?**
A: Default is 8080, but you can specify any port when running the setup script.

**Q: Can I run multiple Conduit instances?**
A: Yes, use different ports for each instance.

**Q: Does this work on Raspberry Pi?**
A: Yes, tested on Raspberry Pi 4 with 64-bit Raspbian.

**Q: How do I change the port after installation?**
A: Edit `~/conduit/docker-compose.yml`, change the port mapping, then run `docker-compose down && docker-compose up -d`.

**Q: What if the port is already in use?**
A: The script automatically kills any process using the port before installation.

---

## Resources

- **Conduit Website**: https://conduit.psiphon.ca/
- **Container Image**: ghcr.io/ssmirr/conduit/conduit:latest
- **Docker Documentation**: https://docs.docker.com/

---

## Support

For issues with:
- **This script**: Check troubleshooting section above
- **Conduit software**: Visit https://conduit.psiphon.ca/
- **Raspberry Pi setup**: Run initial-setup.sh first

---

**Your Conduit load balancer is ready!** 🚀

## Overview

This script sets up a **Psiphon tunnel server** (psiphond) using Docker. Psiphon is a circumvention tool that helps users bypass internet censorship.

---

## What is Psiphon?

Psiphon tunnels Internet traffic through a network of proxy servers to circumvent Internet censorship. It uses:
- **SSH tunnels** for secure connections
- **Traffic obfuscation** to evade blocking
- **Multiple protocols** (OSSH, SSH, etc.)

---

## Installation

### Prerequisites
- Docker and Docker Compose installed
- Raspberry Pi (or any Linux server)
- Public IP address or port forwarding configured

### Quick Setup

```bash
# Make executable
chmod +x setup-psiphon.sh

# Run setup
./setup-psiphon.sh YourSudoPassword
```

---

## What the Script Does

1. **Detects Server IP** - Finds your public IP address
2. **Downloads psiphond** - Gets latest binary from official repository
3. **Generates Configuration** - Creates server config and keys
4. **Creates Docker Setup** - Dockerfile and docker-compose.yml
5. **Builds Container** - Creates Docker image
6. **Starts Server** - Runs psiphond in container
7. **Shows Connection Info** - Displays server entry for clients

---

## Configuration

### Default Ports
- **OSSH**: 4000 (Obfuscated SSH)
- **SSH**: 4001 (Standard SSH)

### Customize Ports
Edit the script before running:
```bash
nano setup-psiphon.sh
# Change: PSIPHON_PORT=4000
```

Or modify after installation:
```bash
cd ~/psiphon-server
# Edit psiphond.config
nano psiphond.config
# Rebuild and restart
docker-compose down
docker build -t psiphond:latest .
docker-compose up -d
```

---

## File Structure

After installation:
```
~/psiphon-server/
├── psiphond                 # Server binary
├── psiphond.config          # Server configuration
├── server-entry.dat         # Client connection info (KEEP SECURE!)
├── Dockerfile               # Docker image definition
├── docker-compose.yml       # Docker Compose configuration
└── data/                    # Server data (volume)
```

---

## Server Management

### View Logs
```bash
docker logs psiphond -f
```

### Stop Server
```bash
cd ~/psiphon-server
docker-compose down
```

### Start Server
```bash
cd ~/psiphon-server
docker-compose up -d
```

### Restart Server
```bash
cd ~/psiphon-server
docker-compose restart
```

### Rebuild (after config changes)
```bash
cd ~/psiphon-server
docker-compose down
docker build -t psiphond:latest .
docker-compose up -d
```

---

## Client Connection

### Get Server Entry
The `server-entry.dat` file contains all information clients need to connect.

```bash
# View server entry
cat ~/psiphon-server/server-entry.dat
```

### Distribute to Clients
**⚠️ Security Important:**
- Send `server-entry.dat` to clients via secure channel
- Don't post publicly (server will be easily blocked)
- Use encrypted messaging or secure file transfer

### Client Apps
Download official Psiphon clients:
- **Android**: https://psiphon.ca/en/download.html
- **iOS**: https://psiphon.ca/en/download.html
- **Windows**: https://psiphon.ca/en/download.html
- **Command Line**: https://github.com/Psiphon-Labs/psiphon-tunnel-core-binaries

### Client Configuration
1. Download Psiphon client
2. Import `server-entry.dat` file
3. Connect to your server

---

## Firewall Configuration

### Open Required Ports

If using UFW:
```bash
sudo ufw allow 4000/tcp comment 'Psiphon OSSH'
sudo ufw allow 4001/tcp comment 'Psiphon SSH'
```

If using iptables:
```bash
sudo iptables -A INPUT -p tcp --dport 4000 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 4001 -j ACCEPT
sudo iptables-save > /etc/iptables/rules.v4
```

### Port Forwarding (if behind NAT)
Configure your router to forward ports 4000-4001 to your Raspberry Pi's local IP.

---

## Security Considerations

### 1. Keep Server Entry Secure
- `server-entry.dat` is like a password
- Don't share publicly
- Limit distribution to trusted users

### 2. Monitor Usage
```bash
# Check connections
docker logs psiphond | grep connected

# Monitor bandwidth
docker stats psiphond
```

### 3. Regular Updates
```bash
# Update psiphond binary
cd ~/psiphon-server
curl -L -o psiphond https://github.com/Psiphon-Labs/psiphon-tunnel-core-binaries/raw/master/psiphond/psiphond
chmod +x psiphond
docker-compose down
docker build -t psiphond:latest .
docker-compose up -d
```

### 4. Limit Access
Consider implementing:
- IP whitelisting in firewall
- Rate limiting
- Connection limits in config

---

## Troubleshooting

### Server Won't Start
```bash
# Check logs
docker logs psiphond

# Check if ports are in use
sudo lsof -i :4000
sudo lsof -i :4001

# Verify config
cat ~/psiphon-server/psiphond.config
```

### Clients Can't Connect
```bash
# 1. Verify server is running
docker ps | grep psiphond

# 2. Check firewall
sudo ufw status

# 3. Verify public IP
curl ifconfig.me

# 4. Test connectivity
telnet YOUR_PUBLIC_IP 4000
```

### Permission Issues
```bash
# Fix ownership
cd ~/psiphon-server
sudo chown -R $USER:$USER .
```

### Port Already in Use
```bash
# Find what's using the port
sudo lsof -i :4000

# Kill the process or change Psiphon port
```

---

## Advanced Configuration

### Custom Protocols
Edit psiphond.config to add more protocols:
```json
{
  "Protocols": ["OSSH", "SSH", "UNFRONTED-MEEK-OSSH"],
  "BindAddresses": {
    "OSSH": "0.0.0.0:4000",
    "SSH": "0.0.0.0:4001",
    "UNFRONTED-MEEK-OSSH": "0.0.0.0:4002"
  }
}
```

### Logging Configuration
Modify docker-compose.yml:
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "100m"  # Increase log size
    max-file: "10"    # Keep more log files
```

### Resource Limits
Add to docker-compose.yml service section:
```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 1G
    reservations:
      memory: 512M
```

---

## Monitoring

### Check Server Status
```bash
# Container status
docker ps | grep psiphond

# Resource usage
docker stats psiphond

# Connection count
docker logs psiphond | grep -c "connected"
```

### Automated Monitoring Script
```bash
#!/bin/bash
# Save as ~/monitor-psiphon.sh

echo "Psiphon Server Status:"
echo "====================="
docker ps --filter name=psiphond --format "Status: {{.Status}}"
echo ""
echo "Resource Usage:"
docker stats psiphond --no-stream
echo ""
echo "Recent Connections:"
docker logs psiphond --tail 10 | grep connected
```

---

## Backup

### Backup Configuration
```bash
# Create backup directory
mkdir -p ~/psiphon-backups

# Backup files
cp ~/psiphon-server/psiphond.config ~/psiphon-backups/
cp ~/psiphon-server/server-entry.dat ~/psiphon-backups/
cp ~/psiphon-server/docker-compose.yml ~/psiphon-backups/

# Create tarball
tar -czf ~/psiphon-backup-$(date +%Y%m%d).tar.gz -C ~/psiphon-server .
```

### Restore from Backup
```bash
# Stop server
cd ~/psiphon-server
docker-compose down

# Restore files
tar -xzf ~/psiphon-backup-YYYYMMDD.tar.gz -C ~/psiphon-server

# Restart
docker-compose up -d
```

---

## Uninstall

### Complete Removal
```bash
# Stop and remove container
cd ~/psiphon-server
docker-compose down

# Remove image
docker rmi psiphond:latest

# Remove volume
docker volume rm psiphon-server_psiphon_data

# Remove files
rm -rf ~/psiphon-server
```

---

## Performance Tips

### 1. Optimize for Raspberry Pi
```bash
# Limit memory usage in docker-compose.yml
mem_limit: 512m
```

### 2. Enable Compression
Edit psiphond.config:
```json
{
  "SSHSessionMaxChannels": 2,
  "Compression": true
}
```

### 3. Reduce Logging
```yaml
# In docker-compose.yml
logging:
  driver: "none"  # Disable logging for better performance
```

---

## FAQ

**Q: Can I run multiple Psiphon servers?**
A: Yes, use different ports for each server or different servers.

**Q: Does this work on Raspberry Pi?**
A: Yes, tested on Raspberry Pi 4 with 64-bit Raspbian.

**Q: How many clients can connect?**
A: Depends on your bandwidth and resources. Start with 10-20 concurrent connections.

**Q: Is this the same as Psiphon official servers?**
A: This runs the same server software but you manage it yourself.

**Q: Can I monetize this?**
A: Check Psiphon's license and terms of service.

---

## Resources

- **Official Psiphon**: https://psiphon.ca
- **Source Code**: https://github.com/Psiphon-Labs/psiphon-tunnel-core
- **Binaries**: https://github.com/Psiphon-Labs/psiphon-tunnel-core-binaries
- **Documentation**: https://github.com/Psiphon-Labs/psiphon-tunnel-core/tree/master/psiphon

---

## Support

For issues with:
- **This script**: Check troubleshooting section above
- **Psiphon software**: https://github.com/Psiphon-Labs/psiphon-tunnel-core/issues
- **Raspberry Pi setup**: Run initial-setup.sh first

---

**Your Psiphon tunnel server is ready to help users bypass censorship!** 🌐🔓
