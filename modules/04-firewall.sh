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
    # Why: Clears any pre-existing or default vendor rules to ensure a pristine slate.
    # What it does: Forces a reset of Uncomplicated Firewall (UFW) rules and configurations.
    info "Resetting firewall to defaults..."
    ufw --force reset > /dev/null 2>&1

    # ─── Default policies ─────────────────────────────────────────────────────
    # Why: The deny-by-default stance ensures no unexpected ports are exposed to the public internet.
    # What it does: Configures UFW to block all incoming traffic while allowing outgoing connections and denying routing (forward).
    ufw default deny incoming
    ufw default allow outgoing
    ufw default deny forward
    success "Default policies: DENY incoming, ALLOW outgoing"

    # ─── IPv6 ─────────────────────────────────────────────────────────────────
    # Why: Aligning firewall capabilities with whether the server utilizes IPv6 prevents loopbacks or unbound traffic.
    # What it does: Toggles IPv6 processing natively within the UFW configuration based on the environment variables.
    if [[ "$ENABLE_IPV6" == true ]]; then
        sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw
        info "IPv6 firewall support enabled"
    else
        sed -i 's/^IPV6=.*/IPV6=no/' /etc/default/ufw
        info "IPv6 firewall support disabled"
    fi

    # ─── SSH rule ─────────────────────────────────────────────────────────────
    # Why: Opening SSH is necessary so we are not locked out after enabling the firewall. Can optionally restrict to a whitelist.
    # What it does: Parses ALLOWED_SSH_IPS to add specific rules or opens the SSH_PORT globally if undefined.
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
    # Why: Mitigates automated brute-force attacks against the SSH port.
    # What it does: Limits connections to 6 within 30 seconds for the specified SSH port.
    ufw limit "${SSH_PORT}/tcp" comment "SSH rate limit"
    success "SSH rate limiting enabled"

    # ─── Open additional ports ────────────────────────────────────────────────
    # Why: Expose additional services (like HTTP/80 or HTTPS/443) dictated by configuration.
    # What it does: Parses a comma-separated list of OPEN_PORTS and applies UFW allow rules.
    if [[ -n "$OPEN_PORTS" ]]; then
        IFS=',' read -ra ports <<< "$OPEN_PORTS"
        for port in "${ports[@]}"; do
            port=$(echo "$port" | tr -d ' ')
            ufw allow "${port}" comment "vm-setup opened port"
            success "Port opened: $port"
        done
    fi

    # ─── Block known bad ports ────────────────────────────────────────────────
    # Why: Prevents accidental exposure of insecure services running locally or via Docker.
    # What it does: Explicitly denies traffic on ports tied to common vulnerabilities (e.g. Samba, Telnet, Default SSH).
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
    # Why: Basic UFW rules do not protect against malformed packets or ICMP (Ping) flooding.
    # What it does: Injects native iptables rules via before.rules.d to drop invalid packets and rate-limit pings.
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
    # Why: Activates the previously defined policies directly on the network interface.
    # What it does: Force-enables UFW so the changes take effect immediately without prompts.
    ufw --force enable
    success "UFW firewall enabled"

    # ─── Status output ────────────────────────────────────────────────────────
    echo ""
    echo -e "${CYAN}${BOLD}  Firewall Rules Summary:${RESET}"
    ufw status numbered | sed 's/^/    /'

    # ─── Also configure iptables persistence ──────────────────────────────────
    # Why: Ensures that custom direct iptables rules (e.g., our port scan protection) persist across reboots.
    # What it does: Uses netfilter-persistent to save the current routing table state.
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save > /dev/null 2>&1 && \
            success "iptables rules saved persistently"
    fi

    success "Firewall configuration complete"
}
