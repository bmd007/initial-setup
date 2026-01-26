# Conduit Connection Monitor & Health Check Guide

## Overview

Conduit is a **Psiphon proxy node** that connects to the Psiphon network and helps users bypass censorship.

**Official Repository:** https://github.com/Psiphon-Inc/conduit

This guide covers two tools:
1. **conduit-monitor.sh** - Real-time connection visualization
2. **conduit-health.sh** - Health check and verification tool

---

## What is Conduit?

Conduit is part of the Psiphon circumvention system:
- **Purpose**: Acts as a proxy node in the Psiphon network
- **Function**: Helps users bypass internet censorship
- **Reputation**: Builds trust with Psiphon broker over time
- **Key**: Uses persistent identity key (conduit_key.json)

### Requirements
- Psiphon network configuration file (psiphon_config.json)
- Persistent data directory for identity key
- Network connectivity to Psiphon infrastructure

---

## Health Check Tool

### Quick Health Check

```bash
# Run comprehensive health check
./conduit-health.sh
```

### What It Checks

1. **Container Status** - Is Conduit running?
2. **Resource Usage** - CPU, memory, network I/O
3. **Data Directory** - Identity key presence
4. **Psiphon Config** - Configuration file validity
5. **Container Logs** - Errors, warnings, connectivity
6. **Network** - DNS resolution, outbound connectivity
7. **Recent Activity** - Log analysis from last hour

### Example Output

```
╔════════════════════════════════════════════════════════════════════════════╗
║                    Conduit Health Check                                    ║
╚════════════════════════════════════════════════════════════════════════════╝

═══ Running Health Checks ═══

[TEST] Checking if Conduit container is running...
[✓] Container is running
  ↳ Status: Up 2 hours

[TEST] Checking container resource usage...
[✓] Resource usage:
  ↳ CPU: 2.5%
  ↳ Memory: 45.2MB / 8GB
  ↳ Network I/O: 1.2MB / 850KB

[TEST] Checking data directory...
[✓] Data directory exists
[✓] Identity key found (conduit_key.json)
  ↳ This key maintains your Psiphon broker reputation
  ↳ Keep this file backed up and persistent!

[TEST] Checking Psiphon configuration...
[✓] Psiphon config exists
[✓] Config is valid JSON

[TEST] Analyzing container logs...
[✓] No errors in recent logs
  ↳ Log summary: 145 info, 3 warnings, 0 errors

[TEST] Checking Psiphon network connectivity...
[✓] Connection indicators found in logs
  ↳ Recent connections:
    INFO: Connected to broker
    INFO: Tunnel established

═══ Health Check Summary ═══

✓ Conduit appears to be running properly

Note: Full functionality depends on:
  • Valid Psiphon configuration
  • Network connectivity to Psiphon infrastructure  
  • Broker reputation (builds over time)
```

---

## Connection Monitor

### Real-Time Monitoring

```bash
# Start monitor with default refresh (3 seconds)
./conduit-monitor.sh

# Custom refresh interval
./conduit-monitor.sh 5  # Update every 5 seconds
```

---

## Features

### 📊 Real-Time Statistics
- Total connections logged
- Currently active connections
- Warning count
- Error count

### 🌍 IP Geolocation
- Automatic IP address detection from logs
- Geographic location lookup (City, Country)
- Country code display
- GPS coordinates
- Local IP detection

### 📈 Visualizations
- Top 20 source IPs with connection counts
- Geographic distribution by country
- Recent activity log (last 10 events)
- Color-coded output

### 🔄 Live Updates
- Configurable refresh interval (default: 3 seconds)
- Real-time connection monitoring
- Automatic log parsing

---

## Installation

### Prerequisites
```bash
# Install required tools
sudo apt-get install -y curl jq

# Ensure Conduit is running
docker ps | grep conduit
```

### Setup
```bash
# Script is already in your raspbian folder
chmod +x conduit-monitor.sh
```

---

## Usage

