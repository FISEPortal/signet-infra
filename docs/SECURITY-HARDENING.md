# Server Security Hardening Documentation

This document outlines the security hardening measures implemented for the deployment infrastructure, mapped to NIST SP 800-53 security controls.

## Overview

The hardening suite consists of modular scripts that can be run individually or together via the master script `harden-all.sh`.

---

## Implemented Controls

### 1. SSH Hardening (`scripts/harden-ssh.sh`)

Secures the SSH daemon configuration to prevent unauthorized access.

| Setting | Value | NIST Control | Description |
|---------|-------|--------------|-------------|
| PasswordAuthentication | no | IA-5 (Authenticator Management) | Forces key-based authentication only |
| PermitRootLogin | no | AC-6 (Least Privilege) | Prevents direct root SSH access |
| PermitEmptyPasswords | no | IA-5 | Rejects accounts without passwords |
| X11Forwarding | no | CM-7 (Least Functionality) | Disables unnecessary X11 tunneling |
| AllowAgentForwarding | no | CM-7 | Reduces attack surface |
| AllowTcpForwarding | no | CM-7 | Prevents SSH tunneling abuse |
| MaxAuthTries | 3 | AC-7 (Unsuccessful Login Attempts) | Limits brute force attempts |
| ClientAliveInterval | 300 | AC-12 (Session Termination) | 5-minute idle timeout |
| ClientAliveCountMax | 0 | AC-12 | Immediate disconnect on timeout |
| LoginGraceTime | 60 | AC-7 | Limits authentication window |
| AllowUsers | fiser | AC-2 (Account Management) | Restricts SSH to specific users |

**Backup:** Original configuration saved to `/etc/ssh/sshd_config.backup.<timestamp>`

---

### 2. Firewall Configuration (`scripts/setup-firewall.sh`)

Implements network boundary protection using UFW (Uncomplicated Firewall).

| Rule | NIST Control | Description |
|------|--------------|-------------|
| Default deny incoming | SC-7 (Boundary Protection) | Block all inbound by default |
| Default allow outgoing | SC-7 | Allow outbound connections |
| SSH (port 22) with rate limiting | SC-7, AC-7 | 6 connections per 30 seconds |
| HTTP (port 80) | SC-7 | Web traffic |
| HTTPS (port 443) | SC-7 | Encrypted web traffic |

---

### 3. Intrusion Prevention (`scripts/setup-firewall.sh`)

Fail2ban configuration for automated threat response.

| Setting | Value | NIST Control | Description |
|---------|-------|--------------|-------------|
| bantime | 3600 (1 hour) | AC-7, SI-4 (Monitoring) | Duration of IP ban |
| findtime | 600 (10 min) | AC-7 | Window for counting failures |
| maxretry | 3 | AC-7 | Failures before ban |
| banaction | ufw | SC-7 | Integration with firewall |

**Log monitoring:** `/var/log/auth.log`

---

### 4. Automatic Security Updates (`scripts/setup-auto-updates.sh`)

Configures unattended-upgrades for timely patch management.

| Setting | Value | NIST Control | Description |
|---------|-------|--------------|-------------|
| Security updates | Enabled | SI-2 (Flaw Remediation) | Automatic security patches |
| Update frequency | Daily | SI-2 | Regular update checks |
| Auto-reboot | 03:00 | SI-2 | Reboot when required |
| Reboot with users | Disabled | SI-2 | Safety check before reboot |
| Unused packages | Auto-removed | CM-7 | Minimize attack surface |

**Logs:** `/var/log/unattended-upgrades/`

---

### 5. Docker Security (`scripts/harden-docker.sh`)

Hardens the Docker daemon configuration.

| Setting | Value | NIST Control | Description |
|---------|-------|--------------|-------------|
| log-driver | json-file | AU-4 (Audit Storage) | Structured logging |
| max-size | 10m | AU-4 | Prevent disk exhaustion |
| max-file | 3 | AU-4 | Log rotation |
| live-restore | true | CP-10 (Recovery) | Containers survive daemon restart |
| userland-proxy | false | SC-7 | Better performance, less attack surface |
| no-new-privileges | true | AC-6 (Least Privilege) | Prevent privilege escalation |
| icc | false | SC-7 | Disable inter-container communication |

**Container-level recommendations:**
- Use `--read-only` for read-only root filesystem
- Use `--cap-drop ALL` to drop Linux capabilities
- Use `--user <uid>:<gid>` to run as non-root
- Use `--security-opt no-new-privileges:true`

---

### 6. Login Monitoring (`scripts/setup-login-alerts.sh`)

Real-time notifications for SSH login events.

| Feature | NIST Control | Description |
|---------|--------------|-------------|
| PAM integration | AU-3 (Audit Content) | Captures login details |
| Syslog logging | AU-6 (Audit Review) | Local log storage |
| Slack webhook | AU-6, IR-6 (Incident Reporting) | Real-time alerts |
| Discord webhook | AU-6, IR-6 | Real-time alerts |
| Email notifications | AU-6, IR-6 | Email alerts |

**Configuration file:** `/etc/ssh-login-alerts.conf`

**Logged information:**
- Username
- Source IP address
- Timestamp
- Hostname

---

