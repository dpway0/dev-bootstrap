# Rust Backend Environment (Orbstack)

Automated provisioning script for a high-performance **"Pro"** Rust development environment on Debian/Ubuntu (Orbstack).

**Author:** dp

## Usage

Run the following command inside your Ubuntu/Debian VM:

```bash
# Interactive Mode (Recommended)
./setup.sh

# Non-Interactive / CI Mode (Skips Git Identity Prompts)
./setup.sh -y
```

or via one-liner:

```bash
bash <(curl -s https://raw.githubusercontent.com/dpway0/dev-bootstrap/main/orbstack/rust-backend/setup.sh)
```

## Features

*   **Robustness**: Strict strict mode (`set -euo pipefail`), error trapping, and idempotency (safe to re-run).
*   **Performance**: Configures **Clang + Mold** linker globally (significantly faster linking than default `ld`).
*   **Shell**: Bash configured with **Starship** prompt, **Atuin** history sync, **Zoxide**, and **Mise**.
*   **Editor**: Includes **Helix** (Post-modern modal editor built in Rust).
*   **Runtime Management**: Includes **Mise** for managing Node.js, Python, and other language runtimes.

## Tool Stack

The environment replaces standard GNU utilities with modern Rust-based alternatives:

| Category | Standard | Replacement | Command | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Navigation** | `cd` | **[zoxide](https://github.com/ajeetdsouza/zoxide)** | `cd` / `z` | Smarter directory navigation |
| **Editor** | `vi` / `vim` | **[helix](https://helix-editor.com/)** | `hx` | Modern modal editor |
| **Shell** | `bash` | **[starship](https://starship.rs/)** | (prompt) | Fast, customizable prompt |
| | `history` | **[atuin](https://github.com/atuinsh/atuin)** | `Ctrl+r` | Syncable shell history |
| **Runtime** | `nvm`/`pyenv` | **[mise](https://mise.jdx.dev/)** | `mise` | Polyglot runtime manager |
| **File Ops** | `ls` | **[eza](https://github.com/eza-community/eza)** | `ls` / `ll` | Modern file listing with icons |
| | `cat` | **[bat](https://github.com/sharkdp/bat)** | `cat` | Syntax highlighting viewer |
| | `find` | **[fd](https://github.com/sharkdp/fd)** | `find` / `fd` | Fast user-friendly find |
| | `grep` | **[ripgrep](https://github.com/BurntSushi/ripgrep)** | `rg` | Blazing fast text search |
| | `du` | **[dust](https://github.com/bootandy/dust)** | `du` / `dust` | Disk usage analyzer |
| **Network** | `curl` | **[xh](https://github.com/ducaale/xh)** | `xh` | Friendly HTTP API Client |
| **System** | `top` | **[bottom](https://github.com/ClementTsang/bottom)** | `top` / `btm` | Process/System monitor |
| **Git** | `git` | **[gitui](https://github.com/extrawurst/gitui)** | `gu` | Blazing fast terminal Git GUI |
| | `diff` | **[delta](https://github.com/dandavison/delta)** | (auto) | Syntax-highlighting git pager |
| | (manual) | **[git-cliff](https://github.com/orhun/git-cliff)** | `git cliff` | Changelog generator |
| **Dev** | `watch` | **[cargo-watch](https://github.com/watchexec/cargo-watch)** | `cargo watch` | Watch for file changes |

## Post-Install

After running the script:

1.  **Restart Shell**: `source ~/.bashrc`
2.  **GitHub Auth**: `gh auth login`
3.  **Mise Runtimes**: Install languages easily, e.g., `mise use node@lts`
