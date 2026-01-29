# Conduit Monitoring Stack

Complete monitoring solution for Psiphon Conduit proxy with Prometheus and Grafana.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────┐
│   Conduit   │────▶│  Prometheus  │────▶│ Grafana  │
│  (port 9090)│     │  (port 9091) │     │(port 3000)│
└─────────────┘     └──────────────┘     └──────────┘
      │                                         │
      └─────── Metrics ──────────────────────────┘
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
3. Start Conduit, Prometheus, and Grafana
4. Set up monitoring with pre-configured dashboards

## Access URLs

- **Grafana Dashboard**: http://YOUR_IP:3000
  - Default credentials: `admin` / `admin` (change on first login)
- **Prometheus**: http://YOUR_IP:9091
- **Conduit Metrics**: http://YOUR_IP:9090/metrics

## Dashboard Features

The pre-configured Grafana dashboard includes:

### Connection Monitoring
- **Active Connections Gauge**: Real-time view of connected clients (main metric)
- **Connecting Clients**: Clients currently in connection process
- **Connection Timeline**: Historical view of connections over time
- **Capacity Usage**: Percentage of max capacity utilized

### Status Indicators
- **Broker Connection**: Shows if Conduit is connected to Psiphon broker
- **Uptime**: Service uptime tracking
- **Max Clients Limit**: Configured connection limit

### Bandwidth Monitoring
- **Total Upload/Download**: Cumulative data transferred
- **Upload/Download Rates**: Real-time bandwidth usage
- **Bandwidth Over Time**: Historical bandwidth graph
- **Bandwidth Limit**: Configured bandwidth cap

### System Metrics
- **Go Runtime**: Goroutines and threads
- **Memory Usage**: Heap allocation and resident memory

## File Structure

```
conduit/
├── setup-conduit.sh                # Setup script (run from this directory)
├── docker-compose.yml              # Main compose file for all services
├── prometheus/
│   └── prometheus.yml              # Prometheus configuration
├── grafana/
│   └── provisioning/
│       ├── datasources/
│       │   └── prometheus.yml      # Auto-configured Prometheus datasource
│       └── dashboards/
│           ├── dashboard.yml       # Dashboard provider config
│           └── conduit-dashboard.json  # Pre-built dashboard
├── conduit-deprecated.yml          # Old compose file (for reference)
└── README.md                       # This file
```

## Management Commands

```bash
# View logs
docker logs conduit -f
docker logs prometheus -f
docker logs grafana -f

# View all logs
docker compose -f ~/conduit/docker-compose.yml logs -f

# Stop all services
cd ~/conduit && docker compose down

# Start all services
cd ~/conduit && docker compose up -d

# Restart specific service
docker restart conduit
docker restart prometheus
docker restart grafana

# Check status
docker ps | grep -E 'conduit|prometheus|grafana'
```

## Configuration

### Conduit Settings

Edit in `docker-compose.yml`:
- `--max-clients 50`: Maximum concurrent connections
- `--bandwidth 1024`: Bandwidth limit in KB/s
- `--metrics-addr 0.0.0.0:9090`: Metrics endpoint

### Prometheus Scraping

Prometheus is configured to scrape Conduit metrics every 10 seconds. Edit `prometheus/prometheus.yml` to adjust:

```yaml
scrape_configs:
  - job_name: 'conduit'
    scrape_interval: 10s  # Adjust scrape frequency
    static_configs:
      - targets: ['conduit:9090']
```

### Grafana

- Data retention: 30 days (configurable in docker-compose.yml)
- Refresh rate: 5 seconds (adjustable in dashboard settings)
- Default admin password should be changed on first login

## Available Metrics

Key Conduit metrics:
- `conduit_connected_clients` - Current active connections
- `conduit_connecting_clients` - Connections in progress
- `conduit_max_clients` - Maximum allowed clients
- `conduit_bytes_uploaded` - Total bytes uploaded
- `conduit_bytes_downloaded` - Total bytes downloaded
- `conduit_bandwidth_limit_bytes_per_second` - Bandwidth limit
- `conduit_is_live` - Broker connection status (1=live, 0=offline)
- `conduit_uptime_seconds` - Service uptime

Plus standard Go and process metrics.

## Troubleshooting

### No data in Grafana

1. Check Prometheus is scraping successfully:
   - Visit http://YOUR_IP:9091/targets
   - Conduit target should show "UP" status

2. Verify Conduit metrics endpoint:
   - Visit http://YOUR_IP:9090/metrics
   - Should see Prometheus-formatted metrics

3. Check Docker network:
   ```bash
   docker network inspect conduit_monitoring
   ```

### Containers not starting

Check logs:
```bash
docker logs conduit
docker logs prometheus
docker logs grafana
```

### Permission issues

Grafana may need proper permissions:
```bash
sudo chown -R 472:472 ~/conduit/grafana
```

## Security Notes

1. **Change default Grafana password** immediately after first login
2. Consider using **firewall rules** to restrict access to ports 3000, 9090, 9091
3. For production, enable **HTTPS** using a reverse proxy (nginx/traefik)
4. Grafana default credentials are stored in docker-compose.yml - consider using Docker secrets

## Updating

To update all services:

```bash
cd ~/conduit
docker compose pull
docker compose up -d
```

## Backup

Important data to backup:
- Grafana data: Docker volume `conduit_grafana-data`
- Prometheus data: Docker volume `conduit_prometheus-data`
- Conduit data: Docker volume `conduit_conduit-data`

Backup command:
```bash
docker run --rm -v conduit_grafana-data:/data -v $(pwd):/backup ubuntu tar czf /backup/grafana-backup.tar.gz /data
```

## Support

- Conduit: https://conduit.psiphon.ca/
- Prometheus: https://prometheus.io/docs/
- Grafana: https://grafana.com/docs/
