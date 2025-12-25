#!/bin/bash

# Firewall and Fail2ban Setup Script
# Configures UFW firewall and Fail2ban for intrusion prevention

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "=== Firewall & Fail2ban Setup ==="
echo ""

# Detect package manager
if command -v apt-get &>/dev/null; then
    PKG_MANAGER="apt"
elif command -v yum &>/dev/null; then
    PKG_MANAGER="yum"
elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
else
    echo "❌ ERROR: Unsupported package manager"
    exit 1
fi

# Install UFW if not present
echo "Installing UFW..."
if [[ "$PKG_MANAGER" == "apt" ]]; then
    apt-get update -qq
    apt-get install -y -qq ufw
else
    $PKG_MANAGER install -y -q ufw
fi
echo "  ✓ UFW installed"

# Reset UFW to defaults
echo ""
echo "Configuring UFW firewall rules..."
ufw --force reset >/dev/null

# Set default policies
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
echo "  ✓ Default policies set (deny incoming, allow outgoing)"

# Allow SSH with rate limiting
ufw limit ssh comment 'SSH with rate limiting' >/dev/null
echo "  ✓ SSH (port 22) allowed with rate limiting"

# Allow HTTP
ufw allow 80/tcp comment 'HTTP' >/dev/null
echo "  ✓ HTTP (port 80) allowed"

# Allow HTTPS
ufw allow 443/tcp comment 'HTTPS' >/dev/null
echo "  ✓ HTTPS (port 443) allowed"

# Enable UFW
echo ""
echo "Enabling UFW..."
ufw --force enable >/dev/null
echo "  ✓ UFW enabled"

# Show status
echo ""
echo "Current firewall rules:"
ufw status numbered

# Install Fail2ban
echo ""
echo "Installing Fail2ban..."
if [[ "$PKG_MANAGER" == "apt" ]]; then
    apt-get install -y -qq fail2ban
else
    $PKG_MANAGER install -y -q fail2ban epel-release 2>/dev/null || $PKG_MANAGER install -y -q fail2ban
fi
echo "  ✓ Fail2ban installed"

# Configure Fail2ban for SSH
echo ""
echo "Configuring Fail2ban..."

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban time: 1 hour
bantime = 3600

# Time window for detecting repeated failures
findtime = 600

# Number of failures before ban
maxretry = 5

# Action to take (ban via UFW)
banaction = ufw

# Email notifications (optional - configure if needed)
# destemail = admin@example.com
# sender = fail2ban@example.com
# action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

echo "  ✓ Fail2ban configuration created"

# Restart Fail2ban
echo ""
echo "Starting Fail2ban service..."
systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban
echo "  ✓ Fail2ban started and enabled"

# Show Fail2ban status
echo ""
echo "Fail2ban status:"
fail2ban-client status

echo ""
echo "✅ Firewall and Fail2ban setup complete!"
echo ""
echo "Configuration:"
echo "  - UFW: enabled with deny-by-default"
echo "  - Allowed ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)"
echo "  - SSH rate limiting: enabled"
echo "  - Fail2ban: 3 failed attempts = 1 hour ban"

