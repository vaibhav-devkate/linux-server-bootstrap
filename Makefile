# =============================================================================
# Makefile — VM Setup Convenience Commands
# =============================================================================
.PHONY: help setup dry-run check-only lint validate

SHELL := /bin/bash
CONFIG ?= config/vm-config.env

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

setup: ## Run full VM setup (requires sudo)
	sudo bash setup.sh --config $(CONFIG)

setup-yes: ## Run full VM setup without confirmation prompts
	sudo bash setup.sh --config $(CONFIG) --yes

dry-run: ## Show what setup would do without executing
	sudo bash setup.sh --config $(CONFIG) --dry-run

module-update: ## Run only: system update
	sudo bash setup.sh --config $(CONFIG) --only update

module-users: ## Run only: user management
	sudo bash setup.sh --config $(CONFIG) --only users

module-ssh: ## Run only: SSH hardening
	sudo bash setup.sh --config $(CONFIG) --only ssh

module-firewall: ## Run only: firewall
	sudo bash setup.sh --config $(CONFIG) --only firewall

module-security: ## Run only: security hardening
	sudo bash setup.sh --config $(CONFIG) --only security

module-packages: ## Run only: package installation
	sudo bash setup.sh --config $(CONFIG) --only packages

module-storage: ## Run only: storage & swap
	sudo bash setup.sh --config $(CONFIG) --only storage

module-report: ## Run only: final verification report
	sudo bash setup.sh --config $(CONFIG) --only report

lint: ## Lint all shell scripts with shellcheck
	@command -v shellcheck > /dev/null || { echo "Installing shellcheck..."; sudo apt-get install -y shellcheck; }
	shellcheck setup.sh lib/*.sh modules/*.sh

validate: ## Validate config file syntax
	@bash -n config/vm-config.env && echo "✅ Config syntax OK" || echo "❌ Config has errors"

logs: ## Tail the setup log
	sudo tail -f /var/log/vm-setup.log

status: ## Show post-setup service status
	@echo "── UFW ──────────────────────────────────────"
	sudo ufw status numbered
	@echo ""
	@echo "── SSH ──────────────────────────────────────"
	sudo systemctl status ssh --no-pager | head -10
	@echo ""
	@echo "── Fail2Ban ─────────────────────────────────"
	sudo fail2ban-client status sshd 2>/dev/null || sudo systemctl status fail2ban --no-pager | head -10

secrets: ## Show generated secrets (root only)
	sudo cat /root/vm-setup-secrets.txt 2>/dev/null || echo "No secrets file found"
