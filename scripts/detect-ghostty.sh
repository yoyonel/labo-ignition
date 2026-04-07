#!/bin/bash
# detect-ghostty.sh
# Détecte l'installation Ghostty et définit les variables d'environnement
# Sourced par Justfile pour la propagation au container
# Exit 0 si Ghostty trouvé, 1 sinon (mais ne fail pas les recettes)

# IMPORTANT: set -e NOT used — must export vars even if Ghostty absent
set -uo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Détecte le binaire Ghostty
detect_binary() {
    if command -v ghostty &>/dev/null; then
        command -v ghostty
        return 0
    fi
    return 1
}

# Détecte le répertoire de ressources
detect_resources_dir() {
    local appimage_extraction_dir="${APPIMAGE_EXTRACTION_DIR:-}"
    
    # Si lancé depuis une AppImage (detection script appelé depuis machine.AppImage)
    if [[ -n "$appimage_extraction_dir" ]] && [[ -d "$appimage_extraction_dir/share/ghostty" ]]; then
        echo "$appimage_extraction_dir/share/ghostty"
        return 0
    fi
    
    # Cherche les mount points AppImage temporaires
    # AppImage monte généralement à /tmp/.mount_XXXXXXXXXXXXXXX
    for tmp_mount in /tmp/.mount_*; do
        if [[ -d "$tmp_mount/share/ghostty" ]]; then
            echo "$tmp_mount/share/ghostty"
            return 0
        fi
    done
    
    # Cherche dans les chemins standard système
    for dir in /usr/share/ghostty ~/.local/share/ghostty /opt/ghostty/share; do
        if [[ -d "$dir" ]]; then
            echo "$dir"
            return 0
        fi
    done
    
    return 1
}

main() {
    local ghostty_bin=""
    local ghostty_resources_dir=""
    local status=0
    
    # Tentative de détection du binaire
    if ghostty_bin=$(detect_binary 2>/dev/null); then
        echo -e "${GREEN}✓ Ghostty binaire trouvé${NC} : $ghostty_bin"
    else
        echo -e "${YELLOW}⚠ Ghostty binaire non trouvé${NC}"
        echo -e "${YELLOW}  → Run: just install-ghostty${NC}"
        ghostty_bin=""
        status=1
    fi
    
    # Tentative de détection des ressources
    if ghostty_resources_dir=$(detect_resources_dir 2>/dev/null); then
        echo -e "${GREEN}✓ Ghostty ressources trouvées${NC} : $ghostty_resources_dir"
    else
        echo -e "${YELLOW}⚠ Ghostty ressources non trouvées${NC}"
        ghostty_resources_dir=""
        status=1
    fi
    
    # ALWAYS export — variables doivent être disponibles même si vides
    export GHOSTTY_BIN_DIR="$ghostty_bin"
    export GHOSTTY_RESOURCES_DIR="$ghostty_resources_dir"
    
    # Affichage final avec contexte
    echo ""
    if [[ -n "$ghostty_bin" ]]; then
        if [[ -n "$ghostty_resources_dir" ]]; then
            echo -e "${GREEN}[detect-ghostty]${NC} ✓ Ghostty opérationnel (binaire + ressources)"
        else
            if file "$ghostty_bin" 2>/dev/null | grep -q "AppImage"; then
                echo -e "${GREEN}[detect-ghostty]${NC} ✓ Ghostty (AppImage) opérationnel (ressources intégrées)"
                status=0  # AppImage avec ressources intégrées = OK
            else
                echo -e "${YELLOW}[detect-ghostty]${NC} ⚠ Ghostty trouvé mais ressources manquantes"
                echo -e "${YELLOW}  → N'affecte généralement pas les usages courants${NC}"
            fi
        fi
    else
        echo -e "${RED}[detect-ghostty]${NC} ✗ Ghostty non détecté"
        echo -e "${YELLOW}  → Installation : just install-ghostty${NC}"
    fi
    
    # Return status, mais script continue (set -e not used)
    return $status
}

main "$@" || true
