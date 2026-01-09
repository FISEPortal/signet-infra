#!/bin/bash

# =============================================================================
# Deploy Signet Infrastructure (Idempotent)
# =============================================================================
# Sets up the nginx reverse proxy and shared Docker network.
# Can be run multiple times safely.
#
# Usage: sudo ./deploy-infra.sh
# =============================================================================

set -e

INFRA_DIR="/opt/signet-infra"
DOMAIN="${DOMAIN:-signetapp.xyz}"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           SIGNET INFRASTRUCTURE DEPLOYMENT                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Domain: $DOMAIN"
echo "Install path: $INFRA_DIR"
echo ""

# -------------------------------------------------------------------------
# Check prerequisites
# -------------------------------------------------------------------------
echo "Checking prerequisites..."

if ! command -v docker &>/dev/null; then
    echo "❌ Docker not installed"
    exit 1
fi
echo "  ✓ Docker installed"

if ! docker compose version &>/dev/null; then
    echo "❌ Docker Compose v2 not installed"
    exit 1
fi
echo "  ✓ Docker Compose v2 installed"

# -------------------------------------------------------------------------
# Create required directories
# -------------------------------------------------------------------------
echo ""
echo "Creating directories..."

mkdir -p /app/logs/nginx
mkdir -p /var/www/certbot
echo "  ✓ /app/logs/nginx"
echo "  ✓ /var/www/certbot"

# -------------------------------------------------------------------------
# Clone or update repository
# -------------------------------------------------------------------------
echo ""
echo "Setting up repository..."

if [[ -d "$INFRA_DIR/.git" ]]; then
    echo "  Repository exists, pulling latest..."
    cd "$INFRA_DIR"
    git pull
    echo "  ✓ Updated to latest"
else
    echo "  Cloning repository..."
    git clone https://github.com/kevinhartig/signet-infra.git "$INFRA_DIR"
    echo "  ✓ Cloned to $INFRA_DIR"
fi

cd "$INFRA_DIR"

# -------------------------------------------------------------------------
# Check SSL certificates
# -------------------------------------------------------------------------
echo ""
echo "Checking SSL certificates..."

CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
if [[ -f "$CERT_PATH/fullchain.pem" ]] && [[ -f "$CERT_PATH/privkey.pem" ]]; then
    echo "  ✓ SSL certificates found"
else
    echo "  ⚠ SSL certificates not found at $CERT_PATH"
    echo ""
    echo "  To obtain certificates, run:"
    echo "    sudo certbot certonly --standalone -d $DOMAIN -d www.$DOMAIN"
    echo ""
    echo "  Or for testing, create self-signed certs:"
    echo "    sudo mkdir -p $CERT_PATH"
    echo "    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\"
    echo "      -keyout $CERT_PATH/privkey.pem \\"
    echo "      -out $CERT_PATH/fullchain.pem \\"
    echo "      -subj \"/CN=$DOMAIN\""
    echo ""
    read -p "Continue without SSL? (containers will fail) [y/N]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# -------------------------------------------------------------------------
# Create Docker network if not exists
# -------------------------------------------------------------------------
echo ""
echo "Setting up Docker network..."

if docker network ls | grep -q signet-network; then
    echo "  ✓ signet-network already exists"
else
    docker network create signet-network
    echo "  ✓ Created signet-network"
fi

# -------------------------------------------------------------------------
# Start nginx container
# -------------------------------------------------------------------------
echo ""
echo "Starting nginx container..."

docker compose up -d

# Wait for container to be healthy
echo "  Waiting for nginx to be healthy..."
for i in {1..30}; do
    if docker ps --filter "name=signet-nginx" --filter "health=healthy" | grep -q signet-nginx; then
        echo "  ✓ Nginx is healthy"
        break
    fi
    if [[ $i -eq 30 ]]; then
        echo "  ⚠ Nginx not healthy after 30s, check logs:"
        echo "    docker logs signet-nginx --tail 20"
    fi
    sleep 1
done

# -------------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Signet infrastructure deployed!"
echo ""
echo "Status:"
docker ps --filter "name=signet-nginx" --format "  {{.Names}}: {{.Status}}"
echo ""
echo "Network:"
echo "  $(docker network inspect signet-network --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo 'No containers connected')"
echo ""
echo "Next: Deploy the application services"
echo ""


