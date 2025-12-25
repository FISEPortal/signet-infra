#!/bin/bash

# Master Server Hardening Script
# Runs all hardening scripts in sequence

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           SERVER HARDENING - COMPLETE SUITE                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "This script will apply the following security hardening:"
echo "  1. SSH Configuration Hardening"
echo "  2. Firewall (UFW) + Fail2ban Setup"
echo "  3. Automatic Security Updates"
echo "  4. Docker Security Hardening"
echo "  5. SSH Login Alerts"
echo ""

# Track results
declare -A RESULTS

# Function to run a script and track result
run_script() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if [[ ! -f "$script_path" ]]; then
        echo "⚠️  Skipping $script_name (not found)"
        RESULTS["$script_name"]="skipped"
        return
    fi
    
    if bash "$script_path"; then
        RESULTS["$script_name"]="success"
    else
        RESULTS["$script_name"]="failed"
        echo ""
        echo "❌ $script_name failed!"
        read -p "Continue with remaining scripts? [y/N]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 1
        fi
    fi
}

# Confirmation prompt
echo "⚠️  WARNING: This will make significant changes to your system!"
echo ""
read -p "Type 'HARDEN' to proceed: " CONFIRM
if [[ "$CONFIRM" != "HARDEN" ]]; then
    echo "Aborted."
    exit 1
fi

# Run all hardening scripts
run_script "harden-ssh.sh"
run_script "setup-firewall.sh"
run_script "setup-auto-updates.sh"
run_script "harden-docker.sh"
run_script "setup-login-alerts.sh"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    HARDENING SUMMARY                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

for script in "harden-ssh.sh" "setup-firewall.sh" "setup-auto-updates.sh" "harden-docker.sh" "setup-login-alerts.sh"; do
    case "${RESULTS[$script]:-unknown}" in
        success)
            echo "  ✅ $script"
            ;;
        failed)
            echo "  ❌ $script (FAILED)"
            ;;
        skipped)
            echo "  ⏭️  $script (skipped)"
            ;;
        *)
            echo "  ❓ $script (unknown)"
            ;;
    esac
done

# Check for failures
FAILED=0
for result in "${RESULTS[@]}"; do
    if [[ "$result" == "failed" ]]; then
        FAILED=1
        break
    fi
done

echo ""
if [[ $FAILED -eq 0 ]]; then
    echo "✅ Server hardening complete!"
else
    echo "⚠️  Server hardening completed with some failures."
    echo "   Review the output above for details."
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "IMPORTANT NEXT STEPS:"
echo ""
echo "1. Test SSH access before closing this session!"
echo "   ssh fiser@$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'your-server-ip')"
echo ""
echo "2. Configure login alerts:"
echo "   sudo nano /etc/ssh-login-alerts.conf"
echo ""
echo "3. Consider running the root lockdown script:"
echo "   sudo ~/lockdown-root.sh"
echo ""
echo "4. Review firewall rules:"
echo "   sudo ufw status"
echo ""
echo "5. Check Fail2ban status:"
echo "   sudo fail2ban-client status sshd"
echo ""

