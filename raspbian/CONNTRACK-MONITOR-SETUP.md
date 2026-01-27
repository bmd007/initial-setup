# Conntrack Monitor Setup

## Overview

Conntrack Monitor is a Terminal User Interface (TUI) application that monitors network connections in real-time. It uses the Linux conntrack system to track active connections and provides geographical information about IP addresses using GeoIP databases.

**Repository**: https://github.com/0xf00f00/conntrack-monitor  
**Docker Image**: `ghcr.io/0xf00f00/conntrack-monitor:latest`

## Features

- 🌐 Real-time network connection monitoring
- 🗺️ Geographical IP information with GeoIP databases
- 📊 Terminal-based UI for easy monitoring
- 🔍 Connection tracking using Linux conntrack
- 📍 Automatic GeoIP database download (DB-IP Lite)
- 🐳 Docker support for easy deployment

## Quick Setup

### Automated Setup

Use the provided setup script to install and configure Conntrack Monitor:

```bash
./setup-conntrack-monitor.sh <sudo_password>
```

**Example:**
```bash
./setup-conntrack-monitor.sh MyPassword123
```

### What the Script Does

1. ✅ Validates Docker installation
2. ✅ Creates Docker Compose configuration
3. ✅ Removes any existing installation
4. ✅ Pulls the latest image
5. ✅ Starts the container in detached mode
6. ✅ Sets up GeoIP database volume

## Usage

### Viewing the TUI (Interactive Mode)

Since Conntrack Monitor is a TUI application, you need to attach to the container to see the interface:

```bash
docker attach conntrack-monitor
```

**To detach without stopping the container:**
- Press `Ctrl+P` then `Ctrl+Q`

### Alternative: Run Interactively

You can also run it in a one-off interactive session:

```bash
cd ~/conntrack-monitor
docker compose run --rm conntrack-monitor
```

This will start a new container and automatically attach to it.

## Management Commands

### Container Management

```bash
# Start the container
cd ~/conntrack-monitor && docker-compose up -d

# Stop the container
cd ~/conntrack-monitor && docker-compose down

# Restart the container
docker restart conntrack-monitor

# Check status
docker ps | grep conntrack-monitor

# View logs (background logs, not TUI)
docker logs conntrack-monitor -f
```

### Attach/Detach

```bash
# Attach to view TUI
docker attach conntrack-monitor

# Detach (keep running)
# Press: Ctrl+P then Ctrl+Q

# Stop container (when attached)
# Press: Ctrl+C or exit TUI
```

## Configuration

### Docker Compose File

The setup script creates a Docker Compose file at `~/conntrack-monitor/docker-compose.yml`:

```yaml
version: '3.8'

services:
  conntrack-monitor:
    image: ghcr.io/0xf00f00/conntrack-monitor:latest
    container_name: conntrack-monitor
    
    cap_add:
      - NET_ADMIN
    
    privileged: true
    tty: true
    stdin_open: true
    
    network_mode: host
    
    volumes:
      - geoip-data:/usr/share/GeoIP
    
    environment:
      - GEOIP_DB_PATHS=/usr/share/GeoIP
    
    restart: unless-stopped

volumes:
  geoip-data:
    driver: local
```

### GeoIP Databases

#### DB-IP Lite (Default)

By default, Conntrack Monitor automatically downloads the free DB-IP Lite databases on first run:
- DB-IP Lite City
- DB-IP Lite ASN

**No configuration required!**

#### MaxMind GeoLite2 (Optional, Higher Accuracy)

If you prefer MaxMind's GeoLite2 databases:

1. **Sign up** for a free account at [MaxMind](https://www.maxmind.com/en/geolite2/signup)

2. **Download** the databases:
   - `GeoLite2-City.mmdb`
   - `GeoLite2-ASN.mmdb`

3. **Copy to volume**:
   ```bash
   docker cp GeoLite2-City.mmdb conntrack-monitor:/usr/share/GeoIP/
   docker cp GeoLite2-ASN.mmdb conntrack-monitor:/usr/share/GeoIP/
   docker restart conntrack-monitor
   ```

The application will automatically prefer MaxMind databases if present.

## Requirements

### System Requirements

- Linux kernel with conntrack support
- Docker installed and running
- NET_ADMIN capability (provided by privileged mode)

### Network Mode

The container runs in **host network mode** to properly monitor the host's network connections. This means:
- No port mapping needed
- Monitors the actual host network traffic
- Required for conntrack functionality

## Troubleshooting

### Container Runs but Shows Empty Logs

**This is normal!** Conntrack Monitor is a TUI application. When run in detached mode (`docker-compose up -d`), the logs will be empty because the TUI needs an interactive terminal.

**Solution**: Attach to the container:
```bash
docker attach conntrack-monitor
```

### Cannot See Network Connections

**Causes:**
1. Container not running in privileged mode
2. NET_ADMIN capability missing
3. Host network mode not enabled

**Solution**: All these are configured in the provided docker-compose.yml

### GeoIP Database Issues

If geographical information is not showing:

1. **Check if databases are downloaded:**
   ```bash
   docker exec conntrack-monitor ls -la /usr/share/GeoIP/
   ```

2. **Wait for first-run download:**
   The first time you attach, the application downloads databases automatically

3. **Manually trigger download:**
   Restart the container to trigger a fresh database check:
   ```bash
   docker restart conntrack-monitor
   ```

### Permission Denied Errors

The container requires privileged mode for conntrack access. Ensure your Docker Compose file has:
```yaml
privileged: true
cap_add:
  - NET_ADMIN
```

## Security Considerations

⚠️ **Important Security Notes:**

1. **Privileged Mode**: The container runs in privileged mode to access conntrack
   - Only run on trusted hosts
   - Consider the security implications

2. **Host Network**: Uses host network mode
   - Container can see all host network traffic
   - No network isolation

3. **NET_ADMIN Capability**: Required for conntrack access
   - Grants network administration privileges

## Uninstallation

To completely remove Conntrack Monitor:

```bash
# Stop and remove container
cd ~/conntrack-monitor
docker-compose down

# Remove volumes (including GeoIP data)
docker volume rm conntrack-monitor_geoip-data

# Remove directory
rm -rf ~/conntrack-monitor

# Remove image (optional)
docker rmi ghcr.io/0xf00f00/conntrack-monitor:latest
```

## Additional Resources

- **GitHub Repository**: https://github.com/0xf00f00/conntrack-monitor
- **DB-IP**: https://db-ip.com
- **MaxMind**: https://www.maxmind.com/en/geolite2/signup

## License & Attribution

This product includes IP Geolocation by DB-IP, available from https://db-ip.com.

Conntrack Monitor is maintained by 0xf00f00 and is available under its respective license.
