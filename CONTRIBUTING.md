# Contributing to vm-setup

Thank you for considering contributing! 🎉

This document explains how to contribute to the **vm-setup** project — from running tests to submitting pull requests.

---

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Module Architecture](#module-architecture)
- [Style Guide](#style-guide)
- [Testing](#testing)
- [Submitting a PR](#submitting-a-pr)

---

## Code of Conduct

Be respectful, constructive, and inclusive. No harassment or discrimination of any kind will be tolerated.

---

## Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/vm-setup.git
   cd vm-setup
   ```
3. Create a descriptive **branch**:
   ```bash
   git checkout -b feature/add-nginx-module
   # or
   git checkout -b fix/fail2ban-config
   ```

---

## Development Setup

You'll need:

- **bash 4.4+** (check: `bash --version`)
- **shellcheck** for linting: `sudo apt-get install shellcheck`
- A Linux VM (Ubuntu 20.04 / 22.04 / 24.04) to test on
- `make` — for convenience targets

Install dev tools:
```bash
sudo apt-get install shellcheck make git
```

---

## How to Contribute

### 🐛 Bug Reports

Open an issue with:
- Your OS version (`lsb_release -a`)
- The command you ran
- The error output (sanitize any secrets first!)
- Contents of `/var/log/vm-setup.log` (if available)

### 💡 Feature Requests

Open an issue describing:
- What problem you're solving
- Your proposed approach
- Whether it belongs in an existing module or a new one

### 🔧 Pull Requests

See [Submitting a PR](#submitting-a-pr) below.

---

## Module Architecture

Each module is a standalone bash file in `modules/` that exports a single function:

```bash
# modules/NN-name.sh

module_name() {
    section "SECTION TITLE"

    info "Doing something..."
    # ... your logic ...
    success "Done"
}
```

**Rules:**
- One exported function per file, named `module_<name>`
- Use `info`, `success`, `warn`, `error`, `fatal` from `lib/colors.sh` — never raw `echo` for user output
- Use `section "TITLE"` at the top of each module function
- Call `parallel_init`, `parallel_add`, `parallel_wait` from `lib/parallel.sh` for parallel work
- All config variables must come from `config/vm-config.env`, not hardcoded

**Adding a new module:**

1. Create `modules/NN-mymodule.sh` (pick the next number)
2. Write the `module_mymodule()` function
3. Add it to `setup.sh` in both the `--only` switch and the main sequence
4. Update `config/vm-config.env` with any new config vars
5. Add verification checks to `modules/08-report.sh`
6. Document it in `README.md`

---

## Style Guide

### Shell Scripting

```bash
# ✅ Good
local my_var="value"
[[ -n "$var" ]] || fatal "var is required"
info "Installing $package..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$package"

# ❌ Avoid
my_var=value
[ -n $var ] || exit 1
echo "Installing..."
apt-get install $package
```

- Always use `local` for function-scoped variables
- Use `[[ ]]` not `[ ]` for conditionals
- Quote all variable expansions: `"$var"` not `$var`
- Use `-qq` for apt-get to suppress progress noise
- Add `set -euo pipefail` at the top of any new top-level scripts
- Use `# ── Comment ────` style for section separators within functions

### Naming
- Module files: `NN-kebab-case.sh`
- Module functions: `module_snake_case()`
- Config variables: `UPPER_SNAKE_CASE`
- Local variables: `lower_snake_case`

---

## Testing

### Syntax check (always run before pushing)
```bash
make lint
# or manually:
shellcheck setup.sh lib/*.sh modules/*.sh
```

### Test on a real VM

The best test environment is a fresh Ubuntu VM. You can use:

```bash
# Multipass (Ubuntu's lightweight VM tool)
multipass launch --name test-vm --disk 10G
multipass transfer -r . test-vm:/opt/vm-setup
multipass exec test-vm -- sudo bash /opt/vm-setup/setup.sh --yes

# Or Docker (for partial testing — firewall won't work)
docker run --rm -it ubuntu:22.04 bash
```

### Dry run
```bash
sudo ./setup.sh --dry-run
```

### Individual module testing
```bash
# Test only one module (much faster)
sudo ./setup.sh --only security
sudo ./setup.sh --only firewall
```

### CI

GitHub Actions automatically runs `shellcheck` on every push and pull request. Check `.github/workflows/lint.yml`.

---

## Submitting a PR

1. **Run `make lint`** — all shellcheck issues must be fixed
2. **Test on a real/virtual machine** with `--dry-run` at minimum
3. **Update `README.md`** if you added or changed features
4. **Update `CHANGELOG.md`** under `[Unreleased]`
5. Push and open a PR with:
   - What problem it solves
   - How you tested it
   - Any breaking changes

PRs that don't pass CI (`shellcheck`) will not be merged.

---

## Questions?

Open a GitHub Discussion or an issue tagged `question`.
