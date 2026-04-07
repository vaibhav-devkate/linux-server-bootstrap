#!/usr/bin/env bash
# =============================================================================
# MODULE: SSH Hardening
# =============================================================================

module_ssh_hardening() {
    section "SSH HARDENING"

    # Backup original sshd_config
    local sshd_config="/etc/ssh/sshd_config"
    cp -n "$sshd_config" "${sshd_config}.bak.$(date +%Y%m%d)" || true
    info "Original sshd_config backed up"

    # ─── Regenerate host keys (fresh VM) ─────────────────────────────────────
    info "Regenerating SSH host keys..."
    rm -f /etc/ssh/ssh_host_*
    ssh-keygen -A > /dev/null 2>&1
    success "Host keys regenerated"

    # ─── Write hardened sshd_config ───────────────────────────────────────────
    info "Writing hardened SSH configuration (port: ${SSH_PORT})..."
    cat > "$sshd_config" << SSHD
# =============================================================================
# HARDENED SSH CONFIGURATION — managed by vm-setup
# Generated: $(date)
# =============================================================================

# ── Network ───────────────────────────────────────────────────────────────────
Port ${SSH_PORT}
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# ── Authentication ────────────────────────────────────────────────────────────
LoginGraceTime 30
MaxAuthTries 3
MaxSessions 5
MaxStartups 10:30:60

PermitRootLogin no
StrictModes yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Password auth — disable once SSH key is confirmed working
PasswordAuthentication $([ "$ALLOW_PASSWORD_AUTH" == "true" ] && echo yes || echo no)
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# ── Session Security ──────────────────────────────────────────────────────────
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive yes

# ── Privilege Escalation ──────────────────────────────────────────────────────
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PermitTunnel no
GatewayPorts no

# ── Allowed Users ─────────────────────────────────────────────────────────────
AllowUsers ${ADMIN_USER}

# ── Ciphers & MACs (modern, strong only) ─────────────────────────────────────
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com

# ── Logging ───────────────────────────────────────────────────────────────────
SyslogFacility AUTH
LogLevel VERBOSE

# ── Banner ────────────────────────────────────────────────────────────────────
Banner /etc/ssh/banner
PrintLastLog yes
PrintMotd no

# ── SFTP ─────────────────────────────────────────────────────────────────────
Subsystem sftp /usr/lib/openssh/sftp-server
SSHD

    # ─── Create login banner ───────────────────────────────────────────────────
    cat > /etc/ssh/banner << 'BANNER'

  ╔═══════════════════════════════════════════════════════════════╗
  ║           ⚠️   AUTHORIZED ACCESS ONLY   ⚠️                    ║
  ║                                                               ║
  ║  This system is for authorized users only. All connections   ║
  ║  are monitored and logged. Unauthorized access will be        ║
  ║  reported to law enforcement.                                 ║
  ╚═══════════════════════════════════════════════════════════════╝

BANNER

    # ─── MOTD ─────────────────────────────────────────────────────────────────
    cat > /etc/motd << 'MOTD'

  Production Server — Unauthorized access strictly prohibited.

MOTD

    # Disable dynamic MOTD scripts (Ubuntu)
    chmod -x /etc/update-motd.d/* 2>/dev/null || true

    # ─── Validate and restart sshd ────────────────────────────────────────────
    if sshd -t -f "$sshd_config"; then
        success "SSH configuration validated"
        systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null \
            || warn "Could not restart SSH — please restart manually"
        success "SSH service restarted on port ${SSH_PORT}"
    else
        error "SSH configuration is INVALID — restoring backup"
        cp "${sshd_config}.bak.$(date +%Y%m%d)" "$sshd_config" 2>/dev/null || true
        fatal "Check /etc/ssh/sshd_config manually"
    fi

    # ─── SSH client hardening ─────────────────────────────────────────────────
    cat > /etc/ssh/ssh_config << 'SSH_CLIENT'
Host *
    ServerAliveInterval 120
    ServerAliveCountMax 3
    HashKnownHosts yes
    StrictHostKeyChecking ask
    IdentitiesOnly yes
    AddressFamily inet
SSH_CLIENT

    success "SSH hardening complete"
}
