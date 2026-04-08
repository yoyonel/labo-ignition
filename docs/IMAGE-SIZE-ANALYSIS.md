# Analyse de taille de l'image Docker

Audit des couts disque de l'image `labo-ci` apres optimisation (avril 2026).

## Historique des optimisations

| Version | Taille | Delta | Changements |
|---|---|---|---|
| Pre-optimisation (`debian:trixie`, sans `--no-install-recommends`) | 1.39 GB | -- | Image initiale |
| Post-optimisation (`debian:trixie-slim`, `--no-install-recommends`, multi-stage ripdrag) | 757 MB | **-46%** | Commit `0c9d587` |

## Repartition actuelle (757 MB)

### Vue d'ensemble

| Poste | Taille | Proportion |
|---|---|---|
| Paquets apt (installes) | ~1180 MB (avant compression) | -- |
| Binaires CLI (`/usr/local/bin/`) | 134 MB | 18% |
| Base Debian trixie-slim | ~75 MB | 10% |
| **Image totale (comprimee)** | **757 MB** | 100% |

> Note : La taille "installee" des paquets (1180 MB) est superieure a la taille de l'image (757 MB) car Podman/Docker compresse les couches et deduplique les fichiers identiques entre couches.

### Binaires CLI — `/usr/local/bin/` (134 MB)

| Binaire | Taille | Source |
|---|---|---|
| `uv` | 57 MB | astral.sh installer |
| `yazi` | 22 MB | GitHub release |
| `glow` | 17 MB | GitHub release |
| `starship` | 12 MB | starship.rs installer |
| `delta` | 6.9 MB | GitHub release |
| `procs` | 6.1 MB | GitHub release |
| `lsd` | 3.7 MB | GitHub release |
| `dust` | 3.1 MB | GitHub release |
| `eza` | 2.2 MB | GitHub release |
| `ya` (yazi helper) | 1.6 MB | GitHub release |
| `hyperfine` | 1.4 MB | GitHub release |
| `zoxide` | 1.2 MB | GitHub release |
| `ripdrag` | 976 KB | Multi-stage build (Rust) |
| `uvx` | 346 KB | astral.sh installer |

### Top 30 paquets Debian installes (par taille)

| Paquet | Taille (KB) | Role | Tire par |
|---|---|---|---|
| `libllvm19` | 126 696 | Backend compilateur Mesa | `mesa-vulkan-drivers` |
| `mesa-vulkan-drivers` | 81 100 | Drivers GPU Vulkan | `libvulkan1` |
| `git` | 49 154 | VCS | Installe directement |
| `mesa-libgallium` | 41 615 | Driver GPU generique | `libegl-mesa0`, `libglx-mesa0` |
| `pocketsphinx-en-us` | 36 991 | Reconnaissance vocale (!?) | `libavfilter10` (ffmpeg) |
| `libperl5.40` | 29 315 | Runtime Perl | `git` |
| `libflite1` | 27 558 | Text-to-speech (!?) | `libavfilter10` (ffmpeg) |
| `libz3-4` | 27 142 | Solveur SMT | `libllvm19` |
| `iso-codes` | 23 094 | Traductions i18n | `libgtk-4-1` |
| `libgs10` | 22 216 | Ghostscript | `imagemagick` |
| `perl-modules-5.40` | 19 988 | Modules Perl | `git` |
| `coreutils` | 18 457 | Utilitaires POSIX | Base systeme |
| `intel-media-va-driver` | 17 751 | Decodage video GPU Intel | `va-driver-all` (ffmpeg) |
| `libx265-215` | 16 788 | Codec HEVC | `libavcodec61` (ffmpeg) |
| `libavcodec61` | 16 602 | Codecs FFmpeg | `ffmpegthumbnailer` |
| `libcodec2-1.2` | 16 506 | Codec voix | `libavcodec61` (ffmpeg) |
| `binutils-common` | 16 098 | Outils binaires | Dep systeme |
| `libgtk-4-common` | 15 787 | Donnees GTK4 | `libgtk-4-1` (ripdrag) |
| `locales` | 15 775 | Locales fr/en | Installe directement |
| `fonts-urw-base35` | 15 560 | Polices PostScript | `imagemagick` (ghostscript) |
| `libavfilter10` | 14 136 | Filtres FFmpeg | `ffmpegthumbnailer` |
| `adwaita-icon-theme` | 13 448 | Icones GNOME | `libgtk-4-1` (ripdrag) |
| `libc6` | 13 225 | Libc | Base systeme |
| `poppler-data` | 13 086 | Donnees Poppler (CJK) | `poppler-utils` |
| `libgtk-4-1` | 11 261 | GTK4 runtime | ripdrag |
| `libgtk-4-bin` | 11 036 | Outils GTK4 | `libgtk-4-1` |
| `libmagic-mgc` | 10 154 | Base magique `file` | `file` |
| `systemd` | 9 946 | Init systeme | Dep transitive GTK |
| `libglib2.0-data` | 9 831 | Donnees GLib | `libglib-2.0-0` |
| `libplacebo349` | 9 190 | Shader GPU | `libavfilter10` (ffmpeg) |

