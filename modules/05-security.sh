#!/usr/bin/env bash
# =============================================================================
# MODULE: Security Hardening (Fail2Ban, Auditd, AppArmor, rkhunter)
# =============================================================================

module_security() {
    section "SECURITY HARDENING"

    # ─── Fail2Ban ─────────────────────────────────────────────────────────────
    # Why: Temporarily bans IP addresses making multiple failed login attempts.
    # What it does: Creates a custom jail.local configuration to protect SSH and HTTP services.
    info "Configuring Fail2Ban..."

    cat > /etc/fail2ban/jail.local << FAIL2BAN
# vm-setup managed Fail2Ban configuration

[DEFAULT]
bantime    = ${FAIL2BAN_BAN_TIME}
findtime   = ${FAIL2BAN_FIND_TIME}
maxretry   = ${FAIL2BAN_MAX_RETRY}
banaction  = ufw
backend    = systemd
usedns     = warn
logencoding= utf-8

# Email notification (optional)
# destemail = admin@yourdomain.com
# sender    = fail2ban@yourdomain.com
# action    = %(action_mwl)s

[sshd]
enabled   = true
port      = ${SSH_PORT}
filter    = sshd
logpath   = %(sshd_log)s
maxretry  = ${FAIL2BAN_MAX_RETRY}
bantime   = ${FAIL2BAN_BAN_TIME}

[sshd-ddos]
enabled   = true
port      = ${SSH_PORT}
filter    = sshd-ddos
logpath   = %(sshd_log)s
maxretry  = 6
bantime   = 7200

[http-auth]
enabled  = false
port     = http,https
logpath  = /var/log/nginx/*access*.log
maxretry = 6

[nginx-botsearch]
enabled  = false
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 2
FAIL2BAN

    systemctl enable fail2ban
    systemctl restart fail2ban
    success "Fail2Ban configured and running (max retries: ${FAIL2BAN_MAX_RETRY}, ban: ${FAIL2BAN_BAN_TIME}s)"

    # ─── Auditd (audit logging) ───────────────────────────────────────────────
    # Why: Essential for regulatory compliance (CIS) and tracking specific system modifications.
    # What it does: Installs rule sets to log critical file changes, user sessions, and syscalls.
    info "Configuring auditd..."
    if systemctl is-active --quiet auditd 2>/dev/null || \
       systemctl enable auditd 2>/dev/null; then

        # CIS benchmark audit rules
        cat > /etc/audit/rules.d/99-production.rules << 'AUDIT'
# vm-setup managed audit rules (CIS Benchmark)

# Delete all previous rules
-D

# Set buffer size (increase if events are lost)
-b 8192

# Failure mode: 1=printk, 2=panic
-f 1

# ── Authentication & Authorization ────────────────────────────────────────
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group  -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# ── SSH keys ──────────────────────────────────────────────────────────────
-w /etc/ssh/sshd_config -p wa -k sshd

# ── Login / Logout ────────────────────────────────────────────────────────
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock/ -p wa -k logins
-w /run/faillock/ -p wa -k logins

# ── Privileged commands ───────────────────────────────────────────────────
-w /usr/bin/sudo  -p x -k priv_cmd
-w /usr/bin/su    -p x -k priv_cmd
-w /usr/bin/newgrp -p x -k priv_cmd
-w /usr/bin/chsh  -p x -k priv_cmd
-w /usr/bin/chfn  -p x -k priv_cmd

# ── System startup files ──────────────────────────────────────────────────
-w /etc/crontab -p wa -k cron
-w /etc/cron.d/ -p wa -k cron
-w /var/spool/cron/ -p wa -k cron

# ── Kernel module loading ─────────────────────────────────────────────────
-w /sbin/insmod  -p x -k modules
-w /sbin/rmmod   -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules

# ── Syscall: file deletion ────────────────────────────────────────────────
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat \
    -F auid>=1000 -F auid!=-1 -k delete

# ── Network configuration changes ────────────────────────────────────────
-w /etc/hosts -p wa -k network
-w /etc/resolv.conf -p wa -k network
-w /etc/network/ -p wa -k network
-w /etc/netplan/ -p wa -k network

# Make the config immutable (requires reboot to change)
# -e 2
AUDIT

        service auditd restart 2>/dev/null || true
        success "Auditd configured with CIS benchmark rules"
    else
        warn "Auditd not available — skipping"
    fi

    # ─── AppArmor ────────────────────────────────────────────────────────────
    # Why: Mandatory Access Control (MAC) isolates applications, limiting the damage of single-service exploits.
    # What it does: Enables the service and enforces all locally defined security profiles.
    info "Enabling AppArmor..."
    if command -v aa-enforce &>/dev/null; then
        systemctl enable apparmor 2>/dev/null || true
        systemctl start apparmor 2>/dev/null || true
        # Enforce all profiles
        find /etc/apparmor.d/ -maxdepth 1 -type f | while read -r profile; do
            aa-enforce "$profile" 2>/dev/null || true
        done
        success "AppArmor enabled and profiles enforced"
    else
        warn "AppArmor utils not found — skipping"
    fi

    # ─── Disable unused services ──────────────────────────────────────────────
    # Why: Reducing the attack surface by stopping unneeded Daemons.
    # What it does: Loops through a predefined list of vulnerable/unused services and disables/stops them.
    info "Disabling unused/insecure services..."
    local unsafe_services=(
        avahi-daemon
        cups
        nfs-server
        rpcbind
        rpc-statd
        bluetooth
        ModemManager
        whoopsie
        apport
    )
    for svc in "${unsafe_services[@]}"; do
        if systemctl is-enabled "$svc" &>/dev/null; then
            systemctl disable --now "$svc" 2>/dev/null || true
            info "  Disabled: $svc"
        fi
    done
    success "Unused services disabled"

    # ─── Password policy ──────────────────────────────────────────────────────
    # Why: Enforces rotation of local passwords, preventing indefinitely lived credentials.
    # What it does: Updates PAM limits to set maximum password age to 90 days.
    info "Enforcing password policy (PAM)..."
    if command -v pam-auth-update &>/dev/null; then
        # Install libpam-pwquality if available
        apt-get install -y -qq libpam-pwquality 2>/dev/null || true
    fi

    # Password aging
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS  90/' /etc/login.defs
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS  1/'  /etc/login.defs
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE  14/' /etc/login.defs
    success "Password aging policy set (max: 90 days)"

    # ─── Secure shared memory ─────────────────────────────────────────────────
    # Why: Shared memory (/run/shm) can be used to execute malicious payloads if not secured.
    # What it does: Mounts tmpfs to /run/shm with nodev, nosuid, and noexec parameters via /etc/fstab.
    info "Securing shared memory..."
    if ! grep -q 'tmpfs.*shm' /etc/fstab; then
        echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
        success "Shared memory secured with noexec,nosuid,nodev"
    fi

    # ─── rkhunter setup ───────────────────────────────────────────────────────
    # Why: Scans the system for rootkits, backdoors, and local exploits.
    # What it does: Updates rkhunter signatures and schedules a silent daily cron check.
    if command -v rkhunter &>/dev/null; then
        info "Initializing rkhunter rootkit scanner..."
        rkhunter --update --nocolors > /dev/null 2>&1 || true
        rkhunter --propupd --nocolors > /dev/null 2>&1 || true
        # Schedule daily scan
        cat > /etc/cron.daily/rkhunter-scan << 'RKHUNTER'
#!/bin/bash
/usr/bin/rkhunter --check --skip-keypress --report-warnings-only \
    --nocolors >> /var/log/rkhunter.log 2>&1
RKHUNTER
        chmod +x /etc/cron.daily/rkhunter-scan
        success "rkhunter configured for daily scans"
    fi

    # ─── Automatic security updates ───────────────────────────────────────────
    # Why: Zero-day exploits can occur at any time; unattended updates close windows of vulnerability quickly.
    # What it does: Installs and configures apt-listchanges/unattended-upgrades to automatically apply security patches.
    if [[ "$ENABLE_AUTO_UPDATES" == true ]]; then
        info "Enabling automatic security updates..."
        apt-get install -y -qq unattended-upgrades apt-listchanges
        cat > /etc/apt/apt.conf.d/50unattended-upgrades << AUTOUPDATE
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::Package-Blacklist {};
Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "$([ "$AUTO_REBOOT" == true ] && echo true || echo false)";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
AUTOUPDATE

        cat > /etc/apt/apt.conf.d/20auto-upgrades << 'AUTO'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
AUTO

        systemctl enable unattended-upgrades
        systemctl start unattended-upgrades
        success "Automatic security updates enabled"
    fi

    success "Security hardening complete"
}
