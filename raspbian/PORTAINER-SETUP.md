# Portainer Setup & First-Time Configuration

## Overview

Portainer is a lightweight management UI for Docker that provides an easy way to manage containers, images, networks, and volumes through a web interface.

## Quick Setup

```bash
./setup-portainer.sh YourSudoPassword
```

## First-Time Access & Environment Setup

### ⚠️ Important: 5-Minute Timeout

After installation, you have **5 minutes** to complete the initial setup before the installation expires and needs to be redone.

### Step-by-Step First Access

1. **Open Portainer in your browser**
   ```
   http://YOUR_PI_IP:9000
   ```

2. **Create Admin Account**
   - Enter a username (e.g., `admin`)
   - Enter a strong password
   - Confirm password
   - Click "Create user"

3. **Select Environment**
   
   You'll see one of these screens:
   
   **Option A: "Get Started" button**
   - Click "Get Started"
   - Portainer will automatically detect the local Docker environment
   
   **Option B: Environment selection**
   - Select "Docker" (not Docker Swarm or Kubernetes)
   - Choose "Manage the local Docker environment"
   - Click "Connect"

4. **Done!**
   - You should now see the Portainer dashboard
   - The "local" environment will be available
   - You can see all containers, images, volumes, and networks

## Why No Environment Shows Initially?

Portainer requires **manual first-time configuration** for security reasons:

1. **Security**: Prevents unauthorized auto-configuration
2. **Admin account**: Ensures you set up authentication first
3. **Environment choice**: Lets you choose between Docker, Swarm, or Kubernetes

The Docker socket (`/var/run/docker.sock`) is already mounted and accessible, but Portainer waits for you to explicitly enable the environment through the web UI.

## What You'll See After Setup

Once configured, your Portainer home page will show:

- **Environment**: `local` (your Raspberry Pi Docker)
- **Containers**: All running and stopped containers
- **Images**: All Docker images
- **Volumes**: All Docker volumes
- **Networks**: All Docker networks
- **Statistics**: CPU, memory, and container counts

## Troubleshooting

### "The Portainer instance timed out" Error

**Problem**: You didn't complete setup within 5 minutes.

**Solution**: Restart Portainer and try again
```bash
docker restart portainer
# Then quickly access http://YOUR_IP:9000 and complete setup
```

### No Environment Showing After Setup

**Problem**: Environment wasn't added during first-time setup.

**Solution**: Add it manually
1. Click on "Environments" in the left menu
2. Click "Add environment"
3. Select "Docker"
4. Select "Socket" connection type
5. Name it "local"
6. Socket path: `/var/run/docker.sock`
7. Click "Connect"

### Can't Access Portainer

**Check if container is running:**
```bash
docker ps | grep portainer
```

**Check logs:**
```bash
docker logs portainer
```

**Restart Portainer:**
```bash
cd ~/portainer
docker-compose restart
```

### Port Already in Use

**Check what's using ports 9000 and 9443:**
```bash
sudo lsof -i :9000
sudo lsof -i :9443
```

**Re-run setup script** (it will automatically free the ports):
```bash
./setup-portainer.sh YourSudoPassword
```

## Management Commands

### Start/Stop/Restart

```bash
# Using docker-compose
cd ~/portainer
docker-compose up -d      # Start
docker-compose down       # Stop
docker-compose restart    # Restart

# Using docker commands
docker start portainer    # Start
docker stop portainer     # Stop
docker restart portainer  # Restart
```

### View Logs

```bash
docker logs portainer -f
```

### Update Portainer

```bash
cd ~/portainer
docker-compose pull
docker-compose up -d
```

### Complete Removal

```bash
cd ~/portainer
docker-compose down
docker volume rm portainer_data  # Removes all settings
rm -rf ~/portainer
```

## Access Methods

### HTTP (Recommended for local network)
```
http://YOUR_PI_IP:9000
```

### HTTPS (Self-signed certificate)
```
https://YOUR_PI_IP:9443
```
**Note**: You'll see a certificate warning - this is normal for self-signed certificates.

## Security Best Practices

1. **Use a strong password** for the admin account
2. **Access only from trusted networks** (your local network)
3. **Consider enabling HTTPS** if accessing over untrusted networks
4. **Don't expose to the internet** without proper security (VPN, firewall, etc.)
5. **Create additional users** with limited permissions if needed

## What Can You Do With Portainer?

### Container Management
- Start/stop/restart containers
- View logs in real-time
- Open container console/terminal
- View resource usage
- Inspect container details

### Image Management
- Pull images from registries
- Build images from Dockerfiles
- Delete unused images
- View image layers and history

### Volume Management
- Create/delete volumes
- Browse volume data
- Attach volumes to containers

### Network Management
- Create custom networks
- View network details
- Connect/disconnect containers

### Docker Compose
- Deploy stacks from compose files
- Manage multi-container applications
- Update and redeploy stacks

## Configuration File Location

```
~/portainer/docker-compose.yml
```

## Default Settings

- **HTTP Port**: 9000
- **HTTPS Port**: 9443
- **Timezone**: UTC
- **Data Volume**: `portainer_data`
- **Docker Socket**: `/var/run/docker.sock` (read-only)

## Changing Settings

### Change Timezone

Edit `~/portainer/docker-compose.yml`:
```yaml
environment:
  - TZ=America/New_York  # Change from UTC
```

Then restart:
```bash
cd ~/portainer
docker-compose up -d
```

### Change Ports

Edit `~/portainer/docker-compose.yml`:
```yaml
ports:
  - "8080:9000"   # Change 8080 to your preferred port
  - "8443:9443"   # Change 8443 to your preferred port
```

Then restart:
```bash
cd ~/portainer
docker-compose up -d
```

## Support

- **Portainer Documentation**: https://docs.portainer.io/
- **Community Forum**: https://community.portainer.io/
- **GitHub**: https://github.com/portainer/portainer

## Summary

**Yes, you need to manually set up the environment on first access!** This is by design for security. Once you complete the initial setup (create admin account + select Docker environment), Portainer will automatically connect to your local Docker through the mounted socket, and you'll see all your containers and images immediately.

The setup takes less than 30 seconds, and you only need to do it once.