### Basic Usage
```bash
# Start monitor with default refresh (3 seconds)
./conduit-monitor.sh

# Custom refresh interval
./conduit-monitor.sh 5  # Update every 5 seconds
```

### Stop Monitoring
Press `Ctrl+C` to exit

---

## Display Explained

### Header Section
```
╔════════════════════════════════════════════════════════════════════════════╗
║                    Conduit Connection Monitor                              ║
╚════════════════════════════════════════════════════════════════════════════╝

Container: conduit
Refresh: Every 3s | Press Ctrl+C to exit
Time: 2026-01-27 15:30:45
```

### Connection Statistics
```
═══ Connection Statistics ═══
● Total Connections (logged): 1234
● Active Connections: 45
● Warnings: 12
● Errors: 2
```

**Metrics Explained:**
- **Total Connections**: All connections found in recent logs
- **Active Connections**: Currently established connections
- **Warnings**: Warning messages in logs
- **Errors**: Error messages in logs

### Active Source IPs Table
```
═══ Active Source IPs ═══
Count   IP Address       Location
─────────────────────────────────────────────────────────────────────────
23      185.220.101.45   Berlin, Germany (DE) [52.52,13.40]
18      104.244.74.89    San Francisco, USA (US) [37.77,-122.41]
15      51.75.144.43     Paris, France (FR) [48.86,2.34]
12      192.168.1.100    LOCAL
8       203.0.113.42     Unknown
...
```

**Column Details:**
- **Count**: Number of connections from this IP
- **IP Address**: Source IP (color coded: green=public, yellow=local, red=unknown)
- **Location**: City, Country (Code) [latitude,longitude]

### Geographic Distribution
```
═══ Geographic Distribution ═══
Top Countries:
(US)   ████████████████ 125
(DE)   ████████████ 98
(FR)   ████████ 67
(GB)   ██████ 45
(CN)   ████ 34
```

Shows connection distribution by country with visual bars.

### Recent Activity
```
═══ Recent Activity (Last 10 Events) ═══
2026-01-27 15:30:42 INFO: Connection established from 185.220.101.45
2026-01-27 15:30:41 INFO: Request processed successfully
2026-01-27 15:30:40 WARN: High connection rate detected
2026-01-27 15:30:39 ERROR: Connection timeout
...
```

Color coded by log level:
- 🔵 Blue: INFO
- 🟡 Yellow: WARN
- 🔴 Red: ERROR

---

## How It Works

### 1. Log Analysis
```bash
# Extracts IPs from container logs
docker logs conduit --tail 1000 2>&1 | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
```

### 2. IP Geolocation
Uses free IP geolocation API:
```bash
# Queries ip-api.com for location data
curl -s "http://ip-api.com/json/185.220.101.45?fields=country,city,lat,lon"
```

**Response Example:**
```json
{
  "status": "success",
  "country": "Germany",
  "countryCode": "DE",
  "city": "Berlin",
  "lat": 52.52,
  "lon": 13.40
}
```

### 3. Caching
- Locations are cached in `/tmp/conduit-monitor-stats.txt`
- Prevents repeated API calls for same IP
- Cache cleared on script restart

### 4. Statistics
```bash
# Active connections from netstat
docker exec conduit sh -c "netstat -an | grep ESTABLISHED"

# Log analysis for events
grep -c "connection\|error\|warning"
```

---

## Configuration

### Adjust Refresh Rate
```bash
# Slow updates (10 seconds)
./conduit-monitor.sh 10

# Fast updates (1 second) - may stress API
./conduit-monitor.sh 1
```

### Modify Log Lines Analyzed
Edit the script:
```bash
nano conduit-monitor.sh

# Change this line:
LOG_LINES=1000  # Increase for more history
```

### Change Container Name
```bash
# If your container has different name
nano conduit-monitor.sh

# Change:
CONTAINER_NAME="conduit"  # To your container name
```

---

## Troubleshooting

### Conduit Not Connecting to Psiphon Network

**Check logs for connection issues:**
```bash
docker logs conduit | grep -i "error\|fail\|refused"
```

**Common issues:**

