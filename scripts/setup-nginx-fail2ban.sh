#!/bin/bash
# =============================================================================
# Setup Nginx Fail2ban Filter for Bot/Attack Mitigation
# =============================================================================
# This script:
#   1. Installs geoip-bin for geographic lookup
#   2. Creates nginx-badbots fail2ban filter
#   3. Adds nginx-badbots jail to fail2ban
#   4. Shows currently banned SSH IPs by country
# =============================================================================

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         NGINX FAIL2BAN ATTACK MITIGATION SETUP             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# -----------------------------------------------------------------------------
# Install GeoIP for country lookup
# -----------------------------------------------------------------------------
echo "━━━ Installing GeoIP tools ━━━"
apt-get update -qq
apt-get install -y geoip-bin geoip-database

# -----------------------------------------------------------------------------
# Show attacking countries (current SSH bans)
# -----------------------------------------------------------------------------
echo ""
echo "━━━ Current SSH Attack Sources by Country ━━━"
BANNED_IPS=$(fail2ban-client status sshd 2>/dev/null | grep "Banned IP" | cut -d: -f2 | tr -d ' ')
if [[ -n "$BANNED_IPS" ]]; then
    for ip in $BANNED_IPS; do
        country=$(geoiplookup "$ip" 2>/dev/null | head -1)
        echo "  $ip → $country"
    done
else
    echo "  No IPs currently banned"
fi

# -----------------------------------------------------------------------------
# Create nginx-badbots filter
# -----------------------------------------------------------------------------
echo ""
echo "━━━ Creating Fail2ban Nginx Filter ━━━"

cat > /etc/fail2ban/filter.d/nginx-badbots.conf << 'EOF'
# Fail2ban filter for nginx bad bots and attack patterns
# Matches common exploit attempts and 444 responses

[Definition]

failregex = ^<HOST> .* "(GET|POST|HEAD).*(\.php|wp-|xmlrpc|phpmyadmin|\.env|\.git|admin|setup|config).*"
            ^<HOST> .* ".*" 444 .*$
            ^<HOST> .* "(GET|POST) /[^ ]*(union|select|concat|eval|base64).*"

ignoreregex =
EOF

echo "  ✓ Created /etc/fail2ban/filter.d/nginx-badbots.conf"

# -----------------------------------------------------------------------------
# Add nginx-badbots jail (append if not exists)
# -----------------------------------------------------------------------------
echo ""
echo "━━━ Configuring Fail2ban Jail ━━━"

# Check if jail already exists
if grep -q "\[nginx-badbots\]" /etc/fail2ban/jail.local 2>/dev/null; then
    echo "  ⚠ nginx-badbots jail already exists in jail.local"
else
    cat >> /etc/fail2ban/jail.local << 'EOF'

# -----------------------------------------------------------------------------
# Nginx Bad Bots / Attack Pattern Jail
# -----------------------------------------------------------------------------
[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2
findtime = 300
bantime = 86400
banaction = ufw

# Recidive jail - ban repeat offenders for longer
[recidive]
enabled = true
logpath = /var/log/fail2ban.log
banaction = ufw
bantime = 4w
findtime = 1d
maxretry = 3
EOF
    echo "  ✓ Added nginx-badbots and recidive jails to /etc/fail2ban/jail.local"
fi

# -----------------------------------------------------------------------------
# Extend SSH ban time
# -----------------------------------------------------------------------------
echo ""
echo "━━━ Extending SSH Ban Duration ━━━"

if grep -q "^\[sshd\]" /etc/fail2ban/jail.local 2>/dev/null; then
    # Update existing sshd section
    sed -i '/^\[sshd\]/,/^\[/{s/bantime = .*/bantime = 1w/}' /etc/fail2ban/jail.local
    echo "  ✓ Updated sshd bantime to 1 week"
else
    cat >> /etc/fail2ban/jail.local << 'EOF'

[sshd]
enabled = true
bantime = 1w
findtime = 10m
maxretry = 3
EOF
    echo "  ✓ Added sshd jail with 1 week ban"
fi

# -----------------------------------------------------------------------------
# Restart fail2ban
# -----------------------------------------------------------------------------
echo ""
echo "━━━ Restarting Fail2ban ━━━"
systemctl restart fail2ban
sleep 2

# -----------------------------------------------------------------------------
# Show status
# -----------------------------------------------------------------------------
echo ""
echo "━━━ Fail2ban Status ━━━"
fail2ban-client status

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Nginx Fail2ban setup complete!"
echo ""
echo "Jails configured:"
echo "  • sshd         - 1 week ban after 3 failed attempts"
echo "  • nginx-badbots - 24hr ban after 2 exploit attempts"
echo "  • recidive     - 4 week ban for repeat offenders"
echo ""
echo "Monitor with:"
echo "  sudo fail2ban-client status nginx-badbots"
echo "  sudo tail -f /var/log/fail2ban.log"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
