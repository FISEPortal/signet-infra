#!/bin/bash

# =============================================================================
# Deploy a Single Service
# =============================================================================
# Usage: sudo ./deploy-service.sh <service-name> <repo-name>
# =============================================================================

set -e

SERVICE_NAME="$1"
REPO_NAME="${2:-$1}"
GITHUB_ORG="${GITHUB_ORG:-kevinhartig}"
BASE_DIR="/opt"

if [[ -z "$SERVICE_NAME" ]]; then
    echo "Usage: $0 <service-name> [repo-name]"
    exit 1
fi

DIR="$BASE_DIR/$SERVICE_NAME"

echo ""
echo "━━━ Deploying: $SERVICE_NAME ━━━"

# For signet-infra, use the deploy-infra.sh script
if [[ "$SERVICE_NAME" == "signet-infra" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/deploy-infra.sh" ]]; then
        "$SCRIPT_DIR/deploy-infra.sh"
        exit 0
    fi
fi

# Clone or update repository
if [[ -d "$DIR/.git" ]]; then
    echo "  Repository exists, pulling..."
    cd "$DIR"
    git pull || echo "  ⚠ Pull failed (may need credentials)"
else
    echo "  Cloning repository..."
    git clone "https://github.com/$GITHUB_ORG/$REPO_NAME.git" "$DIR" || {
        echo "  ❌ Clone failed (repository may be private)"
        exit 1
    }
fi

cd "$DIR"

# Set up .env if needed
if [[ -f ".env.example" ]] && [[ ! -f ".env" ]]; then
    cp .env.example .env
    echo "  ⚠ Created .env - update with production values!"
fi

# Start containers
if [[ -f "docker-compose.yml" ]] || [[ -f "compose.yml" ]]; then
    docker compose up -d --build
    echo "  ✓ Containers started"
else
    echo "  ⚠ No docker-compose.yml found"
fi
