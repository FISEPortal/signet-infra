#!/bin/bash

# =============================================================================
# Deploy All Signet Services (Idempotent)
# =============================================================================
# Deploys the complete Signet ecosystem:
#   - signet-infra (nginx reverse proxy)
#   - signet (main application)
#   - marketplace-app
#   - trustvault-api
#
# Usage: sudo ./deploy-all.sh
# =============================================================================

set -e

GITHUB_ORG="${GITHUB_ORG:-kevinhartig}"
BASE_DIR="/opt"
DOMAIN="${DOMAIN:-signetapp.xyz}"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           SIGNET FULL STACK DEPLOYMENT                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "GitHub org: $GITHUB_ORG"
echo "Base path: $BASE_DIR"
echo "Domain: $DOMAIN"
echo ""

# -------------------------------------------------------------------------
# Helper function to deploy a service
# -------------------------------------------------------------------------
deploy_service() {
    local name="$1"
    local repo="$2"
    local dir="$BASE_DIR/$name"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Deploying: $name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ -d "$dir/.git" ]]; then
        echo "  Repository exists, pulling latest..."
        cd "$dir"
        git pull
    else
        echo "  Cloning repository..."
        git clone "https://github.com/$GITHUB_ORG/$repo.git" "$dir"
    fi
    
    cd "$dir"
    
    # Copy .env.example if .env doesn't exist
    if [[ -f ".env.example" ]] && [[ ! -f ".env" ]]; then
        cp .env.example .env
        echo "  ✓ Created .env from .env.example"
        echo "  ⚠ Review and update .env with production values!"
    fi
    
    # Start the service
    if [[ -f "docker-compose.yml" ]] || [[ -f "compose.yml" ]]; then
        echo "  Starting containers..."
        docker compose up -d --build
        echo "  ✓ Containers started"
    else
        echo "  ⚠ No docker-compose.yml found"
    fi
}

# -------------------------------------------------------------------------
# Check prerequisites
# -------------------------------------------------------------------------
echo "Checking prerequisites..."

if ! command -v docker &>/dev/null; then
    echo "❌ Docker not installed"
    exit 1
fi
echo "  ✓ Docker"

if ! command -v git &>/dev/null; then
    echo "❌ Git not installed"
    exit 1
fi
echo "  ✓ Git"

# -------------------------------------------------------------------------
# Create base directory
# -------------------------------------------------------------------------
mkdir -p "$BASE_DIR"
mkdir -p /app/logs/nginx
mkdir -p /var/www/certbot

# -------------------------------------------------------------------------
# Check SSL certificates first
# -------------------------------------------------------------------------
echo ""
echo "Checking SSL certificates..."
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"

if [[ ! -f "$CERT_PATH/fullchain.pem" ]]; then
    echo ""
    echo "⚠ SSL certificates not found!"
    echo ""
    echo "Options:"
    echo "  1. Get Let's Encrypt certs (production):"
    echo "     sudo certbot certonly --standalone -d $DOMAIN -d www.$DOMAIN"
    echo ""
    echo "  2. Create self-signed certs (testing):"
    echo "     sudo mkdir -p $CERT_PATH"
    echo "     sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\"
    echo "       -keyout $CERT_PATH/privkey.pem \\"
    echo "       -out $CERT_PATH/fullchain.pem \\"
    echo "       -subj \"/CN=$DOMAIN\""
    echo ""
    read -p "Continue without valid SSL? [y/N]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "  ✓ SSL certificates found"
fi

# -------------------------------------------------------------------------
# Deploy infrastructure first (creates network)
# -------------------------------------------------------------------------
deploy_service "signet-infra" "signet-infra"

# -------------------------------------------------------------------------
# Deploy application services
# -------------------------------------------------------------------------
deploy_service "signet" "signet"
deploy_service "marketplace-app" "marketplace-app"
deploy_service "trustvault-api" "trustvault-api"

# -------------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Full stack deployment complete!"
echo ""
echo "Running containers:"
docker ps --format "  {{.Names}}: {{.Status}}" | grep -E "(signet|marketplace|trustvault|nginx)" || echo "  No matching containers"
echo ""
echo "Network connections:"
docker network inspect signet-network --format '{{range .Containers}}  - {{.Name}}{{println}}{{end}}' 2>/dev/null || echo "  Network not found"
echo ""
echo "Health check:"
echo "  curl https://$DOMAIN/health"
echo ""
echo "Logs:"
echo "  docker logs signet-nginx --tail 20"
echo "  docker logs signet-app --tail 20"
echo ""


