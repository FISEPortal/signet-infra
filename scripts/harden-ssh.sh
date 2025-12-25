#!/bin/bash

# SSH Hardening Script
# Configures SSH daemon with security best practices

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_CONFIG="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"

echo "=== SSH Hardening ==="
echo ""

# Backup original config
if [[ -f "$SSHD_CONFIG" ]]; then
    echo "Backing up $SSHD_CONFIG to $BACKUP_CONFIG..."
    cp "$SSHD_CONFIG" "$BACKUP_CONFIG"
    echo "  ✓ Backup created"
else
    echo "❌ ERROR: $SSHD_CONFIG not found"
    exit 1
fi

# Function to set or update SSH config option
set_ssh_option() {
    local option="$1"
    local value="$2"
    
    if grep -qE "^#?\s*${option}\s+" "$SSHD_CONFIG"; then
        # Option exists (possibly commented), replace it
        sed -i "s/^#*\s*${option}\s.*/${option} ${value}/" "$SSHD_CONFIG"
    else
        # Option doesn't exist, append it
        echo "${option} ${value}" >> "$SSHD_CONFIG"
    fi
    echo "  ✓ ${option} ${value}"
}

echo ""
echo "Applying SSH hardening settings..."

# Disable password authentication (key-based only)
set_ssh_option "PasswordAuthentication" "no"

# Disable root login
set_ssh_option "PermitRootLogin" "no"

# Disable empty passwords
set_ssh_option "PermitEmptyPasswords" "no"

# Disable X11 forwarding
set_ssh_option "X11Forwarding" "no"

# Disable agent forwarding
set_ssh_option "AllowAgentForwarding" "no"

# Disable TCP forwarding
set_ssh_option "AllowTcpForwarding" "no"

# Set maximum authentication attempts
set_ssh_option "MaxAuthTries" "3"

# Set idle timeout (5 minutes)
set_ssh_option "ClientAliveInterval" "300"
set_ssh_option "ClientAliveCountMax" "0"

# Use only protocol 2
set_ssh_option "Protocol" "2"

# Disable challenge-response authentication
set_ssh_option "ChallengeResponseAuthentication" "no"

# Disable Kerberos authentication
set_ssh_option "KerberosAuthentication" "no"

# Disable GSSAPI authentication
set_ssh_option "GSSAPIAuthentication" "no"

# Disable host-based authentication
set_ssh_option "HostbasedAuthentication" "no"

# Set login grace time
set_ssh_option "LoginGraceTime" "60"

# Restrict SSH to specific users (if fiser exists)
if id "fiser" &>/dev/null; then
    set_ssh_option "AllowUsers" "fiser"
fi

echo ""
echo "Validating SSH configuration..."
if sshd -t; then
    echo "  ✓ Configuration is valid"
else
    echo "❌ ERROR: Invalid SSH configuration, restoring backup..."
    cp "$BACKUP_CONFIG" "$SSHD_CONFIG"
    exit 1
fi

echo ""
echo "Restarting SSH service..."
systemctl restart sshd || systemctl restart ssh
echo "  ✓ SSH service restarted"

echo ""
echo "✅ SSH hardening complete!"
echo ""
echo "Settings applied:"
echo "  - Password authentication: disabled"
echo "  - Root login: disabled"
echo "  - X11 forwarding: disabled"
echo "  - Agent forwarding: disabled"
echo "  - Idle timeout: 5 minutes"
echo "  - Max auth attempts: 3"
echo ""
echo "⚠️  WARNING: Make sure you have key-based SSH access configured"
echo "   before logging out, or you may be locked out!"

