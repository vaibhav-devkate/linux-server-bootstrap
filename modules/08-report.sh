#!/usr/bin/env bash
# =============================================================================
# MODULE: Final Report & Verification
# =============================================================================

module_report() {
    section "SETUP VERIFICATION & FINAL REPORT"

    local ok=0
    local warn_count=0
    local fail=0

    _check() {
        local label="$1"
        local cmd="$2"
        local expected="${3:-0}"

        if eval "$cmd" > /dev/null 2>&1; then
            echo -e "    ${GREEN}✅  ${label}${RESET}"
            ((ok++))
        else
            echo -e "    ${RED}❌  ${label}${RESET}"
            ((fail++))
        fi
    }

    _warn_check() {
        local label="$1"
        local cmd="$2"
        if eval "$cmd" > /dev/null 2>&1; then
            echo -e "    ${GREEN}✅  ${label}${RESET}"
            ((ok++))
        else
            echo -e "    ${YELLOW}⚠️   ${label} (non-critical)${RESET}"
            ((warn_count++))
        fi
    }

    echo ""
    echo -e "  ${CYAN}${BOLD}[ System ]${RESET}"
    _check "Hostname set"             "hostname | grep -q '${HOSTNAME}'"
    _check "Timezone configured"      "timedatectl | grep -q '${TIMEZONE}'"
    _check "System fully updated"     "apt-get -s upgrade | grep -q '0 upgraded'"

    echo ""
    echo -e "  ${CYAN}${BOLD}[ Users & SSH ]${RESET}"
    _check "Admin user exists"                "id '${ADMIN_USER}'"
    _check "Admin user in sudo group"         "groups '${ADMIN_USER}' | grep -q sudo"
    _check "Root account locked"              "passwd -S root | grep -qE 'L|LK'"
    _check "SSH service running"              "systemctl is-active ssh || systemctl is-active sshd"
    _check "SSH on custom port"               "ss -tlnp | grep -q ':${SSH_PORT}'"
    _check "SSH public key directory exists"  "[ -d '/home/${ADMIN_USER}/.ssh' ]"

    echo ""
    echo -e "  ${CYAN}${BOLD}[ Firewall ]${RESET}"
    _check "UFW is active"                    "ufw status | grep -q 'Status: active'"
    _check "SSH port allowed"                 "ufw status | grep -q '${SSH_PORT}'"
    _check "Default deny incoming"            "ufw status verbose | grep -q 'deny (incoming)'"

    echo ""
    echo -e "  ${CYAN}${BOLD}[ Security Services ]${RESET}"
    _check "Fail2Ban running"                 "systemctl is-active fail2ban"
    _warn_check "Auditd running"              "systemctl is-active auditd"
    _warn_check "AppArmor running"            "systemctl is-active apparmor"
    _warn_check "Unattended upgrades enabled" "systemctl is-active unattended-upgrades"

    echo ""
    echo -e "  ${CYAN}${BOLD}[ Packages ]${RESET}"
    _check "curl installed"     "command -v curl"
    _check "git installed"      "command -v git"
    _check "vim installed"      "command -v vim"
    _check "htop installed"     "command -v htop"
    _check "jq installed"       "command -v jq"
    _warn_check "Docker installed" "command -v docker"
    _warn_check "Node.js installed" "command -v node"
    _warn_check "Python3 installed" "command -v python3"

    echo ""
    echo -e "  ${CYAN}${BOLD}[ Storage ]${RESET}"
    _warn_check "Swap active"          "swapon --show | grep -q swapfile"
    _warn_check "Disk > 10GB free"     "df / | awk 'NR==2 {exit (\$4 > 10*1024*1024) ? 0 : 1}'"

    # ─── Print summary ────────────────────────────────────────────────────────
    local total=$(( ok + warn_count + fail ))
    echo ""
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}CHECK SUMMARY${RESET}:  ${GREEN}${ok} passed${RESET}  ${YELLOW}${warn_count} warnings${RESET}  ${RED}${fail} failed${RESET}  (${total} total)"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # ─── Connection info ──────────────────────────────────────────────────────
    local public_ip
    public_ip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null \
        || curl -s --max-time 5 https://ifconfig.me 2>/dev/null \
        || echo "<server-ip>")

    echo ""
    echo -e "${CYAN}${BOLD}  🚀  YOUR SERVER IS READY!${RESET}"
    echo ""
    echo -e "  ${BOLD}Connect via SSH:${RESET}"
    echo -e "    ${GREEN}ssh -p ${SSH_PORT} ${ADMIN_USER}@${public_ip}${RESET}"
    echo ""
    echo -e "  ${BOLD}Secrets file:${RESET}  ${YELLOW}/root/vm-setup-secrets.txt${RESET} (read with: sudo cat /root/vm-setup-secrets.txt)"
    echo -e "  ${BOLD}Setup log:${RESET}     ${YELLOW}${LOG_FILE}${RESET}"
    echo ""

    # ─── Save setup report ────────────────────────────────────────────────────
    local report_file="/root/vm-setup-report.txt"
    {
        echo "VM SETUP REPORT"
        echo "Generated: $(date)"
        echo ""
        echo "Hostname:        $HOSTNAME"
        echo "Admin User:      $ADMIN_USER"
        echo "SSH Port:        $SSH_PORT"
        echo "Public IP:       $public_ip"
        echo ""
        echo "Checks: $ok passed / $warn_count warnings / $fail failed"
        echo ""
        echo "Connect: ssh -p ${SSH_PORT} ${ADMIN_USER}@${public_ip}"
    } > "$report_file"
    chmod 600 "$report_file"
    success "Report saved to: $report_file"

    # ─── Slack / email notification ───────────────────────────────────────────
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H 'Content-type: application/json' \
            --data "{\"text\":\"✅ VM Setup Complete!\n*Host:* ${HOSTNAME} | *IP:* ${public_ip}\n*SSH:* \`ssh -p ${SSH_PORT} ${ADMIN_USER}@${public_ip}\`\"}" \
            > /dev/null 2>&1 && success "Slack notification sent"
    fi

    if [[ $fail -gt 0 ]]; then
        warn "Some checks failed. Review the log: ${LOG_FILE}"
        return 1
    fi
    return 0
}
