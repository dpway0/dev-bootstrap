# Rust Backend Environment (Orbstack)

Automated provisioning script for a high-performance Rust development environment on Ubuntu (Orbstack).

**Author:** dp

## Usage

Run the following command inside your Ubuntu VM:

```bash
bash <(curl -s [https://raw.githubusercontent.com/dpway0/dev-bootstrap/main/orbstack/rust-backend/setup.sh](https://raw.githubusercontent.com/dpway0/dev-bootstrap/main/orbstack/rust-backend/setup.sh))

```

## Features

* **Build Speed**: Configures Clang + Mold linker globally (significantly faster linking than default ld).
* **Editor**: Includes Helix (Post-modern modal editor built in Rust).
* **Shell**: Bash configured with Starship prompt, Atuin history sync, and Zellij multiplexer.

## Tool Replacements

Standard GNU utilities are replaced with Rust-based alternatives for better performance and UX:

| Standard | Replacement | Command | Description |
| --- | --- | --- | --- |
| cd | zoxide | cd / z | Smarter directory navigation |
| vi / vim | helix | hx | Modern modal editor |
| ls | eza | ls / ll | Modern file listing |
| cat | bat | cat | Syntax highlighting viewer |
| grep | ripgrep | rg | Fast text search |
| find | fd | fd | Simple file search |
| curl | xh | xh | HTTP API Client |
| top | bottom | btm | System monitor |
| git | gitui | gu | Terminal Git GUI |
| diff | delta | (auto) | Git diff viewer |
| du | dust | du | Disk usage analyzer |
| (Manual) | git-cliff | git cliff | Auto-generate Changelog |

```
