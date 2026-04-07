# Documentation Architecturale : Environnement Terminal Moderne & Navigation CLI

Cette documentation détaille non seulement la mise en place d'un environnement de terminal moderne, mais surtout **la logique et la construction** de ses configurations. L'objectif est de comprendre *comment* ces outils interagissent (Ghostty, Tmux, Yazi) pour maîtriser la stack, pouvoir la déboguer et l'adapter à n'importe quel OS (Bazzite, Debian).

---

## 1. Terminal Émulateur : Ghostty

Ghostty utilise une syntaxe de type "clé = valeur" très stricte. La documentation de référence globale pour toutes les clés de configuration se trouve ici : [Ghostty Docs > Config Reference](https://ghostty.org/docs/config/reference).

### Fichier : `~/.config/ghostty/config`

Créer le dossier `mkdir -p ~/.config/ghostty` et insérer :

```toml
# --- Police d'écriture ---
# Réf: [https://ghostty.org/docs/config/reference](https://ghostty.org/docs/config/reference)
font-family = "FiraCode Nerd Font Mono"
font-size = 10

# --- Thème et Couleurs ---
# Réf: [https://ghostty.org/docs/config/reference](https://ghostty.org/docs/config/reference)
# Ghostty embarque ses propres thèmes. La casse est stricte.
# Pour voir la liste des thèmes disponibles sur votre machine : `ghostty +list-themes`
theme = "Catppuccin Mocha"

# --- Transparence et Flou ---
# Réf: [https://ghostty.org/docs/config/reference](https://ghostty.org/docs/config/reference)
# L'opacité va de 0.0 (invisible) à 1.0 (opaque).
background-opacity = 0.9
# Le flou (blur) demande à l'OS d'appliquer un filtre derrière la fenêtre.
# Attention : sous Linux/X11 (Debian), cela exige un compositeur externe (ex: Picom). 
# Sous Wayland (Bazzite), c'est natif.
background-blur = true

# --- Interface et Esthétique ---
window-padding-x = 12
window-padding-y = 12
window-decoration = auto

# --- Comportement ---
# Modifie le curseur pour un bloc solide et clignotant.
cursor-style = block
cursor-style-blink = true
```

**Comprendre et Déboguer Ghostty :**
Ghostty refuse de démarrer si une seule clé est invalide.
1.  **L'outil d'audit intégré :** Utilisez `ghostty --check-config`. C'est le compilateur de Ghostty qui analyse votre fichier sans lancer l'interface graphique.
2.  **Voir la configuration complète chargée :** `ghostty +show-config` vous montrera la fusion de votre fichier avec les paramètres par défaut de l'outil.

---

## 2. Multiplexeur : Tmux

Tmux est un multiplexeur qui agit comme un "terminal virtuel" à l'intérieur de votre terminal physique (Ghostty). Son comportement par défaut est de bloquer et de supprimer toutes les séquences d'échappement non standard (comme celles dessinant des images) pour éviter que des caractères mal formés ne corrompent l'affichage des autres panneaux.

* **Documentation canonique (Le Manuel) :** [Manuel complet Tmux (`man tmux`)](https://man.openbsd.org/OpenBSD-current/man1/tmux.1)

### Fichier : `~/.tmux.conf`

Pour que Tmux laisse transiter les données d'images entre Chafa/Yazi et Ghostty, il faut modifier deux options serveur :

```tmux
# 1. Le Passthrough (Passage direct)
# Réf : [https://man.openbsd.org/OpenBSD-current/man1/tmux.1#allow-passthrough](https://man.openbsd.org/OpenBSD-current/man1/tmux.1#allow-passthrough)
# Depuis la version 3.3, Tmux exige une autorisation explicite pour laisser les 
# applications envoyer des séquences d'échappement brutes (DCS) au terminal parent.
set -g allow-passthrough on

# 2. Déclaration des capacités (Features)
# Réf : [https://man.openbsd.org/OpenBSD-current/man1/tmux.1#terminal-features](https://man.openbsd.org/OpenBSD-current/man1/tmux.1#terminal-features)
# Cette option remplace l'ancienne méthode 'terminal-overrides'. Elle indique à Tmux 
# ce que le terminal extérieur (Ghostty) est physiquement capable de faire.
set -as terminal-features 'xterm*:sixel'
```

### Anatomie de la commande `set -as terminal-features 'xterm*:sixel'` :
Comprendre la syntaxe est essentiel pour déboguer si le terminal parent change.
* **`set`** : L'alias de la commande `set-option`.
* **`-a` (Append)** : Demande à Tmux d'*ajouter* cette capacité à la liste existante, plutôt que d'écraser toutes les capacités par défaut.
* **`-s` (Server)** : Applique ce réglage globalement au niveau du serveur Tmux.
* **`xterm*`** : C'est un masque (wildcard). Le terminal extérieur s'identifie auprès de l'OS via la variable `$TERM`. Il se déclare souvent comme `xterm-256color` ou `xterm-ghostty`. Ce masque cible donc tout terminal dont le nom commence par `xterm`.
* **`:sixel`** : La capacité déclarée. Elle annonce que le terminal sait encoder/décoder les graphiques.

### Débogage & Vérification
1. **Appliquer sans quitter Tmux :** `tmux source-file ~/.tmux.conf`
2. **Test d'isolation :** Vérifiez la variable `$TERM` en dehors de Tmux (`echo $TERM`). Si elle ne commence pas par `xterm`, la règle `xterm*:sixel` sera ignorée par Tmux.

---

## 3. Outils CLI de Rendu & Recherche

L'installation de ces outils dépend de votre système, mais ils fournissent les "moteurs" que Yazi utilisera.

* **Recherche :** [bat](https://github.com/sharkdp/bat) (coloration), [fzf](https://github.com/junegunn/fzf) (floue), [fd](https://github.com/sharkdp/fd) (fichiers), [ripgrep](https://github.com/BurntSushi/ripgrep) (contenu).
* **Médias :** [Chafa](https://hpjansson.org/chafa/) (moteur de rendu), [ImageMagick](https://imagemagick.org/) (convertisseur HDR).
* **Drag & Drop :** [ripdrag](https://github.com/nik012003/ripdrag) (Interface Wayland/X11 GTK4).

### Installation Multi-OS

**Étape 1 : Outils CLI de base (Brew / Apt)**
```bash
brew install bat fzf fd ripgrep chafa imagemagick ffmpegthumbnailer
```

**Étape 2 : ripdrag (Compilation native via Cargo)**
ripdrag est une application GTK4. Elle doit être compilée nativement avec Cargo pour se lier correctement au compositeur système (Wayland ou X11).
*Réf : [Instructions officielles d'installation ripdrag](https://github.com/nik012003/ripdrag?tab=readme-ov-file#installation)*

* **Sur Debian 13 ou Distrobox Ubuntu/Debian :**
  ```bash
  sudo apt install libgtk-4-dev build-essential curl
  ```
* **Sur Distrobox Fedora / CentOS (Bazzite) :**
  ```bash
  sudo dnf install cargo gtk4-devel
  ```
* **Compilation :**
  ```bash
  cargo install ripdrag
  export PATH="$PATH:$HOME/.cargo/bin"
  ```

---

## 4. Configuration du Shell & Rendu HDR (Zsh / Bash)

Afficher une texture 32-bit (Radiance HDR) directement dans un terminal est impossible nativement et fait planter les buffers Tmux. Il faut orchestrer la conversion.
* **Réf ImageMagick CLI :** [ImageMagick Command-line Processing](https://imagemagick.org/script/command-line-processing.php)
* **Réf Chafa :** [Chafa Reference Manual](https://hpjansson.org/chafa/ref/)

### Fichier : `~/.zshrc` ou `~/.bashrc`

```bash
# Variable d'environnement lue par Yazi. 
# Réf: [https://yazi-rs.github.io/docs/configuration/overview](https://yazi-rs.github.io/docs/configuration/overview)
# Indique à Yazi d'envelopper ses séquences d'images spécifiquement pour Tmux.
export YAZI_TMUX=1

# Fonction de prévisualisation sécurisée pour textures complexes (HDR, EXR, etc.)
# 1. `magick ... png:-` -> Redimensionne à 800x800 pour préserver la RAM, puis convertit en binaire PNG sur la sortie standard.
# 2. `| chafa --format=kitty -` -> Lit l'entrée binaire standard et force le protocole natif de Ghostty.
vhdr() {
    magick "$1" -geometry 800x800 png:- | chafa --format=kitty -
}
```

---

## 5. Gestionnaire de Fichiers : Yazi

Yazi est configuré via des fichiers TOML. L'architecture est documentée ici : [Yazi Configuration Overview](https://yazi-rs.github.io/docs/configuration/overview).

### A. Méthode de Rendu d'Image (`~/.config/yazi/yazi.toml`)
*Réf : [Yazi Docs > Configuration](https://yazi-rs.github.io/docs/configuration/yazi)*

Dans un environnement complexe (Distrobox + Tmux + Ghostty), la détection automatique du terminal échoue souvent. Il faut forcer le protocole.

```toml
[manager]
# Force l'utilisation du protocole Kitty (le plus performant sous Ghostty)
image_preview_method = "kitty"
```

### B. Mappages Clavier & Redirection (`~/.config/yazi/keymap.toml`)
*Réf : [Yazi Docs > Keymap Configuration](https://yazi-rs.github.io/docs/configuration/keymap/)*

L'instruction `prepend_keymap` indique à Yazi d'insérer ces raccourcis **avant** ceux par défaut, écrasant ainsi les comportements natifs.

```toml
[manager]
prepend_keymap = [
    # 1. Libérer 'f' en déplaçant le filtre sur 'F' majuscule
    { on = [ "F" ], run = "filter --smart", desc = "Filter" },

    # 2. Appel de Plugins externes (Scripts Lua)
    { on = [ "f", "g" ], run = "plugin fg", desc = "Find Grep (Interactif)" },
    { on = [ "f", "f" ], run = "plugin fg --args='fzf'", desc = "Find File (Interactif)" },
    
    # 3. Moteurs de recherche natifs (Modes forcés)
    # Réf : [https://yazi-rs.github.io/docs/quick-start/](https://yazi-rs.github.io/docs/quick-start/)
    # Le paramètre `--args='-F'` force l'outil (fd ou rg) à traiter la saisie 
    # comme du texte littéral (Fixed strings) et non comme une Regex.
    { on = [ "s" ], run = "search --via=fd --args='-F'", desc = "Recherche fichiers (littérale)" },
    { on = [ "S" ], run = "search --via=rg --args='-F'", desc = "Recherche contenu (littérale)" },

    # 4. Exécution Shell asynchrone (Drag & Drop)
    # Lance ripdrag en tâche de fond (`&`). `$@` transmet le fichier sélectionné.
    { on = [ "<C-n>" ], run = "shell 'ripdrag \"$@\" -x 2>/dev/null &' --confirm", desc = "Glisser-déposer" }
]
```

### C. Comprendre l'API Lua (Correction du Plugin `bat.yazi`)
*Réf : [Yazi Docs > Lua API (Utils)](https://yazi-rs.github.io/docs/plugins/utils/)*

Les plugins Yazi invoquent les sous-processus système via l'objet `Command`. Une erreur commune est l'utilisation de `:arg()`, qui ne prend qu'une seule chaîne de caractères. Pour passer plusieurs arguments (comme `--style` et `--color`), il faut **impérativement** utiliser la méthode au pluriel `:args()` en lui passant une table Lua (les `{}`).

Fichier : `~/.config/yazi/plugins/bat.yazi/main.lua` :
```lua
local child = Command("bat")
    :args({
        "--style=plain",
        "--color=always",
        tostring(job.file.url),
    })
    :stdout(Command.PIPED)
    :stderr(Command.PIPED)
    :spawn()
```

### D. Audit et Logs Yazi
Si une prévisualisation échoue ou qu'un plugin est silencieux :
1.  **Démarrer Yazi en mode diagnostic :** `YAZI_LOG=debug yazi`
2.  **Surveiller les erreurs dans un terminal parallèle :**
    ```bash
    tail -f ~/.local/state/yazi/yazi.log
    ```
    *Ce log remontera toute erreur d'invocation CLI (ex: `bat` introuvable dans le PATH) ou d'anomalie de syntaxe Lua.*