#!/usr/bin/env bash
# =============================================================================
# COLORS & FORMATTING LIBRARY
# =============================================================================

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Icons
ICON_OK="✅"
ICON_FAIL="❌"
ICON_WARN="⚠️ "
ICON_INFO="ℹ️ "
ICON_ROCKET="🚀"
ICON_LOCK="🔒"
ICON_GEAR="⚙️ "
ICON_FIRE="🔥"
ICON_CLOCK="⏱️ "

# ─────────────────────────────────────────────────────────────────────────────
# Logging functions
# ─────────────────────────────────────────────────────────────────────────────

LOG_FILE="${LOG_FILE:-/var/log/vm-setup.log}"

_timestamp() { date "+%Y-%m-%d %H:%M:%S"; }

log() {
    local level="$1"; shift
    local msg="$*"
    local ts; ts=$(_timestamp)
    echo "[$ts] [$level] $msg" >> "$LOG_FILE" 2>/dev/null || true
}

info() {
    echo -e "${CYAN}${ICON_INFO}  ${WHITE}$*${RESET}"
    log "INFO" "$*"
}

success() {
    echo -e "${GREEN}${ICON_OK}  ${GREEN}$*${RESET}"
    log "INFO" "[SUCCESS] $*"
}

warn() {
    echo -e "${YELLOW}${ICON_WARN} ${YELLOW}$*${RESET}"
    log "WARN" "$*"
}

error() {
    echo -e "${RED}${ICON_FAIL}  ${RED}$*${RESET}" >&2
    log "ERROR" "$*"
}

fatal() {
    echo -e "${RED}${BOLD}${ICON_FAIL}  FATAL: $*${RESET}" >&2
    log "ERROR" "FATAL: $*"
    exit 1
}

section() {
    echo ""
    echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${MAGENTA}${BOLD}  $ICON_GEAR  $*${RESET}"
    echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    log "INFO" "=== $* ==="
}

banner() {
    echo -e "${BLUE}${BOLD}"
    cat << 'EOF'
  ██████╗ ███████╗██████╗ ██╗   ██╗███████╗██████╗     ███████╗███████╗████████╗██╗   ██╗██████╗
 ██╔════╝ ██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
 ███████╗ █████╗  ██████╔╝██║   ██║█████╗  ██████╔╝    ███████╗█████╗     ██║   ██║   ██║██████╔╝
 ╚════██║ ██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝
 ███████║ ███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║    ███████║███████╗   ██║   ╚██████╔╝██║
 ╚══════╝ ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝

  Production-Ready Server Configuration Script
  ─────────────────────────────────────────────────────────────────
EOF
    echo -e "${RESET}"
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local msg="${2:-Working...}"
    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "  ${CYAN}${spinstr:0:1}${RESET}  ${DIM}%s${RESET}\r" "$msg"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    tput cnorm 2>/dev/null || true
    printf "                                                  \r"
}
