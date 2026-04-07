#!/bin/bash
# install-ghostty.sh
# Installe Ghostty selon la méthode disponible sur le système :
#   - macOS       : Homebrew (brew install ghostty)
#   - Fedora/RHEL : dnf via Copr ouroboros/ghostty
#   - Linux x86_64/aarch64 : AppImage community (pkgforge-dev)
#     Ref: https://github.com/pkgforge-dev/ghostty-appimage/releases
#
# NOTE: Ghostty est écrit en Zig, PAS en Rust — la compilation
# from source nécessite Zig + blueprint-compiler + dépendances GTK,
# et n'est pas gérée ici (voir https://ghostty.org/docs/install/build).
# L'AppImage est le chemin le plus rapide et fiable sur Linux générique.

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
NC='\033[0m'

# Configuration
LOCAL_BIN_DIR="${HOME}/.local/bin"
GHOSTTY_BIN="${LOCAL_BIN_DIR}/ghostty"
APPIMAGE_REPO="pkgforge-dev/ghostty-appimage"

info()    { echo -e "${BLUE}[install-ghostty]${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1" >&2; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }

# Vérifie si Ghostty est déjà installé
check_existing() {
    if command -v ghostty &>/dev/null; then
        local version
        version=$(ghostty --version 2>/dev/null || echo "unknown")
        success "Ghostty déjà installé : $(which ghostty) ($version)"
        return 0
    fi
    return 1
}

# Crée ~/.local/bin et vérifie qu'il est dans $PATH
setup_local_bin() {
    mkdir -p "$LOCAL_BIN_DIR"
    if ! echo "$PATH" | grep -q "$LOCAL_BIN_DIR"; then
        warn "$HOME/.local/bin n'est pas dans \$PATH"
        warn "Ajoutez à ~/.bashrc ou ~/.zshrc :"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}

# Détecte l'architecture CPU pour choisir la bonne AppImage
detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)             echo "x86_64" ;;
        aarch64 | arm64)    echo "aarch64" ;;
        *)
            error "Architecture non supportée par les AppImages Ghostty: $arch"
            return 1
            ;;
    esac
}

# Récupère l'URL de la dernière AppImage via l'API GitHub
# Ref: https://docs.github.com/en/rest/releases/releases
fetch_appimage_url() {
    local arch=$1
    local api_url="https://api.github.com/repos/${APPIMAGE_REPO}/releases/latest"

    # info() redirigé vers stderr pour ne pas polluer stdout (capturé par l'appelant)
    echo -e "${BLUE}[install-ghostty]${NC} Interrogation de l'API GitHub : $api_url" >&2

    local release_json
    release_json=$(curl -fsSL "$api_url") || {
        error "Impossible de contacter l'API GitHub"
        return 1
    }

    local url
    url=$(echo "$release_json" | python3 -c "
import json, sys
assets = json.load(sys.stdin)['assets']
for a in assets:
    name = a['name']
    if '${arch}' in name and name.endswith('.AppImage') and '.zsync' not in name:
        print(a['browser_download_url'])
        break
" 2>/dev/null)

    if [[ -z "$url" ]]; then
        error "Aucune AppImage trouvée pour l'architecture ${arch}" >&2
        return 1
    fi

    echo "$url"
}

# Installation via AppImage (Linux générique)
# Ref: https://github.com/pkgforge-dev/ghostty-appimage
install_via_appimage() {
    local arch
    arch=$(detect_arch) || return 1

    info "Téléchargement de l'AppImage Ghostty (${arch})..."

    local appimage_url
    appimage_url=$(fetch_appimage_url "$arch") || return 1
    info "URL : $appimage_url"

    setup_local_bin

    # Télécharge directement en tant que binaire final
    curl -fL --progress-bar -o "$GHOSTTY_BIN" "$appimage_url" || {
        error "Échec du téléchargement"
        return 1
    }
    chmod +x "$GHOSTTY_BIN"

    success "Ghostty installé : $GHOSTTY_BIN"
    "$GHOSTTY_BIN" --version
}

# Installation via Fedora/RHEL (dnf + Copr)
# Ref: https://copr.fedorainfracloud.org/coprs/ouroboros/ghostty/
install_via_dnf() {
    info "Fedora/RHEL détecté — installation via dnf + Copr"

    sudo dnf copr enable -y ouroboros/ghostty || {
        error "Échec de l'activation du Copr ouroboros/ghostty"
        return 1
    }
    sudo dnf install -y ghostty || {
        error "Échec de l'installation dnf"
        return 1
    }

    success "Ghostty installé via dnf"
    ghostty --version
}

# Installation sur macOS via Homebrew
install_via_homebrew() {
    info "macOS détecté — installation via Homebrew"

    if ! command -v brew &>/dev/null; then
        error "Homebrew non trouvé. Installez-le : https://brew.sh"
        return 1
    fi

    brew install ghostty || {
        error "Échec de l'installation Homebrew"
        return 1
    }

    success "Ghostty installé via Homebrew"
    ghostty --version
}

main() {
    info "Début de l'installation Ghostty"
    echo ""

    check_existing && return 0

    if [[ "$OSTYPE" == "darwin"* ]]; then
        install_via_homebrew
    elif command -v dnf &>/dev/null; then
        install_via_dnf
    else
        # Linux générique (Debian, Ubuntu, etc.) : AppImage
        install_via_appimage
    fi
}

main "$@"
