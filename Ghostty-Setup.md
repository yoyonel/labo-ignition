# Ghostty — Installation, Configuration et Intégration

> **Objectif** : Installer et configurer [Ghostty](https://ghostty.org/), un terminal émulateur
> moderne hautement optimisé pour les images haute résolution.
>
> **Pourquoi** : Ghostty supporte le protocole d'image Kitty, permettant à des outils comme
> [Yazi](https://yazi-rs.github.io/) d'afficher des aperçus d'images au lieu de texte ANSI
> pixelisé. L'environnement `labo-ignition` le propage via les variables `$GHOSTTY_*` pour
> un rendu optimal dans le container.

---

## 1. Architecture de la solution

### 1.1 — Niveau d'abstraction

La solution Ghostty dans ce repo fonctionne sur **trois niveaux** indépendants :

```
┌─────────────────────────────────────────────┐
│   Recettes Just (orchestration)             │
│   • just install-ghostty                    │
│   • just configure-ghostty                  │
│   • just setup-ghostty (install + config)   │
│   • just audit-ghostty (validation)         │
└─────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────┐
│   Scripts shell (logique)                   │
│   • scripts/install-ghostty.sh              │
│   • scripts/configure-ghostty.sh            │
│   • scripts/detect-ghostty.sh               │
└─────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────┐
│   Installation système                      │
│   • AppImage (Debian, tous supports)        │
│   • Package manager (dnf pour Fedora)       │
│   • Fallback gracieux (pas de crash)        │
└─────────────────────────────────────────────┘
```

### 1.2 — Chemins et emplacements

| Type | Chemin | Notes |
|---|---|---|
| **Binaire** | `~/.local/bin/ghostty` | Standard XDG, dans `$PATH` |
| **Config** | `~/.config/ghostty/config` | [Ghostty config reference](https://ghostty.org/docs/config/reference) |
| **Cache** | `~/.cache/ghostty/` | Géré par Ghostty, pas d'intervention |
| **AppImage** | `~/.local/bin/ghostty-*.AppImage` | Source si AppImage utilisée |

### 1.3 — Détection du terminal hôte

Les scripts détectent le terminal hôte (et donc l'OS) via :

```bash
# Détection Ghostty déjà présent
which ghostty

# Détection des package managers
command -v dnf    # Fedora/RHEL
command -v apt    # Debian/Ubuntu
```

---

## 2. Installation

### 2.1 — Procédure automatique (recommandée)

```bash
# Depuis la racine du repo
just setup-ghostty

# OU en deux étapes
just install-ghostty      # Télécharge et installe le binaire
just configure-ghostty    # Crée la config recommandée
```

### 2.2 — Installation manuelle

> ⚠️ **Note technique** : Ghostty est écrit en [**Zig**](https://ziglang.org/), pas en Rust.
> La compilation from source requiert Zig + GTK4 + blueprint-compiler et prend 15-30 min.
> L'**AppImage** est de loin la méthode la plus rapide pour Linux générique.

#### Sur **Fedora/Bazzite** (dnf) :

```bash
# Installation officielle via Copr
sudo dnf copr enable -y ouroboros/ghostty
sudo dnf install -y ghostty

# Vérification
ghostty --version
```

💡 **Avantage** : Updates automatiques via DNF.  
❌ **Inconvénient** : Nécessite sudo, Copr externe.

#### Sur **Debian/Ubuntu** (AppImage) :

Les AppImages sont fournies par le projet communautaire
[pkgforge-dev/ghostty-appimage](https://github.com/pkgforge-dev/ghostty-appimage/releases).
Elles sont construites automatiquement en nightly depuis le tag `tip` officiel.

```bash
# Récupérer l'URL de la dernière release via l'API GitHub
APPIMAGE_URL=$(curl -fsSL https://api.github.com/repos/pkgforge-dev/ghostty-appimage/releases/latest \
  | python3 -c "
import json, sys
assets = json.load(sys.stdin)['assets']
for a in assets:
    if 'x86_64' in a['name'] and a['name'].endswith('.AppImage') and '.zsync' not in a['name']:
        print(a['browser_download_url']); break
")

# Télécharger et rendre exécutable
mkdir -p ~/.local/bin
curl -fL --progress-bar -o ~/.local/bin/ghostty "$APPIMAGE_URL"
chmod +x ~/.local/bin/ghostty

# Vérifier $PATH
echo $PATH | grep -q "$HOME/.local/bin" || echo "⚠️ ~/.local/bin n'est pas dans \$PATH"

# Vérification
ghostty --version
```

💡 **Avantage** : Aucune compilation, aucune dépendance système, ~46 MB.  
⚠️ **Note** : Nightly build (tip), pas une release stable.

#### Sur **macOS** :

```bash
brew install ghostty
```

### 2.3 — Vérification de l'installation

```bash
# Binaire présent et accessible
ghostty --version
# Ghostty 1.0.0 (ou version actuelle)

# Configuration accessible (vérifiée plus tard)
which ghostty
# /home/username/.local/bin/ghostty (ou /usr/bin/ghostty)
```

---

## 3. Configuration

### 3.1 — Approche basée sur `dotfiles/`

La configuration par défaut se trouve dans le répertoire de dotfiles :

```
dotfiles/
├── ghostty/
│   └── config          # Configuration Ghostty par défaut (maintenue dans le repo)
└── yazi/
    └── yazi.toml       # Configuration Yazi
```

**Avantage** : Configuration versionnée, facilement modifiable, reproduisible.

### 3.2 — Installer la config

Le script `configure-ghostty.sh` :
1. Copie `dotfiles/ghostty/config` → `~/.config/ghostty/config`
2. Sauvegarde l'ancienne config (backup avec timestamp)
3. Valide la sintaxe
4. Vérifie les fonts

**Installation automatique** :

```bash
just configure-ghostty
```

**Installation manuelle** :

```bash
mkdir -p ~/.config/ghostty
cp dotfiles/ghostty/config ~/.config/ghostty/config
ghostty +validate-config
```

### 3.3 — Configuration - Référence

La configuration dans `dotfiles/ghostty/config` suit la documentation officielle
[Ghostty Config Reference](https://ghostty.org/docs/config/reference).

Sections principales :

| Section | Description | Variables |
|---------|-------------|-----------|
| **Police** | FiraCode Nerd Font | `font-family`, `font-size` |
| **Thème** | Catppuccin Mocha | `theme` |
| **Transparence** | Arrière-plan semi-transparent | `background-opacity`, `background-blur` |
| **Fenêtre** | Padding, décoration | `window-padding-x`, `window-padding-y` |
| **Terminal Features** | Kitty Graphics Protocol actif via `TERM = xterm-ghostty` | `term` |
| **Keybindings** | Copier/Coller custom | `keybind` |
| **Tmux** | Integration | `allow-passthrough = always` |

**Pour personnaliser** : Éditez `dotfiles/ghostty/config` directement (fichier texte simple), puis exécutez `just configure-ghostty`.

### 3.4 — Fonts Nerd (optionnel mais recommandé)

Ghostty utilisera une police monospace par défaut, mais pour une meilleure expérience avec les glyphes (powerline, icons, emojis), installez les fonts Nerd :

**Debian/Ubuntu** :
```bash
# Option 1 : Via apt (Noto Emoji seulement)
sudo apt install fonts-noto-color-emoji

# Option 2 : FiraCode manual (recommandé)
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -sL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.0/FiraCode.zip -o FiraCode.zip
unzip FiraCode.zip && rm FiraCode.zip
fc-cache -fv
```

**Fedora/RHEL** :
```bash
sudo dnf install fira-code google-noto-emoji-fonts
```

**macOS** :
```bash
brew install font-fira-code-nerd-font noto-nerd-font
```

### 3.5 — Validation de la config

```bash
# Audit syntaxe (Ghostty built-in compiler)
ghostty +validate-config
# ✓ Config OK

# Afficher la config chargée (fusion fichier + defaults)
ghostty +show-config

# Via Just (automatisé, valide tout)
just audit-ghostty
```

---

## 4. Intégration avec `labo-ignition`

### 4.1 — Variables propagées au container

Le Justfile propage automatiquement les variables Ghostty vers le container (`just lab`) :

```bash
-e GHOSTTY_BIN_DIR         # Chemin vers le binaire (détecté automatiquement)
-e GHOSTTY_RESOURCES_DIR   # Répertoire de ressources Ghostty
-e TERM                    # Type de terminal ($TERM original)
-e COLORTERM               # Support des couleurs 24-bit
```

### 4.2 — Détection du binaire et ressources

Le script `scripts/detect-ghostty.sh` détecte automatiquement :

```bash
# Binaire
GHOSTTY_BIN=$(which ghostty 2>/dev/null)

# Répertoire de ressources (AppImage ou système)
if [[ -n "$APPIMAGE" ]]; then
    # Si lancé depuis AppImage
    GHOSTTY_RESOURCES_DIR="$APPIMAGE_EXTRACTION_DIR/share/ghostty"
else
    # Standard system
    GHOSTTY_RESOURCES_DIR="/usr/share/ghostty"
fi
```

### 4.3 — Test d'intégration

Tester que Yazi affiche les images dans le container :

```bash
# À l'intérieur du container (après `just lab`)
yazi /path/to/images/

# Devrait afficher les aperçus d'image haute résolution
# au lieu de texte ANSI pixelisé
```

---

## 5. Troubleshooting

### 5.1 — "ghostty: command not found"

**Cause** : AppImage/binaire n'est pas dans `$PATH`.

**Solution** :

```bash
# Vérifier ~/.local/bin est dans $PATH
echo $PATH | grep "$HOME/.local/bin"

# Sinon, ajouter à ~/.bashrc ou ~/.zshrc
export PATH="$HOME/.local/bin:$PATH"

# Recharger le shell
source ~/.bashrc  # ou source ~/.zshrc
```

### 5.2 — "Failed to load config: Invalid syntax"

**Cause** : Erreur TOML dans `~/.config/ghostty/config`.

**Solution** :

```bash
# Audit Ghostty (affiche l'erreur)
ghostty +validate-config

# Ou parse la config avec toml-check
cat ~/.config/ghostty/config | toml-check 2>&1
```

### 5.3 — Fonts Nerd non disponibles

**Symptôme** : Caractères "□" ou "?" à la place des glyphes.

**Solution** :

```bash
# Vérifier les fonts installées
fc-list | grep -i "fira code"

# Installer FiraCode Nerd
# Debian (manual): voir 3.4 — Option 2 manual download
# Fedora: sudo dnf install fira-code
# macOS: brew install font-fira-code-nerd-font

# Reconstruire le cache
fc-cache -fv

# Puis relancer Ghostty
```

### 5.4 — Yazi n'affiche pas les images

**Cause** : Kitty graphics protocol pas activée ou Yazi non détecté.

**Solution** :

```bash
# Vérifier le TERM exporté (activation = automatique via Ghostty)
echo "$TERM"
# Doit être: xterm-ghostty-256color

# Vérifier la config (ne pas chercher enable-kitty-graphics — n'existe pas en 1.3+)
grep "^term" ~/.config/ghostty/config
# Doit être: term = xterm-ghostty-256color

# Vérifier que Yazi les détecte
yazi --version && echo "Yazi OK"

# Tester manuellement dans le container
just lab
# Inside:
yazi /tmp/test-images/
```

⚠️ **Note** : `enable-kitty-graphics = true` est **invalide** en Ghostty 1.3+. Le protocole Kitty graphics est activé automatiquement via la variable `TERM` quand elle est définie à `xterm-ghostty-*`.

---

## 6. References & Documentation

### 6.1 — Officiel Ghostty

| Ressource | URL |
|---|---|
| **Homepage** | https://ghostty.org/ |
| **Config Reference** | https://ghostty.org/docs/config/reference |
| **Source Repository** | https://github.com/ghostty-org/ghostty |
| **AppImage (community)** | https://github.com/pkgforge-dev/ghostty-appimage/releases |

### 6.2 — Related Tools

| Tool | Purpose | Reference |
|---|---|---|
| **Yazi** | File manager avec images | https://yazi-rs.github.io/docs/quick-start/ |
| **Tmux** | Terminal multiplexer (intégration) | https://man.openbsd.org/OpenBSD-current/man1/tmux.1 |
| **FiraCode** | Monospace font (recommended) | https://github.com/tonsky/FiraCode |
| **Nerd Fonts** | Icon glyphs | https://www.nerdfonts.com/ |
| **Kitty Protocol** | Terminal graphics protocol | https://sw.kovidgoyal.net/kitty/graphics-protocol/ |

### 6.3 — Linux Package Managers

| OS | Installation Method | Ref |
|---|---|---|
| Fedora/RHEL | `dnf install ghostty` via Copr | https://copr.fedorainfracloud.org/coprs/ouroboros/ghostty/ |
| Debian/Ubuntu | AppImage (~46 MB, nightly) | [pkgforge-dev/ghostty-appimage](https://github.com/pkgforge-dev/ghostty-appimage/releases) |
| macOS | Homebrew | `brew install ghostty` |

---

## 7. Recettes Just disponibles

```bash
# Installation du binaire
just install-ghostty

# Configuration du fichier ~/.config/ghostty/config
just configure-ghostty

# Installation + Configuration (one-shot)
just setup-ghostty

# Validation (audit syntaxe + config)
just audit-ghostty

# Test complet dans le container
just lab                   # Lance Ghostty + container
# Inside: yazi /tmp/
```

---

## 8. Checklist de validation

- [ ] `which ghostty` retourne un chemin
- [ ] `ghostty --version` affiche la version
- [ ] `ghostty +validate-config` passe sans erreur
- [ ] `~/.config/ghostty/config` existe et contient les settings
- [ ] Fonts Nerd (FiraCode) installées : `fc-list | grep -i "fira code"`
- [ ] `just lab` démarre le container correctement
- [ ] `yazi` dans le container affiche les images (pas de texte pixelisé)
- [ ] `just audit-ghostty` passe sans erreur

---

## 9. Architecture des scripts

```
scripts/
├── install-ghostty.sh        ← Télécharge AppImage ou utilise dnf
├── configure-ghostty.sh      ← Crée ~/.config/ghostty/config
└── detect-ghostty.sh         ← Détecte bin + resources (sourced par Justfile)
```

Chaque script :
- Est **idempotent** (peut être rejouée sans casser)
- Affiche du **diagnostic détaillé** (colores)
- Remonte les **erreurs** avec contexte
- Documente son **usage et exits codes**

