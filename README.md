# 🧪 Infrastructure as Code - Lab Environnement

[![CI](https://github.com/yoyonel/labo-ignition/actions/workflows/ci.yml/badge.svg)](https://github.com/yoyonel/labo-ignition/actions/workflows/ci.yml)
[![Docker](https://github.com/yoyonel/labo-ignition/actions/workflows/docker.yml/badge.svg)](https://github.com/yoyonel/labo-ignition/actions/workflows/docker.yml)

Ce projet fournit un environnement de développement conteneurisé robuste, basé sur **Debian 13 (Trixie Slim)**, optimisé pour un usage transparent sous **Bazzite/Fedora** avec le terminal **Ghostty**.

Pour initialiser ton environnement (une seule fois) :
```bash
just setup
```

Pour lancer ton environnement de labo (via build local) :
```bash
just lab
```

Pour gagner du temps et du CPU (utilisation de l'image pré-construite sur la CI) :
```bash
just lab-remote
```
Cette commande télécharge l'image depuis GHCR et te dépose instantanément dans un shell Debian 13 avec ton identité hôte et ton `$HOME` monté en miroir.

## 🛠️ Configuration Recommandée

### 1. Marqueur de Prompt (Starship)
Puisque ton `$HOME` est partagé, ton prompt Starship sera identique à celui de l'hôte. Pour savoir visuellement que tu es "enfermé" dans le labo, ajoute ce bloc à la fin de ton `~/.config/starship.toml` sur ton hôte :

```toml
[custom.lab]
command = "echo 🧪 LAB"
when = 'test -n "$IN_LAB"'
format = "[$output]($style) "
style = "bold yellow"
```

### 2. Ghostty (Rendu Image Haute Résolution)
L'environnement propage les variables `GHOSTTY_*` et `TERM` pour permettre à des outils comme **Yazi** d'utiliser le protocole d'image haute performance au lieu du rendu pixelisé ANSI.

## 📦 Recettes Just Disponibles

| Commande | Description |
| :--- | :--- |
| `just setup` | Initialise l'environnement local (Hooks + Brew bundle). |
| `just lab` | Lance le shell (Build local — recommandé si tu as des besoins spécifiques). |
| `just lab-remote` | Lance le shell instantanément via l'image de la CI (Économise CPU & Temps). |
| `just pull` | Télécharge la dernière image depuis GitHub Container Registry (GHCR). |
| `just audit` | Valide ta configuration Ghostty et tes dotfiles. |
| `just audit-links` | Analyse tes documentations Markdown et vérifie la validité des URLs. |
| `just lint-shell` | Rejoue le lint shell de la CI localement. |
| `just lint-dockerfile` | Rejoue le lint Dockerfile de la CI localement. |
| `just ci-local` | Rejoue localement les prérequis CI/CD avant push. |
| `just install-hooks` | Installe les hooks `pre-commit` et `pre-push` du repo. |
| `just test-ghostty` | Exécute la suite de tests Ghostty et documentation. |
| `just build` | Force la reconstruction de l'image `labo-ci`. |
| `just analyze-image` | Rapport complet de taille image (dive + layers + deps). |
| `just dive` | Explore l'image interactivement avec dive (TUI). |
| `just debtree <pkg>` | Génère un graphe SVG des dépendances d'un paquet Debian. |
| `just apt-rdepends <pkg>` | Arbre de dépendances récursif d'un paquet. |
| `just clean` | Supprime les conteneurs et images orphelines. |

## 🏗️ Architecture du Conteneur

L'image `labo-ci` (~750 MB) est autonome et installe nativement :
- **Navigation** : `yazi`, `fzf`, `fd`, `rg`.
- **Système** : `tmux`, `bat`, `direnv`, `procs`.
- **Développement** : `uv`, `starship`, `jump`, `curl`, `git`.
- **Rendu** : `imagemagick`, `chafa`, `ffmpegthumbnailer`, `poppler-utils`.
- **GUI** : `ripdrag` (drag & drop GTK4, compilé via multi-stage build).

**Optimisations image** : base `debian:trixie-slim`, `--no-install-recommends`, multi-stage build pour `ripdrag` (Rust/GTK-dev isolés du runtime).

## 🛡️ Sécurité & Permissions
- **Montages ciblés** : Par défaut, seuls le répertoire projet (writable), `.gitconfig`, `.ssh` et `.gnupg` (read-only) sont montés. L'ancien comportement (montage complet de `$HOME`) est disponible via `LAB_MOUNT_HOME=1`.
- **Réseau isolé** : Le container utilise `slirp4netns` (réseau isolé). Pour l'ancien mode `--network host`, utiliser `LAB_NETWORK_HOST=1`.
- **Rootless** : Podman tourne en mode non-root. Le container s'exécute avec `--user root` : en rootless podman, `root` dans le container = ton `uid` hôte (1000), sans aucun privilège supplémentaire. C'est la même technique qu'utilise Distrobox.
- **Sudoers restreint** : `NOPASSWD` limité à `apt-get` et `dpkg` uniquement.
- **Display Forwarding** : Détection automatique X11/Wayland — `DISPLAY`, `XAUTHORITY`, socket X11 et socket Wayland sont propagés si présents.
- **GPU Passthrough** : `/dev/dri` monté conditionnellement (uniquement s'il existe sur l'hôte).
- **Scan de vulnérabilités** : Trivy analyse l'image en CI — les vulnérabilités CRITICAL bloquent le build, les HIGH sont reportées.

## ⚙️ Variables d'environnement (opt-in)

| Variable | Défaut | Description |
| :--- | :--- | :--- |
| `LAB_MOUNT_HOME` | `0` | `1` pour monter `$HOME` entier (ancien comportement, déconseillé) |
| `LAB_NETWORK_HOST` | `0` | `1` pour utiliser `--network host` au lieu de `slirp4netns` |
| `CONTAINER_ENGINE` | `podman` | Moteur container (`podman` ou `docker`) |
| `GITHUB_TOKEN` | _(vide)_ | Token GitHub pour éviter le rate-limit API lors du build |

**Exemples :**
```bash
# Build avec token GitHub (évite le rate-limit de 60 req/h)
just build GITHUB_TOKEN=$(gh auth token)

# Lancer le labo avec Docker au lieu de Podman
CONTAINER_ENGINE=docker just lab

# Lancer le labo avec montage $HOME complet (migration)
LAB_MOUNT_HOME=1 just lab
```

## 🔁 CI/CD GitHub

Le repo embarque maintenant une base GitHub Actions exploitable immédiatement.

- **CI** : lint shell, exécution de la suite `tests/test-ghostty-integration.sh`, validation des liens, lint Dockerfile.
- **Docker** : build de l'image sur PR et pushes pertinents, publication sur GHCR lors d'un push sur `master` ou `main`.
- **Image utilisable** : Tu peux consommer directement l'image de la CI via `just lab-remote` pour éviter de recompiler les outils lourds (comme `ripdrag`).
- **Dependabot** : surveillance hebdomadaire des actions GitHub et de la base Docker.

### Workflows

- `.github/workflows/ci.yml`
- `.github/workflows/docker.yml`
- `.github/dependabot.yml`

### Ce qui est testé sur GitHub Actions

- Scripts Bash : syntaxe et qualité via `shellcheck`
- Intégration Ghostty : suite de tests existante du repo
- Documentation : vérification des liens externes
- Dockerfile : lint structurel
- Image container : build smoke-test sur runner GitHub

### Ce qui n'est pas encore exécuté sur GitHub-hosted runners

- Validation sémantique via le vrai binaire `ghostty +validate-config` dans le workflow GitHub
- Exécution Podman rootless bout-en-bout du labo interactif

Ces deux points restent faisables plus tard avec un runner self-hosted ou un job plus spécialisé si on veut pousser la couverture encore plus loin.

## Flux local recommandé avant push

Le repo expose maintenant le même socle de vérifications côté local :

```bash
just ci-local
```

Cette commande rejoue :
- le lint shell
- la suite `tests/test-ghostty-integration.sh`
- la validation des liens Markdown
- le lint `hadolint` du `Dockerfile`
- un build smoke test de l'image

Pour automatiser ça avant chaque push :

```bash
pre-commit install
pre-commit install --hook-type pre-push
```

Ou via le repo :

```bash
just install-hooks
```
