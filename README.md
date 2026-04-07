<div align="center">

# 🚀 vm-setup

**One command. Production-ready VM in minutes.**

A modular, parallel bash setup script that transforms a fresh cloud VM into a hardened, secure, production-ready server — automatically.

[![ShellCheck](https://github.com/vaibhav-devkate/vm-setup/actions/workflows/lint.yml/badge.svg)](https://github.com/vaibhav-devkate/vm-setup/actions/workflows/lint.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/bash-4.4%2B-brightgreen.svg)](https://www.gnu.org/software/bash/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04%20%7C%2024.04-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

[**Quick Start**](#-quick-start) · [**Features**](#-features) · [**Modules**](#-modules) · [**Configuration**](#%EF%B8%8F-configuration) · [**Contributing**](CONTRIBUTING.md)

</div>

---

## 🎯 What It Does

You just provisioned a fresh VM. Now what?

```
Fresh Ubuntu VM  →  sudo ./setup.sh  →  Production-Ready Server
```

**vm-setup** runs 8 modules — installing packages **in parallel**, hardening SSH, locking down the firewall, creating a secure admin user, configuring auditd, Fail2Ban, AppArmor, swap, and more — then prints a verified checklist and your SSH connect string.

> ⏱️ Typical run time: **3–6 minutes** (vs 20+ minutes done manually)

---

## ✨ Features

| | Feature | Details |
|---|---|---|
| ⚡ | **Parallel installs** | Package groups install simultaneously — live progress bar |
| 🔒 | **SSH Hardening** | Custom port, modern ciphers only, key-only auth, banner |
| 👤 | **User Management** | Non-root admin user, sudo, custom `.bashrc` + `.vimrc` |
| 🔥 | **Firewall (UFW)** | Default-deny, SSH rate limiting, port scan protection |
| 🛡️ | **Security Suite** | Fail2Ban, Auditd (CIS), AppArmor, rkhunter, auto-updates |
| ⚙️ | **Kernel Tuning** | 30+ sysctl parameters for performance + security |
| 💾 | **Storage** | Swap file, locked `/tmp` (`noexec,nosuid`), log rotation |
| 🐋 | **Docker** | Production-hardened daemon config, added to docker group |
| 🔍 | **Verification** | 20+ automated checks + SSH connect string at the end |
| 🧩 | **Modular** | Run the full stack or any single module with `--only` |

---

## 📁 Project Structure

```
vm-setup/
├── 📄 setup.sh                   ← Main entry point  (run this)
├── 📄 Makefile                   ← Convenience targets
│
├── 📁 config/
│   └── vm-config.env             ← 🔧 Edit this first!
│
├── 📁 lib/
│   ├── colors.sh                 ← Terminal colors, icons, spinner
│   └── parallel.sh               ← Parallel job runner with live progress
│
├── 📁 modules/
│   ├── 01-system-update.sh       ← apt upgrade, sysctl, limits
│   ├── 02-user-management.sh     ← User, sudo, SSH key, .bashrc
│   ├── 03-ssh-hardening.sh       ← SSHD port, ciphers, banner
│   ├── 04-firewall.sh            ← UFW rules, rate limiting
│   ├── 05-security.sh            ← Fail2Ban, Auditd, AppArmor
│   ├── 06-install-packages.sh    ← Parallel package groups
│   ├── 07-storage.sh             ← Swap, tmpfs, log rotation
│   └── 08-report.sh              ← Verification checks + report
│
└── 📁 .github/
    ├── workflows/lint.yml         ← CI: ShellCheck + dry-run
    └── ISSUE_TEMPLATE/            ← Bug / Feature templates
```

---

## 🚀 Quick Start

### 1 — Clone to your VM

```bash
git clone https://github.com/vaibhav-devkate/vm-setup.git /opt/vm-setup
cd /opt/vm-setup
```

### 2 — Configure

```bash
cp config/vm-config.env config/my-server.env
nano config/my-server.env
```

**Minimum required values:**

```bash
HOSTNAME="my-prod-server"
ADMIN_USER="devops"
SSH_PORT=2222
SSH_PUBKEY="ssh-ed25519 AAAA..."   # your ~/.ssh/id_ed25519.pub
OPEN_PORTS="80,443"                # open to internet
```

### 3 — Run

```bash
# Option A: SSH key passed via config
sudo ./setup.sh

# Option B: SSH key passed as argument  (most common)
sudo ./setup.sh --ssh-key "$(cat ~/.ssh/id_ed25519.pub)"

# Option C: Non-interactive (CI/CD)
sudo ./setup.sh --yes --config /path/to/server.env
```

### 4 — Connect

After setup, the script prints:

```
🚀  YOUR SERVER IS READY!

  Connect via SSH:
    ssh -p 2222 devops@<your-ip>
```

> ⚠️ **Before closing your session** — open a **second terminal** and verify you can SSH on the new port!

---

## ⚙️ Configuration

Edit `config/vm-config.env` before running. All options are documented inline.

| Variable | Default | Description |
|---|---|---|
| `HOSTNAME` | `prod-vm-01` | Server hostname |
| `TIMEZONE` | `Asia/Kolkata` | System timezone |
| `ADMIN_USER` | `devops` | Non-root admin username |
| `ADMIN_PASSWORD` | *(auto)* | Leave blank to auto-generate |
| `SSH_PORT` | `2222` | SSH port (avoids port 22) |
| `SSH_PUBKEY` | *(empty)* | Your SSH public key content |
| `DISABLE_ROOT_LOGIN` | `true` | Lock root account |
| `ALLOW_PASSWORD_AUTH` | `false` | Allow password login |
| `ALLOWED_SSH_IPS` | *(any)* | Comma-separated IPs to whitelist |
| `OPEN_PORTS` | `80,443` | Ports to open in firewall |
| `INSTALL_DOCKER` | `true` | Install Docker CE |
| `ENABLE_SWAP` | `true` | Create swap file |
| `SWAP_SIZE_GB` | `2` | Swap size in GB |
| `FAIL2BAN_MAX_RETRY` | `3` | SSH attempts before ban |
| `FAIL2BAN_BAN_TIME` | `3600` | Ban duration in seconds |
| `ENABLE_AUTO_UPDATES` | `true` | Auto-apply security patches |
| `SLACK_WEBHOOK` | *(empty)* | Slack webhook for notifications |

---

## 🧩 Modules

Each module is independent and can be re-run at any time:

```bash
sudo ./setup.sh --only <module>
```

### Available modules

| Module | Flag | What it does |
|---|---|---|
| System Update | `update` | `apt upgrade`, kernel sysctl, file limits |
| Packages | `packages` | Parallel install of all package groups |
| Users | `users` | Admin user, sudo, SSH key, `.bashrc` |
| SSH | `ssh` | Hardened `/etc/ssh/sshd_config`, restart |
| Firewall | `firewall` | UFW rules, rate limits, port scan blocks |
| Security | `security` | Fail2Ban, Auditd, AppArmor, rkhunter |
| Storage | `storage` | Swap, `/tmp` tmpfs, log rotation |
| Report | `report` | Verification checks + connect info |

---

## 📦 Package Groups (Installed in Parallel)

```
Group 1 — Core:        curl wget git vim nano htop unzip zip tar jq net-tools
Group 2 — Security:    fail2ban ufw auditd apparmor-utils rkhunter chkrootkit
Group 3 — Monitoring:  prometheus-node-exporter sysstat iotop ncdu
Group 4 — Runtime:     nodejs npm python3 python3-pip docker.io docker-compose
Group 5 — Extras:      rsync screen tmux tree nmap dnsutils mtr
```

All 5 groups launch simultaneously. A live progress bar tracks completion per-group.

---

## 🔐 Security Hardening Details

<details>
<summary><strong>SSH Hardening</strong> (click to expand)</summary>

- Port changed from `22` to your configured `SSH_PORT`
- Root login disabled (`PermitRootLogin no`)
- Password auth disabled (`PasswordAuthentication no`)
- Max 3 auth attempts, 30s grace time
- Allowed ciphers: `chacha20-poly1305`, `aes256-gcm`, `aes128-gcm`
- Allowed KEX: `curve25519-sha256`, `diffie-hellman-group16/18-sha512`
- Allowed MACs: `hmac-sha2-512-etm`, `hmac-sha2-256-etm`
- Host keys regenerated fresh on first run
- Login banner added (`/etc/ssh/banner`)
- Agent forwarding and TCP forwarding disabled

</details>

<details>
<summary><strong>Firewall (UFW)</strong> (click to expand)</summary>

- Default policy: `DENY incoming`, `ALLOW outgoing`
- SSH port rate-limited (`ufw limit`)
- Port 22 explicitly blocked (since we moved SSH)
- Telnet (23), FTP (21), Samba (137/138/139/445) blocked
- iptables: NULL, XMAS, SYN-RST, SYN-FIN packet drops
- ICMP flood protection (max 1/s burst 5)
- Optional IP whitelist for SSH

</details>

<details>
<summary><strong>Kernel Hardening (sysctl)</strong> (click to expand)</summary>

```
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.tcp_syncookies = 1
kernel.randomize_va_space = 2
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.sysrq = 0
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
```

Plus TCP performance tuning for production workloads.

</details>

<details>
<summary><strong>Fail2Ban</strong> (click to expand)</summary>

- Backend: `systemd` (reads journald directly)
- Ban action: `ufw` (creates UFW deny rules)
- SSH jail: 3 retries in 10 minutes → 1 hour ban
- SSHD-DDoS jail: 6 retries → 2 hour ban
- Extensible: Nginx, HTTP-auth jails pre-configured (disabled by default)

</details>

<details>
<summary><strong>Auditd (CIS Benchmark)</strong> (click to expand)</summary>

Tracks: `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, SSH config, cron, logins, kernel module loads, file deletions, network config changes, privileged command execution.

</details>

---

## 🛠️ CLI Reference

```
Usage: sudo ./setup.sh [OPTIONS]

Options:
  --config <file>      Config file path (default: ./config/vm-config.env)
  --ssh-key <key>      SSH public key string (overrides config)
  --skip-update        Skip system update step
  --skip-packages      Skip package installation
  --skip-security      Skip security hardening
  --skip-firewall      Skip firewall configuration
  --only <module>      Run one module: update|users|ssh|firewall|security|packages|storage|report
  --dry-run            Preview the plan without executing
  --yes | -y           Skip confirmation prompts
  -h, --help           Show this help
```

### Makefile shortcuts

```bash
make setup            # Full setup
make dry-run          # Preview
make module-firewall  # Re-run firewall only
make module-security  # Re-run security only
make lint             # Run ShellCheck on all files
make status           # Show UFW + SSH + Fail2Ban status
make logs             # Tail /var/log/vm-setup.log
make secrets          # Show generated password
```

---

## 📊 Post-Setup Files

| File | Contents |
|---|---|
| `/var/log/vm-setup.log` | Full timestamped setup log |
| `/root/vm-setup-secrets.txt` | Auto-generated password (chmod 600) |
| `/root/vm-setup-report.txt` | Summary: IP, user, SSH connect string |

---

## 🔄 CI/CD

The repository runs **GitHub Actions** on every push and pull request:

- ✅ **ShellCheck** — lints all `.sh` files at `warning` severity
- ✅ **Syntax check** — `bash -n` on every script
- ✅ **Dry-run** — runs the full setup in `--dry-run` mode on Ubuntu 22.04
- ✅ **Secret scan** — checks for accidentally hardcoded credentials

---

## 🖥️ Supported Systems

| OS | Version | Status |
|---|---|---|
| Ubuntu | 24.04 LTS (Noble) | ✅ Tested |
| Ubuntu | 22.04 LTS (Jammy) | ✅ Tested |
| Ubuntu | 20.04 LTS (Focal) | ✅ Tested |
| Debian | 12 (Bookworm) | ⚠️ Mostly works |
| Other | Debian-based | 🔧 May need tweaks |

---

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- How to add a new module
- Style guide and conventions
- Testing on VMs
- PR requirements

---

## 📄 License

MIT © [Vaibhav Devkate](https://github.com/vaibhav-devkate)

See [LICENSE](LICENSE) for full text.

---

<div align="center">

**If this saved you time, please ⭐ the repo!**

</div>
