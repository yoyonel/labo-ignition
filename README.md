# 🧪 Infrastructure as Code - Lab Environnement

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
| `just check-links` | Analyse tes documentations Markdown et vérifie la validité des URLs. |
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
- **Rootless** : Podman tourne en mode non-root avec `--userns keep-id`.
