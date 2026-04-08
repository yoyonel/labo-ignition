#!/usr/bin/env bash
# scripts/lab-run.sh
# Lance l'environnement de laboratoire avec les bons montages et permissions.

set -euo pipefail

IMAGE_NAME="${1:-labo-ci}"
USER_NAME=$(whoami)
PROJECT_DIR=$(pwd)

echo -e "\e[1;36m==> Lancement du labo-ignition via l'image : ${IMAGE_NAME}...\e[0m"

# Détection Ghostty
if [[ -f "./scripts/detect-ghostty.sh" ]]; then
    # shellcheck disable=SC1091
    source ./scripts/detect-ghostty.sh || true
fi

# Nettoyage préalable
podman rm -f labo-ci-run 2>/dev/null || true

# Gestion du Display (X11 + Wayland)
DISPLAY_ARGS=()
if [[ -n "${DISPLAY:-}" ]]; then
    DISPLAY_ARGS+=(-e "DISPLAY=${DISPLAY}" -v /tmp/.X11-unix:/tmp/.X11-unix:ro)
    # On gère XAUTHORITY si présent
    if [[ -v XAUTHORITY ]]; then
         DISPLAY_ARGS+=(-e "XAUTHORITY=${XAUTHORITY}")
         [[ -f "$XAUTHORITY" ]] && DISPLAY_ARGS+=(-v "$XAUTHORITY:$XAUTHORITY:ro")
    elif [[ -f "$HOME/.Xauthority" ]]; then
         DISPLAY_ARGS+=(-e "XAUTHORITY=$HOME/.Xauthority" -v "$HOME/.Xauthority:$HOME/.Xauthority:ro")
    fi
fi

if [[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" ]]; then
    WAYLAND_SOCKET="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
    if [[ -S "$WAYLAND_SOCKET" ]]; then
        DISPLAY_ARGS+=(-e "WAYLAND_DISPLAY=${WAYLAND_DISPLAY}" -v "${WAYLAND_SOCKET}:${WAYLAND_SOCKET}:ro")
    fi
fi

# Exécution Podman
# Note: On utilise --user root pour que root-in-container == host-user en rootless Podman.
# Cela garantit que le montage de $HOME fonctionne sans friction de permissions.
podman run -it --rm \
    --name labo-ci-run \
    --security-opt label=disable \
    --network host \
    --user root \
    -e USER="${USER_NAME}" \
    -e HOME="${HOME}" \
    -v "${HOME}:${HOME}" \
    -e IN_LAB=true \
    -e TERM -e COLORTERM -e XDG_RUNTIME_DIR \
    -e GHOSTTY_BIN_DIR="${GHOSTTY_BIN_DIR:-}" \
    -e GHOSTTY_RESOURCES_DIR="${GHOSTTY_RESOURCES_DIR:-}" \
    "${DISPLAY_ARGS[@]}" \
    --device /dev/dri \
    --workdir "${PROJECT_DIR}" \
    "${IMAGE_NAME}" bash
