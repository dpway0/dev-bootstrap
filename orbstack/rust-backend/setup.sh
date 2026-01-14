#!/bin/bash

# ==============================================================================
# Rust Backend Environment Provisioning
# Target: Debian/Ubuntu
# Author: dp
# ==============================================================================

# --- Strict Mode ---
set -euo pipefail
IFS=$'\n\t'

# --- Constants ---
readonly BOLD='\033[1m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

# --- Global Config ---
INTERACTIVE=true
VERBOSE=false

# --- Error Handling ---
trap 'err_handler $LINENO "$BASH_COMMAND"' ERR

err_handler() {
    local exit_code=$?
    local line_no=$1
    local command=$2
    log_error "Command \"$command\" failed on line $line_no with exit code $exit_code"
    exit "$exit_code"
}

# --- Logging Helpers ---
log_step() { echo -e "\n${BLUE}${BOLD}[STEP $1]${NC} $2"; }
log_info() { echo -e "  ${BLUE}➜${NC} $1"; }
log_success() { echo -e "  ${GREEN}✔${NC} $1"; }
log_warn() { echo -e "  ${YELLOW}⚠ WARNING:${NC} $1"; }
log_error() { echo -e "  ${RED}✖ ERROR:${NC} $1" >&2; }

# --- Utilities ---
is_installed() { command -v "$1" &> /dev/null; }

execute_cmd() {
    local desc="$1"
    local cmd="$2"

    log_info "$desc"
    if [ "$VERBOSE" = true ]; then
        eval "$cmd"
    else
        # Capture stderr to a temp file so we can show it on error
        local err_file
        err_file=$(mktemp)
        if ! eval "$cmd" > /dev/null 2> "$err_file"; then
            local exit_code=$?
            cat "$err_file" >&2
            rm -f "$err_file"
            return "$exit_code"
        fi
        rm -f "$err_file"
    fi
    log_success "Done."
}

# --- Steps ---

check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|pop|mint|kali) ;;
            *) log_warn "Detected OS ($ID) might not be fully supported. Proceeding anyway...";;
        esac
    else
        log_error "Cannot detect OS. Only Debian/Ubuntu based systems are supported."
        exit 1
    fi
}

install_sys_deps() {
    log_step "1/7" "System Dependencies & Repositories"

    execute_cmd "Updating apt package lists" "sudo apt-get update -y"

    execute_cmd "Installing software-properties-common & curl" \
        "sudo apt-get install -y software-properties-common curl"

    if ! grep -q "ppa:maveonair/helix-editor" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        execute_cmd "Adding Helix PPA" "sudo add-apt-repository ppa:maveonair/helix-editor -y"
    fi

    if [ ! -f /usr/share/keyrings/githubcli-archive-keyring.gpg ]; then
        execute_cmd "Adding GitHub CLI GPG key" \
            "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg"
    fi

    if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
         execute_cmd "Adding GitHub CLI Repository" \
            "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list"
    fi

    execute_cmd "Updating apt again" "sudo apt-get update -y"

    local DEPS="build-essential git unzip pkg-config libssl-dev clang lld mold libpq-dev postgresql-client helix gh wget"
    execute_cmd "Installing core packages: $DEPS" "sudo apt-get install -y $DEPS"
}

install_rust_toolchain() {
    log_step "2/7" "Rust Toolchain (Rustup)"

    if ! is_installed rustc; then
        execute_cmd "Installing Rust (stable)" "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
    else
        execute_cmd "Updating Rust" "rustup update"
    fi

    # Ensure cargo is in path for the script session
    export PATH="$HOME/.cargo/bin:$PATH"
}

install_cargo_binstall() {
    log_step "3/7" "Cargo Binstall"
    if ! is_installed cargo-binstall; then
        execute_cmd "Installing cargo-binstall" \
            "curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash"
    else
        log_success "cargo-binstall already installed."
    fi
}

install_pro_tools() {
    log_step "4/7" "Installing 'Pro' Rust Tools"
    
    local TOOLS="cargo-watch cargo-edit zellij atuin starship zoxide bottom xh gitui git-delta git-cliff fd-find ripgrep eza du-dust bat"
    
    execute_cmd "Installing tools via binstall: $TOOLS" "cargo binstall -y $TOOLS"
}

install_mise() {
    log_step "5/7" "Mise (Runtime Manager)"
    
    if ! is_installed mise; then
        execute_cmd "Installing Mise (via cargo-binstall)" "cargo binstall -y mise"
    else
        log_success "Mise is already installed."
    fi
}

