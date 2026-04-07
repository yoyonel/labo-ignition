#!/bin/bash
# configure-ghostty.sh
# Copie et valide la configuration Ghostty depuis dotfiles/

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
NC='\033[0m'

# Chemins
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DOTFILES_CONFIG="${REPO_DIR}/dotfiles/ghostty/config"
GHOSTTY_CONFIG_DIR="${HOME}/.config/ghostty"
GHOSTTY_CONFIG_FILE="${GHOSTTY_CONFIG_DIR}/config"

info() {
    echo -e "${BLUE}[configure-ghostty]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Vérifie que dotfiles/ghostty/config existe
check_dotfiles_config() {
    if [[ ! -f "$DOTFILES_CONFIG" ]]; then
        error "Config par défaut non trouvée: $DOTFILES_CONFIG"
        return 1
    fi
    success "Config par défaut trouvée: $DOTFILES_CONFIG"
    return 0
}

# Crée le répertoire ~/.config/ghostty s'il n'existe pas
setup_config_dir() {
    if [[ ! -d "$GHOSTTY_CONFIG_DIR" ]]; then
        info "Création de $GHOSTTY_CONFIG_DIR"
        mkdir -p "$GHOSTTY_CONFIG_DIR"
        success "Répertoire créé"
    fi
}

# Sauvegarde l'ancienne config si elle existe
backup_config() {
    if [[ -f "$GHOSTTY_CONFIG_FILE" ]]; then
        local backup_file="${GHOSTTY_CONFIG_FILE}.backup.$(date +%s)"
        info "Configuration existante sauvegardée: $backup_file"
        cp "$GHOSTTY_CONFIG_FILE" "$backup_file"
    fi
}

# Copie la configuration
copy_config() {
    info "Copie de la configuration par défaut..."
    cp "$DOTFILES_CONFIG" "$GHOSTTY_CONFIG_FILE"
    success "Config écrite: $GHOSTTY_CONFIG_FILE"
}

# Affiche un extrait de la config
show_config_preview() {
    echo ""
    echo "Aperçu de la config:"
    echo "─────────────────────────────────────────"
    head -20 "$GHOSTTY_CONFIG_FILE" | sed 's/^/  /'
    echo "  ... (voir $GHOSTTY_CONFIG_FILE pour la version complète)"
    echo "─────────────────────────────────────────"
    echo ""
}

# Vérifie les fonts recommandées et liste les alternatives disponibles
check_fonts() {
    info "Vérification des fonts disponibles..."
    
    # Récupère les Nerd Fonts monospace disponibles
    # fc-list :spacing=100 filtre les monospace fonts seulement
    # cut -d',' -f1 prend le premier nom de chaque famille
    # sort -u déduplique
    local available_nerd_fonts
    available_nerd_fonts=$(fc-list :spacing=100 family 2>/dev/null | grep -i "nerd font" | awk -F',' '{print $1}' | sort -u)
    
    if [[ -n "$available_nerd_fonts" ]]; then
        success "Fonts Nerd monospace trouvées:"
        echo "$available_nerd_fonts" | head -5 | while read -r font; do
            echo "  • $font"
        done
        local count=$(echo "$available_nerd_fonts" | wc -l)
        if [[ $count -gt 5 ]]; then
            echo "  ... et $(( count - 5 )) autres"
        fi
        return 0
    else
        warn "Aucune Nerd Font monospace trouvée"
        info "Pour installer une Nerd Font (recommandé pour glyphes powerline/icons):"
        case "$OSTYPE" in
            linux-gnu*)
                echo "  Option 1 : Noto Emoji (emoji support) :"
                echo "    sudo apt install fonts-noto-color-emoji"
                echo ""
                echo "  Option 2 : JetBrainsMono Nerd Font (recommandé) :"
                echo "    mkdir -p ~/.local/share/fonts"
                echo "    cd ~/.local/share/fonts"
                echo "    curl -sL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.0/JetBrainsMono.zip -o JetBrainsMono.zip"
                echo "    unzip JetBrainsMono.zip && rm JetBrainsMono.zip"
                echo "    fc-cache -fv"
                ;;
            darwin*)
                echo "  brew install font-jetbrains-mono-nerd-font"
                ;;
        esac
    fi
}

# Valide la syntaxe TOML de la config
validate_config() {
    info "Validation de la syntaxe Ghostty..."
    
    # Utilise Ghostty lui-même pour valider
    if command -v ghostty &>/dev/null; then
        if ghostty +validate-config &>/dev/null; then
            success "Conf Ghostty valide"
            return 0
        else
            error "La config contient des erreurs syntaxe"
            ghostty +validate-config
            return 1
        fi
    else
        warn "Ghostty non trouvé — validation manquée (non bloquant)"
        return 0
    fi
}

main() {
    info "Début de la configuration Ghostty"
    echo ""
    
    # Vérifications préalables
    check_dotfiles_config || return 1
    
    # Prépare le répertoire cible
    setup_config_dir
    
    # Sauvegarde l'ancienne config
    backup_config
    
    # Copie la nouvelle config
    copy_config
    
    # Affiche un aperçu
    show_config_preview
    
    # Vérifie les fonts
    check_fonts
    echo ""
    
    # Valide la syntaxe
    validate_config || {
        error "Configuration invalide"
        warn "Consultez $GHOSTTY_CONFIG_FILE et corrigez les erreurs"
        return 1
    }
    
    success "Configuration Ghostty complète et valide"
    info "Prochaines étapes:"
    echo "  1. Installez les fonts recommandées (voir ci-dessus)"
    echo "  2. Redémarrez Ghostty"
    echo "  3. Testez avec: ghostty +show-config"
    
    return 0
}

main "$@"

