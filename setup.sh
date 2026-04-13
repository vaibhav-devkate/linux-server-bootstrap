#!/usr/bin/env bash
# =============================================================================
#
#   ██████╗ ███████╗██████╗ ██╗   ██╗███████╗██████╗     ███████╗███████╗████████╗██╗   ██╗██████╗
#  ██╔════╝ ██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
#  ███████╗ █████╗  ██████╔╝██║   ██║█████╗  ██████╔╝    ███████╗█████╗     ██║   ██║   ██║██████╔╝
#  ╚════██║ ██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝
#  ███████║ ███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║    ███████║███████╗   ██║   ╚██████╔╝██║
#  ╚══════╝ ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝
#
#   Production Server Setup Script — Parallel, Secure, Production-Ready
#   Author:  vm-setup
#   Version: 2.0.0
#
#   Usage:
#     sudo ./setup.sh [OPTIONS]
#
#   Options:
#     --config <file>      Path to config file (default: ./config.env)
#     --ssh-key <pubkey>   SSH public key string to add
#     --skip-update        Skip system update step
#     --skip-packages      Skip package installation step
#     --skip-security      Skip security hardening step
#     --skip-firewall      Skip firewall configuration step
#     --only <module>      Run only this module (e.g. --only security)
#     --dry-run            Show what would be done without executing
#     --yes                Skip confirmation prompts
#     -h, --help           Show this help message
#
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ── Script directory ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_START=$(date +%s)

# ── Source libraries ──────────────────────────────────────────────────────────
source "${SCRIPT_DIR}/lib/colors.sh"
source "${SCRIPT_DIR}/lib/parallel.sh"

# ── Default options ───────────────────────────────────────────────────────────
CONFIG_FILE="${SCRIPT_DIR}/config.env"
SKIP_UPDATE=false
SKIP_PACKAGES=false
SKIP_SECURITY=false
SKIP_FIREWALL=false
ONLY_MODULE=""
DRY_RUN=false
AUTO_YES=false

# ─────────────────────────────────────────────────────────────────────────────
# Parse CLI arguments
# ─────────────────────────────────────────────────────────────────────────────
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config)        CONFIG_FILE="$2"; shift 2 ;;
            --ssh-key)       CLI_SSH_PUBKEY="$2"; shift 2 ;;
            --skip-update)   SKIP_UPDATE=true; shift ;;
            --skip-packages) SKIP_PACKAGES=true; shift ;;
            --skip-security) SKIP_SECURITY=true; shift ;;
            --skip-firewall) SKIP_FIREWALL=true; shift ;;
            --only)          ONLY_MODULE="$2"; shift 2 ;;
            --dry-run)       DRY_RUN=true; shift ;;
            --yes|-y)        AUTO_YES=true; shift ;;
            -h|--help)       _print_help; exit 0 ;;
            *)               fatal "Unknown option: $1 (run with --help)" ;;
        esac
    done
}

