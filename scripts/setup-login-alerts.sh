#!/bin/bash

# SSH Login Alerts Setup Script
# Configures notifications for SSH logins via email or webhook

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

echo "=== SSH Login Alerts Setup ==="
echo ""

# Configuration variables (can be overridden via environment)
ALERT_EMAIL="${ALERT_EMAIL:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"

# Create the login alert script
ALERT_SCRIPT="/usr/local/bin/ssh-login-alert.sh"

echo "Creating login alert script..."

cat > "$ALERT_SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash

# SSH Login Alert Script
# Called by PAM on successful SSH login

# Get login details
LOGIN_USER="${PAM_USER:-$USER}"
LOGIN_IP="${PAM_RHOST:-unknown}"
LOGIN_TIME="$(date '+%Y-%m-%d %H:%M:%S %Z')"
HOSTNAME="$(hostname -f 2>/dev/null || hostname)"

# Skip if not an SSH login
if [[ "${PAM_TYPE:-}" != "open_session" ]] && [[ -z "${SSH_CONNECTION:-}" ]]; then
    exit 0
fi

# Skip for certain users (add more as needed)
case "$LOGIN_USER" in
    root|nobody|daemon)
        # Still alert for root, but you can skip by uncommenting:
        # exit 0
        ;;
esac

# Build the message
MESSAGE="🔐 SSH Login Alert

Server: $HOSTNAME
User: $LOGIN_USER
IP: $LOGIN_IP
Time: $LOGIN_TIME"

# Load configuration
CONFIG_FILE="/etc/ssh-login-alerts.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Send email alert
if [[ -n "${ALERT_EMAIL:-}" ]] && command -v mail &>/dev/null; then
    echo "$MESSAGE" | mail -s "SSH Login: $LOGIN_USER@$HOSTNAME from $LOGIN_IP" "$ALERT_EMAIL" 2>/dev/null &
fi

# Send Slack webhook
if [[ -n "${SLACK_WEBHOOK:-}" ]]; then
    curl -s -X POST -H 'Content-type: application/json' \
        --data "{\"text\": \"$MESSAGE\"}" \
        "$SLACK_WEBHOOK" >/dev/null 2>&1 &
fi

# Send Discord webhook
if [[ -n "${DISCORD_WEBHOOK:-}" ]]; then
    curl -s -X POST -H 'Content-type: application/json' \
        --data "{\"content\": \"$MESSAGE\"}" \
        "$DISCORD_WEBHOOK" >/dev/null 2>&1 &
fi

# Log to syslog
logger -t ssh-login-alert "SSH login: $LOGIN_USER from $LOGIN_IP"

exit 0
SCRIPT_EOF

chmod +x "$ALERT_SCRIPT"
echo "  ✓ Alert script created at $ALERT_SCRIPT"

# Create configuration file
CONFIG_FILE="/etc/ssh-login-alerts.conf"

echo ""
echo "Creating configuration file..."

cat > "$CONFIG_FILE" << EOF
# SSH Login Alerts Configuration
# Uncomment and configure the notification methods you want to use

# Email notifications (requires mailutils or similar)
# ALERT_EMAIL="admin@example.com"

# Slack webhook URL
# SLACK_WEBHOOK="https://hooks.slack.com/services/XXX/YYY/ZZZ"

# Discord webhook URL
# DISCORD_WEBHOOK="https://discord.com/api/webhooks/XXX/YYY"
EOF

# Apply provided configuration
if [[ -n "$ALERT_EMAIL" ]]; then
    sed -i "s|# ALERT_EMAIL=.*|ALERT_EMAIL=\"$ALERT_EMAIL\"|" "$CONFIG_FILE"
fi
if [[ -n "$SLACK_WEBHOOK" ]]; then
    sed -i "s|# SLACK_WEBHOOK=.*|SLACK_WEBHOOK=\"$SLACK_WEBHOOK\"|" "$CONFIG_FILE"
fi
if [[ -n "$DISCORD_WEBHOOK" ]]; then
    sed -i "s|# DISCORD_WEBHOOK=.*|DISCORD_WEBHOOK=\"$DISCORD_WEBHOOK\"|" "$CONFIG_FILE"
fi

chmod 600 "$CONFIG_FILE"
echo "  ✓ Configuration file created at $CONFIG_FILE"

# Configure PAM to run the alert script
PAM_SSHD="/etc/pam.d/sshd"

echo ""
echo "Configuring PAM..."

# Check if already configured
if grep -q "ssh-login-alert" "$PAM_SSHD" 2>/dev/null; then
    echo "  - PAM already configured for login alerts"
else
    # Add PAM configuration
    echo "" >> "$PAM_SSHD"
    echo "# SSH Login Alerts" >> "$PAM_SSHD"
    echo "session optional pam_exec.so seteuid $ALERT_SCRIPT" >> "$PAM_SSHD"
    echo "  ✓ PAM configured to run login alerts"
fi

# Install mail utilities if email is configured
if [[ -n "$ALERT_EMAIL" ]]; then
    echo ""
    echo "Installing mail utilities..."
    if command -v apt-get &>/dev/null; then
        apt-get install -y -qq mailutils 2>/dev/null || true
    elif command -v yum &>/dev/null; then
        yum install -y -q mailx 2>/dev/null || true
    fi
fi

echo ""
echo "✅ SSH login alerts configured!"
echo ""
echo "Configuration file: $CONFIG_FILE"
echo ""
echo "To enable notifications, edit $CONFIG_FILE and uncomment:"
echo "  - ALERT_EMAIL for email notifications"
echo "  - SLACK_WEBHOOK for Slack notifications"
echo "  - DISCORD_WEBHOOK for Discord notifications"
echo ""
echo "Test by logging in via SSH from another session."
echo ""
echo "View logs: sudo journalctl -t ssh-login-alert"

