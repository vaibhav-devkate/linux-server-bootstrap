#!/usr/bin/env bash
# =============================================================================
# MODULE: Firewall (UFW) Configuration
# =============================================================================

module_firewall() {
    section "FIREWALL CONFIGURATION (UFW)"

    # Ensure UFW is installed
    if ! command -v ufw &>/dev/null; then
        info "Installing UFW..."
        apt-get install -y -qq ufw
    fi

    # ─── Reset UFW to clean state ─────────────────────────────────────────────
    info "Resetting firewall to defaults..."
    ufw --force reset > /dev/null 2>&1

    # ─── Default policies ─────────────────────────────────────────────────────
    ufw default deny incoming
    ufw default allow outgoing
    ufw default deny forward
    success "Default policies: DENY incoming, ALLOW outgoing"

    # ─── IPv6 ─────────────────────────────────────────────────────────────────
    if [[ "$ENABLE_IPV6" == true ]]; then
        sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw
        info "IPv6 firewall support enabled"
    else
        sed -i 's/^IPV6=.*/IPV6=no/' /etc/default/ufw
        info "IPv6 firewall support disabled"
    fi

    # ─── SSH rule ─────────────────────────────────────────────────────────────
    if [[ -n "$ALLOWED_SSH_IPS" ]]; then
        # Whitelist-only SSH
        IFS=',' read -ra ssh_ips <<< "$ALLOWED_SSH_IPS"
        for ip in "${ssh_ips[@]}"; do
            ip=$(echo "$ip" | tr -d ' ')
            ufw allow from "$ip" to any port "$SSH_PORT" proto tcp comment "SSH whitelist: $ip"
            success "SSH allowed from: $ip"
        done
        warn "SSH is restricted to whitelisted IPs only"
    else
        ufw allow "${SSH_PORT}/tcp" comment "SSH (vm-setup)"
        success "SSH allowed on port: ${SSH_PORT}"
    fi

    # ─── Rate limiting on SSH ─────────────────────────────────────────────────
    ufw limit "${SSH_PORT}/tcp" comment "SSH rate limit"
    success "SSH rate limiting enabled"

    # ─── Open additional ports ────────────────────────────────────────────────
    if [[ -n "$OPEN_PORTS" ]]; then
        IFS=',' read -ra ports <<< "$OPEN_PORTS"
        for port in "${ports[@]}"; do
            port=$(echo "$port" | tr -d ' ')
            ufw allow "${port}" comment "vm-setup opened port"
            success "Port opened: $port"
        done
    fi

    # ─── Block known bad ports ────────────────────────────────────────────────
    info "Blocking common attack vectors..."
    # Block default SSH port (since we changed it)
    if [[ "$SSH_PORT" != "22" ]]; then
        ufw deny 22/tcp comment "Block default SSH port"
    fi
    # Block telnet
    ufw deny 23/tcp comment "Block telnet"
    # Block FTP
    ufw deny 21/tcp comment "Block FTP"
    # Block Samba
    ufw deny 137/udp comment "Block Samba"
    ufw deny 138/udp comment "Block Samba"
    ufw deny 139/tcp comment "Block Samba"
    ufw deny 445/tcp comment "Block SMB"
    success "Common attack vectors blocked"

    # ─── Port scan protection via iptables ────────────────────────────────────
    info "Adding port scan & flood protection..."
    cat > /etc/ufw/before.rules.d/port-scan-protection << 'IPTABLES'
# Anti-port-scan
*filter
-A INPUT -p tcp --tcp-flags ALL NONE -j DROP
-A INPUT -p tcp --tcp-flags ALL ALL -j DROP
-A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
-A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP

# ICMP flood protection
-A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 5 -j ACCEPT
-A INPUT -p icmp --icmp-type echo-request -j DROP
COMMIT
IPTABLES

    # ─── Enable UFW ───────────────────────────────────────────────────────────
    ufw --force enable
    success "UFW firewall enabled"

    # ─── Status output ────────────────────────────────────────────────────────
    echo ""
    echo -e "${CYAN}${BOLD}  Firewall Rules Summary:${RESET}"
    ufw status numbered | sed 's/^/    /'

    # ─── Also configure iptables persistence ──────────────────────────────────
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save > /dev/null 2>&1 && \
            success "iptables rules saved persistently"
    fi

    success "Firewall configuration complete"
}
