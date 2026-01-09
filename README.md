# Signet Infrastructure

Shared infrastructure for the Signet ecosystem, providing a unified nginx reverse proxy and Docker network for all services.

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │           signetapp.xyz                 │
                    │                                         │
                    │  ┌───────────────────────────────────┐  │
Internet ──────────▶│  │           nginx:alpine            │  │
  :80/:443          │  │         (signet-nginx)            │  │
                    │  └─────────────┬─────────────────────┘  │
                    │                │                        │
                    │    ┌───────────┼───────────┐            │
                    │    │           │           │            │
                    │    ▼           ▼           ▼            │
                    │ ┌─────┐   ┌─────────┐  ┌─────────┐      │
                    │ │ /   │   │/market- │  │  /storage  │      │
                    │ │     │   │  place  │  │         │      │
                    │ │signet│   │market- │  │trustvault│     │
                    │ │:3000│   │place    │  │-api     │      │
                    │ │     │   │:3001    │  │:3002    │      │
                    │ └─────┘   └─────────┘  └─────────┘      │
                    │                                         │
                    │         signet-network (bridge)         │
                    └─────────────────────────────────────────┘
```

## Routing

| Path | Service | Internal Port |
|------|---------|---------------|
| `/` | signet-app | 3000          |
| `/marketplace` | marketplace-app | 3001          |
| `/storage` | trustvault | 3002          |

## Prerequisites

- Docker and Docker Compose v2+
- SSL certificates in `nginx/ssl/`
- All application images built and available

## Deployment

### 1. Clone and configure

```bash
cd /opt
git clone https://github.com/kevinhartig/signet-infra.git
cd signet-infra
cp .env.example .env
```

### 2. Set up SSL certificates

Place your SSL certificates in `nginx/ssl/`:
- `fullchain.pem` - Full certificate chain
- `privkey.pem` - Private key

For Let's Encrypt:
```bash
certbot certonly --webroot -w /var/www/certbot \
  -d signetapp.xyz -d www.signetapp.xyz
```

### 3. Start infrastructure

```bash
# Create log directories
sudo mkdir -p /app/logs/nginx /var/www/certbot
sudo chown -R $USER:$USER /app/logs/nginx

# Start nginx (creates signet-network)
docker compose up -d
```

### 4. Deploy applications

Each application joins the shared network:

```bash
# Signet
cd /opt/signet && docker compose up -d

# Marketplace
cd /opt/marketplace && docker compose up -d

# TrustVault API
cd /opt/trustvault && docker compose up -d
```

## Application Configuration

Each application's `docker-compose.yml` must:

1. **Not expose ports externally** (nginx handles that)
2. **Use the external network**

Example:
```yaml
services:
  my-app:
    # ... config ...
    expose:
      - "3000"  # Internal only
    networks:
      - signet-network

networks:
  signet-network:
    external: true
```

## Management

### Reload nginx configuration

```bash
docker compose exec nginx nginx -s reload
```

### View logs

```bash
# Nginx logs
docker compose logs -f nginx

# Or from host
tail -f /app/logs/nginx/access.log
tail -f /app/logs/nginx/error.log
```

### Health check

```bash
curl http://localhost/health
```

### Update nginx config

```bash
# Edit nginx/nginx.conf
# Test configuration
docker compose exec nginx nginx -t
# Reload
docker compose exec nginx nginx -s reload
```

## SSL Certificate Renewal

For Let's Encrypt auto-renewal, add a cron job:

```bash
0 0 * * * certbot renew --quiet && docker exec signet-nginx nginx -s reload
```

## Troubleshooting

### Network issues

```bash
# Check if network exists
docker network ls | grep signet

# Inspect network
docker network inspect signet-network

# Check which containers are connected
docker network inspect signet-network --format '{{range .Containers}}{{.Name}} {{end}}'
```

### Container connectivity

```bash
# From nginx, test upstream connectivity
docker exec signet-nginx wget -qO- http://signet-app:3000/ || echo "signet-app unreachable"
docker exec signet-nginx wget -qO- http://marketplace-app:3002/marketplace || echo "marketplace unreachable"
docker exec signet-nginx wget -qO- http://trustvault-api:3001/api/health || echo "trustvault unreachable"
```

### Nginx configuration test

```bash
docker compose exec nginx nginx -t
```

