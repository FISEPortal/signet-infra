#!/bin/bash

# =============================================================================
# SSL Certificate Setup Script
# =============================================================================
# Obtains SSL certificates from Let's Encrypt or creates self-signed certs.
#
# Usage: 
#   sudo ./setup-ssl.sh                    # Interactive
#   sudo ./setup-ssl.sh --self-signed      # Create self-signed (testing)
#   sudo ./setup-ssl.sh --letsencrypt      # Get Let's Encrypt certs
# =============================================================================

set -e

DOMAIN="${DOMAIN:-signetapp.xyz}"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           SSL CERTIFICATE SETUP                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Domain: $DOMAIN"
echo "Cert path: $CERT_PATH"
echo ""

# Parse arguments
MODE=""
if [[ "$1" == "--self-signed" ]]; then
    MODE="self-signed"
elif [[ "$1" == "--letsencrypt" ]]; then
    MODE="letsencrypt"
fi

# Check if certs already exist
if [[ -f "$CERT_PATH/fullchain.pem" ]] && [[ -f "$CERT_PATH/privkey.pem" ]]; then
    echo "✓ SSL certificates already exist"
    echo ""
    openssl x509 -in "$CERT_PATH/fullchain.pem" -noout -subject -dates 2>/dev/null || true
    echo ""
    read -p "Replace existing certificates? [y/N]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing certificates."
        exit 0
    fi
fi

# Interactive mode selection
if [[ -z "$MODE" ]]; then
    echo "Select certificate type:"
    echo "  1) Let's Encrypt (production - requires domain pointed to this server)"
    echo "  2) Self-signed (testing only)"
    echo ""
    read -p "Choice [1/2]: " -n 1 -r
    echo ""
    case $REPLY in
        1) MODE="letsencrypt" ;;
        2) MODE="self-signed" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
fi

# Create certificate directory
mkdir -p "$CERT_PATH"

if [[ "$MODE" == "self-signed" ]]; then
    echo ""
    echo "Creating self-signed certificate..."
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$CERT_PATH/privkey.pem" \
        -out "$CERT_PATH/fullchain.pem" \
        -subj "/CN=$DOMAIN"
    
    echo "  ✓ Self-signed certificate created"
    echo ""
    echo "⚠ WARNING: This certificate will show browser warnings."
    echo "  Use Let's Encrypt for production."
    
elif [[ "$MODE" == "letsencrypt" ]]; then
    echo ""
    echo "Obtaining Let's Encrypt certificate..."
    
    # Check if certbot is installed
    if ! command -v certbot &>/dev/null; then
        echo "Installing certbot..."
        apt-get update -qq
        apt-get install -y -qq certbot
    fi
    
    # Stop nginx if running (need port 80)
    if docker ps | grep -q signet-nginx; then
        echo "Stopping nginx temporarily..."
        docker stop signet-nginx || true
        RESTART_NGINX=true
    fi
    
    # Get certificate
    certbot certonly --standalone \
        -d "$DOMAIN" \
        -d "www.$DOMAIN" \
        --non-interactive \
        --agree-tos \
        --email "admin@$DOMAIN" \
        --no-eff-email
    
    echo "  ✓ Let's Encrypt certificate obtained"
    
    # Restart nginx if we stopped it
    if [[ "$RESTART_NGINX" == "true" ]]; then
        echo "Restarting nginx..."
        docker start signet-nginx || true
    fi
    
    # Set up auto-renewal cron
    echo ""
    echo "Setting up auto-renewal..."
    CRON_CMD="0 0 * * * certbot renew --quiet && docker exec signet-nginx nginx -s reload 2>/dev/null"
    (crontab -l 2>/dev/null | grep -v "certbot renew"; echo "$CRON_CMD") | crontab -
    echo "  ✓ Auto-renewal cron job added"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ SSL certificate setup complete!"
echo ""
echo "Certificate info:"
openssl x509 -in "$CERT_PATH/fullchain.pem" -noout -subject -dates 2>/dev/null || echo "  Could not read certificate"
echo ""
echo "Next: Start or restart nginx"
echo "  cd /opt/signet-infra && docker compose up -d"
echo ""


