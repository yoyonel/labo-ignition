# Documentation : Outils CLI Modernes

Cette documentation couvre l'installation, la configuration et l'utilisation des outils CLI modernes du projet. Chaque outil remplace un utilitaire UNIX classique par une alternative plus rapide, plus lisible et plus ergonomique.

**Stack complète :** eza · zoxide · starship · delta · dust · btop · procs · hyperfine · glow

---

## Table des Matières

1. [eza — Remplacement de ls](#1-eza--remplacement-de-ls)
2. [zoxide — Navigation intelligente](#2-zoxide--navigation-intelligente)
3. [starship — Prompt shell](#3-starship--prompt-shell)
4. [delta — Pager git diff](#4-delta--pager-git-diff)
5. [dust — Espace disque](#5-dust--espace-disque)
6. [btop — Moniteur système](#6-btop--moniteur-système)
7. [procs — Liste de processus](#7-procs--liste-de-processus)
8. [hyperfine — Benchmarking](#8-hyperfine--benchmarking)
9. [glow — Rendu Markdown](#9-glow--rendu-markdown)
10. [Intégration Shell](#10-intégration-shell)

---

## 1. eza — Remplacement de `ls`

*Ref : [https://github.com/eza-community/eza](https://github.com/eza-community/eza) · [https://eza.rocks](https://eza.rocks)*

### Installation

```bash
brew install eza
# Ou sur Debian/Ubuntu :
# sudo apt install eza
```

### Configuration

eza ne requiert pas de fichier de configuration. Tout passe par des alias shell.

**Fichier :** `dotfiles/shell/aliases.sh`

### Aliases fournis

| Alias | Commande | Description |
|-------|----------|-------------|
| `ls`  | `eza --icons --classify` | Listing par défaut avec icônes |
| `ll`  | `eza -l --icons --git --header --group-directories-first` | Format long + git status |
| `la`  | `eza -la --icons --git --header --group-directories-first` | Tout afficher (cachés inclus) |
| `l`   | `eza --icons --grid --classify` | Grille compacte |
| `lt`  | `eza --tree --level=2 --icons --git` | Arbre profondeur 2 |
| `lt3` | `eza --tree --level=3 --icons --git` | Arbre profondeur 3 |
| `lm`  | `eza -l --icons --sort=modified --git --header` | Tri par date de modification |
| `lz`  | `eza -l --icons --sort=size --git --header --reverse` | Tri par taille (décroissant) |
| `ld`  | `eza -lda --icons .* --git --header` | Dotfiles uniquement |
| `lr`  | `eza -l --icons --git --header --recurse --level=2` | Récursif niveau 2 |

### Utilisation

```bash
# Lister avec détails + git status
ll

# Arbre du projet
lt

# Trouver les gros fichiers
lz

# Voir les dotfiles
ld
```

### Options utiles hors-alias

```bash
# Filtrer par extension
eza -l --icons *.md

# Trier par extension
eza -l --sort=extension

# Ignorer un pattern
eza -l --ignore-glob="node_modules|.git"

# Format JSON (scripting)
eza -l --json
```

### Prérequis

- **Nerd Font** installée (ex: FiraCode Nerd Font) pour les icônes. Déjà configurée dans Ghostty.

---

## 2. zoxide — Navigation intelligente

*Ref : [https://github.com/ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide)*

### Installation

```bash
brew install zoxide
```

### Configuration

L'initialisation se fait dans `dotfiles/shell/init.sh` :

```bash
eval "$(zoxide init bash)"
# Pour zsh : eval "$(zoxide init zsh)"
```

Cela remplace `cd` par une version augmentée qui **apprend** vos répertoires fréquents.

### Utilisation

```bash
# Naviguer normalement (zoxide apprend en arrière-plan)
cd ~/Prog/__PERSO__/labo-ignition

# Plus tard, sauter directement avec un fragment :
z labo           # → ~/Prog/__PERSO__/labo-ignition
z ignition       # → idem (correspondance partielle)

# Recherche interactive avec fzf
zi

# Lister les chemins appris et leur score
zoxide query --list --score

# Supprimer un chemin de la base
zoxide remove /chemin/obsolete

# Ajouter manuellement un chemin
zoxide add /chemin/important
```

### Fonctionnement interne

zoxide maintient une base SQLite dans `~/.local/share/zoxide/db.zo`. Chaque `cd` incrémente le score du répertoire visité. L'algorithme de recherche combine :
- **Fréquence** : nombre de visites
- **Récence** : date de dernière visite (décroissance exponentielle)

Le terme officiel est **frecency** (frequency + recency).

### Variables d'environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `_ZO_DATA_DIR` | `~/.local/share/zoxide` | Emplacement de la base de données |
| `_ZO_ECHO` | `0` | Afficher le chemin résolu après `z` |
| `_ZO_EXCLUDE_DIRS` | — | Répertoires à ignorer (ex: `/tmp/*`) |
| `_ZO_MAXAGE` | `10000` | Score total maximum avant nettoyage |
| `_ZO_RESOLVE_SYMLINKS` | `0` | Résoudre les symlinks |

---

## 3. starship — Prompt Shell

*Ref : [https://starship.rs](https://starship.rs) · [https://starship.rs/config/](https://starship.rs/config/)*

### Installation

```bash
brew install starship
```

### Configuration

**Fichier :** `dotfiles/starship/starship.toml` → déployé en `~/.config/starship.toml`

L'initialisation shell est dans `dotfiles/shell/init.sh` :

```bash
eval "$(starship init bash)"
```

### Architecture du prompt

Le prompt est composé de **modules** activés automatiquement selon le contexte :

```
 ~/Prog/💻/labo-ignition   master +2 !1 ?3   ⇡2   🐍 3.12   took 4s
 ❯ 
```

| Segment | Module | Condition d'affichage |
|---------|--------|----------------------|
| Répertoire | `directory` | Toujours |
| Branche git | `git_branch` | Dépôt git détecté |
| Statut git | `git_status` | Changements détectés |
| Métriques git | `git_metrics` | Diff non vide |
| Docker | `docker_context` | `docker-compose.yml` ou `Dockerfile` présent |
| Python | `python` | `*.py`, `requirements.txt`, etc. |
| Rust | `rust` | `Cargo.toml` détecté |
| Go | `golang` | `go.mod` détecté |
| Node.js | `nodejs` | `package.json` détecté |
| Durée | `cmd_duration` | Commande > 2 secondes |
| Username | `username` | SSH ou root uniquement |
| Hostname | `hostname` | SSH uniquement |

### Personnalisation

```bash
# Voir la configuration complète (avec défauts)
starship config

# Tester les modules individuellement
starship module git_branch
starship module cmd_duration

# Voir le "timings" de chaque module
starship timings

# Pré-générer le prompt (debug)
starship prompt
```

### Substitutions de répertoires

Configurées dans `starship.toml`, elles raccourcissent visuellement les chemins fréquents :

```toml
[directory.substitutions]
"Documents" = "📄"
"Downloads" = "📥"
"Prog" = "💻"
```

---

## 4. delta — Pager Git Diff

*Ref : [https://github.com/dandavison/delta](https://github.com/dandavison/delta) · [https://dandavison.github.io/delta/](https://dandavison.github.io/delta/)*

### Installation

```bash
brew install git-delta
```

> **Note :** Le paquet Homebrew s'appelle `git-delta`, le binaire s'appelle `delta`.

### Configuration

**Fichier :** `dotfiles/delta/delta.gitconfig` → inclure dans `~/.gitconfig` :

```gitconfig
[include]
    path = ~/.config/delta/delta.gitconfig
```

### Fonctionnalités activées

| Option | Valeur | Effet |
|--------|--------|-------|
| `side-by-side` | `true` | Affichage côte à côte |
| `line-numbers` | `true` | Numéros de ligne |
| `navigate` | `true` | Navigation par hunks avec `n`/`N` |
| `syntax-theme` | `Catppuccin Mocha` | Cohérent avec Ghostty |

### Utilisation

```bash
# Diff git classique (delta s'active automatiquement)
git diff
git log -p
git show HEAD

# Navigation dans les hunks
# n → hunk suivant
# N → hunk précédent

# Diff hors git (alias fourni)
diff fichier_a fichier_b

# Lister les thèmes disponibles
delta --list-syntax-themes

# Prévisualiser un thème
delta --syntax-theme="Dracula" < fichier.patch

# Désactiver temporairement delta
git --no-pager diff
```

### Intégration avec d'autres outils

```bash
# Avec bat
bat --diff fichier_a fichier_b

# Avec ripgrep (diff des résultats)
rg "pattern" -l | xargs delta
```

---

## 5. dust — Espace Disque

*Ref : [https://github.com/bootandy/dust](https://github.com/bootandy/dust)*

### Installation

```bash
brew install dust
```

### Configuration

dust ne requiert pas de fichier de configuration. Tout se passe via alias.

### Aliases fournis

| Alias | Commande | Description |
|-------|----------|-------------|
| `du` | `dust` | Utilisation disque du répertoire courant |
| `du2` | `dust -d 2` | Profondeur limitée à 2 |
| `du3` | `dust -d 3` | Profondeur limitée à 3 |
| `dut` | `dust -n 20` | Top 20 plus gros éléments |
| `dur` | `dust -r` | Ordre inversé (plus petit d'abord) |

### Utilisation

```bash
# Analyse du répertoire courant (affichage en arbre avec barres)
dust

# Analyse d'un chemin spécifique
dust /var/log

# Limiter la profondeur
dust -d 1

# Top 10 plus gros dossiers
dust -n 10

# Ignorer les fichiers cachés
dust -i

# Afficher les tailles apparentes (pas l'espace disque réel)
dust -s

# Analyser uniquement les fichiers (pas les dossiers)
dust -f

# Inverse : uniquement les dossiers
dust -D

# Combiner : top 5 plus gros dossiers à profondeur 1
dust -d 1 -n 5 -D /home
```

### Lecture de la sortie

```
  5.1G ┌── target                │████████████████████████████  │  62%
  1.2G ├── .git                  │███████                       │  15%
800.0M ├── node_modules          │█████                         │  10%
```

Les barres visuelles permettent de repérer immédiatement les répertoires volumineux.

---

## 6. btop — Moniteur Système

*Ref : [https://github.com/aristocratos/btop](https://github.com/aristocratos/btop) · [https://github.com/aristocratos/btop#configurability](https://github.com/aristocratos/btop#configurability)*

### Installation

```bash
brew install btop
```

### Configuration

**Fichier :** `dotfiles/btop/btop.conf` → déployé en `~/.config/btop/btop.conf`

### Options de la configuration fournie

| Option | Valeur | Description |
|--------|--------|-------------|
| `color_theme` | `catppuccin_mocha` | Thème cohérent avec la stack |
| `update_ms` | `1500` | Rafraîchissement 1.5s |
| `proc_tree` | `True` | Processus en arbre par défaut |
| `show_temps` | `True` | Températures CPU/GPU |
| `graph_symbol_cpu` | `braille` | Graphiques en braille (haute résolution) |

### Utilisation

```bash
# Lancer btop (remplace top/htop via alias)
btop
# Ou via l'alias :
top

# Raccourcis clavier dans btop :
# h/l ou ←/→   : Naviguer entre les panneaux
# j/k ou ↑/↓   : Naviguer dans les processus
# f             : Filtrer les processus
# t             : Basculer vue arbre/liste
# s             : Trier (bascule entre CPU, MEM, etc.)
# ENTER         : Détails du processus sélectionné
# k             : Envoyer un signal (SIGTERM, SIGKILL, etc.)
# e             : Changer l'échelle réseau
# m             : Changer le tri mémoire
# q             : Quitter
```

### Thèmes

```bash
# Lister les thèmes disponibles
ls /usr/share/btop/themes/
# Ou via Homebrew :
ls $(brew --prefix)/share/btop/themes/
```

Pour le thème Catppuccin, si absent du système :
```bash
# Installer le thème manuellement
mkdir -p ~/.config/btop/themes
curl -sL https://raw.githubusercontent.com/catppuccin/btop/main/themes/catppuccin_mocha.theme \
  -o ~/.config/btop/themes/catppuccin_mocha.theme
```

---

## 7. procs — Liste de Processus

*Ref : [https://github.com/dalance/procs](https://github.com/dalance/procs) · [https://github.com/dalance/procs#configuration](https://github.com/dalance/procs#configuration)*

### Installation

```bash
brew install procs
```

### Configuration

**Fichier :** `dotfiles/procs/procs.toml` → déployé en `~/.config/procs/config.toml`

### Aliases fournis

| Alias | Commande | Description |
|-------|----------|-------------|
| `ps` | `procs` | Liste de processus par défaut |
| `pst` | `procs --tree` | Vue en arbre |
| `psf` | `procs --or` | Recherche par nom |
| `psc` | `procs --sortd cpu` | Tri par CPU décroissant |
| `psm` | `procs --sortd mem` | Tri par mémoire décroissante |
| `psp` | `procs --tcp` | Processus écoutant sur des ports TCP |

### Utilisation

```bash
# Liste tous les processus
procs

# Chercher un processus
procs firefox
procs --or "node|python"

# Arbre de processus
procs --tree

# Afficher les ports TCP ouverts
procs --tcp

# Trier par mémoire (desc)
procs --sortd mem

# Afficher uniquement certaines colonnes
procs --insert cpu,mem,command

# Compter les processus
procs --no-header | wc -l

# Voir les threads
procs --thread
```

### Colonnes configurées

La configuration `procs.toml` fournie affiche par défaut :
PID · User · State · Nice · CPU · Mem · VmRss · TcpPort · StartTime · Command

---

## 8. hyperfine — Benchmarking

*Ref : [https://github.com/sharkdp/hyperfine](https://github.com/sharkdp/hyperfine)*

### Installation

```bash
brew install hyperfine
```

### Configuration

hyperfine ne requiert pas de fichier de configuration. Tout passe par alias et options CLI.

### Aliases fournis

| Alias | Commande | Description |
|-------|----------|-------------|
| `bench` | `hyperfine --runs 3` | Benchmark rapide |
| `benchp` | `hyperfine --warmup 3 --runs 10` | Benchmark précis |
| `benchcmp` | `hyperfine --warmup 3` | Comparatif (2+ commandes) |
| `benchmd` | `hyperfine --export-markdown /tmp/bench.md --warmup 3` | Export Markdown |

### Utilisation

```bash
# Benchmark simple
hyperfine 'sleep 0.3'

# Benchmark avec warmup (recommandé pour I/O, compilation, etc.)
hyperfine --warmup 5 'fd . /usr'

# Comparer deux commandes
hyperfine 'fd . /usr' 'find /usr'

# Comparer avec labels
hyperfine --command-name 'fd' 'fd . /usr' \
          --command-name 'find' 'find /usr'

# Export JSON pour analyse
hyperfine --export-json /tmp/bench.json 'commande'

# Export Markdown (tableau lisible)
hyperfine --export-markdown /tmp/bench.md 'fd .' 'find .'

# Commande de préparation (vider cache, etc.)
hyperfine --prepare 'sync; echo 3 | sudo tee /proc/sys/vm/drop_caches' \
          'grep -r pattern /usr'

# Paramétrage de la commande (injection de variable)
hyperfine --parameter-scan threads 1 8 'make -j {threads}'

# Ignorer les échecs
hyperfine --ignore-failure 'commande_instable'
```

### Lecture de la sortie

```
Benchmark 1: fd . /usr
  Time (mean ± σ):     123.4 ms ±   5.6 ms    [User: 80.1 ms, System: 43.3 ms]
  Range (min … max):   115.2 ms … 138.7 ms    10 runs

Benchmark 2: find /usr
  Time (mean ± σ):     456.7 ms ±  12.3 ms    [User: 320.1 ms, System: 136.6 ms]
  Range (min … max):   440.2 ms … 478.9 ms    10 runs

Summary
  fd . /usr ran
    3.70 ± 0.19 times faster than find /usr
```

---

## 9. glow — Rendu Markdown

*Ref : [https://github.com/charmbracelet/glow](https://github.com/charmbracelet/glow)*

### Installation

```bash
brew install glow
```

### Configuration

**Fichier :** `dotfiles/glow/glow.yml` → déployé en `~/.config/glow/glow.yml`

### Aliases fournis

| Alias | Commande | Description |
|-------|----------|-------------|
| `md` | `glow` | Rendu Markdown inline |
| `mdp` | `glow -p` | Rendu avec pager |

### Utilisation

```bash
# Rendre un fichier Markdown
glow README.md

# Avec pager intégré (scroll)
glow -p README.md

# Lire depuis stdin (pipe)
cat README.md | glow -

# Forcer un thème
glow -s dark README.md
glow -s light README.md

# Largeur personnalisée
glow -w 80 README.md

# Mode TUI : naviguer dans les fichiers .md du répertoire
glow .

# Ouvrir directement une URL
glow https://raw.githubusercontent.com/user/repo/main/README.md
```

### Mode TUI (stash)

glow intègre un mode TUI complet :

```bash
# Lancer le TUI dans le répertoire courant
glow .

# Raccourcis dans le TUI :
# j/k        : naviguer dans la liste
# ENTER      : ouvrir le fichier
# /          : rechercher
# q          : quitter
# s          : ajouter au stash (favoris locaux)
```

---

## 10. Intégration Shell

### Architecture des fichiers

```
dotfiles/
├── shell/
│   ├── init.sh         # Initialisation (zoxide, starship) — à sourcer en premier
│   └── aliases.sh      # Tous les alias CLI — sourcé par init.sh
├── starship/
│   └── starship.toml   # Config du prompt
├── delta/
│   └── delta.gitconfig # Config git pour delta
├── btop/
│   └── btop.conf       # Config moniteur système
├── procs/
│   └── procs.toml      # Config liste processus
└── glow/
    └── glow.yml        # Config rendu Markdown
```

### Déploiement via chezmoi

Ajouter dans votre `.chezmoiignore` ou `.chezmoi.toml` les mappings :

| Source (repo) | Destination (système) |
|---------------|----------------------|
| `dotfiles/shell/init.sh` | `~/.config/shell/init.sh` |
| `dotfiles/shell/aliases.sh` | `~/.config/shell/aliases.sh` |
| `dotfiles/starship/starship.toml` | `~/.config/starship.toml` |
| `dotfiles/delta/delta.gitconfig` | `~/.config/delta/delta.gitconfig` |
| `dotfiles/btop/btop.conf` | `~/.config/btop/btop.conf` |
| `dotfiles/procs/procs.toml` | `~/.config/procs/config.toml` |
| `dotfiles/glow/glow.yml` | `~/.config/glow/glow.yml` |

### Activation dans `~/.bashrc` ou `~/.zshrc`

Ajouter **à la fin** du fichier RC :

```bash
# Outils CLI modernes (labo-ignition)
source ~/.config/shell/init.sh
```

Cela charge automatiquement :
1. **zoxide** (remplacement de `cd`)
2. **starship** (prompt)
3. **aliases** (eza, dust, btop, procs, hyperfine, glow, bat, delta)

### Vérification post-installation

```bash
# Vérifier que tous les outils sont disponibles
for tool in eza zoxide starship delta dust btop procs hyperfine glow; do
    printf "%-12s: " "$tool"
    command -v "$tool" && echo "✓" || echo "✗ MANQUANT"
done
```