### 7. Privileged Access Control (`lockdown-root.sh`)

Disables root account access after administrative user is configured.

| Action | NIST Control | Description |
|--------|--------------|-------------|
| Remove authorized_keys | AC-2 (Account Management) | Disable SSH key access |
| Set shell to nologin | AC-2 | Prevent shell access |
| Lock password | AC-2 | Disable password authentication |

**Safety check:** Verifies sudo-capable users exist before execution.

---

### 8. User Account Management (`add-fiser-user.sh`)

Creates a dedicated administrative user with appropriate privileges.

| Configuration | NIST Control | Description |
|---------------|--------------|-------------|
| Non-root user | AC-6 (Least Privilege) | Separate admin account |
| Sudo access | AC-6 | Controlled privilege escalation |
| Docker group | AC-6 | Container management access |
| SSH key copy | IA-5 | Key-based authentication |
| Restricted /opt access | AC-6 | Application directory access |

---

## Not Yet Implemented

The following NIST controls are recommended but not currently implemented:

### High Priority

| Control | NIST Reference | Recommended Solution | Complexity |
|---------|----------------|---------------------|------------|
| Audit Logging | AU-2, AU-3 (Audit Events/Content) | Install and configure `auditd` | Medium |
| File Integrity Monitoring | SI-7 (Software Integrity) | Deploy AIDE or OSSEC | Medium |
| Multi-Factor Authentication | IA-2(1) (MFA for Privileged) | Google Authenticator PAM module | Low |

### Medium Priority

| Control | NIST Reference | Recommended Solution | Complexity |
|---------|----------------|---------------------|------------|
| Disk Encryption | SC-28 (Protection at Rest) | LUKS full-disk encryption | High |
| Vulnerability Scanning | RA-5 (Vulnerability Scanning) | OpenVAS, Nessus, or Trivy | Medium |
| Backup & Recovery | CP-9 (System Backup) | Automated backup scripts | Medium |
| Security Benchmarking | CM-6 (Configuration Settings) | CIS Benchmark compliance scan | Low |

### Lower Priority

| Control | NIST Reference | Recommended Solution | Complexity |
|---------|----------------|---------------------|------------|
| Network Segmentation | SC-7 (Boundary Protection) | VLANs, separate subnets | High |
| Centralized Logging | AU-6 (Audit Review) | ELK Stack, Loki, or Splunk | High |
| SIEM Integration | SI-4 (Monitoring) | Wazuh, Security Onion | High |
| Certificate Management | SC-17 (PKI Certificates) | Let's Encrypt automation | Low |

---

## NIST Framework Mapping

### NIST Cybersecurity Framework (CSF) Coverage

| Function | Category | Implemented | Gap |
|----------|----------|-------------|-----|
| **Identify** | Asset Management | Partial | Full inventory needed |
| | Risk Assessment | No | Vulnerability scanning |
| **Protect** | Access Control | ✅ Yes | MFA recommended |
| | Data Security | Partial | Encryption at rest |
| | Maintenance | ✅ Yes | Auto-updates |
| | Protective Technology | ✅ Yes | Firewall, hardening |
| **Detect** | Anomalies & Events | ✅ Yes | Login alerts |
| | Continuous Monitoring | Partial | SIEM recommended |
| **Respond** | Response Planning | Partial | IR procedures needed |
| | Mitigation | ✅ Yes | Fail2ban |
| **Recover** | Recovery Planning | No | Backup procedures |

### NIST SP 800-53 Control Families

| Family | Controls Addressed |
|--------|-------------------|
| AC (Access Control) | AC-2, AC-6, AC-7, AC-12 |
| AU (Audit) | AU-4, AU-6 |
| CM (Configuration) | CM-7 |
| CP (Contingtic Planning) | CP-10 |
| IA (Identification/Auth) | IA-5 |
| SC (System/Comm Protection) | SC-7 |
| SI (System/Info Integrity) | SI-2, SI-4 |

---

## Additional References

- [NIST SP 800-53 Rev. 5](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final) - Security and Privacy Controls
- [NIST SP 800-123](https://csrc.nist.gov/publications/detail/sp/800-123/final) - Guide to General Server Security
- [NIST SP 800-190](https://csrc.nist.gov/publications/detail/sp/800-190/final) - Application Container Security Guide
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/) - Industry security benchmarks
- [Docker Security Best Practices](https://docs.docker.com/engine/security/) - Official Docker security guide

---

## Script Locations

```
signet-infra/
├── add-fiser-user.sh          # User provisioning
├── lockdown-root.sh           # Root account lockdown
└── scripts/
    ├── harden-all.sh          # Master hardening script
    ├── harden-ssh.sh          # SSH configuration
    ├── harden-docker.sh       # Docker daemon security
    ├── setup-auto-updates.sh  # Unattended upgrades
    ├── setup-firewall.sh      # UFW + Fail2ban
    └── setup-login-alerts.sh  # SSH login notifications
```

---

## Execution Order

1. **Create admin user:** `sudo ./add-fiser-user.sh`
2. **Login as new user:** `ssh fiser@<server>`
3. **Run hardening:** `sudo ~/scripts/harden-all.sh`
4. **Lock down root:** `sudo ~/lockdown-root.sh`

---

*Document generated: December 2024*

