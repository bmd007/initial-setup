# Conduit Monitoring with Netdata

Lightweight monitoring solution for Psiphon Conduit proxy using Netdata - a single container that provides real-time dashboards with automatic metric collection.

## Architecture

```
┌─────────────┐     ┌──────────┐
│   Conduit   │────▶│ Netdata  │
│  (port 9090)│     │(port 19999)
└─────────────┘     └──────────┘
      │                   │
      └──── Metrics ──────┘
```

## Quick Start

Run the setup script from the conduit directory:

```bash
cd raspbian/conduit
./setup-conduit.sh
```

The script will:
1. Verify the conduit directory structure
2. Pull the latest Docker images
3. Start Conduit and Netdata
4. Configure Netdata to scrape Conduit metrics

## Access URLs

- **Netdata Dashboard**: http://YOUR_IP:19999
  - No login required - instant access
  - Real-time updates (1-second resolution)
- **Conduit Metrics**: http://YOUR_IP:9090/metrics

## Dashboard Features

Netdata automatically creates beautiful charts for all Conduit metrics:

### Connection Monitoring (Primary Focus)
- **Active Connections**: Real-time gauge showing `conduit_connected_clients`
- **Connecting Clients**: Clients in connection process
- **Connection Timeline**: Historical view with automatic retention
- **Max Capacity**: Configured limit display

### Bandwidth Monitoring
- **Bytes Uploaded/Downloaded**: Total data transferred
- **Upload/Download Rates**: Real-time bandwidth usage (auto-calculated)
- **Bandwidth Limit**: Configured bandwidth cap display

### Status Indicators
- **Broker Connection**: Shows if Conduit is live (1) or offline (0)
- **Uptime**: Service uptime in seconds

### System Metrics (Automatically Collected)
- **Go Runtime**: Goroutines, threads, memory allocation
- **Process Metrics**: CPU time, memory usage, network I/O
- **Docker Container**: CPU, memory, network for both containers

## File Structure

```
conduit/
├── setup-conduit.sh                # Setup script (run from this directory)
├── docker-compose.yml              # Conduit + Netdata services
├── netdata/
│   └── go.d/
│       └── prometheus.conf         # Netdata config to scrape Conduit metrics
├── conduit-sample-metrics          # Sample metrics for reference
├── conduit-deprecated.yml          # Old compose file (for reference)
└── README.md                       # This file
```

## Management Commands

```bash
# View logs
docker logs conduit -f
docker logs netdata -f

# View all logs
docker compose logs -f

# Stop all services
cd ~/conduit && docker compose down

# Start all services
cd ~/conduit && docker compose up -d

# Restart specific service
docker restart conduit
docker restart netdata

# Check status
docker ps
```

## Netdata Advantages

Compared to Prometheus + Grafana:

**Resource Usage:**
- Netdata: ~50-100MB RAM total
- Prometheus + Grafana: ~500MB+ RAM total
- **5-10x lighter on Raspberry Pi**

**Features:**
- **Zero configuration** - dashboards auto-generated
- **Real-time** - 1-second resolution vs 5-15 seconds
- **All-in-one** - single container vs two containers
- **No login required** - instant access
- **Beautiful UI** - modern, responsive design
- **Smart charts** - automatic rate calculations, anomaly detection

## Configuration

### Conduit Settings

Edit in `docker-compose.yml`:
- `--max-clients 50`: Maximum concurrent connections
- `--bandwidth 1024`: Bandwidth limit in KB/s
- `--metrics-addr 0.0.0.0:9090`: Metrics endpoint

### Netdata Scraping

Netdata scrapes Conduit every 5 seconds. Edit `netdata/go.d/prometheus.conf` to adjust:

```yaml
jobs:
  - name: conduit
    url: http://conduit:9090/metrics
    update_every: 5  # Adjust scrape frequency (seconds)
```

### Custom Charts

The config file defines custom chart groups:
- **connections**: Active and connecting clients
- **capacity**: Max client limits
- **bandwidth**: Upload/download bytes and rates
- **status**: Broker connection and uptime
- **runtime**: Go memory and goroutines
- **process**: CPU and network I/O

## Available Metrics

Key Conduit metrics (auto-discovered by Netdata):
- `conduit_connected_clients` - **Current active connections** ⭐
- `conduit_connecting_clients` - Connections in progress
- `conduit_max_clients` - Maximum allowed clients
- `conduit_bytes_uploaded` - Total bytes uploaded
- `conduit_bytes_downloaded` - Total bytes downloaded
- `conduit_bandwidth_limit_bytes_per_second` - Bandwidth limit
- `conduit_is_live` - Broker connection status (1=live, 0=offline)
- `conduit_uptime_seconds` - Service uptime

Plus automatic Go runtime and process metrics.

## Navigating Netdata

1. Open http://YOUR_IP:19999
2. Use the **menu on the right** to navigate
3. Look for **"conduit"** section in the menu
4. Charts are organized by family (connections, bandwidth, etc.)
5. Click and drag to zoom in on any time range
6. Hover over charts for exact values

### Quick Tips:
- **Pan**: Click and drag horizontally
- **Zoom**: Click and drag vertically or use mouse wheel
- **Reset**: Double-click chart
- **Alarms**: Netdata can alert on thresholds (optional)

## Troubleshooting

### No Conduit metrics in Netdata

1. Check if Conduit metrics are accessible:
   ```bash
   curl http://localhost:9090/metrics
   ```

2. Check Netdata logs:
   ```bash
   docker logs netdata | grep conduit
   ```

3. Verify Netdata can reach Conduit:
   ```bash
   docker exec netdata curl http://conduit:9090/metrics
   ```

### Netdata not showing data

1. Check if Netdata is running:
   ```bash
   docker ps | grep netdata
   ```

2. Check Docker network:
   ```bash
   docker network inspect conduit_monitoring
   ```

3. Restart Netdata:
   ```bash
   docker restart netdata
   ```

## Advanced Configuration

### Enable Netdata Cloud (Optional)

To access dashboards remotely via Netdata Cloud:

1. Sign up at https://app.netdata.cloud
2. Get your claim token
3. Update `docker-compose.yml`:
   ```yaml
   environment:
     - NETDATA_CLAIM_TOKEN=your_token_here
     - NETDATA_CLAIM_URL=https://app.netdata.cloud
   ```
4. Restart: `docker compose up -d`

### Disable System Monitoring

If you only want Conduit metrics, create `netdata/netdata.conf`:

```conf
[plugins]
    proc = no
    diskspace = no
    cgroups = no
```

Then mount it:
```yaml
volumes:
  - ./netdata/netdata.conf:/etc/netdata/netdata.conf:ro
```

## Updating

To update all services:

```bash
cd ~/conduit
docker compose pull
docker compose up -d
```

## Data Retention

Netdata keeps:
- **1-second resolution**: Last 1 hour
- **1-minute resolution**: Last 6 hours
- **10-minute resolution**: Last 7 days
- **1-hour resolution**: Last 30 days

Total disk usage: ~50-100MB

## Security Notes

1. Netdata has **no authentication** by default
   - Safe on local network
   - Use firewall rules to restrict access to port 19999
   - Or enable Netdata authentication (see docs)

2. For production, consider:
   - Running Netdata behind nginx/traefik with auth
   - Using Netdata Cloud for secure remote access
   - Restricting Docker socket access

## Support

- Conduit: https://conduit.psiphon.ca/
- Netdata: https://learn.netdata.cloud/
- Netdata Prometheus Collector: https://learn.netdata.cloud/docs/data-collection/apm/openmetrics/prometheus
