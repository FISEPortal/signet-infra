#!/bin/bash

# =============================================================================
# Bootstrap New Server Script
# =============================================================================
# Complete server setup from scratch:
#   1. Install Docker
#   2. Create fiser user
#   3. Set up SSL certificates
#   4. Deploy all services
#
# Usage: curl -sSL <url>/bootstrap-server.sh | sudo bash
#    or: sudo ./bootstrap-server.sh
# =============================================================================

set -e

GITHUB_ORG="${GITHUB_ORG:-kevinhartig}"
DOMAIN="${DOMAIN:-signetapp.xyz}"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           SIGNET SERVER BOOTSTRAP                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "This script will:"
echo "  1. Install Docker and prerequisites"
echo "  2. Clone signet-infra repository"
echo "  3. Create the fiser admin user"
echo "  4. Set up SSL certificates"
echo "  5. Deploy all Signet services"
echo ""
echo "Domain: $DOMAIN"
echo "GitHub org: $GITHUB_ORG"
echo ""

read -p "Continue? [y/N]: " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# -------------------------------------------------------------------------
# Install Docker if not present
# -------------------------------------------------------------------------
echo ""
echo "━━━ Step 1: Docker Installation ━━━"

if command -v docker &>/dev/null; then
    echo "✓ Docker already installed"
    docker --version
else
    echo "Installing Docker..."
    
    # Install prerequisites
    apt-get update
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start Docker
    systemctl enable docker
    systemctl start docker
    
    echo "✓ Docker installed"
fi

# -------------------------------------------------------------------------
# Install other prerequisites
# -------------------------------------------------------------------------
echo ""
echo "Installing prerequisites..."
apt-get install -y git certbot

# -------------------------------------------------------------------------
# Clone infrastructure repository
# -------------------------------------------------------------------------
echo ""
echo "━━━ Step 2: Clone Repository ━━━"

INFRA_DIR="/opt/signet-infra"

if [[ -d "$INFRA_DIR/.git" ]]; then
    echo "Repository exists, updating..."
    cd "$INFRA_DIR"
    git pull
else
    echo "Cloning repository..."
    mkdir -p /opt
    git clone "https://github.com/$GITHUB_ORG/signet-infra.git" "$INFRA_DIR"
fi

cd "$INFRA_DIR"
chmod +x *.sh scripts/*.sh 2>/dev/null || true

echo "✓ Repository ready at $INFRA_DIR"

# -------------------------------------------------------------------------
# Create fiser user
# -------------------------------------------------------------------------
echo ""
echo "━━━ Step 3: Create Admin User ━━━"

./add-fiser-user.sh

# -------------------------------------------------------------------------
# SSL Certificates
# -------------------------------------------------------------------------
echo ""
echo "━━━ Step 4: SSL Certificates ━━━"

CERT_PATH="/etc/letsencrypt/live/$DOMAIN"

if [[ -f "$CERT_PATH/fullchain.pem" ]]; then
    echo "✓ SSL certificates already exist"
else
    echo ""
    echo "SSL certificates needed for $DOMAIN"
    echo ""
    echo "Options:"
    echo "  1) Let's Encrypt (requires DNS pointing to this server)"
    echo "  2) Self-signed (for testing)"
    echo "  3) Skip (configure later)"
    echo ""
    read -p "Choice [1/2/3]: " -n 1 -r
    echo ""
    
    case $REPLY in
        1)
            echo "Obtaining Let's Encrypt certificate..."
            certbot certonly --standalone \
                -d "$DOMAIN" \
                -d "www.$DOMAIN" \
                --non-interactive \
                --agree-tos \
                --email "admin@$DOMAIN" \
                --no-eff-email
            echo "✓ Certificate obtained"
            ;;
        2)
            echo "Creating self-signed certificate..."
            mkdir -p "$CERT_PATH"
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout "$CERT_PATH/privkey.pem" \
                -out "$CERT_PATH/fullchain.pem" \
                -subj "/CN=$DOMAIN"
            echo "✓ Self-signed certificate created"
            ;;
        3)
            echo "Skipping SSL setup"
            echo "⚠ Nginx will fail until certificates are configured"
            ;;
    esac
fi

# -------------------------------------------------------------------------
# Create directories
# -------------------------------------------------------------------------
echo ""
echo "Creating directories..."
mkdir -p /app/logs/nginx /var/www/certbot
chown -R fiser:fiser /opt /app/logs

# -------------------------------------------------------------------------
# Deploy services
# -------------------------------------------------------------------------
echo ""
echo "━━━ Step 5: Deploy Services ━━━"

# Start infrastructure
echo "Starting nginx..."
docker compose up -d

# Deploy other services
for service in signet marketplace-app trustvault-api; do
    dir="/opt/$service"
    if [[ -d "$dir/.git" ]]; then
        echo "Updating $service..."
        cd "$dir"
        git pull
    else
        echo "Cloning $service..."
        git clone "https://github.com/$GITHUB_ORG/$service.git" "$dir" || echo "  ⚠ Could not clone $service"
    fi
    
    if [[ -d "$dir" ]]; then
        cd "$dir"
        if [[ -f ".env.example" ]] && [[ ! -f ".env" ]]; then
            cp .env.example .env
            echo "  ⚠ Created .env for $service - update with production values!"
        fi
        if [[ -f "docker-compose.yml" ]] || [[ -f "compose.yml" ]]; then
            docker compose up -d --build || echo "  ⚠ Failed to start $service"
        fi
    fi
done

# -------------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Server bootstrap complete!"
echo ""
echo "Running containers:"
docker ps --format "  {{.Names}}: {{.Status}}"
echo ""
echo "Admin user: fiser"
echo "  - SSH: ssh fiser@$(hostname -I | awk '{print $1}')"
echo "  - Sudo: passwordless"
echo ""
echo "Next steps:"
echo "  1. Update .env files in each /opt/* directory"
echo "  2. Test: curl https://$DOMAIN/health"
echo "  3. Lock down root: sudo /home/fiser/lockdown-root.sh"
echo ""


