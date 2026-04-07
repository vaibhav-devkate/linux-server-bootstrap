# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.0] — 2026-04-07

### Added
- **Parallel package installation** — all package groups install simultaneously with a live progress bar and spinner
- **Modular architecture** — 8 independent modules, any module can be re-run in isolation with `--only <module>`
- **lib/parallel.sh** — reusable parallel job runner with real-time status tracking and per-job output capture
- **lib/colors.sh** — rich terminal formatting library (colors, icons, sections, spinner)
- **Docker production hardening** — custom `daemon.json` with log limits, overlay2, no-new-privileges
- **NVM installation** for admin user
- **AppArmor enforcement** — all profiles set to enforce mode
- **rkhunter** — daily rootkit scan via cron
- **Auditd CIS rules** — comprehensive kernel audit logging
- **Port scan protection** — iptables rules blocking NULL, XMAS, SYN-RST packets
- **Login banner** (`/etc/ssh/banner`) and MOTD customization
- **Makefile** with targets for every module, linting, and status checks
- **`--dry-run`** mode — previews the full plan without executing
- **`--only <module>`** flag — run a single module (update|users|ssh|firewall|security|packages|storage|report)
- **Slack webhook** notification support post-setup
- **`/root/vm-setup-report.txt`** — auto-generated summary with public IP and SSH connect string
- **GitHub Actions CI** — automatic ShellCheck linting on every push and PR

### Changed
- Moved all configuration to `config/vm-config.env` (single source of truth)
- SSH hardening now restricts key exchange to `curve25519` and `diffie-hellman-group16/18-sha512` only
- Fail2Ban now uses `ufw` as backend for integrated banning
- System limits increased to `1048576` for both nofile and nproc

### Security
- `kernel.kptr_restrict = 2` — hide kernel pointer addresses
- `kernel.yama.ptrace_scope = 1` — restrict ptrace
- `fs.protected_symlinks/hardlinks = 1` — prevent link-based attacks
- `net.ipv4.conf.all.log_martians = 1` — log spoofed/source-routed packets

---

## [1.0.0] — 2026-04-05

### Added
- Initial version with sequential installation
- Basic SSH, UFW, user creation
- Single monolithic script
