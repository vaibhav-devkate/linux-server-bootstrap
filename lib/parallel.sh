#!/usr/bin/env bash
# =============================================================================
# PARALLEL JOB RUNNER LIBRARY
# =============================================================================
# Runs multiple tasks concurrently and collects results

PARALLEL_STATUS_DIR=""
PARALLEL_JOBS=()
PARALLEL_NAMES=()

# Initialize parallel job tracking
parallel_init() {
    PARALLEL_STATUS_DIR=$(mktemp -d /tmp/vm-setup-parallel.XXXXXX)
    PARALLEL_JOBS=()
    PARALLEL_NAMES=()
}

# Add a job to the parallel queue
# Usage: parallel_add "Job Name" "command to run"
parallel_add() {
    local name="$1"
    local cmd="$2"
    local id="${#PARALLEL_JOBS[@]}"
    local status_file="$PARALLEL_STATUS_DIR/job_${id}.status"
    local output_file="$PARALLEL_STATUS_DIR/job_${id}.output"

    echo "RUNNING" > "$status_file"

    (
        if eval "$cmd" >> "$output_file" 2>&1; then
            echo "SUCCESS" > "$status_file"
        else
            echo "FAILED" > "$status_file"
        fi
    ) &

    PARALLEL_JOBS+=($!)
    PARALLEL_NAMES+=("$name")
}

# Wait for all parallel jobs and report results
parallel_wait() {
    local total=${#PARALLEL_JOBS[@]}
    local done_count=0
    local failed=0
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    echo ""
    echo -e "  ${CYAN}${BOLD}Running ${total} tasks in parallel...${RESET}"
    echo ""

    # Show live progress
    while true; do
        done_count=0
        for id in "${!PARALLEL_JOBS[@]}"; do
            local status_file="$PARALLEL_STATUS_DIR/job_${id}.status"
            local status; status=$(cat "$status_file" 2>/dev/null || echo "RUNNING")
            [[ "$status" != "RUNNING" ]] && ((done_count++))
        done

        # Print progress bar
        local pct=$(( done_count * 100 / total ))
        local bar_done=$(( done_count * 40 / total ))
        local bar_left=$(( 40 - bar_done ))
        local bar=""
        for ((i=0; i<bar_done; i++)); do bar+="█"; done
        for ((i=0; i<bar_left; i++)); do bar+="░"; done

        local temp=${spinstr#?}
        printf "  ${CYAN}${spinstr:0:1}${RESET}  [${GREEN}%s${GRAY}%s${RESET}] ${WHITE}%d%%${RESET} (%d/%d done)\r" \
            "$bar" "" "$pct" "$done_count" "$total"
        spinstr=$temp${spinstr%"$temp"}

        [[ $done_count -eq $total ]] && break
        sleep 0.2
    done

    printf "                                                                                  \r"
    echo ""

    # Print results
    for id in "${!PARALLEL_JOBS[@]}"; do
        local name="${PARALLEL_NAMES[$id]}"
        local status_file="$PARALLEL_STATUS_DIR/job_${id}.status"
        local output_file="$PARALLEL_STATUS_DIR/job_${id}.output"
        local status; status=$(cat "$status_file" 2>/dev/null || echo "UNKNOWN")

        if [[ "$status" == "SUCCESS" ]]; then
            echo -e "    ${GREEN}✅  ${name}${RESET}"
        else
            echo -e "    ${RED}❌  ${name}${RESET}"
            echo -e "    ${DIM}    Output:${RESET}"
            tail -5 "$output_file" 2>/dev/null | sed 's/^/        /'
            ((failed++))
        fi
        wait "${PARALLEL_JOBS[$id]}" 2>/dev/null || true
    done

    echo ""

    # Cleanup
    rm -rf "$PARALLEL_STATUS_DIR"

    if [[ $failed -gt 0 ]]; then
        warn "$failed of $total parallel tasks failed"
        return 1
    fi

    success "All $total parallel tasks completed successfully"
    return 0
}

# Install a list of packages (helper for parallel use)
install_packages() {
    local packages=("$@")
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}" \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confnew" \
        2>&1
}
