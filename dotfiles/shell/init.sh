#!/bin/bash
# Initialisation des outils CLI modernes
# Source ce fichier depuis ~/.bashrc ou ~/.zshrc :
#   source ~/.config/shell/init.sh

# ============================================================
# zoxide — cd intelligent avec apprentissage
# Ref: https://github.com/ajeetdsouza/zoxide#installation
# ============================================================
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init bash)"
    # Pour zsh, remplacer "bash" par "zsh"
fi

# ============================================================
# starship — Prompt cross-shell
# Ref: https://starship.rs/guide/#step-2-set-up-your-shell-to-use-starship
# ============================================================
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
    # Pour zsh, remplacer "bash" par "zsh"
fi

# ============================================================
# Charger les aliases
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/aliases.sh" ]]; then
    # shellcheck source=aliases.sh
    source "$SCRIPT_DIR/aliases.sh"
fi
