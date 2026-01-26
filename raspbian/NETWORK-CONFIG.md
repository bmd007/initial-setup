# Network Configuration Guide

## Overview

The setup script configures your Raspberry Pi with **dual network support**:
- **Ethernet (eth0)** - Primary connection
- **WiFi (wlan0)** - Automatic fallback

## How It Works

### Priority System

The script uses **metric-based routing** to prioritize network interfaces:

```
Ethernet (eth0): metric 100  ← Lower = Higher Priority (PRIMARY)
WiFi (wlan0):    metric 200  ← Higher = Lower Priority (BACKUP)
```

### Automatic Failover

1. **Ethernet Connected** → Uses Ethernet (faster, more stable)
2. **Ethernet Disconnected** → Automatically switches to WiFi
3. **Ethernet Reconnected** → Automatically switches back to Ethernet

No manual intervention needed!

## Setup Instructions

### 1. Configure WiFi (Before Running Script)

Edit `wifi-config.txt`:

```bash
nano wifi-config.txt
```

Add your credentials:

```
SSID=YourNetworkName
PASSWORD=YourPassword
```

### 2. Run Installation Script

```bash
./initial-setup.sh
```

The script will:
- Set up network priority (Ethernet > WiFi)
- Configure WiFi with your credentials
- Test both connections
- Show network status

### 3. Verify Configuration

After installation:

```bash
# Check which interface is active
ip route | grep default

# View all network info
./test-network-info.sh

# Check WiFi connection
iwgetid -r
```

## Configuration Files

### Created by Script

1. **`/etc/dhcpcd.conf.d/40-network-priority.conf`**
   - Sets interface priorities
   - Ethernet: metric 100
   - WiFi: metric 200

2. **`/etc/wpa_supplicant/wpa_supplicant.conf`**
   - WiFi credentials (encrypted)
   - Auto-connect settings

3. **`~/wifi-config.txt`** (template)
   - Your WiFi credentials
   - Keep this file secure!

## Use Cases

### Home Setup
```
├─ Ethernet cable plugged in → Fast wired connection
└─ Move Pi to another room → Seamlessly switches to WiFi
```

### Development Setup
```
├─ Ethernet for downloads/updates → Maximum speed
└─ WiFi for remote access → Always accessible
```

### Server Setup
```
├─ Ethernet as primary → Stable connection
└─ WiFi as backup → Redundancy if cable fails
```

## Managing Networks

### Check Current Connection

```bash
# Show default route (active connection)
ip route | grep default

# Output examples:
# default via 192.168.1.1 dev eth0 metric 100    ← Ethernet active
# default via 192.168.1.1 dev wlan0 metric 200   ← WiFi active
```

### View Network Status

```bash
# All interfaces with IPs
ip addr show

# Ethernet status
ip addr show eth0

# WiFi status
ip addr show wlan0

# WiFi SSID
iwgetid -r
```

### Test Connectivity

```bash
# Ping test
ping -c 4 8.8.8.8

# Trace route to see which interface is used
traceroute -n 8.8.8.8

# Check DNS
nslookup google.com
```

## Reconfiguration

### Change WiFi Credentials

```bash
# Edit credentials
nano ~/wifi-config.txt

# Update SSID and PASSWORD
SSID=NewNetwork
PASSWORD=NewPassword

# Apply changes
./initial-setup.sh
```

The script will add the new WiFi network configuration.

### Change Network Priority

```bash
# Edit priority configuration
sudo nano /etc/dhcpcd.conf.d/40-network-priority.conf

# Change metrics:
interface eth0
metric 100    # Lower = higher priority

interface wlan0
metric 200    # Higher = lower priority

# Restart networking
sudo systemctl restart dhcpcd
```

### Remove WiFi Configuration

```bash
# Edit wpa_supplicant config
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf

# Remove the network block for your WiFi
# Or disable WiFi interface
sudo ifconfig wlan0 down
```

## Troubleshooting

### WiFi Not Connecting

**Check if WiFi is enabled:**
```bash
sudo ifconfig wlan0 up
```

