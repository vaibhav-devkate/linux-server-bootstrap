#!/usr/bin/env bash
# =============================================================================
# MODULE: Final Report & Verification
# =============================================================================

module_report() {
    section "SETUP VERIFICATION & FINAL REPORT"

    local ok=0
    local warn_count=0
    local fail=0

    # Helper function: Check if command succeeds and print its description
    # Why: DRY (Don't Repeat Yourself) principle. Condenses testing system states into readable 1-liners.
    # What it does: Runs 'cmd' passed as a string, and increments a counter based on whether it exits 0 (success) or >0 (fail).
    _check() {
        local desc="$1"     # Description of what we are checking
        local cmd="$2"      # Command to evaluate (returns 0 on success)
        
        if eval "$cmd" > /dev/null 2>&1; then
            echo -e "    ${GREEN}✅  ${desc}${RESET}"
            # Print visually appealing subcommand
            echo -e "        ${DIM}Cmd: ${cmd}${RESET}"
            ((ok++))
        else
            echo -e "    ${RED}❌  ${desc}${RESET}"
            echo -e "        ${DIM}Cmd: ${cmd}${RESET}"
            ((fail++))
        fi
    }

    _warn_check() {
        local desc="$1"
        local cmd="$2"
        if eval "$cmd" > /dev/null 2>&1; then
            echo -e "    ${GREEN}✅  ${desc}${RESET}"
            echo -e "        ${DIM}Cmd: ${cmd}${RESET}"
            ((ok++))
        else
            echo -e "    ${YELLOW}⚠️   ${desc} (non-critical)${RESET}"
            echo -e "        ${DIM}Cmd: ${cmd}${RESET}"
            ((warn_count++))
        fi
    }

    echo ""
    echo -e "  ${CYAN}${BOLD}[ 01 - System Update & Base Config ]${RESET}"
    _check "Verify Hostname is correctly set"                 "hostname | grep -q '${HOSTNAME}'"
    _check "Verify Timezone is correctly configured"          "timedatectl | grep -q '${TIMEZONE}'"
    _check "Verify NTP time synchronization is active"        "timedatectl show --property=NTP | grep -q 'yes'"
    _check "Verify somaxconn kernel parameter is applied"      "sysctl net.core.somaxconn | grep -q '65535'"
    _check "Verify ulimit open files limit is configured"     "cat /etc/security/limits.d/99-production.conf | grep -q 'nofile'"
    _check "Verify all system packages are upgraded"          "apt-get -s upgrade | grep -q '0 upgraded'"

    echo ""
    echo -e "  ${CYAN}${BOLD}[ 02 - User Management ]${RESET}"
    _check "Verify non-root admin user exists"                "id '${ADMIN_USER}'"
    _check "Verify admin user belongs to the sudo group"      "groups '${ADMIN_USER}' | grep -q '\\bsudo\\b'"
    _check "Verify root account is strictly locked"           "passwd -S root | grep -qE 'L|LK'"
    _check "Verify .ssh directory exists for admin user"      "[ -d '/home/${ADMIN_USER}/.ssh' ]"
    _check "Verify .ssh directory has secure 700 permissions" "stat -c '%a' '/home/${ADMIN_USER}/.ssh' | grep -q '700'"
    
    # Check Least Privilege Roles
    _check "Verify application user exists"                   "id '${APP_USER}'"
    _check "Verify application user has NO sudo access"       "! groups '${APP_USER}' | grep -q '\\bsudo\\b'"
    _check "Verify database service admin exists"             "id '${DB_ADMIN_USER}'"
    _check "Verify database admin has nologin shell"          "grep '^${DB_ADMIN_USER}:' /etc/passwd | grep -q '/usr/sbin/nologin'"

    echo ""
    echo -e "  ${CYAN}${BOLD}[ 03 - SSH Hardening ]${RESET}"
    _check "Verify SSH service is actively running"           "systemctl is-active ssh || systemctl is-active sshd"
    _check "Verify SSH is bound to the custom configured port" "ss -tlnp | grep -q ':${SSH_PORT}'"
    _check "Verify RootLogin is explicitly disabled in sshd"  "sshd -T 2>/dev/null | grep -i 'permitrootlogin no'"
    _check "Verify PasswordAuthentication is disabled"        "sshd -T 2>/dev/null | grep -i 'passwordauthentication no'"

    echo ""
    echo -e "  ${CYAN}${BOLD}[ 04 - Firewall (UFW) ]${RESET}"
    _check "Verify UFW firewall is active and enabled"        "ufw status | grep -q 'Status: active'"
    _check "Verify default policy blocks all incoming traffic" "ufw status verbose | grep -q 'deny (incoming)'"
    _check "Verify SSH custom port is explicitly allowed"     "ufw status | grep -q '${SSH_PORT}'"
    _check "Verify common attack vector (port 23/telnet) is blocked" "ufw status | grep -E -q '23/tcp.*DENY'"

    echo ""
    echo -e "  ${CYAN}${BOLD}[ 05 - Security Services ]${RESET}"
    _check "Verify Fail2Ban intrusion prevention is running"  "systemctl is-active fail2ban"
    _check "Verify sshd jail is active in Fail2Ban"           "fail2ban-client status | grep -q sshd"
    _warn_check "Verify Auditd is recording system events"    "systemctl is-active auditd"
    _warn_check "Verify AppArmor MAC framework is active"     "systemctl is-active apparmor"

    echo ""
    echo -e "  ${CYAN}${BOLD}[ 06 - Packages ]${RESET}"
    _check "Verify curl utility is installed"                 "command -v curl"
    _check "Verify git version control is installed"          "command -v git"
    _check "Verify vim editor is installed"                   "command -v vim"
    _check "Verify htop process monitor is installed"         "command -v htop"
    _warn_check "Verify Docker engine is installed"           "command -v docker"

    echo ""
    echo -e "  ${CYAN}${BOLD}[ 07 - Storage ]${RESET}"
    _warn_check "Verify swap space is active and mounted"     "swapon --show | grep -q swapfile"
    _warn_check "Verify sufficient root disk space (> 10GB free)" "df / | awk 'NR==2 {exit (\$4 > 10*1024*1024) ? 0 : 1}'"

    # ─── Print summary ────────────────────────────────────────────────────────
    local total=$(( ok + warn_count + fail ))
    echo ""
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}CHECK SUMMARY${RESET}:  ${GREEN}${ok} passed${RESET}  ${YELLOW}${warn_count} warnings${RESET}  ${RED}${fail} failed${RESET}  (${total} total)"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # ─── Connection info ──────────────────────────────────────────────────────
    # Why: Quickly instructs developers how to log in after the script completes.
    # What it does: Fetches the public IP address via external APIs and prints out the final connection command alongside where secrets are kept.
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
    # Why: Historical trace. Future administrators need to know when and how the server was bootstrapped.
    # What it does: Dumps the summarized variables and outcomes into a restricted /root/vm-setup-report.txt file.
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
        echo "Check log file for exact command outputs."
        echo ""
        echo "Connect: ssh -p ${SSH_PORT} ${ADMIN_USER}@${public_ip}"
    } > "$report_file"
    chmod 600 "$report_file"
    success "Report saved to: $report_file"

    # ─── Slack / email notification ───────────────────────────────────────────
    # Why: Teams administering multiple servers via CI/CD pipelines require automated callbacks when deployment finishes.
    # What it does: Sends a formatted JSON payload containing server readiness explicitly to a mapped SLACK_WEBHOOK.
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
