#!/bin/bash
# Aliases CLI Modernes
# Source ce fichier depuis ~/.bashrc ou ~/.zshrc :
#   source ~/.config/shell/aliases.sh

# ============================================================
# eza — Remplacement moderne de ls
# Ref: https://github.com/eza-community/eza
# ============================================================

# Liste par défaut avec icônes et classification
alias ls='eza --icons --classify'

# Liste longue détaillée (permissions, taille, date, git)
alias ll='eza -l --icons --git --header --group-directories-first'

# Tout afficher (fichiers cachés inclus)
alias la='eza -la --icons --git --header --group-directories-first'

# Liste compacte (noms uniquement, en grille)
alias l='eza --icons --grid --classify'

# Arbre avec profondeur 2
alias lt='eza --tree --level=2 --icons --git'

# Arbre profond (niveau 3)
alias lt3='eza --tree --level=3 --icons --git'

# Trier par date de modification (récent en dernier)
alias lm='eza -l --icons --sort=modified --git --header'

# Trier par taille (plus gros en dernier)
alias lz='eza -l --icons --sort=size --git --header --reverse'

# Fichiers cachés uniquement (dotfiles)
alias ld='eza -lda --icons .* --git --header'

# Récursif avec git status
alias lr='eza -l --icons --git --header --recurse --level=2'

# ============================================================
# zoxide — Navigation intelligente
# Ref: https://github.com/ajeetdsouza/zoxide
# ============================================================

# L'initialisation de zoxide remplace `cd` automatiquement.
# Ces alias sont des raccourcis additionnels :

# Recherche interactive de répertoire (fzf)
alias zi='zi'

# ============================================================
# dust — Visualisation espace disque
# Ref: https://github.com/bootandy/dust
# ============================================================

# Utilisation disque du répertoire courant
alias du='dust'

# Utilisation disque avec profondeur limitée
alias du2='dust -d 2'
alias du3='dust -d 3'

# Top N plus gros fichiers/dossiers
alias dut='dust -n 20'

# Utilisation disque inversée (plus petit en premier)
alias dur='dust -r'

# ============================================================
# btop — Moniteur système
# Ref: https://github.com/aristocratos/btop
# ============================================================

# Remplacement de htop/top
alias top='btop'
alias htop='btop'

# ============================================================
# procs — Liste de processus
# Ref: https://github.com/dalance/procs
# ============================================================

# Remplacement de ps
alias ps='procs'

# Processus en arbre
alias pst='procs --tree'

# Chercher un processus par nom
alias psf='procs --or'

# Processus triés par CPU
alias psc='procs --sortd cpu'

# Processus triés par mémoire
alias psm='procs --sortd mem'

# Processus écoutant sur des ports TCP
alias psp='procs --tcp'

# ============================================================
# hyperfine — Benchmarking
# Ref: https://github.com/sharkdp/hyperfine
# ============================================================

# Benchmark rapide (3 runs, pas de warmup)
alias bench='hyperfine --runs 3'

# Benchmark précis (10 runs + 3 warmup)
alias benchp='hyperfine --warmup 3 --runs 10'

# Benchmark comparatif (2 commandes côte à côte)
alias benchcmp='hyperfine --warmup 3'

# Benchmark avec export markdown
alias benchmd='hyperfine --export-markdown /tmp/bench.md --warmup 3'

# ============================================================
# glow — Rendu Markdown
# Ref: https://github.com/charmbracelet/glow
# ============================================================

# Rendu inline (sans pager)
alias md='glow'

# Rendu avec pager
alias mdp='glow -p'

# ============================================================
# delta — Pager diff (configuré via gitconfig)
# Ref: https://github.com/dandavison/delta
# ============================================================

# Diff rapide entre fichiers (hors git)
alias diff='delta'

# ============================================================
# bat — Déjà installé, alias complémentaires
# Ref: https://github.com/sharkdp/bat
# ============================================================

alias cat='bat --paging=never'
alias catp='bat'
