# Conduit Monitor Scripts - Comparison Guide

## Overview

You now have **three** monitoring scripts for your Conduit node:

1. **check-conduit.sh** - Simple health check (one-time)
2. **conduit-monitor.sh** - Original advanced monitor (IP geolocation)
3. **conduit-monitor-adapted.sh** - Adapted for real Conduit behavior ⭐ **RECOMMENDED**

---

## Script Comparison

### 1. check-conduit.sh (Simple Health Check)

**Purpose:** Quick one-time status check

**Best For:**
- Quick verification that Conduit is running
- Troubleshooting startup issues
- Periodic manual checks

**Features:**
- ✓ Container status
- ✓ Process check
- ✓ Log pattern analysis
- ✓ Interprets "limited" and "no match" correctly
- ✓ Resource usage
- ✓ Simple, fast, efficient

**Usage:**
```bash
./check-conduit.sh
```

**When to Use:**
- After first installation
- When troubleshooting
- Before/after restarts
- Quick daily checks

---

### 2. conduit-monitor.sh (Original)

**Purpose:** Real-time IP geolocation monitoring

**Problem:** ❌ **Not designed for Conduit's architecture**

**Why It Doesn't Work Well:**
- ❌ Tries to geolocate IPs (only sees broker IP, not clients)
- ❌ Expects traditional TCP connections (Conduit uses WebRTC)
- ❌ Looks for generic log patterns (doesn't match Conduit logs)
- ❌ Makes many API calls to ip-api.com (rate limited, unnecessary)
- ❌ Shows misleading geographic data

**What It Actually Shows:**
- The Psiphon broker's IP address (repeatedly)
- Generic log patterns that may not exist
- False sense of "connections" that aren't real client connections

**Recommendation:** ⚠️ **Don't use this for Conduit**

This script was designed for traditional proxy servers that log client IPs directly. Conduit's privacy-preserving architecture intentionally doesn't expose this information.

---

### 3. conduit-monitor-adapted.sh (RECOMMENDED) ⭐

**Purpose:** Real-time monitoring designed for Conduit's actual behavior

**Best For:**
- Continuous monitoring
- Understanding your node's status
- Watching reputation build
- Seeing actual Conduit activity

**Features:**
- ✓ **Node Status Dashboard** - Shows if you're ACTIVE, READY, ANNOUNCING, etc.
- ✓ **Broker Communication Tracking** - Monitors announcements, responses
- ✓ **Reputation Estimation** - Calculated from actual activity
- ✓ **Connection Activity** - Tracks real client matches and relay sessions
- ✓ **WebRTC Monitoring** - Shows offers, answers, ICE candidates
- ✓ **Smart Log Interpretation** - Correctly interprets "limited" as GOOD
- ✓ **Trend Analysis** - Tracks improvement over time
- ✓ **Data Transfer Stats** - Shows bytes sent/received
- ✓ **Error Tracking** - Monitors warnings and errors

**What Makes It Special:**

1. **Understands Conduit's Architecture**
   - Knows you connect to broker, not clients directly
   - Recognizes WebRTC signaling patterns
   - Interprets rate limiting as positive (you're being heard!)

2. **Correct Status Interpretation**
   - "limited" = ✓ GOOD (broker is responding)
   - "no match" = ✓ GOOD (broker communication working)
   - Shows when you're actually helping users

3. **Reputation System**
   - Estimates your node's reputation (0-100%)
   - Based on announcements, matches, relay activity
   - Helps you understand why you're not getting connections yet

4. **Real Connection Tracking**
   - Detects actual client matches
   - Monitors relay sessions
   - Shows WebRTC connection establishment

**Usage:**
```bash
# Default: 5 second refresh
./conduit-monitor-adapted.sh

# Custom refresh interval (e.g., 10 seconds)
./conduit-monitor-adapted.sh 10
```

**Sample Output:**

```
╔════════════════════════════════════════════════════════════════════════════╗
║                  Conduit Real-Time Monitor                                 ║
║              Tracking Broker Communication & Activity                      ║
╚════════════════════════════════════════════════════════════════════════════╝

Container: conduit
Refresh: Every 5s | Press Ctrl+C to exit
Time: 2026-01-27 14:32:15
Uptime: Started at 2026-01-27T12:00:00

═══ Node Status ═══
Status: ● READY
Your node is communicating with broker, waiting for clients

Estimated Reputation:
████████████░░░░░░░░ 60% (Building)

═══ Broker Communication ═══
● Announcements sent:     42
● Broker contacts:        38
● Rate limited responses: 15 ✓ (Good!)
● No match responses:     23 ✓ (Good!)

✓ BROKER COMMUNICATION WORKING
  Your node is registered and responding to broker queries

═══ Connection Activity ═══
● Client matches:         0
● Active relays:          0
● Clients connected:      0
● Clients disconnected:   0

WebRTC Signaling:
● Offers sent/received:   5
● Answers sent/received:  3
● ICE candidates:         12

═══ Health Summary ═══
● Errors:   3 (Some errors normal)
● Warnings: 12

═══ Trend Analysis ═══
● Waiting for first connections...
  Keep your node running to build reputation

═══ Recent Events (Last 15 Lines) ═══
[INFO] 2026-01-27 14:32:10 Announcing to broker...
[GOOD] 2026-01-27 14:32:12 Response: limited ✓
[INFO] 2026-01-27 14:32:15 Waiting for match...
...

═══ Tips ═══
● 'limited' and 'no match' messages are GOOD - they mean broker communication works
● It can take hours or days before your first client connection
● Keep your node running 24/7 to build reputation
● High uptime = better reputation = more connections
```

---

## Quick Comparison Table

| Feature | check-conduit.sh | conduit-monitor.sh | conduit-monitor-adapted.sh |
|---------|------------------|--------------------|-----------------------------|
| One-time check | ✓ | ✗ | ✗ |
| Real-time monitoring | ✗ | ✓ | ✓ |
| Conduit-specific | ✓ | ✗ | ✓ |
| IP geolocation | ✗ | ✓ (misleading) | ✗ |
| Broker tracking | ✓ | ✗ | ✓ |
| Reputation tracking | ✗ | ✗ | ✓ |
| WebRTC monitoring | ✗ | ✗ | ✓ |
| Trend analysis | ✗ | ✗ | ✓ |
| Correct interpretation | ✓ | ✗ | ✓ |
| Resource usage | Low | Medium-High | Low-Medium |
| Raspberry Pi friendly | ✓ | Questionable | ✓ |

---

## Recommendations

### Quick Decision Guide 🎯

**Which script should I use?**

```
Are you just checking if Conduit is working?
    YES → Use check-conduit.sh (quick, one-time)
    NO ↓

Do you want to watch activity in real-time?
    YES → Use conduit-monitor-adapted.sh (continuous)
    NO → Use check-conduit.sh periodically
```

### For Daily Use:
**Use `conduit-monitor-adapted.sh`** ⭐
- Run it in a screen/tmux session
- Check it periodically to see your progress
- Watch your reputation build over time

### For Quick Checks:
**Use `check-conduit.sh`**
- Fast one-time verification
- Good for scripts/cron jobs
- Perfect for troubleshooting

### Don't Use:
**conduit-monitor.sh (original)**
- Not designed for Conduit
- Shows misleading information
- Wastes resources on API calls

---

## Installation & Usage

### Make scripts executable:
```bash
chmod +x check-conduit.sh
chmod +x conduit-monitor-adapted.sh
```

### Run the adapted monitor in background:
```bash
# Install screen if not already installed
sudo apt-get install screen

# Start a screen session
screen -S conduit-monitor

# Run the monitor
./conduit-monitor-adapted.sh

# Detach: Press Ctrl+A, then D
# Reattach: screen -r conduit-monitor
```

### Or use tmux:
```bash
# Install tmux if not already installed
sudo apt-get install tmux

# Start tmux session
tmux new -s conduit-monitor

# Run the monitor
./conduit-monitor-adapted.sh

# Detach: Press Ctrl+B, then D
# Reattach: tmux attach -t conduit-monitor
```

### Advanced: Run as systemd service (optional):
```bash
# Create service file
sudo tee /etc/systemd/system/conduit-monitor.service > /dev/null <<EOF
[Unit]
Description=Conduit Monitor Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/raspbian
ExecStart=$HOME/raspbian/conduit-monitor-adapted.sh 10
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable conduit-monitor
sudo systemctl start conduit-monitor

# View output
sudo journalctl -u conduit-monitor -f
```

---

## Understanding the Output

### Node Status Levels:

1. **ACTIVE** (Green)
   - ✓ Actively relaying traffic
   - ✓ Helping users right now
   - ✓ Best possible state

2. **MATCHED** (Cyan)
   - ✓ Matched with clients
   - ✓ Establishing connections
   - ✓ About to relay traffic

3. **READY** (Yellow)
   - ✓ Broker communication working
   - ✓ Waiting for client matches
   - ✓ Normal for new/idle nodes

4. **ANNOUNCING** (Blue)
   - Registering with network
   - Normal during startup
   - Should progress to READY

5. **ERROR** (Red)
   - Something's wrong
   - Check the logs
   - May need restart

### What "Good" Looks Like:

**When Starting:**
```
Status: ANNOUNCING → READY
Announcements: increasing
Limited responses: 0 → increasing ✓
Reputation: 10% → 40%
```

**After Hours/Days:**
```
Status: READY → MATCHED → ACTIVE
Client matches: 0 → 1+
Relay activity: 0 → 1+
Reputation: 40% → 70%+
```

### What's Normal:

- ✓ Lots of "limited" and "no match" responses (GOOD!)
- ✓ Zero client connections for hours or days (patience!)
- ✓ Some errors in logs (network issues happen)
- ✓ Reputation building slowly (trust takes time)

### What's Concerning:

- ✗ No announcements after 10+ minutes
- ✗ Many FATAL errors
- ✗ Container restarting frequently
- ✗ Zero broker communication

---

## Summary

**Use `conduit-monitor-adapted.sh` for monitoring** - it's specifically designed for Conduit's architecture and will give you accurate, helpful information about your node's status and activity.

The original `conduit-monitor.sh` was a well-crafted script, but it's designed for traditional proxy servers, not Conduit's privacy-preserving WebRTC architecture.