## Analyse des chaines de dependances

### Chaine 1 : Mesa/Vulkan/LLVM (~277 MB)

La chaine la plus couteuse de l'image, tiree par **deux sources independantes** :

```
ffmpegthumbnailer
  └─ libavfilter10
       └─ libplacebo349
            └─ libvulkan1 (hard Depends)  ──────────┐
                  └─ mesa-vulkan-drivers (81 MB)     │
                       └─ libllvm19 (127 MB)         │
                            └─ libz3-4 (27 MB)       │
                  └─ mesa-libgallium (42 MB)         │
                                                     │
ripdrag                                              │
  └─ libgtk-4-1                                      │
       └─ libvulkan1 (hard Depends)  ────────────────┘
```

Les deux dependances (`libplacebo349` pour ffmpeg, `libgtk-4-1` pour ripdrag) ont un `Depends` hard sur `libvulkan1`. Retirer l'une ou l'autre ne suffit pas a eliminer la stack Mesa/LLVM.

### Chaine 2 : FFmpeg / ffmpegthumbnailer (~160 MB exclusifs)

```
ffmpegthumbnailer (51 KB)
  └─ libffmpegthumbnailer4v5 (279 KB)
       └─ libavfilter10 (14 MB)
            ├─ libplacebo349 (9 MB) → libvulkan1 → Mesa/LLVM (voir ci-dessus)
            ├─ libpocketsphinx3 → pocketsphinx-en-us (37 MB) [reconnaissance vocale]
            └─ libflite1 (28 MB) [text-to-speech]
       └─ libavcodec61 (16 MB)
            ├─ libx265-215 (17 MB)
            ├─ libcodec2-1.2 (17 MB)
            └─ libaom3 (6 MB)
       └─ libavformat61 (3 MB)
```

Anomalies notables : les filtres FFmpeg tirent pocketsphinx (reconnaissance vocale) et flite (synthese vocale) — des fonctionnalites totalement inutiles pour generer des thumbnails.

### Chaine 3 : GTK4 / ripdrag (~106 MB exclusifs)

Paquets installes **exclusivement** pour ripdrag (48 paquets, 105 MB). Si ripdrag etait retire, ces paquets deviendraient supprimables :

| Paquet | Taille (KB) | Role |
|---|---|---|
| `iso-codes` | 23 094 | Traductions i18n |
| `libgtk-4-common` | 15 787 | Donnees GTK4 |
| `adwaita-icon-theme` | 13 448 | Icones GNOME |
| `libgtk-4-1` | 11 261 | GTK4 runtime |
| `libgtk-4-bin` | 11 036 | Outils GTK4 |
| `xkb-data` | 6 911 | Layouts clavier |
| `libgstreamer1.0-0` | 5 186 | Multimedia |
| `libgstreamer-plugins-base1.0-0` | 3 681 | Multimedia |
| `gstreamer1.0-plugins-base` | 2 606 | Multimedia |
| `procps` | 2 395 | Outils processus |
| 38 autres paquets | ~10 MB | Libs transitives |

Les paquets **partages** avec d'autres outils (et donc non supprimables) incluent : `libcairo2` (chafa, poppler, imagemagick), `libpango-1.0-0` (imagemagick, librsvg), `libgdk-pixbuf-2.0-0` (librsvg).

### Chaine 4 : ImageMagick (~80 MB exclusifs)

```
imagemagick
  └─ imagemagick-7.q16
       └─ libmagickcore-7.q16-10 (7 MB)
       └─ libgs10 (22 MB) [Ghostscript]
            └─ fonts-urw-base35 (16 MB) [polices PostScript]
       └─ netpbm (9 MB) [conversion d'images]
       └─ libgstreamer* [dep transitive]
```

### Chaine 5 : Git + Perl (~100 MB, incompressible)

```
git (49 MB)
  └─ libperl5.40 (29 MB)
  └─ perl-modules-5.40 (20 MB)
  └─ liberror-perl, perl-base...
```

Git est un outil fondamental. Son cout Perl est incompressible sauf a passer a une distribution statique de git.

## Cout par fonctionnalite

Resume du cout en taille image de chaque fonctionnalite :

