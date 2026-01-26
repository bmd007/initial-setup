# Portainer Quick Reference

## What is Portainer?

Portainer is a lightweight, open-source management UI that allows you to easily manage Docker environments through a web browser. It's perfect for Raspberry Pi users who want a visual way to manage containers without memorizing Docker CLI commands.

## Features

- **Container Management**: Start, stop, restart, and remove containers
- **Image Management**: Pull, push, and remove Docker images
- **Volume Management**: Create and manage Docker volumes
- **Network Management**: Manage Docker networks
- **Stack Deployment**: Deploy multi-container applications using docker-compose files
- **Resource Monitoring**: View CPU, memory, and network usage
- **Logs Viewer**: View container logs in real-time
- **Console Access**: Execute commands directly in running containers
- **User Management**: Multi-user support with role-based access control

## Installation

Portainer is automatically installed by the `initial-setup.sh` script. It creates:
- A docker-compose file at `~/portainer/docker-compose.yml`
- A Docker volume for persistent data storage
- Runs on ports 9000 (HTTP) and 9443 (HTTPS)

### Manual Installation

If you want to install Portainer manually or on a different system:

```bash
# Create directory
mkdir -p ~/portainer
cd ~/portainer

# Copy the portainer-compose.yml file or create docker-compose.yml
# Then start it
docker-compose up -d
```

## Access

After installation, access Portainer at:
- HTTP: `http://YOUR_RASPBERRY_PI_IP:9000`
- HTTPS: `https://YOUR_RASPBERRY_PI_IP:9443`

### First-Time Setup

1. Open Portainer in your web browser
2. Create an admin account (username and password)
3. Select "Docker" as the environment to manage
4. Click "Connect"

## Common Operations

### Managing Portainer Container

```bash
# View Portainer status
docker ps | grep portainer

# View Portainer logs
docker logs portainer
docker logs portainer -f  # Follow logs in real-time

# Restart Portainer
cd ~/portainer
docker-compose restart

# Stop Portainer
cd ~/portainer
docker-compose down

# Start Portainer
cd ~/portainer
docker-compose up -d

# Update Portainer to latest version
cd ~/portainer
docker-compose pull
docker-compose up -d
```

### Using Portainer Web UI

#### Deploy a Container
1. Go to **Containers** → **Add container**
2. Enter container name
3. Enter image name (e.g., `nginx:latest`)
4. Configure ports, volumes, and environment variables
5. Click **Deploy the container**

#### Deploy a Stack (docker-compose)
1. Go to **Stacks** → **Add stack**
2. Give your stack a name
3. Paste your docker-compose content or upload a file
4. Click **Deploy the stack**

#### View Container Logs
1. Go to **Containers**
2. Click on a container name
3. Click **Logs** in the top menu
4. Use the search and filter options

#### Access Container Console
1. Go to **Containers**
2. Click on a container name
3. Click **Console** in the top menu
4. Select shell (usually `/bin/sh` or `/bin/bash`)
5. Click **Connect**

#### Monitor Resources
1. Go to **Containers** to see resource usage overview
2. Click on a container for detailed stats
3. View CPU, memory, and network usage graphs

## Docker-Compose Configuration

The Portainer docker-compose file (`~/portainer/docker-compose.yml`) includes:

```yaml
version: '3.8'

services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "9000:9000"      # HTTP Web UI
      - "9443:9443"      # HTTPS Web UI
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer_data:/data
    environment:
      - TZ=UTC

volumes:
  portainer_data:
    driver: local
```

### Configuration Notes

- **restart: unless-stopped** - Automatically starts on boot
- **security_opt: no-new-privileges** - Security hardening
- **Docker socket** - Read-only access to manage Docker
- **portainer_data volume** - Persists configuration and data
- **TZ environment variable** - Set timezone (change UTC to your timezone)

### Customization

#### Change Timezone
Edit `~/portainer/docker-compose.yml` and change the TZ value:
```yaml
environment:
  - TZ=America/New_York  # or Europe/London, Asia/Tokyo, etc.
```

#### Change Ports
If ports 9000 or 9443 are already in use:
```yaml
ports:
  - "8000:9000"      # Change 8000 to your preferred port
  - "8443:9443"      # Change 8443 to your preferred port
```

After making changes, restart Portainer:
```bash
cd ~/portainer
docker-compose down
docker-compose up -d
```

## Troubleshooting

### Cannot Access Web UI

```bash
# Check if Portainer is running
docker ps | grep portainer

# Check Portainer logs for errors
docker logs portainer

# Verify Docker socket access
ls -la /var/run/docker.sock

# Check firewall (if enabled)
sudo ufw status
sudo ufw allow 9000/tcp
sudo ufw allow 9443/tcp
```

### Forgot Admin Password

```bash
# Stop and remove Portainer (keeps data)
cd ~/portainer
docker-compose down

# Start fresh (this will reset admin password)
docker-compose up -d
```

### Portainer Shows No Containers

- Make sure you selected the correct environment
- Verify Docker socket permissions
- Check that your user is in the docker group: `groups`

### Update Issues

```bash
# Force recreate containers
cd ~/portainer
docker-compose down
docker-compose pull
docker-compose up -d --force-recreate
```

## Backup and Restore

### Backup Portainer Data

```bash
# Backup the Portainer data volume
docker run --rm -v portainer_data:/data -v $(pwd):/backup alpine tar czf /backup/portainer-backup.tar.gz -C /data .
```

### Restore Portainer Data

```bash
# Stop Portainer
cd ~/portainer
docker-compose down

# Restore from backup
docker run --rm -v portainer_data:/data -v $(pwd):/backup alpine sh -c "cd /data && tar xzf /backup/portainer-backup.tar.gz"

# Start Portainer
docker-compose up -d
```

## Security Best Practices

1. **Use HTTPS**: Access Portainer via port 9443 instead of 9000
2. **Strong Password**: Use a strong admin password
3. **Network Isolation**: If exposing to internet, use a reverse proxy with authentication
4. **Regular Updates**: Keep Portainer updated to the latest version
5. **Limit Access**: Use Portainer's built-in user management for multi-user environments

## Alternative: Portainer Agent

For managing multiple Docker hosts, consider using Portainer Business Edition with agents on each host. The CE (Community Edition) installed by this script is perfect for single-node setups like Raspberry Pi.

## Resources

- Official Documentation: https://docs.portainer.io/
- GitHub Repository: https://github.com/portainer/portainer
- Docker Hub: https://hub.docker.com/r/portainer/portainer-ce
- Community Forums: https://community.portainer.io/

## Quick Tips

- Use **Stacks** instead of individual containers for related services
- Enable **Auto-update** feature for containers that should stay current
- Use **Templates** for quick deployment of popular applications
- Check **Events** page to see Docker activity history
- Export container configurations as docker-compose for version control
