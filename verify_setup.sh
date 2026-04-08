#!/usr/bin/env bash
# =============================================================================
# Automated setup verification script
# =============================================================================

set -euo pipefail

# Try loading the config
CONFIG_FILE="./config/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Config file not found. Run this from the root of the linux-server-bootstrap project."
    exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

pass=0
fail=0

assert_command() {
    local desc="$1"
    local run_cmd="$2"
    if eval "$run_cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}[PASS]${NC} $desc"
        ((pass++))
    else
        echo -e "${RED}[FAIL]${NC} $desc"
        ((fail++))
    fi
}

echo "=== Running post-installation verification tests ==="

# 1. System state
assert_command "Hostname is $HOSTNAME" "hostname | grep -q '^${HOSTNAME}$'"
assert_command "Timezone is $TIMEZONE" "timedatectl | grep -q '$TIMEZONE'"

# 2. Users (Least Privilege Roles)
assert_command "Admin user ($ADMIN_USER) exists" "id $ADMIN_USER"
assert_command "Admin user is in sudo group" "groups $ADMIN_USER | grep -q '\\bsudo\\b'"

assert_command "App user ($APP_USER) exists" "id $APP_USER"
assert_command "App user has NO sudo access" "! groups $APP_USER | grep -q '\\bsudo\\b'"

assert_command "DB Admin user ($DB_ADMIN_USER) exists" "id $DB_ADMIN_USER"
assert_command "DB Admin user has nologin shell" "grep '^${DB_ADMIN_USER}:' /etc/passwd | grep -q '/usr/sbin/nologin'"

# 3. SSH
assert_command "SSH is listening on $SSH_PORT" "ss -tlnp | grep -q ':$SSH_PORT '"

# 4. Firewall
assert_command "UFW is active" "ufw status | grep -q 'active'"
assert_command "Custom SSH port $SSH_PORT is allowed" "ufw status | grep -q '$SSH_PORT'"

echo ""
echo "=== Summary ==="
echo "Passed: $pass"
echo "Failed: $fail"

if [ "$fail" -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed successfully!${NC}"
    exit 0
fi
