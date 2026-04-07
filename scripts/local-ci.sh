#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

require_cmd() {
    local cmd=$1
    local hint=$2

    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi

    echo "Missing required command: $cmd" >&2
    echo "Hint: $hint" >&2
    exit 1
}

run_step() {
    local label=$1
    shift

    printf '\n==> %s\n' "$label"
    "$@"
}

require_cmd bash "bash is required to run repository scripts"
require_cmd just "install just: https://github.com/casey/just"
require_cmd podman "install podman to reproduce Dockerfile lint/build locally"
require_cmd shellcheck "install shellcheck locally to match the CI shell lint job"

run_step "Shellcheck" shellcheck check_links.sh test_infra.sh scripts/*.sh tests/*.sh
run_step "Ghostty integration tests" bash tests/test-ghostty-integration.sh
run_step "Documentation links" just audit-links
run_step "Dockerfile lint" podman run --rm -i -v "$ROOT_DIR:/work:Z" -w /work docker.io/hadolint/hadolint hadolint Dockerfile

run_step "Container build (format docker)" podman build --format docker --build-arg USER_ID="$(id -u)" --build-arg USER_NAME="$(whoami)" -t labo-local-ci-smoke .

run_step "CLI tools integration tests (container)" podman run --rm \
    -v "$ROOT_DIR:/home/$(whoami)/project:ro,z" \
    labo-local-ci-smoke \
    bash "/home/$(whoami)/project/tests/test-cli-tools.sh"

printf '\nAll local CI checks passed.\n'
