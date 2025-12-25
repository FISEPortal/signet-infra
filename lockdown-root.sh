#!/bin/bash

# Script to lock down root user - disable shell login and remove SSH authorized keys
# WARNING: Make sure you have another user with sudo access before running this!

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "⚠️  WARNING: This will disable root login!"
echo "Make sure you have another user with sudo access before proceeding."
echo ""

# Check if there's at least one other user with sudo access
SUDO_USERS=$(getent group sudo | cut -d: -f4)
if [[ -z "$SUDO_USERS" ]]; then
    echo "❌ ERROR: No users found in sudo group!"
    echo "Create a user with sudo access before locking down root."
    exit 1
fi

echo "Users with sudo access: $SUDO_USERS"
echo ""

# Prompt for confirmation
read -p "Type 'LOCKDOWN' to confirm: " CONFIRM
if [[ "$CONFIRM" != "LOCKDOWN" ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Locking down root user..."

# Remove root's authorized_keys
if [[ -f /root/.ssh/authorized_keys ]]; then
    echo "Removing /root/.ssh/authorized_keys..."
    rm -f /root/.ssh/authorized_keys
    echo "  ✓ Removed authorized_keys"
else
    echo "  - No authorized_keys file found (already removed or never existed)"
fi

# Disable root shell login by setting shell to nologin
echo "Disabling root shell login..."
usermod -s /usr/sbin/nologin root
echo "  ✓ Root shell set to /usr/sbin/nologin"

# Optionally lock the root password (prevents su to root)
echo "Locking root password..."
passwd -l root
echo "  ✓ Root password locked"

echo ""
echo "✅ Root user locked down successfully!"
echo ""
echo "Root can no longer:"
echo "  - SSH in with authorized keys"
echo "  - Log in via shell"
echo "  - Be accessed via 'su root'"
echo ""
echo "Use 'sudo' from a privileged user account for administrative tasks."

