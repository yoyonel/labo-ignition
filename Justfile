user_id := `id -u`
user_name := `whoami`
container_name := "labo-ci"
image := "debian:trixie"
script_name := "test_infra.sh"

default:
    @just --list

# --- Recettes d'audit ---

# Valider tous les liens de la documentation architecturale
audit-links:
    #!/usr/bin/env bash
    chmod +x check_links.sh
    ./check_links.sh

# Valider la configuration Ghostty (nécessite Ghostty installé localement)
audit-ghostty:
    @echo -e "\e[1;36m==> Audit du fichier de configuration Ghostty...\e[0m"
    ghostty +validate-config

# Audit de l'instructure via le script CI (Podman)
audit-infra: test-ci

# Audit complet (Liens + Infra)
audit: audit-links audit-infra

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
    podman rm -f {{container_name}}-run 2>/dev/null || true
    podman run -it --rm --name {{container_name}}-run \
        --security-opt label=disable --userns keep-id --network host \
        -v $HOME:$HOME \
        -e IN_LAB=true \
        -e TERM -e COLORTERM -e XDG_RUNTIME_DIR -e GHOSTTY_BIN_DIR -e GHOSTTY_RESOURCES_DIR \
        --workdir $(pwd) {{container_name}} bash

# Nettoyage
clean:
    podman rm -f {{container_name}} 2>/dev/null || true
    podman rm -f {{container_name}}-run 2>/dev/null || true

clean-image:
    podman rmi {{container_name}} 2>/dev/null || true