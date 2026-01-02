#!/bin/bash

# =============================================================================
# Add Fiser User Script (Idempotent)
# =============================================================================
# Creates or updates the 'fiser' user with proper access.
# This script can be run multiple times safely.
#
# Usage: sudo ./add-fiser-user.sh
# =============================================================================

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

USERNAME="fiser"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           FISER USER SETUP (Idempotent)                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# -------------------------------------------------------------------------
# Create or verify user exists
# -------------------------------------------------------------------------
if id "$USERNAME" &>/dev/null; then
    echo "✓ User '$USERNAME' already exists"
else
    echo "Creating user '$USERNAME'..."
    useradd -m -s /bin/bash "$USERNAME"
    echo "  ✓ User created"
fi

# Ensure correct shell
current_shell=$(getent passwd "$USERNAME" | cut -d: -f7)
if [[ "$current_shell" != "/bin/bash" ]]; then
    echo "Setting shell to /bin/bash..."
    usermod -s /bin/bash "$USERNAME"
    echo "  ✓ Shell updated"
else
    echo "✓ Shell is /bin/bash"
fi

# -------------------------------------------------------------------------
# Add to groups (idempotent - usermod -aG is safe to run multiple times)
# -------------------------------------------------------------------------
echo ""
echo "Configuring group memberships..."

# Docker group
if getent group docker &>/dev/null; then
    usermod -aG docker "$USERNAME"
    echo "  ✓ Added to docker group"
else
    echo "  ⚠ Docker group doesn't exist (install docker first)"
fi

# Root group
usermod -aG root "$USERNAME"
echo "  ✓ Added to root group"

# Sudo group
usermod -aG sudo "$USERNAME"
echo "  ✓ Added to sudo group"

# -------------------------------------------------------------------------
# Configure passwordless sudo
# -------------------------------------------------------------------------
echo ""
echo "Configuring passwordless sudo..."
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
SUDOERS_CONTENT="$USERNAME ALL=(ALL) NOPASSWD:ALL"

if [[ -f "$SUDOERS_FILE" ]] && grep -qF "$SUDOERS_CONTENT" "$SUDOERS_FILE"; then
    echo "  ✓ Passwordless sudo already configured"
else
    echo "$SUDOERS_CONTENT" > "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    echo "  ✓ Passwordless sudo configured"
fi

# -------------------------------------------------------------------------
# Grant /opt access
# -------------------------------------------------------------------------
echo ""
echo "Configuring /opt access..."
mkdir -p /opt
chown root:"$USERNAME" /opt
chmod 775 /opt
echo "  ✓ /opt access configured (group: $USERNAME, mode: 775)"

# -------------------------------------------------------------------------
# Copy SSH keys from root
# -------------------------------------------------------------------------
echo ""
echo "Configuring SSH keys..."
USER_SSH_DIR="/home/$USERNAME/.ssh"

if [[ -d /root/.ssh ]]; then
    mkdir -p "$USER_SSH_DIR"
    
    # Copy authorized_keys if exists
    if [[ -f /root/.ssh/authorized_keys ]]; then
        cp /root/.ssh/authorized_keys "$USER_SSH_DIR/authorized_keys"
        echo "  ✓ Copied authorized_keys"
    fi
    
    # Copy known_hosts if exists
    if [[ -f /root/.ssh/known_hosts ]]; then
        cp /root/.ssh/known_hosts "$USER_SSH_DIR/known_hosts"
        echo "  ✓ Copied known_hosts"
    fi
    
    # Set ownership and permissions
    chown -R "$USERNAME:$USERNAME" "$USER_SSH_DIR"
    chmod 700 "$USER_SSH_DIR"
    chmod 600 "$USER_SSH_DIR/"* 2>/dev/null || true
    
    # Fix permissions for public keys
    for pubkey in "$USER_SSH_DIR/"*.pub; do
        [[ -f "$pubkey" ]] && chmod 644 "$pubkey"
    done
    
    echo "  ✓ SSH directory permissions set"
else
    echo "  ⚠ /root/.ssh not found, skipping SSH key copy"
fi

# -------------------------------------------------------------------------
# Copy lockdown script
# -------------------------------------------------------------------------
echo ""
echo "Copying lockdown script..."
LOCKDOWN_SRC="$SCRIPT_DIR/lockdown-root.sh"
LOCKDOWN_DST="/home/$USERNAME/lockdown-root.sh"

if [[ -f "$LOCKDOWN_SRC" ]]; then
    cp "$LOCKDOWN_SRC" "$LOCKDOWN_DST"
    chown "$USERNAME:$USERNAME" "$LOCKDOWN_DST"
    chmod +x "$LOCKDOWN_DST"
    echo "  ✓ lockdown-root.sh copied to ~/lockdown-root.sh"
else
    echo "  ⚠ lockdown-root.sh not found at $LOCKDOWN_SRC"
fi

# -------------------------------------------------------------------------
# Copy hardening scripts
# -------------------------------------------------------------------------
echo ""
echo "Copying hardening scripts..."
SCRIPTS_SRC="$SCRIPT_DIR/scripts"
SCRIPTS_DST="/home/$USERNAME/scripts"

if [[ -d "$SCRIPTS_SRC" ]]; then
    mkdir -p "$SCRIPTS_DST"
    cp "$SCRIPTS_SRC/"*.sh "$SCRIPTS_DST/" 2>/dev/null || true
    chown -R "$USERNAME:$USERNAME" "$SCRIPTS_DST"
    chmod +x "$SCRIPTS_DST/"*.sh 2>/dev/null || true
    echo "  ✓ Hardening scripts copied to ~/scripts/"
else
    echo "  ⚠ scripts directory not found at $SCRIPTS_SRC"
fi

# -------------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ User '$USERNAME' configured successfully!"
echo ""
echo "Configuration:"
echo "  - Shell: /bin/bash"
echo "  - Groups: $(groups $USERNAME | cut -d: -f2)"
echo "  - Sudo: passwordless"
echo "  - /opt: read/write access"
echo "  - SSH keys: $([ -f /home/$USERNAME/.ssh/authorized_keys ] && echo 'configured' || echo 'not found')"
echo "  - Lockdown script: $([ -f /home/$USERNAME/lockdown-root.sh ] && echo '~/lockdown-root.sh' || echo 'not found')"
echo "  - Hardening scripts: $([ -d /home/$USERNAME/scripts ] && echo '~/scripts/' || echo 'not found')"
echo ""
echo "Next steps (login as '$USERNAME'):"
echo ""
echo "  1. Harden the server:"
echo "     sudo ~/scripts/harden-all.sh"
echo ""
echo "  2. Lock down root access:"
echo "     sudo ~/lockdown-root.sh"
echo ""
