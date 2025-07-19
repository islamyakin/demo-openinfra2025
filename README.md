# Demo OID25: OpenTelemetry + ClickHouse + Grafana + Nginx Log Monitoring

This Docker Compose setup provides a complete observability stack that collects nginx access logs using OpenTelemetry, stores them in ClickHouse, and visualizes them with Grafana.

## Architecture

```
Nginx (Web Server) 
    ↓ (access.log file)
OpenTelemetry Collector (File Log Receiver)
    ↓ (parsed log data with log levels)
ClickHouse (Storage)
    ↓ (visualization)
Grafana (Dashboard)
```

## Quick Start

1. **Start the stack:**
   ```bash
   docker-compose -f compose-otel-clickhouse.yaml up -d
   ```

2. **Verify services are running:**
   ```bash
   docker-compose -f compose-otel-clickhouse.yaml ps
   ```

3. **Access the services:**
   - **Nginx Web Server**: http://localhost
   - **Grafana Dashboard**: http://localhost:3000 (admin/admin123)
   - **ClickHouse**: http://localhost:8123
   - **OpenTelemetry Health**: http://localhost:13133

## Components

### OpenTelemetry Collector
- **Ports**: 4317 (gRPC), 13133 (health)
- **Function**: Reads nginx access logs, parses them, assigns log levels, and forwards to ClickHouse
- **Config**: `otel/otel-collector.yaml`
- **Log Levels**: Automatically assigns INFO/WARN/ERROR based on HTTP status codes

### ClickHouse Database
- **Ports**: 8123 (HTTP), 9000 (Native)
- **Credentials**: user=`otel`, password=`otel123`, database=`otel`
- **Tables**: `otel_logs`, `otel_traces`
- **Views**: `logs_query_builder`, `nginx_access_logs`

### Nginx Web Server
- **Port**: 80
- **Log Format**: Standard nginx access log format
- **Log Location**: `/var/log/nginx/access.log` (shared volume)

### Grafana
- **Port**: 3000
- **Credentials**: admin/admin123
- **Function**: Log visualization and analytics dashboard
- **Features**: Pre-configured ClickHouse datasource and nginx dashboard

## Monitoring & Querying

### Grafana Dashboard
Access the pre-built dashboard at http://localhost:3000:

- **Requests per Minute**: Time series of traffic volume
- **Recent Access Logs**: Table with message, log level, service, and labels
- **Top URLs and Client IPs**: Most active endpoints and clients

### ClickHouse Query Builder Queries

The setup supports query builder with these key fields:

```sql
-- Filter by message content
SELECT * FROM otel.logs_query_builder 
WHERE Message LIKE '%users%' 
ORDER BY Timestamp DESC
LIMIT 10;

-- Filter by log level
SELECT * FROM otel.logs_query_builder 
WHERE LogLevel = 'ERROR' 
ORDER BY Timestamp DESC
LIMIT 10;

-- Filter by service labels
SELECT * FROM otel.logs_query_builder 
WHERE Service = 'inventory'
AND Component = 'ingress'
AND Environment = 'production'
LIMIT 12;

-- Analytic Query
SELECT 
  toStartOfHour(Timestamp) as hour,
  LogAttributes['status'] as status,
  COUNT(*) as requests,
  uniq(LogAttributes['remote_addr']) as unique_users,
  avg(toFloat64OrZero(LogAttributes['body_bytes_sent'])) as avg_response_size
FROM otel_logs 
WHERE Timestamp > now() - INTERVAL 24 HOUR
GROUP BY hour, status
ORDER BY hour DESC;
```


### OpenTelemetry Health Check

Health check:
```bash
curl http://localhost:13133
```

## Testing Log Generation

The setup includes a log generator that automatically makes requests to nginx. You can also manually generate logs by:

1. **Visit the web interface**: http://localhost
2. **Make API calls**:
   ```bash
   curl http://localhost/api/health
   curl http://localhost/api/users
   curl http://localhost/api/metrics
   ```

## Folder Structure

```
.
├── compose-otel-clickhouse.yaml    # Main Docker Compose file
├── otel/
│   └── otel-collector.yaml         # OpenTelemetry Collector config
├── clickhouse/
│   └── init.sql                    # ClickHouse database initialization
├── nginx/
│   ├── nginx.conf                  # Nginx configuration
│   └── html/
│       └── index.html              # Web interface
├── grafana/
│   └── provisioning/
│       ├── datasources/
│       │   └── clickhouse.yaml     # ClickHouse datasource config
│       └── dashboards/
│           ├── dashboard.yaml      # Dashboard provider config
│           └── nginx-logs.json     # Pre-built nginx dashboard
└── logs/                           # Shared log directory
```

##  Config Details

### Log Processing
The OpenTelemetry Collector is configured to:
- Monitor `/var/log/nginx/access.log`
- Parse nginx log format using regex
- Extract fields: IP, method, URL, status, user agent, etc.
- Assign log levels based on HTTP status codes:
  - **ERROR**: 4xx and 5xx status codes
  - **WARN**: 3xx status codes  
  - **INFO**: 1xx and 2xx status codes
- Add service labels: inventory, ingress, production

### ClickHouse Schema
- **Retention**: 30 days TTL
- **Partitioning**: By date
- **Ordering**: Optimized by ServiceName, LogLevel, Timestamp
- **Views**: Query builder friendly and backward compatible views

## Tshoot

### Check service logs:
```bash
docker-compose -f compose-otel-clickhouse.yaml logs otel-collector
docker-compose -f compose-otel-clickhouse.yaml logs clickhouse
docker-compose -f compose-otel-clickhouse.yaml logs nginx
docker-compose -f compose-otel-clickhouse.yaml logs grafana
```

### Verify log file creation:
```bash
docker exec nginx ls -la /var/log/nginx/
docker exec otel-collector ls -la /var/log/nginx/
```

### Test ClickHouse connection:
```bash
docker exec -it clickhouse clickhouse-client --user=otel --password=otel123
```

## Stopping the Demo

```bash
docker-compose -f compose-otel-clickhouse.yaml down -v
```

## Reference

- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)
- [ClickHouse Documentation](https://clickhouse.com/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