1. **Missing Psiphon Config**
```bash
# Check if config exists
ls -l ~/conduit/psiphon_config.json

# If missing, you need to obtain one from Psiphon
# Contact: https://github.com/Psiphon-Inc/conduit
```

2. **Invalid Configuration**
```bash
# Validate JSON
jq empty ~/conduit/psiphon_config.json

# Check for required fields
jq 'keys' ~/conduit/psiphon_config.json
```

3. **Network Connectivity Issues**
```bash
# Test from container
docker exec conduit ping -c 4 8.8.8.8

# Test DNS
docker exec conduit nslookup google.com
```

4. **Firewall Blocking Outbound**
```bash
# Check if firewall is blocking
sudo iptables -L OUTPUT -n

# Conduit needs outbound HTTPS (443) access
sudo ufw allow out 443/tcp
```

5. **Identity Key Issues**
```bash
# Check if key exists
ls -l ~/conduit/data/conduit_key.json

# If missing, it will be generated on first run
# Ensure data directory is persistent!
```

### Low Reputation / No Client Connections

**This is normal for new nodes:**
- Psiphon broker tracks proxy reputation by key
- New proxies start with zero reputation
- Reputation builds over time (hours to days)
- Keep your identity key persistent across restarts

**Check reputation status:**
```bash
# Look for broker communication in logs
docker logs conduit | grep -i "broker\|reputation"
```

### Container is Running But Not Working

1. **Check recent logs:**
```bash
docker logs conduit --tail 50
```

2. **Run health check:**
```bash
./conduit-health.sh
```

3. **Verify configuration:**
```bash
# Check command line args
docker inspect conduit | jq '.[0].Config.Cmd'

# Should include:
# - start
# - --psiphon-config
# - -b (bandwidth)
# - -m (max clients)
# - -vv (verbose)
```

4. **Check data directory permissions:**
```bash
ls -ld ~/conduit/data
# Should be owned by your user or container user
```

### "Container is not running"
```bash
# Check container status
docker ps | grep conduit

# Start Conduit
cd ~/conduit && docker-compose up -d
```

### "curl is not installed"
```bash
# Install curl
sudo apt-get install -y curl
```

### "jq not found"
```bash
# Install jq (for JSON parsing)
sudo apt-get install -y jq
```

### No IPs Detected
**Possible causes:**
1. Container just started (no logs yet)
2. No connections to Conduit yet
3. Log format doesn't match IP extraction pattern

**Solutions:**
```bash
# Check container logs manually
docker logs conduit | head -50

# Verify Conduit is receiving connections
docker exec conduit netstat -an | grep ESTABLISHED
```

### Geolocation Shows "Unknown"
**Causes:**
- IP geolocation API rate limit (150 requests/minute)
- Network connectivity issues
- Invalid IP address

**Solutions:**
```bash
# Test API manually
curl "http://ip-api.com/json/8.8.8.8"

# Wait a minute if rate limited
# Try with slower refresh rate
./conduit-monitor.sh 10
```

### High CPU Usage
```bash
# Use longer refresh intervals
./conduit-monitor.sh 10

# Reduce log lines analyzed
nano conduit-monitor.sh
# Change LOG_LINES=1000 to LOG_LINES=500
```

---

## Advanced Usage

### Export Statistics
```bash
# Run monitor and save output
./conduit-monitor.sh > conduit-stats.log

# View cached location data
cat /tmp/conduit-monitor-stats.txt
```

### Filter Specific Countries
```bash
# View only connections from specific country
docker logs conduit | grep -E "185\.|104\." | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
```

### Monitor in Background
```bash
# Not recommended (use tmux instead)
# Better approach:
tmux new-session -s conduit-monitor
./conduit-monitor.sh
# Detach with Ctrl+B, D
# Reattach with: tmux attach -t conduit-monitor
```

### Integration with Other Tools

#### Export to CSV
```bash
# Modify script to output CSV
docker logs conduit --tail 1000 | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort | uniq -c > ips.txt
```