configure_environment() {
    log_step "6/7" "Applying Configurations"

    # Mold Linker
    execute_cmd "Configuring Mold Linker" \
        "mkdir -p \"$HOME/.cargo\" && \
         cat > \"$HOME/.cargo/config.toml\" <<EOF
[target.x86_64-unknown-linux-gnu]
linker = \"clang\"
rustflags = [\"-C\", \"link-arg=-fuse-ld=mold\"]

[target.aarch64-unknown-linux-gnu]
linker = \"clang\"
rustflags = [\"-C\", \"link-arg=-fuse-ld=mold\"]
EOF"

    # Git Config (Delta + Defaults)
    execute_cmd "Configuring Git Global Defaults" \
        "git config --global core.pager \"delta\" && \
         git config --global interactive.diffFilter \"delta --color-only\" && \
         git config --global delta.navigate true && \
         git config --global delta.line-numbers true && \
         git config --global delta.side-by-side true && \
         git config --global pull.rebase true && \
         git config --global rebase.autoStash true && \
         git config --global init.defaultBranch main"

    if is_installed gh; then
        # This might need interaction if not logged in, but just setting config is safe
        if ! git config credential.helper | grep -q "gh"; then
             execute_cmd "Setting gh as git credential helper" "gh auth setup-git"
        fi
    fi

    # Helix Config
    if [ ! -f "$HOME/.config/helix/config.toml" ]; then
        execute_cmd "Configuring Helix Theme" \
            "mkdir -p \"$HOME/.config/helix\" && echo 'theme = \"dracula\"' > \"$HOME/.config/helix/config.toml\""
    fi

    # Bash Pre-exec
    if [ ! -f "$HOME/.bash-preexec.sh" ]; then
        execute_cmd "Downloading bash-preexec" \
            "curl -s https://raw.githubusercontent.com/rcaloras/bash-preexec/master/bash-preexec.sh -o ~/.bash-preexec.sh"
    fi

    # Bashrc Injection
    if ! grep -q "# --- Rust Dev Stack ---" ~/.bashrc; then
        log_info "Injecting aliases into .bashrc..."
        cat <<EOT >> ~/.bashrc

# --- Rust Dev Stack (dp) ---
HISTSIZE=1000000
HISTFILESIZE=20000000

[[ -f ~/.bash-preexec.sh ]] && source ~/.bash-preexec.sh

if command -v starship &> /dev/null; then eval "\$(starship init bash)"; fi
if command -v atuin &> /dev/null; then eval "\$(atuin init bash)"; fi
if command -v zoxide &> /dev/null; then eval "\$(zoxide init bash --cmd cd)"; fi
if command -v mise &> /dev/null; then eval "\$(mise activate bash)"; fi

if command -v eza &> /dev/null; then 
    alias ls="eza --icons"
    alias ll="eza -l --icons --git"
    alias tree="eza --tree --icons"
fi
if command -v gitui &> /dev/null; then alias gu="gitui"; fi
alias zj="zellij"
alias sb="source ~/.bashrc"
alias hb="hx ~/.bashrc"
EOT
        log_success "Bashrc updated."
    else
         log_success "Bashrc already configured."
    fi
}

setup_git_identity() {
    if [ "$INTERACTIVE" = false ]; then
        log_info "Skipping interactive Git setup (Non-interactive mode)."
        return
    fi
    
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
}

cleanup() {
    log_step "7/7" "Final Cleanup"
    execute_cmd "Auto-removing unused packages" "sudo apt-get autoremove -y"
    execute_cmd "Cleaning apt cache" "sudo apt-get clean"
}

print_summary() {
    echo -e "\n${GREEN}========================================================${NC}"
    echo -e "${GREEN}  ✔ SETUP COMPLETE! READY TO CODE.${NC}"
    echo -e "${GREEN}========================================================${NC}"
    echo -e "  • Shell:    Bash + Starship + Atuin + Zoxide"
    echo -e "  • Runtimes: Mise (Node/Python manager)"
    echo -e "  • Editor:   Helix (hx)"
    echo -e "  • Git:      GitUI (gu) + GitHub CLI (gh)"
    echo -e "  • Linker:   Mold (Blazing fast)"
    echo -e "\n${BOLD}Action Required:${NC}"
    echo -e "  1. Run ${BLUE}source ~/.bashrc${NC} to refresh shell."
    echo -e "  2. Run ${BLUE}gh auth login${NC} to connect your GitHub account."
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -v, --verbose   Enable verbose output"
    echo "  -y, --yes       Run non-interactively (skip git setup prompts)"
    echo "  -h, --help      Show this help message"
}

# --- Main ---

main() {
    # Parse Arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -y|--yes)
                INTERACTIVE=false
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    echo -e "${BOLD}Starting Rust Backend Environment Setup ...${NC}"
    
    check_os
    install_sys_deps
    install_rust_toolchain
    install_cargo_binstall
    install_pro_tools
    install_mise
    configure_environment
    setup_git_identity
    cleanup
    print_summary
}

main "$@"
