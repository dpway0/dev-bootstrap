#!/bin/bash

# ==============================================================================
# Rust Backend Environment Provisioning
# Target: Ubuntu (Orbstack)
# Author: dp
# ==============================================================================

set -e

# --- Visual Helpers (The Pro Look) ---
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Hàm logging chuyên nghiệp
log_step() {
    echo -e "\n${BLUE}${BOLD}[STEP $1]$2${NC}"
}

log_info() {
    echo -e "  ${BLUE}➜${NC} $1"
}

log_success() {
    echo -e "  ${GREEN}✔${NC} $1"
}

log_warn() {
    echo -e "  ${YELLOW}⚠ WARNING:${NC} $1"
}

log_error() {
    echo -e "  ${RED}✖ ERROR:${NC} $1"
}

# --- Start Setup ---
echo -e "${BOLD}Starting Rust Backend Environment Setup for Orbstack...${NC}"
echo -e "--------------------------------------------------------"

# 1. System Dependencies
# ------------------------------------------------------------------------------
log_step "1/6" " System Dependencies & Repositories"

log_info "Updating apt package lists..."
if ! sudo apt-get update -y > /dev/null 2>&1; then
    log_warn "Apt update failed (Hash Sum Mismatch?). Attempting fix..."
    sudo rm -rf /var/lib/apt/lists/*
    sudo apt-get clean
    sudo apt-get update -y > /dev/null 2>&1
    log_success "Apt fixed and updated."
else
    log_success "Apt updated successfully."
fi

log_info "Adding PPAs (Helix Editor)..."
sudo apt-get install -y software-properties-common > /dev/null 2>&1
sudo add-apt-repository ppa:maveonair/helix-editor -y > /dev/null 2>&1
sudo apt-get update -y > /dev/null 2>&1

log_info "Installing core libraries (Build-essential, Clang, Mold, LibPQ)..."
sudo apt-get install -y \
    build-essential curl git unzip \
    pkg-config libssl-dev \
    clang lld mold \
    libpq-dev postgresql-client \
    helix > /dev/null 2>&1

log_success "System libraries & Helix installed."

# 2. Rust Toolchain
# ------------------------------------------------------------------------------
log_step "2/6" " Rust Toolchain (Rustup)"

if ! command -v rustc &> /dev/null; then
    log_info "Installing Rust (Stable)..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y > /dev/null 2>&1
    log_success "Rust installed."
else
    log_info "Rust already installed. Updating..."
    rustup update > /dev/null 2>&1
    log_success "Rust updated."
fi

source "$HOME/.cargo/env"

# 3. Cargo Binstall
# ------------------------------------------------------------------------------
log_step "3/6" " Cargo Binstall (Fast Binary Installer)"

if ! command -v cargo-binstall &> /dev/null; then
    log_info "Fetching cargo-binstall..."
    curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash > /dev/null 2>&1
    log_success "cargo-binstall installed."
else
    log_success "cargo-binstall is already ready."
fi

# 4. Rust Productivity Tools
# ------------------------------------------------------------------------------
log_step "4/6" " Installing 'Pro' Rust Tools"
log_info "This might take a moment (installing binaries)..."

# List tools explicitly so user knows what's happening
TOOLS="cargo-watch cargo-edit zellij atuin starship zoxide bottom xh gitui git-delta git-cliff fd-find ripgrep eza du-dust bat"

if cargo binstall -y $TOOLS > /dev/null 2>&1; then
    log_success "All Rust tools installed: $(echo $TOOLS | sed 's/ /, /g')"
else
    log_warn "Some tools might have failed to install. Check cargo logs."
fi

# 5. Configuration
# ------------------------------------------------------------------------------
log_step "5/6" " Applying Configurations"

log_info "Configuring Mold Linker (Global Speedup)..."
mkdir -p "$HOME/.cargo"
cat > "$HOME/.cargo/config.toml" <<EOF
[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]

[target.aarch64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]
EOF

log_info "Configuring Git (Delta + Rebase workflow)..."
git config --global core.pager "delta"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.line-numbers true
git config --global delta.side-by-side true
git config --global pull.rebase true
git config --global rebase.autoStash true
git config --global init.defaultBranch main

log_info "Configuring Helix (Theme)..."
mkdir -p "$HOME/.config/helix"
if [ ! -f "$HOME/.config/helix/config.toml" ]; then
    echo 'theme = "dracula"' > "$HOME/.config/helix/config.toml"
fi

log_info "Downloading bash-preexec (Required for Atuin on Bash)..."
curl -s https://raw.githubusercontent.com/rcaloras/bash-preexec/master/bash-preexec.sh -o ~/.bash-preexec.sh

log_info "Injecting aliases into .bashrc..."
if ! grep -q "# --- Rust Dev Stack ---" ~/.bashrc; then
    cat <<EOT >> ~/.bashrc

# --- Rust Dev Stack (dp) ---
HISTSIZE=1000000
HISTFILESIZE=20000000

[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh

eval "\$(starship init bash)"
eval "\$(atuin init bash)"
eval "\$(zoxide init bash --cmd cd)"

alias cat="bat"
alias ls="eza --icons"
alias ll="eza -l --icons --git"
alias tree="eza --tree --icons"
alias find="fd"
alias du="dust"
alias gu="gitui"
alias top="btm"
alias vim="hx"
alias vi="hx"
alias zj="zellij"
EOT
    log_success "Bashrc updated."
else
    log_success "Bashrc already configured."
fi

# Interactive Git Identity Setup
# Check specifically if user email is missing
if [ -z "$(git config --global user.email)" ]; then
    echo -e "\n${YELLOW}  ⚠ Git identity is not set.${NC}"
    read -p "    Enter Global Git Name: " git_name
    read -p "    Enter Global Git Email: " git_email

    if [ -n "$git_name" ] && [ -n "$git_email" ]; then
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        log_success "Git identity configured."
    else
        log_warn "Skipped Git identity setup."
    fi
fi

# 6. Cleanup
# ------------------------------------------------------------------------------
log_step "6/6" " Final Cleanup"
log_info "Removing unused packages..."
sudo apt-get autoremove -y > /dev/null 2>&1
sudo apt-get clean > /dev/null 2>&1
log_success "System clean."

# Final Summary
echo -e "\n${GREEN}========================================================${NC}"
echo -e "${GREEN}  ✔ SETUP COMPLETE! READY TO CODE.${NC}"
echo -e "${GREEN}========================================================${NC}"
echo -e "  • Shell:   Bash + Starship + Atuin + Zoxide"
echo -e "  • Editor:  Helix (hx)"
echo -e "  • Monitor: Bottom (btm)"
echo -e "  • Git:     GitUI (gu)"
echo -e "\n${BOLD}Action Required:${NC} Run ${BLUE}source ~/.bashrc${NC} to start."
