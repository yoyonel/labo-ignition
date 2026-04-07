# 🧪 Infrastructure as Code - Lab Environnement

[![CI](https://github.com/yoyonel/labo-ignition/actions/workflows/ci.yml/badge.svg)](https://github.com/yoyonel/labo-ignition/actions/workflows/ci.yml)
[![Docker](https://github.com/yoyonel/labo-ignition/actions/workflows/docker.yml/badge.svg)](https://github.com/yoyonel/labo-ignition/actions/workflows/docker.yml)

Ce projet fournit un environnement de développement conteneurisé robuste, basé sur **Debian 13 (Trixie)**, optimisé pour un usage transparent sous **Bazzite/Fedora** avec le terminal **Ghostty**.

## 🚀 Démarrage Rapide

Pour lancer ton environnement de labo :
```bash
just lab
```
Cette commande construit l'image (si nécessaire) et te dépose dans un shell Debian 13 avec ton identité hôte et ton `$HOME` monté en miroir.

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
| `just lab` | Lance le shell interactif (Miroir $HOME + Outils natifs). |
| `just audit` | Valide ta configuration Ghostty et tes dotfiles. |
| `just audit-links` | Analyse tes documentations Markdown et vérifie la validité des URLs. |
| `just lint-shell` | Rejoue le lint shell de la CI localement. |
| `just lint-dockerfile` | Rejoue le lint Dockerfile de la CI localement. |
| `just ci-local` | Rejoue localement les prérequis CI/CD avant push. |
| `just install-hooks` | Installe les hooks `pre-commit` et `pre-push` du repo. |
| `just test-ghostty` | Exécute la suite de tests Ghostty et documentation. |
| `just build` | Force la reconstruction de l'image `labo-ci`. |
| `just clean` | Supprime les conteneurs et images orphelines. |

## 🏗️ Architecture du Conteneur

L'image `labo-ci` est autonome et installe nativement :
- **Navigation** : `yazi`, `fzf`, `fd`, `rg`.
- **Système** : `tmux`, `bat`, `direnv`, `procs`.
- **Développement** : `uv`, `starship`, `jump`, `curl`, `git`.
- **Rendu** : `imagemagick`, `chafa`, `ffmpegthumbnailer`, `poppler-utils`.

## 🛡️ Sécurité & Permissions
- **Mirror Mount** : Ton `$HOME` hôte est monté tel quel (ex: `/var/home/latty`). Toutes tes configs (`.bashrc`, `.ssh`, `.gitconfig`) sont disponibles.
- **SELinux** : Le labo est lancé avec `--security-opt label=disable` pour permettre l'accès à tes fichiers sans conflits de permissions sur Bazzite.
- **Rootless** : Podman tourne en mode non-root. Le container s'exécute avec `--user root` : en rootless podman, `root` dans le container = ton `uid` hôte (1000), sans aucun privilège supplémentaire. C'est la même technique qu'utilise Distrobox.

## 🔁 CI/CD GitHub

Le repo embarque maintenant une base GitHub Actions exploitable immédiatement.

- **CI** : lint shell, exécution de la suite `tests/test-ghostty-integration.sh`, validation des liens, lint Dockerfile.
- **Docker** : build de l'image sur PR et pushes pertinents, publication sur GHCR lors d'un push sur `master` ou `main`.
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
