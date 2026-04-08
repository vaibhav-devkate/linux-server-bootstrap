#!/usr/bin/env bash
# =============================================================================
# MODULE: Parallel Package Installation
# =============================================================================

module_install_packages() {
    section "PARALLEL PACKAGE INSTALLATION"

    # Ensure apt is ready
    apt-get update -qq

    info "Starting parallel installation of package groups..."
    parallel_init

    # ─── Build package groups based on config ─────────────────────────────────
    # Why: Installing packages in separate groups helps modularize configurations. Using parallel logic speeds up provisioning drastically.
    # What it does: Reads environment variables and adds corresponding apt install commands to a parallel executor queue.
    [[ -n "$GROUP_CORE" ]] && \
        parallel_add "Core utilities     ($GROUP_CORE)" \
            "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $GROUP_CORE"

    [[ -n "$GROUP_SECURITY" ]] && \
        parallel_add "Security tools     ($GROUP_SECURITY)" \
            "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $GROUP_SECURITY"

    [[ -n "$GROUP_MONITORING" ]] && \
        parallel_add "Monitoring tools   ($GROUP_MONITORING)" \
            "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $GROUP_MONITORING"

    [[ -n "$GROUP_EXTRAS" ]] && \
        parallel_add "Extra utilities    ($GROUP_EXTRAS)" \
            "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $GROUP_EXTRAS"

    [[ -n "$GROUP_DATABASE" ]] && \
        parallel_add "Database packages  ($GROUP_DATABASE)" \
            "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $GROUP_DATABASE"

    # ─── Docker installation ──────────────────────────────────────────────────
    # Why: Many modern applications are deployed via containers.
    # What it does: Triggers a dedicated function to install the Docker Engine officially from Docker repositories.
    if [[ "$INSTALL_DOCKER" == true ]]; then
        parallel_add "Docker Engine" \
            "_install_docker_engine"
    fi

    # ─── Runtime (Node, Python) ───────────────────────────────────────────────
    [[ -n "$GROUP_RUNTIME" ]] && \
        parallel_add "Runtime (Node/Python)" \
            "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $GROUP_RUNTIME"

    # Wait for all parallel jobs to finish
    parallel_wait

    # ─── Post-install configuration ───────────────────────────────────────────
    # Why: The default Docker daemon lacks required log rotation and safe-restart settings.
    # What it does: Executes the configuration routines for Docker and installs NVM for the administrator.
    if [[ "$INSTALL_DOCKER" == true ]]; then
        _configure_docker
    fi

    # Install NVM (Node Version Manager) for the admin user
    _install_nvm

    # Cleanup
    apt-get autoremove -y -qq
    apt-get autoclean -qq

    success "All package groups installed"
}

# ─── Docker Engine Installer ──────────────────────────────────────────────────
# Why: Standard repositories often have outdated Docker versions. Using official repos ensures access to the latest patched builds.
# What it does: Removes legacy Docker packages, adds the HTTPS apt repository/GPG key, and installs the latest CLI/daemon.
_install_docker_engine() {
    # Remove old docker packages
    apt-get remove -y -qq docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Add Docker GPG key and repo
    apt-get install -y -qq ca-certificates curl gnupg || return 1

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || {
        # Fallback: use distro package
        apt-get install -y -qq docker.io docker-compose-plugin
        return 0
    }
    chmod a+r /etc/apt/keyrings/docker.gpg

    local codename
    codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${codename} stable" \
        > /etc/apt/sources.list.d/docker.list

    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# ─── Docker post-install configuration ───────────────────────────────────────
# Why: Production setups require bounded logging (to avoid filling up hard drives) and userless proxy rules for security.
# What it does: Writes a custom /etc/docker/daemon.json, restarts Docker, and assigns the admin to the docker group.
_configure_docker() {
    info "Configuring Docker daemon..."

    # Docker daemon configuration for production
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'DOCKERD'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "5"
    },
    "storage-driver": "overlay2",
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 65536,
            "Soft": 65536
        }
    },
    "live-restore": true,
    "userland-proxy": false,
    "no-new-privileges": true,
    "icc": false,
    "iptables": true
}
DOCKERD

    systemctl enable docker
    systemctl start docker

    if [[ "$ADD_USER_TO_DOCKER" == true ]] && id "$ADMIN_USER" &>/dev/null; then
        usermod -aG docker "$ADMIN_USER"
        success "Added $ADMIN_USER to docker group"
    fi

    success "Docker configured with production-ready daemon settings"
}

# ─── NVM Installation ─────────────────────────────────────────────────────────
# Why: Provides developers/ops easy control over their Node.js versions without needing sudo privileges.
# What it does: Pulls the standard NVM installation script securely to the user's home folder.
_install_nvm() {
    if id "$ADMIN_USER" &>/dev/null; then
        info "Installing NVM for $ADMIN_USER..."
        local nvm_version="0.39.7"
        local nvm_dir="/home/${ADMIN_USER}/.nvm"

        if [[ -d "$nvm_dir" ]]; then
            info "NVM already installed"
            return 0
        fi

        sudo -u "$ADMIN_USER" bash -c "
            export HOME=/home/${ADMIN_USER}
            curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v${nvm_version}/install.sh \
                | PROFILE=/dev/null bash
        " 2>/dev/null && success "NVM installed for $ADMIN_USER" \
          || warn "NVM install failed (optional) — install manually"
    fi
}