| Fonctionnalite | Outils | Cout exclusif | Cout partage | Cout total |
|---|---|---|---|---|
| **Drag & drop** | ripdrag | 106 MB | 277 MB (Mesa/LLVM) | ~106 MB net |
| **Preview video** | ffmpegthumbnailer | 160 MB | 277 MB (Mesa/LLVM) | ~160 MB net |
| **Mesa/LLVM** | (transitif) | -- | -- | 277 MB (partage ripdrag + ffmpeg) |
| **Manipulation image** | imagemagick | ~80 MB | -- | ~80 MB |
| **Preview PDF** | poppler-utils | ~14 MB | -- | ~14 MB |
| **Preview image terminal** | chafa | <1 MB | ~20 MB (cairo shared) | ~1 MB net |
| **VCS** | git | ~100 MB (+ perl) | -- | ~100 MB |
| **Outils CLI modernes** | /usr/local/bin/* | 134 MB | -- | 134 MB |

## Scenarios d'optimisation

| Scenario | Taille estimee | Elements retires |
|---|---|---|
| Status quo | **757 MB** | -- |
| - ripdrag | ~650 MB | Drag & drop yazi (`<C-n>`) |
| - ripdrag - imagemagick | ~570 MB | + manipulation image avancee |
| - ripdrag - imagemagick - ffmpegthumbnailer | ~340 MB | + previews video yazi |
| - ffmpegthumbnailer (garder ripdrag) | ~600 MB | Previews video uniquement |

> Note : Retirer ffmpegthumbnailer ET ripdrag libererait aussi la stack Mesa/LLVM (277 MB) car aucune autre dependance ne la necessite.

## Dependances dures non contournables

Ces relations de dependance sont de type `Depends` (pas `Recommends`), donc non bypassables avec `--no-install-recommends` :

- `libgtk-4-1` **Depends** `libvulkan1`
- `libplacebo349` **Depends** `libvulkan1`
- `libvulkan1` **Depends** `mesa-vulkan-drivers`
- `mesa-vulkan-drivers` **Depends** `libllvm19`
- `libllvm19` **Depends** `libz3-4`
- `libavfilter10` **Depends** `libplacebo349`

## Outillage d'analyse

### Recettes Just disponibles

| Commande | Description |
|---|---|
| `just analyze-image` | Rapport complet automatise : dive + layers + top paquets + deps inverses |
| `just dive` | TUI interactif dive — exploration layer par layer |
| `just debtree <pkg>` | Genere un graphe SVG des dependances d'un paquet (ex: `just debtree libgtk-4-1`) |
| `just apt-rdepends <pkg>` | Arbre de dependances recursif en texte |

### Outils utilises

| Outil | Install | Scope | Role |
|---|---|---|---|
| **dive** | `brew install dive` (hote) | Layers image | Score d'efficacite, fichiers dupliques entre layers, wasted space |
| **debtree** | apt (dans container) | Deps Debian | Graphe DOT des dependances d'un paquet → SVG via Graphviz |
| **apt-rdepends** | apt (dans container) | Deps Debian | Arbre de dependances recursif (texte ou format DOT) |
| **aptitude why** | apt (dans container) | Deps Debian | Explique la chaine qui force l'installation d'un paquet |

> `debtree` et `apt-rdepends` ne sont pas installes dans l'image de production (bloat). Les recettes Just les installent a la volee dans un container ephemere.

### Exemples d'utilisation

```bash
# Rapport complet
just analyze-image

# Explorer l'image interactivement
just dive

# Pourquoi libllvm19 est installe ?
just apt-rdepends libllvm19

# Graphe visuel des deps de GTK4
just debtree libgtk-4-1
# Ouvrir le SVG genere
xdg-open libgtk-4-1-deps.svg

# Analyse ponctuelle dans le container
podman run --rm labo-ci bash -c \
  "dpkg-query -Wf '\${Installed-Size}\t\${Package}\n' | sort -rn | head -20"
```

### Methode de collecte des donnees

Les donnees de ce document ont ete collectees avec :

```bash
# Taille des paquets installes
podman run --rm labo-ci bash -c \
  "dpkg-query -Wf '\${Installed-Size}\t\${Package}\n' | sort -rn"

# Dependances inverses (qui tire un paquet)
apt-cache rdepends --installed <package>

# Arbre de dependances recursif
apt-cache depends --recurse --no-suggests --no-conflicts \
  --no-breaks --no-replaces --no-enhances <package>

# Paquets exclusifs a une chaine
comm -23 <(deps_of_feature | sort -u) <(deps_of_kept_tools | sort -u)

# Taille des binaires CLI
ls -lhS /usr/local/bin/
```
