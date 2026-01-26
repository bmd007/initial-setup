# Portainer Setup - Port 9000 Issue Fixed

## 🔧 What Was Fixed

The `setup-portainer.sh` script has been improved to handle port conflicts more robustly.

---

## 🆕 Improvements Made

### 1. **Better Port Checking**
- ✅ Checks if `lsof` is installed, installs it if missing
- ✅ Falls back to `netstat` if `lsof` fails
- ✅ Handles empty PID gracefully

### 2. **Enhanced Process Killing**
- ✅ Tries graceful kill (SIGTERM) first
- ✅ Waits 1 second
- ✅ If still running, forces kill (SIGKILL -9)
- ✅ Waits 2 seconds
- ✅ Checks for process restart
- ✅ Kills again if process restarted

### 3. **Better Error Handling**
- ✅ Shows clear error messages
- ✅ Exits with troubleshooting steps if ports can't be freed
- ✅ Validates both ports before proceeding
- ✅ Stops installation if port freeing fails

### 4. **Diagnostic Output**
- ✅ New `show_port_usage()` function
- ✅ Shows what's using ports 9000 and 9443 before attempting to free them
- ✅ Works with both `lsof` and `netstat`

---

## 🚀 Updated Script Flow

```
1. Validate password
2. Check Docker installed and running
3. Show what's using ports 9000/9443 (NEW)
4. Remove existing Portainer
5. Free ports (improved logic):
   - Install lsof if missing
   - Graceful kill first
   - Force kill if needed
   - Check for restart
   - Kill again if restarted
   - Exit if still can't free
6. Install fresh Portainer
```

---

## 🔍 What You'll See Now

### If Port is Free:
```
[INFO] Checking port usage...

Port 9000: Available
Port 9443: Available

[INFO] Freeing required ports for Portainer...
[INFO] Checking if port 9000 is available...
[SUCCESS] Port 9000 is available
[INFO] Checking if port 9000 is available...
[SUCCESS] Port 9443 is available
[SUCCESS] All required ports are available
```

### If Port is In Use:
```
[INFO] Checking port usage...

Port 9000:
COMMAND   PID  USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
nginx    1234  pi     6u  IPv4  12345      0t0  TCP *:9000 (LISTEN)

[INFO] Freeing required ports for Portainer...
[INFO] Checking if port 9000 is available...
[WARNING] Port 9000 is already in use by another process
[WARNING] Process using port 9000: nginx (PID: 1234)
[INFO] Killing process 1234 to free port 9000...
[SUCCESS] Port 9000 freed successfully
```

### If Port Can't Be Freed:
```
[ERROR] Port 9000 is still in use. Please manually stop the process and try again.
[ERROR] Could not free port 9000
[ERROR] Failed to free required ports. Cannot proceed with Portainer installation.

[INFO] Troubleshooting steps:
  1. Check what's using the ports: sudo lsof -i :9000 -i :9443
  2. Manually stop the service
  3. Try running this script again
```

---

## 💡 Manual Troubleshooting

If the script still fails, here's how to manually fix it:

### 1. Check What's Using Port 9000
```bash
sudo lsof -i :9000
# or
sudo netstat -tlnp | grep 9000
```

### 2. Find the Process
```bash
# Example output:
# nginx    1234  pi    6u  IPv4  12345      0t0  TCP *:9000 (LISTEN)
# The PID is 1234
```

### 3. Stop the Service
```bash
# If it's a systemd service:
sudo systemctl stop nginx

# Or kill the process directly:
sudo kill -9 1234
```

### 4. Verify Port is Free
```bash
sudo lsof -i :9000
# Should return nothing
```

### 5. Run Portainer Setup Again
```bash
./setup-portainer.sh YourPassword
```

---

## 🔧 Common Port Conflicts

### Nginx or Apache on Port 9000
```bash
# Stop nginx
sudo systemctl stop nginx

# Or change nginx config to use different port
sudo nano /etc/nginx/sites-enabled/default
# Change port from 9000 to something else
sudo systemctl restart nginx
```

### Another Docker Container
```bash
# Find container using port
docker ps --format '{{.Names}}\t{{.Ports}}' | grep 9000

# Stop the container
docker stop <container-name>
```

### Old Portainer Instance
```bash
# Stop and remove
docker stop portainer
docker rm portainer

# Or use docker-compose
cd ~/portainer
docker-compose down
```

### Service Auto-Restart
Some services automatically restart after being killed. To prevent this:

```bash
# Stop and disable the service
sudo systemctl stop <service-name>
sudo systemctl disable <service-name>

# Then run setup-portainer.sh
./setup-portainer.sh YourPassword

# Re-enable the service later if needed
sudo systemctl enable <service-name>
```

---

## ✅ Testing the Fix

Try running the script again:

```bash
./setup-portainer.sh YourSudoPassword
```

You should now see:
1. Clear diagnostic output showing port usage
2. Better error messages if ports can't be freed
3. Multiple attempts to kill blocking processes
4. Helpful troubleshooting steps if it still fails

---

## 📊 Enhanced Features

| Feature | Before | After |
|---------|--------|-------|
| **lsof check** | Assumed installed | Installs if missing |
| **Kill strategy** | SIGKILL only | SIGTERM → SIGKILL |
| **Restart check** | No | Yes, kills again |
| **Error exit** | Continues anyway | Stops with guidance |
| **Diagnostics** | None | Shows port usage upfront |
| **Fallback** | None | Uses netstat if lsof fails |

---

## 🎯 Summary

The script now:
✅ Shows what's using ports before attempting to free them
✅ Tries multiple kill strategies
✅ Checks for process restarts
✅ Provides clear error messages
✅ Exits with troubleshooting steps if it can't proceed
✅ Handles missing tools (installs lsof)
✅ Falls back to netstat if needed

**Try running it again - it should work now!** 🚀

If you still have issues, the error message will tell you exactly what to do manually.
