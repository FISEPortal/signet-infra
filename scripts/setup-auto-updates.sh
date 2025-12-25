#!/bin/bash

# Automatic Security Updates Setup Script
# Configures unattended-upgrades for automatic security patching

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "=== Automatic Security Updates Setup ==="
echo ""

# Check for Debian/Ubuntu
if ! command -v apt-get &>/dev/null; then
    echo "❌ ERROR: This script is designed for Debian/Ubuntu systems"
    echo "For RHEL/CentOS, use dnf-automatic instead"
    exit 1
fi

# Install unattended-upgrades
echo "Installing unattended-upgrades..."
apt-get update -qq
apt-get install -y -qq unattended-upgrades apt-listchanges
echo "  ✓ unattended-upgrades installed"

# Configure unattended-upgrades
echo ""
echo "Configuring unattended-upgrades..."

cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
// Automatically upgrade packages from these origins
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

// List of packages to not update
Unattended-Upgrade::Package-Blacklist {
    // Add packages here that should not be auto-updated
    // "linux-image*";
};

// Send email notifications (uncomment and configure if needed)
// Unattended-Upgrade::Mail "admin@example.com";
// Unattended-Upgrade::MailReport "on-change";

// Remove unused kernel packages
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";

// Remove unused dependencies
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Automatically reboot if required (at 3 AM)
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";

// Don't reboot if users are logged in
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";

// Enable logging
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";

// Verbose logging
Unattended-Upgrade::Verbose "false";

// Debug mode
Unattended-Upgrade::Debug "false";
EOF

echo "  ✓ unattended-upgrades configuration created"

# Enable automatic updates
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

echo "  ✓ Automatic updates enabled"

# Enable and start the timer
echo ""
echo "Enabling unattended-upgrades service..."
systemctl enable unattended-upgrades >/dev/null 2>&1
systemctl start unattended-upgrades
echo "  ✓ Service enabled and started"

# Run a dry-run to verify configuration
echo ""
echo "Verifying configuration (dry run)..."
if unattended-upgrades --dry-run --debug 2>&1 | grep -q "Allowed origins"; then
    echo "  ✓ Configuration is valid"
else
    echo "  ⚠ Could not verify configuration (this may be normal)"
fi

echo ""
echo "✅ Automatic security updates configured!"
echo ""
echo "Configuration:"
echo "  - Security updates: enabled"
echo "  - Update check: daily"
echo "  - Auto-reboot if needed: 3:00 AM (only if no users logged in)"
echo "  - Unused packages: auto-removed"
echo ""
echo "Logs: /var/log/unattended-upgrades/"
echo ""
echo "To test: sudo unattended-upgrades --dry-run -v"

