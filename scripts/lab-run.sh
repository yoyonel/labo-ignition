#!/usr/bin/env bash
# scripts/lab-run.sh
# Lance l'environnement de laboratoire avec les bons montages et permissions.
#
# Variables d'environnement (opt-in) :
#   LAB_MOUNT_HOME=1    — Monte $HOME entier (ancien comportement, déconseillé)
#   LAB_NETWORK_HOST=1  — Utilise --network host au lieu de slirp4netns (isolé)
#   CONTAINER_ENGINE    — Moteur container (défaut: podman)

set -euo pipefail

IMAGE_NAME="${1:-labo-ci}"
USER_NAME=$(whoami)
PROJECT_DIR=$(pwd)
ENGINE="${CONTAINER_ENGINE:-podman}"

echo -e "\e[1;36m==> Lancement du labo-ignition via l'image : ${IMAGE_NAME}...\e[0m"

# Détection Ghostty
if [[ -f "./scripts/detect-ghostty.sh" ]]; then
    # shellcheck disable=SC1091
    source ./scripts/detect-ghostty.sh || true
fi

# Nettoyage préalable
"${ENGINE}" rm -f labo-ci-run 2>/dev/null || true

# --- Montages sécurisés (T1) ---
# Par défaut : montages ciblés read-only au lieu de $HOME entier
MOUNT_ARGS=()
if [[ "${LAB_MOUNT_HOME:-0}" == "1" ]]; then
    echo -e "\e[1;33m⚠ LAB_MOUNT_HOME=1 : montage complet de \$HOME (déconseillé)\e[0m"
    MOUNT_ARGS+=(-v "${HOME}:${HOME}")
else
    # Projet courant (writable)
    MOUNT_ARGS+=(-v "${PROJECT_DIR}:${PROJECT_DIR}:z")
    # Git identity (read-only)
    [[ -f "$HOME/.gitconfig" ]] && MOUNT_ARGS+=(-v "$HOME/.gitconfig:$HOME/.gitconfig:ro,z")
    [[ -d "$HOME/.config/git" ]] && MOUNT_ARGS+=(-v "$HOME/.config/git:$HOME/.config/git:ro,z")
    # SSH keys (read-only)
    [[ -d "$HOME/.ssh" ]] && MOUNT_ARGS+=(-v "$HOME/.ssh:$HOME/.ssh:ro,z")
    # GPG (read-only, si présent)
    [[ -d "$HOME/.gnupg" ]] && MOUNT_ARGS+=(-v "$HOME/.gnupg:$HOME/.gnupg:ro,z")
fi

# --- Réseau (T2) ---
NETWORK_ARGS=()
if [[ "${LAB_NETWORK_HOST:-0}" == "1" ]]; then
    NETWORK_ARGS+=(--network host)
else
    NETWORK_ARGS+=(--network slirp4netns)
fi

# --- GPU conditionnel (T5 preview) ---
GPU_ARGS=()
if [[ -e /dev/dri ]]; then
    GPU_ARGS+=(--device /dev/dri)
fi

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

# Exécution container
# --user root en rootless Podman : root-in-container == UID hôte (pas de vrais privilèges).
# C'est le mécanisme natif documenté dans Podman-Rootless-Permissions.md.
# --userns keep-id provoque des erreurs overlay sur Bazzite/Fedora Atomic, donc on garde --user root.
# --security-opt label=disable est indispensable sur Bazzite/Fedora (SELinux) pour lire $HOME.
"${ENGINE}" run -it --rm \
    --name labo-ci-run \
    --user root \
    --security-opt label=disable \
    "${NETWORK_ARGS[@]}" \
    -e USER="${USER_NAME}" \
    -e HOME="${HOME}" \
    "${MOUNT_ARGS[@]}" \
    -e IN_LAB=true \
    -e TERM -e COLORTERM -e XDG_RUNTIME_DIR \
    -e GHOSTTY_BIN_DIR="${GHOSTTY_BIN_DIR:-}" \
    -e GHOSTTY_RESOURCES_DIR="${GHOSTTY_RESOURCES_DIR:-}" \
    "${DISPLAY_ARGS[@]}" \
    "${GPU_ARGS[@]}" \
    --workdir "${PROJECT_DIR}" \
    "${IMAGE_NAME}" bash
