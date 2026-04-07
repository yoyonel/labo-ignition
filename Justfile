user_id := `id -u`
user_name := `whoami`
container_name := "labo-ci"
image := "debian:trixie"
script_name := "test_infra.sh"

default:
    @just --list

# --- Recettes d'audit ---

# Valider tous les liens dans tous les fichiers Markdown du repo
audit-links:
    #!/usr/bin/env bash
    chmod +x check_links.sh
    exit_code=0
    while IFS= read -r -d '' file; do
        ./check_links.sh "$file" || exit_code=1
    done < <(find . -maxdepth 2 -name "*.md" -print0 | sort -z)
    exit $exit_code

# Installe Ghostty (AppImage sur Linux générique, dnf sur Fedora, brew sur macOS)
install-ghostty:
    #!/usr/bin/env bash
    chmod +x scripts/install-ghostty.sh
    ./scripts/install-ghostty.sh

# Configure Ghostty (~/.config/ghostty/config) selon les bonnes pratiques
configure-ghostty:
    #!/usr/bin/env bash
    chmod +x scripts/configure-ghostty.sh
    ./scripts/configure-ghostty.sh

# Installation + Configuration en une seule commande
setup-ghostty: install-ghostty configure-ghostty
    @echo -e "\e[1;32m✓ Ghostty complètement installé et configuré\e[0m"

# Valider la configuration Ghostty (graceful si absent)
audit-ghostty:
    #!/usr/bin/env bash
    if ! command -v ghostty &>/dev/null; then
        echo -e "\e[1;33m⚠ Ghostty non installé\e[0m"
        echo -e "\e[1;33m  → Run: just install-ghostty\e[0m"
        exit 0
    fi
    echo -e "\e[1;36m==> Audit du fichier de configuration Ghostty..\e[0m"
    ghostty +validate-config
    echo -e "\e[1;32m✓ Configuration Ghostty valide\e[0m"

# Audit de l'instructure via le script CI (Podman)
audit-infra: test-ci

# Audit complet (Liens + Infra)
audit: audit-links audit-infra

# Tests pour l'intégration Ghostty (suite de tests programmatique)
test-ghostty:
    #!/usr/bin/env bash
    set -u
    bash tests/test-ghostty-integration.sh

# --- CI et Maintenance ---

# Lancement de la CI complète (Podman)
test-ci:
    #!/usr/bin/env bash
    set -e
    echo -e "\e[1;36m==> Lancement de la CI en salle blanche (Podman)...\e[0m"
    chmod +x {{script_name}}
    podman run --name {{container_name}} --rm \
      -v $(pwd)/dotfiles:/mnt/dotfiles:ro,z \
      -v $(pwd)/{{script_name}}:/{{script_name}}:ro,z \
      {{image}} bash /{{script_name}}

# --- Laboratoire de développement (Docker/Podman) ---

# Construit l'image avec ton utilisateur hôte pour les permissions
build:
    podman build \
      --build-arg USER_ID={{user_id}} \
      --build-arg USER_NAME={{user_name}} \
      -t {{container_name}} .

# Lance le labo (Miroir $HOME + Terminal ISO + Marqueur PROMPT)
lab: build
    #!/usr/bin/env bash
    set -e
    # Détecte Ghostty et ses variables d'env
    chmod +x scripts/detect-ghostty.sh
    source ./scripts/detect-ghostty.sh || true
    
    podman rm -f {{container_name}}-run 2>/dev/null || true
    podman run -it --rm --name {{container_name}}-run \
        --security-opt label=disable --network host \
        --user root -e USER={{user_name}} -e HOME=$HOME \
        -v $HOME:$HOME \
        -e IN_LAB=true \
        -e TERM -e COLORTERM -e XDG_RUNTIME_DIR \
        -e GHOSTTY_BIN_DIR="${GHOSTTY_BIN_DIR:-}" \
        -e GHOSTTY_RESOURCES_DIR="${GHOSTTY_RESOURCES_DIR:-}" \
        --workdir $(pwd) {{container_name}} bash

# Nettoyage
clean:
    podman rm -f {{container_name}} 2>/dev/null || true
    podman rm -f {{container_name}}-run 2>/dev/null || true

clean-image:
    podman rmi {{container_name}} 2>/dev/null || true