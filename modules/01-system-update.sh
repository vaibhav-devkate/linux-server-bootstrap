#!/usr/bin/env bash
# =============================================================================
# MODULE: System Update & Base Configuration
# =============================================================================

module_system_update() {
    section "SYSTEM UPDATE & BASE CONFIGURATION"

    # Set hostname
    info "Setting hostname to: ${HOSTNAME}"
    hostnamectl set-hostname "$HOSTNAME" || warn "Could not set hostname"
    echo "127.0.1.1  ${HOSTNAME}" >> /etc/hosts

    # Set timezone
    info "Setting timezone: ${TIMEZONE}"
    timedatectl set-timezone "$TIMEZONE" 2>/dev/null \
        || ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime

    # Sync hardware clock
    timedatectl set-ntp true 2>/dev/null || true

    # Set locale
    info "Setting locale: ${LOCALE}"
    locale-gen "$LOCALE" 2>/dev/null || true
    update-locale LANG="$LOCALE" 2>/dev/null || true

    # Configure sysctl for production performance + security
    info "Applying kernel sysctl hardening..."
    cat > /etc/sysctl.d/99-vm-production.conf << 'SYSCTL'
# ── Network Performance ────────────────────────────────────────────────
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65536
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# ── Security Hardening ─────────────────────────────────────────────────
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 0

# ── IPv6 ───────────────────────────────────────────────────────────────
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_ra = 0

# ── Kernel ─────────────────────────────────────────────────────────────
kernel.randomize_va_space = 2
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.sysrq = 0

# ── File system ────────────────────────────────────────────────────────
fs.file-max = 2097152
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
vm.swappiness = 10
vm.dirty_ratio = 60
vm.dirty_background_ratio = 2
SYSCTL

    sysctl -p /etc/sysctl.d/99-vm-production.conf > /dev/null 2>&1 || true
    success "Kernel parameters applied"

    # Limits
    info "Configuring system limits..."
    cat > /etc/security/limits.d/99-production.conf << 'LIMITS'
* soft nofile 1048576
* hard nofile 1048576
* soft nproc  65536
* hard nproc  65536
root soft nofile 1048576
root hard nofile 1048576
LIMITS

    # Update apt & do full upgrade
    info "Updating package lists..."
    apt-get update -qq

    info "Upgrading packages..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confnew"

    info "Running dist-upgrade..."
    DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -qq \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confnew"

    apt-get autoremove -y -qq
    apt-get autoclean -qq

    success "System fully updated"
}