**Check WiFi credentials:**
```bash
# View configured networks
sudo cat /etc/wpa_supplicant/wpa_supplicant.conf
```

**Reconfigure WiFi:**
```bash
sudo wpa_cli -i wlan0 reconfigure
```

**Check logs:**
```bash
sudo journalctl -u wpa_supplicant -n 50
```

### Both Networks Not Working

**Check network manager:**
```bash
sudo systemctl status dhcpcd
```

**Restart networking:**
```bash
sudo systemctl restart dhcpcd
sudo systemctl restart networking
```

**Check interface status:**
```bash
ip link show
```

### WiFi Connecting But Ethernet Not Preferred

**Verify metrics:**
```bash
ip route show table all | grep metric
```

**Should see:**
```
default via 192.168.1.1 dev eth0 metric 100
default via 192.168.1.1 dev wlan0 metric 200
```

If not, check `/etc/dhcpcd.conf.d/40-network-priority.conf`

### Cannot Find WiFi Network

**Scan for networks:**
```bash
sudo iwlist wlan0 scan | grep SSID
```

**Check if SSID is correct:**
```bash
# SSID is case-sensitive!
# "MyNetwork" ≠ "mynetwork"
```

**Check WiFi region settings:**
```bash
sudo raspi-config
# → Localisation Options → WLAN Country
```

## Advanced Configuration

### Multiple WiFi Networks

Edit `wifi-config.txt` with multiple networks:

```
# Home network
SSID=HomeWiFi
PASSWORD=HomePassword

# Work network  
SSID=WorkWiFi
PASSWORD=WorkPassword
```

Then manually configure in wpa_supplicant with priorities:

```bash
sudo nano /etc/wpa_supplicant/wpa_supplicant.conf
```

```
network={
    ssid="HomeWiFi"
    psk=<encrypted>
    priority=100
}

network={
    ssid="WorkWiFi"
    psk=<encrypted>
    priority=50
}
```

Higher priority = preferred network.

### Static IP Configuration

**For Ethernet:**
```bash
sudo nano /etc/dhcpcd.conf
```

Add:
```
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 8.8.4.4
```

**For WiFi:**
```
interface wlan0
static ip_address=192.168.1.101/24
static routers=192.168.1.1
static domain_name_servers=8.8.8.8 8.8.4.4
```

Restart:
```bash
sudo systemctl restart dhcpcd
```

### Disable IPv6 (if needed)

```bash
sudo nano /etc/sysctl.conf
```

Add:
```
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
```

Apply:
```bash
sudo sysctl -p
```

## Security Considerations

### Protect WiFi Credentials

```bash
# Secure wifi-config.txt
chmod 600 ~/wifi-config.txt

# Or delete after setup
rm ~/wifi-config.txt
```

### Use Strong WiFi Password

- Minimum 12 characters
- Mix of letters, numbers, symbols
- Avoid dictionary words

### Monitor Connections

```bash
# View active connections
sudo netstat -tuln

# Check who's connected (if running services)
sudo ss -tuln
```

## Status Commands Reference

```bash
# Quick status check
ip a                              # All interfaces
ip route                          # Routing table
iwgetid -r                        # WiFi SSID

# Detailed status
ip addr show eth0                 # Ethernet details
ip addr show wlan0                # WiFi details
sudo wpa_cli -i wlan0 status     # WiFi connection details

# Testing
ping -c 4 -I eth0 8.8.8.8        # Test via Ethernet
ping -c 4 -I wlan0 8.8.8.8       # Test via WiFi

# Logs
journalctl -u dhcpcd -n 50       # DHCP logs
journalctl -u wpa_supplicant -n 50  # WiFi logs
```

## Summary

✅ **Ethernet Priority** - Always preferred when available
✅ **Automatic Fallback** - Switches to WiFi seamlessly
✅ **Easy Setup** - Just edit wifi-config.txt
✅ **Idempotent** - Safe to reconfigure anytime
✅ **No Manual Switching** - Handles failover automatically

Your Raspberry Pi now has robust dual-network support! 🎉
