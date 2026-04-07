#!/usr/bin/env bash
# =============================================================================
# MODULE: Swap Space, Disk & Storage Optimization
# =============================================================================

module_storage() {
    section "STORAGE & SWAP CONFIGURATION"

    # ─── Swap setup ───────────────────────────────────────────────────────────
    if [[ "$ENABLE_SWAP" == true ]]; then
        local swap_file="/swapfile"
        local swap_bytes=$(( SWAP_SIZE_GB * 1024 * 1024 * 1024 ))

        if swapon --show | grep -q "$swap_file"; then
            info "Swap file already active: ${SWAP_SIZE_GB}GB"
        else
            info "Creating ${SWAP_SIZE_GB}GB swap file..."

            # Remove old swap if present
            swapoff "$swap_file" 2>/dev/null || true
            rm -f "$swap_file"

            # Create swap (use fallocate, fall back to dd)
            if fallocate -l "${SWAP_SIZE_GB}G" "$swap_file" 2>/dev/null; then
                success "Swap file created with fallocate"
            else
                warn "fallocate failed, using dd (slower)..."
                dd if=/dev/zero of="$swap_file" bs=1M count=$(( SWAP_SIZE_GB * 1024 )) \
                    status=none
            fi

            chmod 600 "$swap_file"
            mkswap "$swap_file" > /dev/null
            swapon "$swap_file"

            # Persist in fstab
            if ! grep -q "$swap_file" /etc/fstab; then
                echo "${swap_file} none swap sw 0 0" >> /etc/fstab
            fi

            success "${SWAP_SIZE_GB}GB swap created and activated"
        fi

        # Optimal swappiness for production
        sysctl vm.swappiness=10 > /dev/null
        grep -q "^vm.swappiness" /etc/sysctl.conf \
            && sed -i 's/^vm.swappiness.*/vm.swappiness=10/' /etc/sysctl.conf \
            || echo "vm.swappiness=10" >> /etc/sysctl.conf

        success "Swappiness set to 10 (production optimal)"
    fi

    # ─── Log rotation ─────────────────────────────────────────────────────────
    info "Configuring log rotation..."
    cat > /etc/logrotate.d/vm-production << 'LOGROTATE'
/var/log/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    sharedscripts
    delaycompress
    createolddir 755 root root
}

/var/log/vm-setup.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
LOGROTATE
    success "Log rotation configured (14 day retention)"

    # ─── tmpfs for performance ────────────────────────────────────────────────
    info "Mounting tmpfs for /tmp..."
    if ! grep -q 'tmpfs.*\/tmp' /etc/fstab; then
        echo "tmpfs /tmp tmpfs defaults,nosuid,nodev,noexec,mode=1777,size=1G 0 0" >> /etc/fstab
        mount -o remount /tmp 2>/dev/null || true
        success "tmpfs mounted for /tmp (nosuid, nodev, noexec)"
    else
        info "/tmp already configured"
    fi

    # ─── Disk summary ─────────────────────────────────────────────────────────
    echo ""
    echo -e "${CYAN}${BOLD}  Disk & Memory Summary:${RESET}"
    df -h | grep -E '^(/|tmpfs)' | sed 's/^/    /'
    echo ""
    free -h | sed 's/^/    /'
    echo ""

    success "Storage configuration complete"
}
