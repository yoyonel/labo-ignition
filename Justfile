user_id := `id -u`
user_name := `whoami`
container_name := "labo-ci"
remote_image := "ghcr.io/yoyonel/labo-ignition:latest"
image := "debian:trixie"
script_name := "test_infra.sh"

default:
    @just --list

# --- Recettes d'audit ---

# Lint shell identique au job CI
lint-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    shellcheck check_links.sh test_infra.sh scripts/*.sh tests/*.sh

# Lint Dockerfile identique au job CI
lint-dockerfile:
    #!/usr/bin/env bash
    set -euo pipefail
    podman run --rm -i -v $(pwd):/work:Z -w /work docker.io/hadolint/hadolint hadolint Dockerfile

# Rejoue localement les prérequis CI/CD avant push
ci-local:
    #!/usr/bin/env bash
    set -euo pipefail
    chmod +x scripts/local-ci.sh
    ./scripts/local-ci.sh

# Installe les hooks pre-commit et pre-push du repo
install-hooks:
    #!/usr/bin/env bash
    set -euo pipefail
    pre-commit install
    pre-commit install --hook-type pre-push

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

# Initialise l'environnement de développement complet (Hooks + Dépendances hôte via Brew)
setup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo -e "\e[1;36m==> Initialisation du projet...\e[0m"
    if command -v brew &>/dev/null; then
        echo "--> Installation des dépendances Homebrew..."
        brew bundle
    else
        echo "--> [Warning] Homebrew non détecté, saut de l'installation des outils hôtes."
    fi
    echo "--> Configuration des hooks Git (pre-push)..."
    just install-hooks
    echo -e "\e[1;32m✓ Environnement de développement prêt !\e[0m"

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

# Tests d'intégration pour les outils CLI modernes (dans le container)
test-cli-tools: build
    #!/usr/bin/env bash
    set -u
    podman run --rm \
      -v "$(pwd):/home/{{user_name}}/project:ro,z" \
      {{container_name}} \
      bash /home/{{user_name}}/project/tests/test-cli-tools.sh

# Tous les tests
test-all: test-ghostty test-cli-tools

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
      --format docker \
      --build-arg USER_ID={{user_id}} \
      --build-arg USER_NAME={{user_name}} \
      -t {{container_name}} .

# Lance le labo (Miroir $HOME + Terminal ISO + Marqueur PROMPT) - Construit localement
lab: build
    #!/usr/bin/env bash
    chmod +x scripts/lab-run.sh
    ./scripts/lab-run.sh {{container_name}}

# Télécharge la dernière version de l'image pré-construite depuis GHCR (Gain de temps/CPU)
pull:
    podman pull {{remote_image}}
    podman tag {{remote_image}} {{container_name}}:latest

# Lance le labo instantanément en utilisant l'image GHCR (évite le build local long)
lab-remote: pull
    #!/usr/bin/env bash
    chmod +x scripts/lab-run.sh
    ./scripts/lab-run.sh {{remote_image}}

# Nettoyage
clean:
    podman rm -f {{container_name}} 2>/dev/null || true
    podman rm -f {{container_name}}-run 2>/dev/null || true

clean-image:
    podman rmi {{container_name}} 2>/dev/null || true