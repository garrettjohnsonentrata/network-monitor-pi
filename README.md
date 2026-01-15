# Pi Network Tester

**Gaming-focused network monitoring stack for Raspberry Pi 3 Model B (ARM64)**

Monitor your ISP connection quality with metrics that matter for gaming: **Jitter**, **Latency**, **Packet Loss**, and **Bandwidth**.

## Quick Start

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd pi-network-tester

# 1.5 Configure Discord alerts (optional but recommended)
cp .env.example .env
# Edit .env and set DISCORD_WEBHOOK_URL

# 2. Run setup (installs Docker if needed)
chmod +x setup.sh
./setup.sh

# 3. Log out and back in (if added to docker group)
exit

# 4. Start the stack
docker compose up -d
```

## Access

| Service    | URL                     | Credentials   |
|------------|-------------------------|---------------|
| Grafana    | `http://<pi-ip>:3000`   | admin / admin |
| Prometheus | `http://<pi-ip>:9090`   | -             |

## What's Monitored

### Targets (ICMP Ping)
- **ISP Gateway** - Auto-discovered every 60 seconds
- **1.1.1.1** - Cloudflare DNS
- **8.8.8.8** - Google DNS  
- **dynamodb.us-east-1.amazonaws.com** - AWS connectivity

### Metrics
- **Latency (RTT)** - Round-trip time in milliseconds
- **Jitter** - Standard deviation of latency (5-minute window)
- **Packet Loss** - Percentage of failed probes
- **Bandwidth** - Download/Upload speed (tested hourly)

### Pi Health
- CPU usage and temperature
- Memory utilization

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Docker Compose Stack                         │
├─────────────────────────────────────────────────────────────────┤
│  Prometheus (:9090)     Grafana (:3000)    Gateway Finder       │
│       │                      │                   │              │
│       │ scrapes              │ queries           │ writes       │
│       ▼                      ▼                   ▼              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │  Blackbox   │  │  Speedtest  │  │  targets.json           │ │
│  │  Exporter   │  │  Exporter   │  │  (auto-updated)         │ │
│  │  (:9115)    │  │  (:9798)    │  └─────────────────────────┘ │
│  └─────────────┘  └─────────────┘                               │
│       │                │                                        │
│       ▼                ▼                                        │
│  ICMP Ping        Bandwidth Test                                │
│  (15s interval)   (1h interval)                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Memory Usage

Optimized for Raspberry Pi 3's 1GB RAM:

| Container       | Limit  | Reserved |
|-----------------|--------|----------|
| Prometheus      | 300MB  | 150MB    |
| Grafana         | 200MB  | 100MB    |
| Speedtest       | 100MB  | 50MB     |
| Blackbox        | 50MB   | 25MB     |
| Node Exporter   | 50MB   | 25MB     |
| Gateway Finder  | 32MB   | 16MB     |
| **Total**       | **732MB** | **366MB** |

## File Structure

```
pi-network-tester/
├── docker-compose.yml          # Main stack definition
├── setup.sh                    # Installation script
├── README.md
├── prometheus/
│   ├── prometheus.yml          # Prometheus config
│   ├── blackbox.yml            # Blackbox exporter config
│   └── targets/                # Auto-generated targets
│       └── targets.json        # Created by gateway finder
├── scripts/
│   └── gateway_finder.sh       # Auto-discovery script
└── grafana/
    ├── provisioning/
    │   ├── datasources/
    │   │   └── datasource.yml  # Prometheus datasource
    │   └── dashboards/
    │       └── dashboard.yml   # Dashboard provisioning
    └── dashboards/
        └── gaming-network-health.json
```

## Configuration

### Prometheus Retention

Data is kept for 15 days with a 512MB size cap:

```yaml
# In docker-compose.yml
--storage.tsdb.retention.time=15d
--storage.tsdb.retention.size=512MB
```

### Scrape Intervals

| Target          | Interval |
|-----------------|----------|
| ICMP Ping       | 15s      |
| Node Exporter   | 15s      |
| Speedtest       | 1h       |

### Gateway Discovery

The `gateway_finder.sh` script runs every minute and:
1. Detects the default gateway using `ip route`
2. Updates `prometheus/targets/targets.json`
3. Prometheus auto-reloads the file (no restart needed)

## Commands

```bash
# Start stack
docker compose up -d

# View logs
docker compose logs -f

# View specific service logs
docker compose logs -f prometheus

# Check container stats
docker stats

# Stop stack
docker compose down

# Stop and remove volumes (delete all data)
docker compose down -v

# Restart a specific service
docker compose restart grafana

# Force reload Prometheus config
docker compose exec prometheus kill -HUP 1
```

## Troubleshooting

### Gateway not detected

Check if the gateway finder is running:
```bash
docker compose logs gateway-finder
```

Verify the targets file:
```bash
cat prometheus/targets/targets.json
```

### High memory usage

Check container memory:
```bash
docker stats --no-stream
```

### ICMP probes failing

Verify blackbox exporter has NET_RAW capability:
```bash
docker compose logs blackbox
```

### Speedtest not running

Speedtest only runs once per hour. Check last result:
```bash
curl http://localhost:9798/metrics | grep speedtest
```

## Dashboard Panels

The "Gaming Network Health" dashboard includes:

1. **Overview Row**
   - Gateway Latency (gauge)
   - Gateway Jitter (gauge)
   - Packet Loss % (gauge)
   - Download/Upload Speed (stat)
   - Pi CPU Usage (stat)

2. **Latency Analysis Row**
   - Latency by Target (time series)
   - Jitter by Target (time series)
   - Packet Loss by Target (time series)
   - Latency Heatmap

3. **Bandwidth Row**
   - Bandwidth Over Time (time series)
   - Speedtest Server Latency (stat)

4. **Raspberry Pi Health Row**
   - CPU Usage (time series)
   - Memory Usage (time series)
   - CPU Temperature (gauge)

5. **Probe Status Row**
   - Current Probe Status (table)

## License

MIT