#### Alert on Specific IPs
```bash
# Add to script to alert on suspicious IPs
SUSPICIOUS_IPS=("1.2.3.4" "5.6.7.8")
# Check and alert...
```

---

## Performance Considerations

### API Rate Limits
- **ip-api.com**: 150 requests/minute for free tier
- **Solution**: Script caches results to minimize API calls

### Refresh Rate Guidelines
- **3-5 seconds**: Good for active monitoring
- **10-30 seconds**: Good for passive monitoring
- **1-2 seconds**: Only for short-term debugging (high API usage)

### Log Size Impact
- More log lines = more IPs found = more API calls
- Balance `LOG_LINES` with refresh rate
- Recommended: 500-1000 lines with 3-5s refresh

---

## Alternative Geolocation APIs

If you need more requests or better accuracy:

### 1. ipinfo.io
```bash
# Free: 50k requests/month
curl "https://ipinfo.io/8.8.8.8/json"
```

### 2. ipapi.co
```bash
# Free: 1k requests/day
curl "https://ipapi.co/8.8.8.8/json/"
```

### 3. GeoIP Database (Offline)
```bash
# Install MaxMind GeoLite2
sudo apt-get install -y geoip-bin geoip-database
geoiplookup 8.8.8.8
```

---

## Limitations

1. **Local IPs**: Only shows as "LOCAL" (no geolocation)
2. **VPN/Proxy**: Shows VPN server location, not actual user location
3. **API Limits**: Free tier has request limits
4. **Accuracy**: City-level accuracy varies (~90% accuracy for country)
5. **Log Parsing**: Depends on Conduit's log format

---

## Security & Privacy

### Data Handling
- IPs cached temporarily in `/tmp` (cleared on reboot)
- Location data fetched from public API
- No data sent outside of IP lookups

### Privacy Considerations
- IP addresses visible in output
- Consider legal requirements for storing IP data
- Use responsibly and comply with local regulations

### Secure Usage
```bash
# Don't expose output publicly
# Don't log sensitive connection data
# Clear cache regularly
rm -f /tmp/conduit-monitor-stats.txt
```

---

## Examples

### Quick Health Check
```bash
# Run for 30 seconds and exit
timeout 30 ./conduit-monitor.sh
```

### Find Most Active IPs
```bash
docker logs conduit | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort | uniq -c | sort -rn | head -10
```

### Check Specific IP Location
```bash
curl -s "http://ip-api.com/json/185.220.101.45" | jq '.'
```

---

## Updating the Monitor

### Get Latest Version
```bash
# If updates are released
# Download and replace
chmod +x conduit-monitor.sh
```

### Customize for Your Needs
The script is fully commented and easy to modify:
- Adjust colors
- Change display format
- Add custom metrics
- Integrate alerts

---

## FAQ

**Q: Does this work with other containers?**
A: Yes! Change `CONTAINER_NAME` variable to any container name.

**Q: Can I monitor multiple containers?**
A: Run separate monitor instances with different container names.

**Q: Does it affect Conduit performance?**
A: Minimal impact - only reads logs, doesn't interfere with Conduit.

**Q: Can I export data?**
A: Yes, redirect output or read cache file `/tmp/conduit-monitor-stats.txt`.

**Q: Why "Unknown" location?**
A: Could be API rate limit, invalid IP, or network issue.

**Q: How accurate is geolocation?**
A: ~90% accurate for country, ~70% for city, ~50% for exact location.

---

## Support

For issues:
1. Check Conduit is running: `docker ps | grep conduit`
2. Verify logs exist: `docker logs conduit`
3. Test API: `curl "http://ip-api.com/json/8.8.8.8"`
4. Check dependencies: `which curl jq`

---

## Summary

**conduit-monitor.sh** provides real-time visualization of Conduit connections:
- ✅ Source IP tracking
- ✅ Geographic location lookup
- ✅ Connection statistics
- ✅ Live updates
- ✅ Color-coded display
- ✅ Easy to use

**Start monitoring:**
```bash
./conduit-monitor.sh
```

**Happy monitoring!** 📊🌍
