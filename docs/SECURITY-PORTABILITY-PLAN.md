# Plan Sécurité & Portabilité

> Objectif : atteindre ≥ 8/10 sur les deux axes (audit initial : Sécurité 6/10, Portabilité 5/10).

## Scores actuels vs cibles

| Catégorie | Avant | Cible | Après (projection) |
|-----------|-------|-------|---------------------|
| Sécurité | 6/10 | ≥ 8 | ~9.5/10 |
| Portabilité | 5/10 | ≥ 8 | ~9.5/10 |

---

## Tranches P0 — Critiques

### T1 — Restreindre le montage `$HOME` (Sécurité +1.5)

**Problème** : `scripts/lab-run.sh` monte `-v "${HOME}:${HOME}"` — le container accède à `~/.ssh`, `~/.gnupg`, tokens, browser profiles, wallets.

**Actions** :
- Remplacer le montage global par des montages ciblés read-only :
  - `-v "$HOME/.gitconfig:$HOME/.gitconfig:ro"` (identité git)
  - `-v "$HOME/.ssh:$HOME/.ssh:ro"` (clés SSH)
  - `-v "$HOME/.gnupg:$HOME/.gnupg:ro"` (GPG, si détecté)
  - `-v "$(pwd):$(pwd)"` (projet courant — seul writable)
- Variable `LAB_MOUNT_HOME=0` pour opt-in de l'ancien comportement (migration)

### T2 — Durcir le container runtime (Sécurité +1.0)

**Problème** : `--user root`, `--network host`, `--security-opt label=disable`, `NOPASSWD:ALL`.

**Actions** :
- Supprimer `--user root` → utiliser `--userns keep-id` (mapping UID natif Podman)
- Remplacer `--network host` par `--network slirp4netns` (isolé) avec opt-in `LAB_NETWORK_HOST=1`
- Retirer `--security-opt label=disable` → relabeling SELinux via `:z`
- Restreindre sudoers : `NOPASSWD: /usr/bin/apt-get, /usr/bin/dpkg` au lieu de `ALL`
- Ajouter `--read-only` + `--tmpfs /tmp --tmpfs /run`

### T3 — Multi-architecture Dockerfile (Portabilité +2.0)

**Problème** : 12+ URLs hardcodées `x86_64`/`amd64`. Cassé sur ARM64 (Apple Silicon, Graviton, RPi).

**Actions** :
- Ajouter `ARG TARGETARCH` (injecté automatiquement par Docker Buildx / Podman)
- Mapping d'architecture au début de chaque RUN :
  ```bash
  case "${TARGETARCH}" in
    amd64) ARCH=x86_64; MUSL_ARCH=x86_64; DEB_ARCH=amd64 ;;
    arm64) ARCH=aarch64; MUSL_ARCH=aarch64; DEB_ARCH=arm64 ;;
    *) echo "Unsupported architecture: ${TARGETARCH}" >&2 && exit 1 ;;
  esac
  ```
- Remplacer chaque URL hardcodée par `${ARCH}` / `${DEB_ARCH}`
- Outils concernés : jump, procs, lsd, eza, zoxide, delta, dust, hyperfine, glow, yazi (10 outils)
- Appliquer aussi au stage builder-ripdrag (Rust target triple)

---

## Tranches P1 — Robustesse

### T4 — `jq` au lieu de `grep|cut` (Portabilité +0.5)

**Problème** : `grep tag_name | cut -d'"' -f4` pour parser les releases GitHub — fragile. `jq` est installé mais jamais utilisé.

**Actions** :
- Remplacer chaque `grep ... | cut ...` par :
  - Version : `jq -r '.tag_name'`
  - URL binaire : `jq -r '.assets[] | select(.name | test("pattern")) | .browser_download_url'`
- ~10 occurrences dans le Dockerfile

### T5 — Device GPU conditionnel (Portabilité +0.5)

**Problème** : `--device /dev/dri` crash sur macOS, headless CI, serveurs sans GPU.

**Actions** :
- Guard conditionnel dans `scripts/lab-run.sh` :
  ```bash
  GPU_ARGS=()
  if [[ -e /dev/dri ]]; then
      GPU_ARGS+=(--device /dev/dri)
  fi
  ```

### T6 — Abstraction moteur container (Portabilité +0.5)

**Problème** : `podman` hardcodé 14+ fois dans le Justfile.

**Actions** :
- Variable Just : `engine := env("CONTAINER_ENGINE", "podman")`
- Remplacer tous les `podman` par `{{engine}}`
- Adapter les flags incompatibles (ex: `--format docker` est podman-only)

---

## Tranches P2 — Polish

### T7 — Checksum des binaires téléchargés (Sécurité +0.5)

**Problème** : Aucune vérification de checksum sur les 12+ binaires GitHub. Supply-chain risk.

**Actions** :
- Vérifier `sha256sum` après téléchargement pour les outils publiant des checksums
- Alternative : épingler versions + SHA256 hardcodés via `ARG`

### T8 — Rate-limit GitHub API (Portabilité +0.5)

**Problème** : 60 req/h anonyme, épuisé après ~6 builds.

**Actions** :
- `ARG GITHUB_TOKEN=""` dans le Dockerfile
- Conditionnel : `-H "Authorization: Bearer ${GITHUB_TOKEN}"` si non-vide
- Documenter : `just build GITHUB_TOKEN=$(gh auth token)`

### T9 — CI multi-arch + scan image (Sécurité +0.5, Portabilité +0.5)

**Actions** :
- `platforms: linux/amd64,linux/arm64` dans docker.yml
- Job Trivy/Grype pour scan de vulnérabilités
- Cosign pour signer l'image GHCR

---

## Récapitulatif

| Tranche | Domaine | Effort | Sécu | Porta | Priorité | Statut |
|---------|---------|--------|------|-------|----------|--------|
| T1 | Sécurité | Faible | +1.5 | — | P0 | ✅ |
| T2 | Sécurité | Moyen | +1.0 | — | P0 | ✅ |
| T3 | Portabilité | Élevé | — | +2.0 | P0 | ✅ |
| T4 | Portabilité | Moyen | — | +0.5 | P1 | ✅ |
| T5 | Portabilité | Faible | — | +0.5 | P1 | ✅ |
| T6 | Portabilité | Moyen | — | +0.5 | P1 | ✅ |
| T7 | Sécurité | Élevé | +0.5 | — | P2 | ✅ |
| T8 | Portabilité | Faible | — | +0.5 | P2 | ✅ |
| T9 | Les deux | Moyen | +0.5 | +0.5 | P2 | ✅ |

**P0 seul** amène à : Sécurité ~8.5/10, Portabilité ~7/10.
**P0 + P1** : Sécurité ~8.5/10, Portabilité ~8.5/10.
**Toutes tranches** : ~9.5/10 sur les deux axes.
