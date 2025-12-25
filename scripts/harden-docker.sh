#!/bin/bash

# Docker Security Hardening Script
# Configures Docker daemon with security best practices

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "=== Docker Security Hardening ==="
echo ""

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
    echo "❌ ERROR: Docker is not installed"
    exit 1
fi

DAEMON_CONFIG="/etc/docker/daemon.json"
BACKUP_CONFIG="/etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)"

# Backup existing config if present
if [[ -f "$DAEMON_CONFIG" ]]; then
    echo "Backing up existing Docker daemon config..."
    cp "$DAEMON_CONFIG" "$BACKUP_CONFIG"
    echo "  ✓ Backup created at $BACKUP_CONFIG"
fi

# Create Docker config directory if it doesn't exist
mkdir -p /etc/docker

echo ""
echo "Creating hardened Docker daemon configuration..."

cat > "$DAEMON_CONFIG" << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "live-restore": true,
    "userland-proxy": false,
    "no-new-privileges": true,
    "icc": false,
    "storage-driver": "overlay2",
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 65536,
            "Soft": 65536
        },
        "nproc": {
            "Name": "nproc",
            "Hard": 4096,
            "Soft": 4096
        }
    }
}
EOF

echo "  ✓ Docker daemon configuration created"

# Validate the configuration
echo ""
echo "Validating Docker configuration..."
if python3 -c "import json; json.load(open('$DAEMON_CONFIG'))" 2>/dev/null || \
   python -c "import json; json.load(open('$DAEMON_CONFIG'))" 2>/dev/null; then
    echo "  ✓ Configuration is valid JSON"
else
    echo "❌ ERROR: Invalid JSON configuration"
    if [[ -f "$BACKUP_CONFIG" ]]; then
        cp "$BACKUP_CONFIG" "$DAEMON_CONFIG"
    fi
    exit 1
fi

# Set proper permissions on Docker socket
echo ""
echo "Setting Docker socket permissions..."
if [[ -S /var/run/docker.sock ]]; then
    chmod 660 /var/run/docker.sock
    echo "  ✓ Docker socket permissions set to 660"
fi

# Restart Docker to apply changes
echo ""
echo "Restarting Docker service..."
systemctl restart docker
echo "  ✓ Docker service restarted"

# Verify Docker is running
if docker info >/dev/null 2>&1; then
    echo "  ✓ Docker is running with new configuration"
else
    echo "❌ ERROR: Docker failed to start"
    if [[ -f "$BACKUP_CONFIG" ]]; then
        echo "Restoring backup configuration..."
        cp "$BACKUP_CONFIG" "$DAEMON_CONFIG"
        systemctl restart docker
    fi
    exit 1
fi

echo ""
echo "✅ Docker hardening complete!"
echo ""
echo "Security settings applied:"
echo "  - Log rotation: max 10MB, 3 files per container"
echo "  - Live restore: enabled (containers survive daemon restart)"
echo "  - Inter-container communication (ICC): disabled"
echo "  - No new privileges: containers can't gain additional privileges"
echo "  - Userland proxy: disabled (better performance, less attack surface)"
echo "  - Default ulimits: configured for stability"
echo ""
echo "⚠️  Note: Existing containers may need to be recreated to apply"
echo "   new default settings."
echo ""
echo "For per-container security, consider using:"
echo "  --read-only              (read-only root filesystem)"
echo "  --security-opt no-new-privileges:true"
echo "  --cap-drop ALL           (drop all Linux capabilities)"
echo "  --user <uid>:<gid>       (run as non-root user)"