_print_help() {
    echo ""
    echo -e "${BOLD}Usage:${RESET}  sudo ./setup.sh [OPTIONS]"
    echo ""
    echo -e "${BOLD}Options:${RESET}"
    echo "  --config <file>      Config file path (default: ./config.env)"
    echo "  --ssh-key <key>      SSH public key to add to admin user"
    echo "  --skip-update        Skip OS update step"
    echo "  --skip-packages      Skip package installation"
    echo "  --skip-security      Skip security hardening"
    echo "  --skip-firewall      Skip firewall configuration"
    echo "  --only <name>        Run only one module"
    echo "                       Names: update | users | ssh | firewall | security | packages | storage"
    echo "  --dry-run            Show plan without executing"
    echo "  --yes                Skip confirmation prompts"
    echo "  -h, --help           Show this help"
    echo ""
    echo -e "${BOLD}Examples:${RESET}"
    echo "  sudo ./setup.sh --ssh-key 'ssh-ed25519 AAAA...'"
    echo "  sudo ./setup.sh --only security"
    echo "  sudo ./setup.sh --skip-update --yes"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Pre-flight checks
# ─────────────────────────────────────────────────────────────────────────────
preflight() {
    # Must run as root
    if [[ $EUID -ne 0 ]]; then
        fatal "This script must be run as root.\n  Try: sudo $0 $*"
    fi

    # Must be Debian/Ubuntu
    if ! command -v apt-get &>/dev/null; then
        fatal "This script requires a Debian/Ubuntu-based system (apt-get not found)"
    fi

    # Load config file
    if [[ ! -f "$CONFIG_FILE" ]]; then
        fatal "Config file not found: $CONFIG_FILE\n  Create or copy config.env and edit it"
    fi

    # Prompt user to edit the config file if not in AUTO_YES mode
    if [[ "$AUTO_YES" == false ]]; then
        echo -ne "${YELLOW}${BOLD}  Have you edited the config file at ${CONFIG_FILE}? [y/N]:${RESET} "
        read -r edit_ans
        if [[ ! "$edit_ans" =~ ^[Yy]$ ]]; then
            info "Opening config file in editor..."
            sleep 1
            ${EDITOR:-nano} "$CONFIG_FILE" || fatal "Editor exited with error"
            info "Config edited, continuing setup..."
        fi
    fi

    source "$CONFIG_FILE"

    # CLI overrides
    [[ -n "${CLI_SSH_PUBKEY:-}" ]] && SSH_PUBKEY="$CLI_SSH_PUBKEY"

    # Ensure log file is writable
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"

    info "Configuration loaded: $CONFIG_FILE"
    info "Log file: $LOG_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Show setup plan
# ─────────────────────────────────────────────────────────────────────────────
show_plan() {
    echo ""
    echo -e "${BLUE}${BOLD}  SETUP PLAN${RESET}"
    echo -e "  ${DIM}────────────────────────────────────────────────────${RESET}"
    echo -e "  Hostname      : ${WHITE}${HOSTNAME}${RESET}"
    echo -e "  Admin User    : ${WHITE}${ADMIN_USER}${RESET}"
    echo -e "  SSH Port      : ${WHITE}${SSH_PORT}${RESET}"
    echo -e "  Firewall      : ${WHITE}UFW — allow ports: ${SSH_PORT}, ${OPEN_PORTS}${RESET}"
    echo -e "  Swap          : ${WHITE}${SWAP_SIZE_GB}GB${RESET}"
    echo -e "  Auto Updates  : ${WHITE}${ENABLE_AUTO_UPDATES}${RESET}"
    echo -e "  Docker        : ${WHITE}${INSTALL_DOCKER}${RESET}"
    echo -e "  Password Auth : ${WHITE}${ALLOW_PASSWORD_AUTH}${RESET}"
    local key_status="${YELLOW}⚠ Not configured (add SSH key!)${RESET}"
    [[ -n "$SSH_PUBKEY" ]] && key_status="${GREEN}✓ Configured${RESET}"
    echo -e "  SSH Public Key: $key_status"
    echo ""

    echo -e "  ${BOLD}Modules:${RESET}"
    [[ "$SKIP_UPDATE"   == false ]] && echo -e "    ${GREEN}●${RESET} System update & kernel hardening"  || echo -e "    ${GRAY}○${RESET} System update (${YELLOW}SKIPPED${RESET})"
    [[ "$SKIP_PACKAGES" == false ]] && echo -e "    ${GREEN}●${RESET} Parallel package installation"     || echo -e "    ${GRAY}○${RESET} Packages (${YELLOW}SKIPPED${RESET})"
    echo -e "    ${GREEN}●${RESET} User management & SSH keys"
    echo -e "    ${GREEN}●${RESET} SSH hardening"
    [[ "$SKIP_FIREWALL" == false ]] && echo -e "    ${GREEN}●${RESET} Firewall (UFW)"         || echo -e "    ${GRAY}○${RESET} Firewall (${YELLOW}SKIPPED${RESET})"
    [[ "$SKIP_SECURITY" == false ]] && echo -e "    ${GREEN}●${RESET} Security hardening"     || echo -e "    ${GRAY}○${RESET} Security (${YELLOW}SKIPPED${RESET})"
    echo -e "    ${GREEN}●${RESET} Storage & swap"
    echo -e "    ${GREEN}●${RESET} Verification & report"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}${BOLD}  DRY RUN MODE — No changes will be made${RESET}"
        echo ""
        exit 0
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Confirm prompt
# ─────────────────────────────────────────────────────────────────────────────
confirm() {
    if [[ "$AUTO_YES" == true ]]; then
        return
    fi
    echo -ne "${YELLOW}${BOLD}  Proceed with setup? [y/N]:${RESET} "
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
}

# ─────────────────────────────────────────────────────────────────────────────
# Source and run a module
# ─────────────────────────────────────────────────────────────────────────────
run_module() {
    local module_file="$1"
    local module_fn="$2"

    if [[ ! -f "$module_file" ]]; then
        error "Module file not found: $module_file"
        return 1
    fi

    source "$module_file"
    $module_fn
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"
    preflight

    # Display banner
    banner

    # Show configuration
    show_plan

    # Confirm
    confirm

    local modules_dir="${SCRIPT_DIR}/modules"

    # ── Single module mode ────────────────────────────────────────────────────
    if [[ -n "$ONLY_MODULE" ]]; then
        case "$ONLY_MODULE" in
            update)   run_module "${modules_dir}/01-system-update.sh"  "module_system_update" ;;
            users)    run_module "${modules_dir}/02-user-management.sh" "module_user_management" ;;
            ssh)      run_module "${modules_dir}/03-ssh-hardening.sh"   "module_ssh_hardening" ;;
            firewall) run_module "${modules_dir}/04-firewall.sh"        "module_firewall" ;;
            security) run_module "${modules_dir}/05-security.sh"        "module_security" ;;
            packages) run_module "${modules_dir}/06-install-packages.sh" "module_install_packages" ;;
            storage)  run_module "${modules_dir}/07-storage.sh"         "module_storage" ;;
            report)   run_module "${modules_dir}/08-report.sh"          "module_report" ;;
            *) fatal "Unknown module: $ONLY_MODULE" ;;
        esac
        exit 0
    fi

    # ── Full setup sequence ───────────────────────────────────────────────────

    # 1. System update (MUST run sequentially - holds dpkg locks)
    if [[ "$SKIP_UPDATE" == false ]]; then
        run_module "${modules_dir}/01-system-update.sh" "module_system_update"
    fi

    # ── Simultaneous Tasks ────────────────────────────────────────────────────
    # Start Storage/Swap preparation simultaneously in the background.
    # Why: Does not rely on apt or network, so it can run alongside package installs.
    info "Starting Storage & Swap configuration in background..."
    ( run_module "${modules_dir}/07-storage.sh" "module_storage" ) &
    STORAGE_PID=$!

    # ── Sequential Tasks ──────────────────────────────────────────────────────
    # 2. Install packages (MUST run sequentially - tools needed by 03,04,05)
    if [[ "$SKIP_PACKAGES" == false ]]; then
        run_module "${modules_dir}/06-install-packages.sh" "module_install_packages"
    fi

    # 3. User management (MUST run sequentially - required by SSH setup)
    run_module "${modules_dir}/02-user-management.sh" "module_user_management"

    # 4. SSH hardening (MUST run sequentially - depends on users, prevents lockdown)
    run_module "${modules_dir}/03-ssh-hardening.sh" "module_ssh_hardening"

    # 5. Firewall (MUST run sequentially - relies on packages)
    if [[ "$SKIP_FIREWALL" == false ]]; then
        run_module "${modules_dir}/04-firewall.sh" "module_firewall"
    fi

    # 6. Security hardening (MUST run sequentially - relies on firewall/packages)
    if [[ "$SKIP_SECURITY" == false ]]; then
        run_module "${modules_dir}/05-security.sh" "module_security"
    fi

    # Wait for the background Storage task to finish
    info "Waiting for simultaneous tasks to complete..."
    wait $STORAGE_PID

    # 8. Final report (MUST run sequentially - must be last to summarize)
    run_module "${modules_dir}/08-report.sh" "module_report"

    # ── Total elapsed time ────────────────────────────────────────────────────
    local end_time; end_time=$(date +%s)
    local elapsed=$(( end_time - SETUP_START ))
    local mins=$(( elapsed / 60 ))
    local secs=$(( elapsed % 60 ))

    echo ""
    echo -e "${GREEN}${BOLD}  ✅  Setup complete in ${mins}m ${secs}s${RESET}"
    echo ""
    echo -e "${YELLOW}${BOLD}  ⚠️   IMPORTANT: Test SSH on port ${SSH_PORT} before closing this session!${RESET}"
    echo ""

    log "INFO" "Setup completed in ${mins}m ${secs}s"
}

# ── Trap errors ───────────────────────────────────────────────────────────────
trap 'echo -e "\n${RED}${BOLD}  ERROR at line $LINENO — check ${LOG_FILE}${RESET}\n" >&2' ERR

main "$@"
