# Audit de Portabilité — labo-ignition

**Date** : 2026-04-07
**Scope** : Tous les scripts, Dockerfile, Justfile, dotfiles, tests
**Résultat** : 35 findings (9 CRITICAL, 15 MEDIUM, 11 LOW)

---

## Table des Matières

1. [CRITICAL — Bloquants portabilité](#critical--bloquants-portabilité)
2. [MEDIUM — Limitations significatives](#medium--limitations-significatives)
3. [LOW — Améliorations mineures](#low--améliorations-mineures)
4. [Plans de correction](#plans-de-correction)

---

## CRITICAL — Bloquants portabilité

### C1-C4. Dockerfile : architecture x86_64 hardcodée

**Fichiers** : `Dockerfile` (lignes 22-59)
**Impact** : Cassé sur ARM (Apple Silicon, AWS Graviton, Raspberry Pi)

Tous les downloads de binaires (jump, procs, lsd, eza, zoxide, delta, dust, hyperfine, glow, yazi) utilisent soit `grep "x86_64"` soit une URL directe `amd64`. Aucun fallback ARM/aarch64.

Exemples :
```dockerfile
# Hardcodé amd64
curl -L ".../jump_${JUMP_VERSION}_amd64.deb"

# Grep x86_64 sans alternative
grep "browser_download_url" | grep "x86_64"

# URL directe
curl -L ".../yazi-x86_64-unknown-linux-gnu.zip"
```

**Plan de correction** :
1. Détecter l'architecture en début de Dockerfile :
   ```dockerfile
   ARG TARGETARCH
   # Mapping: amd64 → x86_64, arm64 → aarch64
   ```
2. Utiliser `${TARGETARCH}` dans tous les downloads
3. Pour chaque outil, vérifier que des binaires ARM existent sur les releases GitHub
4. Tester avec `podman build --platform linux/arm64`

---

### C5. Dockerfile : `grep|cut` sur du JSON au lieu de `jq`

**Fichier** : `Dockerfile` (lignes 18-45)
**Impact** : Silencieusement cassé si GitHub change le formatage JSON

`jq` est installé à la ligne 14 mais jamais utilisé. Les 10+ appels GitHub API parsent le JSON avec :
```bash
grep tag_name | cut -d'"' -f4    # fragile
grep "browser_download_url" | grep "x86_64" | head -n 1 | cut -d'"' -f4
```

Ces patterns cassent si :
- GitHub ajoute des espaces/indentation différente
- `tag_name` apparaît dans le champ `body` (release notes)
- Plusieurs assets matchent le grep

**Plan de correction** :
```bash
# Avant (fragile)
curl -s .../releases/latest | grep tag_name | cut -d'"' -f4

# Après (robuste)
curl -s .../releases/latest | jq -r '.tag_name'
curl -s .../releases/latest | jq -r '.assets[] | select(.name | test("x86_64.*linux.*musl.*tar.gz")) | .browser_download_url'
```

Appliquer la même transformation pour chaque outil (eza, zoxide, delta, dust, hyperfine, glow, procs, lsd, jump, yazi).

---

### C6. Dockerfile : rate limit GitHub API

**Fichier** : `Dockerfile` (lignes 18-45)
**Impact** : Builds échouent silencieusement après 60 appels/heure (limite anonyme)

~10 appels `api.github.com` non authentifiés dans un seul build. Des `podman build` répétés → 403, les `jq`/`grep` retournent vide, les `curl -L ""` téléchargent la page d'erreur HTML.

**Plan de correction** :
1. **Court terme** : Grouper les appels API dans un seul `RUN` pour bénéficier du cache de couche Docker. Si le cache est chaud, 0 appels API.
2. **Moyen terme** : Supporter un `GITHUB_TOKEN` optionnel en build-arg :
   ```dockerfile
   ARG GITHUB_TOKEN=""
   # Si token fourni, l'ajouter au header
   ```
3. **Long terme** : Épingler les versions dans un fichier `versions.env` (pas d'appels API du tout, versions mises à jour via Dependabot ou script dédié).

---

### C7. Justfile `lab` : monte `$HOME` entier dans le container

**Fichier** : `Justfile` (ligne 116)
**Impact** : Sécurité — expose SSH keys, GPG, credentials. Casse l'isolation.

```just
-v $HOME:$HOME
```

**Plan de correction** :
1. Monter uniquement le répertoire du projet :
   ```just
   -v $(pwd):$(pwd)
   ```
2. Si des dotfiles sont nécessaires, monter explicitement :
   ```just
   -v $HOME/.gitconfig:/home/${USER}/.gitconfig:ro
   ```
3. Documenter quels fichiers hôte sont exposés et pourquoi.

---

### C8. Justfile `lab` : `--device /dev/dri` Linux-only

**Fichier** : `Justfile` (ligne 122)
**Impact** : Crash sur macOS, CI headless sans GPU

```just
--device /dev/dri
```

**Plan de correction** :
```bash
DRI_ARGS=()
if [[ -e /dev/dri ]]; then
    DRI_ARGS+=(--device /dev/dri)
fi
```

---

### C9. `install-ghostty.sh` : `python3` requis mais pas garanti

**Fichier** : `scripts/install-ghostty.sh` (lignes 86-93)
**Impact** : Cassé sur systèmes minimaux (Alpine, conteneurs slim)

`fetch_appimage_url()` utilise `python3 -c "import json..."` pour parser du JSON.

**Plan de correction** :
1. Remplacer par `jq` (déjà installé dans le Dockerfile) :
   ```bash
   curl -s ... | jq -r '.assets[] | select(.name | endswith(".AppImage")) | .browser_download_url'
   ```
2. Ou ajouter un guard : `command -v python3 || command -v jq || die "Installer python3 ou jq"`

---

## MEDIUM — Limitations significatives

### M10. Justfile `test-cli-tools` : chemin container dépend du username hôte

**Fichier** : `Justfile` (lignes 87-90)

Monte vers `/home/{{user_name}}/project` — si le `whoami` hôte ≠ `USER_NAME` du build-arg, le path n'existe pas.

**Plan** : Monter vers un chemin fixe `/project` indépendant du username.

---

### M11. Justfile `lab` : display forwarding Linux-only

**Fichier** : `Justfile` (lignes 107-114)

X11 (`/tmp/.X11-unix`) et socket Wayland sont Linux-specific.

**Plan** : Documenter que la recette `lab` est Linux-desktop only. Ajouter un commentaire explicite. Éventuellement un guard OS.

---

### M12. Justfile : `podman` hardcodé

**Fichier** : `Justfile` (tout le fichier)

Pas de support Docker. Utilisateurs Docker-only → `command not found`.

**Plan** : Variable `engine` en tête de Justfile :
```just
engine := env("CONTAINER_ENGINE", "podman")
```

---

### M13. `btop.conf` : chemin thème absolu Debian-only

**Fichier** : `dotfiles/btop/btop.conf` (ligne 5)

```
color_theme = "/usr/share/btop/themes/catppuccin_mocha.theme"
```

Existe uniquement sur Debian/Ubuntu.

**Plan** : Utiliser un chemin relatif ou le nom du thème seul si btop le supporte. Sinon, documenter l'installation manuelle du thème sur les autres distros.

---

### M14. `init.sh` : `bash` hardcodé pour zoxide/starship

**Fichier** : `dotfiles/shell/init.sh` (lignes 12, 21)

`zoxide init bash` et `starship init bash` ne fonctionnent pas sous zsh.

**Plan** : Détecter le shell courant :
```bash
current_shell=$(basename "$SHELL")
eval "$(zoxide init "$current_shell")"
eval "$(starship init "$current_shell")"
```

---

### M15. Ghostty config : `term = xterm-ghostty-256color`

**Fichier** : `dotfiles/ghostty/config`

Terminfo absent sur la plupart des serveurs SSH distants.

**Plan** : Documenter `export TERM=xterm-256color` dans le `.ssh/config` ou utiliser `infocmp | ssh remote -- tic -x -` pour propager le terminfo.

---

### M16. Dockerfile : fake `brew` symlink

**Fichier** : `Dockerfile` (ligne 67)

`ln -s /usr/bin/true /home/linuxbrew/.linuxbrew/bin/brew` — `command -v brew` retourne faux positif.

**Plan** : Supprimer ou remplacer par un script wrapper qui affiche un message explicatif.

---

### M17. `test_infra.sh` : installe Homebrew dans un container jetable

**Fichier** : `test_infra.sh` (lignes 9-10)

Lent, dépend d'infra externe, pas de vérification de checksum.

**Plan** : Réévaluer si ce test est encore nécessaire vu que le Dockerfile installe tout nativement. Sinon, épingler la version de l'installeur et vérifier son hash.

---

### M18-M19. `check_links.sh` : pas de strict mode + extraction URLs fragile

**Fichier** : `check_links.sh`

Pas de `set -u`. Extraction des URLs par `sed` mangle les `:` des URLs `https://`.

**Plan** : Ajouter `set -u`. Refactorer l'extraction avec un pattern grep plus robuste :
```bash
grep -oP 'https?://[^\s\)\]>"'"'"']+' "$DOC_FILE"
```

---

### M20. `test-cli-tools.sh` : `mktemp --suffix` GNU-only

**Fichier** : `tests/test-cli-tools.sh` (ligne 371)

`mktemp --suffix=.json` n'existe pas sur macOS.

**Plan** : Pas bloquant car tourne dans le container Debian. Documenter cette dépendance GNU. Alternativement : `tmp=$(mktemp); mv "$tmp" "$tmp.json"`.

---

### M21. `detect-ghostty.sh` : chemins ressources Linux-only

**Fichier** : `scripts/detect-ghostty.sh` (lignes 35-47)

`/tmp/.mount_*`, `/usr/share/ghostty`, `/opt/ghostty/share` — pas de support macOS.

**Plan** : Ajouter les chemins macOS : `/Applications/Ghostty.app/Contents/Resources/`, `$(brew --prefix)/share/ghostty/`.

---

### M22. Justfile : `:Z` suffixe SELinux-specific

**Fichier** : `Justfile` (volume mounts)

Flag de relabeling Podman/SELinux. Docker l'accepte mais l'ignore.

**Plan** : Acceptable. Documenter dans un commentaire.

---

### M23. Dockerfile : ripdrag build from source

**Fichier** : `Dockerfile` (lignes 50-52)

Installe Rust + GTK4 dev → compile ripdrag → désinstalle. ~5 min, fragile.

**Plan** : Surveiller les releases GitHub de ripdrag pour d'éventuels binaires pré-compilés. Sinon, multi-stage build pour isoler la compilation.

---

### M24. Dockerfile : `curl | sh` sans checksum

**Fichier** : `Dockerfile` (lignes 18-19)

starship et uv installés via `curl | sh`. Supply chain attack vector.

**Plan** : Utiliser les paquets Debian quand disponibles, ou télécharger + vérifier le hash :
```bash
curl -sS https://starship.rs/install.sh -o /tmp/starship.sh
echo "SHA256_ATTENDU /tmp/starship.sh" | sha256sum -c
sh /tmp/starship.sh -y
```

---

## LOW — Améliorations mineures

| # | Fichier | Problème | Plan |
|---|---------|----------|------|
| L25 | Justfile | `--network host` ne marche pas sur macOS Podman (VM) | Documenter la limitation |
| L26 | check_links.sh | User-Agent Chrome/120 obsolète | Mettre à jour périodiquement |
| L27 | configure-ghostty.sh | `fc-list` absent sur macOS | OK — fail silencieux, pas critique |
| L28 | aliases.sh | Override `du`/`ps`/`top` casse les scripts POSIX | Documenter en commentaire que ces aliases sont pour usage interactif uniquement |
| L29 | .tmux.conf | Sixel glob `xterm*` ne couvre pas tous les terminaux | Ajouter les patterns foot/alacritty si nécessaire |
| L30 | Brewfile | Homebrew-only, pas d'alternative apt/dnf | Le Dockerfile est l'alternative — documenter |
| L31 | test-ghostty-integration.sh | `check_links.sh` peut ne pas être exécutable après clone | Ajouter `chmod +x` en début de test ou dans le Justfile |
| L32 | yazi keymap.toml | `ripdrag` requis + display server pour drag-and-drop | Erreurs cachées par `2>/dev/null` — acceptable, documenter |
| L33 | Dockerfile | GTK4/Pango/Cairo runtime libs lourdes pour CLI | Envisager un stage séparé ou conditionnel pour ripdrag |
| L34 | test_infra.sh | `apt-get` sans sudo — suppose root | Ajouter un guard `if [ "$(id -u)" -ne 0 ]; then ... fi` |
| L35 | configure-ghostty.sh | URL Nerd Font version `v3.0.0` hardcodée | Utiliser `/latest` ou documenter la mise à jour |

---

## Priorités de correction

### Phase 1 — CRITICAL (sécurité + portabilité de base)
- [ ] C5 : Migrer tous les `grep|cut` vers `jq` dans le Dockerfile
- [ ] C6 : Supporter `GITHUB_TOKEN` optionnel + cache de couches
- [ ] C7 : Limiter le montage `lab` au projet (pas `$HOME`)
- [ ] C8 : Guard conditionnel sur `/dev/dri`
- [ ] C9 : Remplacer `python3` par `jq` dans `install-ghostty.sh`

### Phase 2 — CRITICAL (multi-architecture)
- [ ] C1-C4 : Refactorer le Dockerfile avec détection `TARGETARCH`
- [ ] Tester `podman build --platform linux/arm64`

### Phase 3 — MEDIUM (robustesse)
- [ ] M10 : Chemin container fixe `/project`
- [ ] M12 : Variable `CONTAINER_ENGINE` (podman/docker)
- [ ] M14 : Détection shell dans init.sh
- [ ] M16 : Supprimer le fake `brew` symlink
- [ ] M18-M19 : Strict mode + extraction URLs dans check_links.sh
- [ ] M24 : Checksum sur les `curl | sh`

### Phase 4 — LOW (polish)
- [ ] L28 : Documenter les overrides d'aliases
- [ ] L30 : Documenter Dockerfile comme alternative à Brewfile
- [ ] L31 : `chmod +x` dans les tests
- [ ] L34 : Guard root dans test_infra.sh
- [ ] L35 : URL Nerd Font dynamique
