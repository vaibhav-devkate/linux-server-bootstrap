#!/usr/bin/env bash
# =============================================================================
# MODULE: User Management
# =============================================================================

module_user_management() {
    section "USER MANAGEMENT"

    # ─── Generate password if blank ────────────────────────────────────────────
    # Why: Ensures there is always a secure means of access if no password was provided.
    # What it does: Uses openssl to generate a 24-char base64 random password and writes it to a file.
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        ADMIN_PASSWORD=$(openssl rand -base64 24)
        warn "No password set in config — generated a random one"
        warn "Admin password: ${ADMIN_PASSWORD}"
        echo "ADMIN_PASSWORD=$ADMIN_PASSWORD" >> /root/vm-setup-secrets.txt
        chmod 600 /root/vm-setup-secrets.txt
    fi

    # ─── Create admin group ────────────────────────────────────────────────────
    # Why: Groups allow easier permission management for multiple admin users later.
    # What it does: Creates a system group if it does not already exist.
    if ! getent group "$ADMIN_GROUP" > /dev/null 2>&1; then
        groupadd "$ADMIN_GROUP"
        success "Created group: $ADMIN_GROUP"
    else
        info "Group already exists: $ADMIN_GROUP"
    fi

    # ─── Create admin user ─────────────────────────────────────────────────────
    # Why: Best practice dictates not using the root user for daily operations or SSH logins.
    # What it does: Creates a new user with a home directory, specified shell, and adds to admin/sudo groups.
    if id "$ADMIN_USER" &>/dev/null; then
        info "User already exists: $ADMIN_USER — updating settings"
    else
        useradd \
            --create-home \
            --shell "$ADMIN_SHELL" \
            --gid "$ADMIN_GROUP" \
            --groups "sudo" \
            --comment "Admin user managed by vm-setup" \
            "$ADMIN_USER"
        success "Created user: $ADMIN_USER"
    fi

    # Set password
    echo "${ADMIN_USER}:${ADMIN_PASSWORD}" | chpasswd
    success "Password set for: $ADMIN_USER"

    # Ensure user is in sudo group
    usermod -aG sudo "$ADMIN_USER" 2>/dev/null || true

    # ─── Sudoers configuration ─────────────────────────────────────────────────
    # Why: Allow the created admin to execute root commands via sudo, which is necessary for fully managing the server.
    # What it does: Creates a custom sudoers file allowing passwordless sudo and disables requiretty.
    info "Configuring sudoers..."
    cat > "/etc/sudoers.d/99-${ADMIN_USER}" << SUDOERS
# vm-setup managed — allow $ADMIN_USER full sudo without password
$ADMIN_USER ALL=(ALL:ALL) NOPASSWD:ALL

# Restrict TTY requirement (needed for non-interactive sudo)
Defaults:$ADMIN_USER !requiretty
SUDOERS
    chmod 440 "/etc/sudoers.d/99-${ADMIN_USER}"
    visudo -c -f "/etc/sudoers.d/99-${ADMIN_USER}" && success "Sudoers validated" \
        || fatal "Sudoers file is invalid!"

    # ─── SSH directory for admin user ──────────────────────────────────────────
    # Why: Prepares the user's home directory so SSH keys can be added securely.
    # What it does: Creates the .ssh directory and authorized_keys file with strict permissions.
    local ssh_dir="/home/${ADMIN_USER}/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    touch "${ssh_dir}/authorized_keys"
    chmod 600 "${ssh_dir}/authorized_keys"
    chown -R "${ADMIN_USER}:${ADMIN_USER}" "$ssh_dir"

    # ─── Add SSH public key ────────────────────────────────────────────────────
    # Why: Key-based authentication is significantly more secure than passwords.
    # What it does: Appends the provided SSH public key safely to the user's authorized_keys file.
    if [[ -n "$SSH_PUBKEY" ]]; then
        if grep -qF "$SSH_PUBKEY" "${ssh_dir}/authorized_keys" 2>/dev/null; then
            info "SSH public key already present"
        else
            echo "$SSH_PUBKEY" >> "${ssh_dir}/authorized_keys"
            success "SSH public key added for $ADMIN_USER"
        fi
    else
        warn "No SSH_PUBKEY set in config — skipping key injection"
        warn "Add your key manually: ssh-copy-id -p ${SSH_PORT} ${ADMIN_USER}@<server-ip>"
    fi

    # ─── Lock root account ─────────────────────────────────────────────────────
    # Why: Prevents anyone from logging directly into the root account via password, stopping brute force attacks against root.
    # What it does: Locks the root password using the passwd -l command.
    if [[ "$DISABLE_ROOT_LOGIN" == true ]]; then
        passwd -l root > /dev/null
        success "Root account locked"
    fi

    # ─── Bash & Vim profile for admin user ─────────────────────────────────────
    # Why: Enhances the command line experience with useful aliases, prompts, and settings.
    # What it does: Generates .bashrc with aliases and environment variables for the user.
    cat > "/home/${ADMIN_USER}/.bashrc" << 'BASHRC'
# ~/.bashrc — Production admin profile

# Prompt with hostname and git branch
parse_git_branch() {
    git branch 2>/dev/null | grep '^*' | sed 's/* //'
}
PS1='\[\033[1;32m\]\u\[\033[0m\]@\[\033[1;34m\]\h\[\033[0m\]:\[\033[1;33m\]\w\[\033[0;36m\]$(parse_git_branch)\[\033[0m\]\$ '

# Aliases
alias ll='ls -alFh --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps auxf'
alias top='htop'
alias ports='ss -tulpn'
alias logs='journalctl -f'
alias update='sudo apt update && sudo apt upgrade -y'

# History
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Environment
export EDITOR=vim
export VISUAL=vim
export PAGER=less
export LESS='-R -i -J'

# NVM / Node
[ -s "$HOME/.nvm/nvm.sh" ] && \. "$HOME/.nvm/nvm.sh"
[ -s "$HOME/.nvm/bash_completion" ] && \. "$HOME/.nvm/bash_completion"

# Welcome message
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
whoami | awk '{printf "\033[1;36m  Welcome back, %s!\033[0m\n", toupper($1)}'
echo -e "\033[0;37m  $(date '+%A, %B %d %Y  %H:%M:%S')\033[0m"
echo -e "\033[1;32m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
BASHRC

    chown "${ADMIN_USER}:${ADMIN_USER}" "/home/${ADMIN_USER}/.bashrc"

    # ─── Vim config ────────────────────────────────────────────────────────────
    # Why: Provides sane defaults for terminal text editing (syntax highlighting, indentation, etc.).
    # What it does: Generates a custom .vimrc file with these configurations.
    cat > "/home/${ADMIN_USER}/.vimrc" << 'VIMRC'
syntax on
set number
set tabstop=4
set shiftwidth=4
set expandtab
set background=dark
set hlsearch
set incsearch
set ignorecase
set smartcase
set autoindent
set ruler
set showcmd
VIMRC
    chown "${ADMIN_USER}:${ADMIN_USER}" "/home/${ADMIN_USER}/.vimrc"

    # ─── Create application user (appuser) ─────────────────────────────────────
    # Why: Following least privilege, application processes should not run as root or admin.
    # What it does: Creates an unprivileged user with a home directory but NO sudo access.
    info "Setting up application user: $APP_USER"
    if ! getent group "$APP_GROUP" > /dev/null 2>&1; then
        groupadd "$APP_GROUP"
    fi

    if id "$APP_USER" &>/dev/null; then
        info "User already exists: $APP_USER"
    else
        useradd \
            --create-home \
            --shell /bin/bash \
            --gid "$APP_GROUP" \
            --comment "Application execution user" \
            "$APP_USER"
        success "Created user: $APP_USER"
    fi

    # ─── Create database service user (dbadmin) ────────────────────────────────
    # Why: Database administration processes shouldn't share application or admin credentials.
    # What it does: Creates a system account without a login shell to isolate database permissions.
    info "Setting up database user: $DB_ADMIN_USER"
    if ! getent group "$DB_ADMIN_GROUP" > /dev/null 2>&1; then
        groupadd "$DB_ADMIN_GROUP"
    fi

    if id "$DB_ADMIN_USER" &>/dev/null; then
        info "User already exists: $DB_ADMIN_USER"
    else
        useradd \
            --system \
            --shell /usr/sbin/nologin \
            --gid "$DB_ADMIN_GROUP" \
            --comment "Database service administration user" \
            "$DB_ADMIN_USER"
        success "Created user: $DB_ADMIN_USER"
    fi

    success "User management complete"
}
