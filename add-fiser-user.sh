#!/bin/bash

# Script to add user 'fiser' with bash shell, docker access, and SSH keys from root


# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

USERNAME="fiser"

# Check if user already exists
if id "$USERNAME" &>/dev/null; then
    echo "User '$USERNAME' already exists"
    exit 1
fi

# Create user with bash shell and home directory
echo "Creating user '$USERNAME'..."
useradd -m -s /bin/bash "$USERNAME"

set -e


# Add user to docker group for Docker CLI access
echo "Adding '$USERNAME' to docker group..."
usermod -aG docker "$USERNAME"

# Add user to sudo group for sudo access
echo "Adding '$USERNAME' to sudoers..."
usermod -aG sudo "$USERNAME"

# Grant read/write access to /opt directory
echo "Granting read/write access to /opt..."
if [[ -d /opt ]]; then
    chown -R root:"$USERNAME" /opt
    chmod -R g+rw /opt
else
    mkdir -p /opt
    chown root:"$USERNAME" /opt
    chmod 775 /opt
fi

# Copy SSH directory from root
if [[ -d /root/.ssh ]]; then
    echo "Copying SSH keys from /root/.ssh..."
    cp -r /root/.ssh "/home/$USERNAME/.ssh"
    
    # Set proper ownership
    chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
    
    # Set proper permissions
    chmod 700 "/home/$USERNAME/.ssh"
    chmod 600 "/home/$USERNAME/.ssh/"* 2>/dev/null || true
    
    # Fix permissions for public keys if they exist
    for pubkey in "/home/$USERNAME/.ssh/"*.pub; do
        [[ -f "$pubkey" ]] && chmod 644 "$pubkey"
    done
else
    echo "Warning: /root/.ssh directory not found, skipping SSH key copy"
fi

# Copy lockdown-root.sh script to fiser's home directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCKDOWN_SCRIPT="$SCRIPT_DIR/lockdown-root.sh"

if [[ -f "$LOCKDOWN_SCRIPT" ]]; then
    echo "Copying lockdown-root.sh to /home/$USERNAME/..."
    cp "$LOCKDOWN_SCRIPT" "/home/$USERNAME/lockdown-root.sh"
    chown "$USERNAME:$USERNAME" "/home/$USERNAME/lockdown-root.sh"
    chmod +x "/home/$USERNAME/lockdown-root.sh"
    echo "  ✓ lockdown-root.sh copied to /home/$USERNAME/"
else
    echo "Warning: lockdown-root.sh not found at $LOCKDOWN_SCRIPT, skipping copy"
fi

# Copy hardening scripts to fiser's home directory
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
USER_SCRIPTS_DIR="/home/$USERNAME/scripts"

if [[ -d "$SCRIPTS_DIR" ]]; then
    echo "Copying hardening scripts to /home/$USERNAME/scripts/..."
    mkdir -p "$USER_SCRIPTS_DIR"
    cp -r "$SCRIPTS_DIR/"*.sh "$USER_SCRIPTS_DIR/" 2>/dev/null || true
    chown -R "$USERNAME:$USERNAME" "$USER_SCRIPTS_DIR"
    chmod +x "$USER_SCRIPTS_DIR/"*.sh 2>/dev/null || true
    echo "  ✓ Hardening scripts copied to /home/$USERNAME/scripts/"
else
    echo "Warning: scripts directory not found at $SCRIPTS_DIR, skipping hardening scripts"
fi

echo ""
echo "User '$USERNAME' created successfully!"
echo "  - Shell: /bin/bash"
echo "  - Docker access: yes (member of docker group)"
echo "  - Sudo access: yes (member of sudo group)"
echo "  - /opt access: read/write"
echo "  - SSH keys: $([ -d /home/$USERNAME/.ssh ] && echo 'copied' || echo 'not copied')"
echo "  - Lockdown script: $([ -f /home/$USERNAME/lockdown-root.sh ] && echo 'copied to ~/lockdown-root.sh' || echo 'not copied')"
echo "  - Hardening scripts: $([ -d /home/$USERNAME/scripts ] && echo 'copied to ~/scripts/' || echo 'not copied')"
echo ""
echo "Note: The user may need to log out and back in for group memberships to take effect."
echo ""
echo "Next steps (login as '$USERNAME'):"
echo ""
echo "  1. Harden the server:"
echo "     sudo ~/scripts/harden-all.sh"
echo ""
echo "  2. Lock down root access:"
echo "     sudo ~/lockdown-root.sh"

