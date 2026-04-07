# Investigation & Fix : Permissions Rootless Podman sur Debian 13

> **Contexte** : Environnement `labo-ignition` — shell interactif dans un container Podman
> rootless avec `$HOME` monté en miroir.
> **Date** : Avril 2026 — Debian 13 (Trixie), Podman 5.x, kernel Debian stock.

---

## 1. Symptômes initiaux

### 1.1 — Échec au lancement du labo (`just lab`)

```
Error: container create failed (no logs from conmon): conmon bytes "": readObjectStart:
expect { or n, but found , error found in #0 byte of ...||...
```

Le container ne démarrait même pas. L'erreur conmon indique un problème de sérialisation
JSON, mais le vrai message était masqué.

### 1.2 — Yazi échoue en permission denied

Une fois le container lancé via un contournement temporaire (`--user root`), yazi affichait :

```
Failed to read config "/home/latty/.config/yazi/yazi.toml"
Caused by:
Permission denied (os error 13)
```

Alors que le fichier n'existait même pas — le problème était l'impossibilité de **lire
le répertoire** `~/.config/yazi/`.

---

## 2. Diagnostic étape par étape

### 2.1 — Isolation du flag `--userns keep-id`

Le Justfile original utilisait `--userns keep-id`, une option Podman qui mappe le UID
de l'utilisateur hôte vers le même UID dans le container. C'est le comportement attendu
pour qu'un container ayant un user `latty` (uid=1000) puisse lire des fichiers appartenant
à `latty` (uid=1000) sur l'hôte.

Testé en isolation :

```bash
# Teste keep-id seul → ÉCHEC
podman run --rm --userns keep-id labo-ci echo "ok"
# Error: runc: runc create failed: ... remount-private dst=.../overlay/XXX/merged,
# flags=MS_PRIVATE: permission denied: OCI permission denied

# Teste sans keep-id → OK
podman run --rm labo-ci echo "ok"
# ok
```

### 2.2 — Identification du runtime OCI : `runc` de `containerd.io`

```bash
podman info --format json | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(json.dumps(d['host']['ociRuntime'], indent=2))"
```

```json
{
  "name": "runc",
  "package": "containerd.io_2.2.2-1~debian.13~trixie_amd64",
  "path": "/usr/bin/runc",
  "version": "runc version 1.3.4"
}
```

**Point crucial** : ce n'est pas le `runc` du paquet Debian `runc`, mais celui embarqué
dans `containerd.io` (installé pour Docker). Cette version de `runc` échoue sur l'appel
`remount-private` dans un user namespace rootless sur le kernel Debian.

### 2.3 — `fuse-overlayfs` était déjà configuré (mais insuffisant)

```bash
cat ~/.config/containers/storage.conf
# [storage]
# driver = "overlay"
# [storage.options]
# mount_program = "/usr/bin/fuse-overlayfs"

podman info | grep -A5 "mount_program"
# Executable: /usr/bin/fuse-overlayfs
# Package: fuse-overlayfs_1.14-1+b1_amd64
```

`fuse-overlayfs` était présent et configuré. Sur Fedora/Bazzite, cela suffit pour que
`--userns keep-id` fonctionne. Pas sur Debian — la cause réside dans le runtime OCI.

### 2.4 — Tentative avec `crun` comme runtime OCI

[`crun`](https://github.com/containers/crun) est le runtime OCI écrit en C par Red Hat,
utilisé par défaut sur Fedora/Bazzite. Il gère mieux les user namespaces rootless que
`runc`.

```bash
# Installation
sudo apt install crun   # version 1.21-1 disponible dans Debian 13

# Configuration du runtime par défaut
mkdir -p ~/.config/containers
cat > ~/.config/containers/containers.conf << 'EOF'
[engine]
runtime = "crun"
EOF

# Re-test
podman run --rm --userns keep-id labo-ci echo "ok"
# Error: crun: open `.../overlay/XXX/merged`: Permission denied: OCI permission denied
```

`crun` seul ne résout pas non plus le problema. L'erreur change (de `runc: runc create failed`
à `crun: open .../merged: Permission denied`), mais la cause profonde est ailleurs.

### 2.5 — Cause racine : `CONFIG_OVERLAY_FS` en user namespace

La vraie différence entre Fedora et Debian est au niveau **kernel** :

| Kernel | `overlayfs` en user namespace non-privilégié |
|---|---|
| Fedora 39+ / Bazzite | ✅ activé (`CONFIG_OVERLAY_FS` unprivileged) |
| Debian 13 Trixie stock | ❌ désactivé ou restreint |

Sur Fedora, `--userns keep-id` + `fuse-overlayfs` + `crun` fonctionnent ensemble car le
kernel autorise nativement les user namespaces à monter des overlays. Sur Debian, même
avec `fuse-overlayfs`, le kernel refuse le `remount-private` que `runc`/`crun` demande
lors de la préparation du rootfs dans un user namespace.

### 2.6 — Comprendre le mapping UID rootless sans `--userns keep-id`

Sans `--userns keep-id`, le [mapping Podman rootless par défaut](https://docs.podman.io/en/latest/markdown/podman_rootless.1.html)
est le suivant (avec `/etc/subuid: latty:100000:65536`) :

```
container uid=0  (root)   → host uid=1000  (latty) ✅
container uid=1  (daemon) → host uid=100000         ✅
...
container uid=1000 (latty dans l'image) → host uid=101000 (inexistant) ❌
```

Le `Dockerfile` crée un user `latty` avec `uid=1000`. Yazi tourne donc comme
`uid=1000` dans le container, qui correspond à `uid=101000` côté hôte. Les fichiers de
`$HOME` appartiennent à `uid=1000` hôte → accès refusé.

---

## 3. Solution appliquée

### 3.1 — `--user root` dans `podman run`

La solution est d'utiliser `--user root` dans la commande `podman run`. Cela peut sembler
contre-intuitif, mais c'est une propriété fondamentale du mode rootless :

> **En rootless Podman, `uid=0` (root) dans le container correspond à l'UID de
> l'utilisateur appelant (`uid=1000`, `latty`) sur l'hôte.**

C'est documenté explicitement dans le [guide rootless officiel](https://docs.podman.io/en/latest/markdown/podman_rootless.1.html) :

> *"If your container runs with the root user, then `root` in the container is actually
> your user on the host."*

Et dans [`podman-run(1)`](https://docs.podman.io/en/latest/markdown/podman-run.1.html#user-u-user-group) :

> *"In rootless containers, for example, a user namespace is always used, and root in the
> container by default corresponds to the UID and GID of the user invoking Podman."*

**Aucune élévation de privilège réelle n'est accordée** — le container est toujours
totalement isolé, avec les seules capacités de l'utilisateur hôte.

### 3.2 — Validation

```bash
podman run --rm \
    --security-opt label=disable --network host \
    --user root -e USER=latty -e HOME=$HOME \
    -v "$HOME:$HOME" labo-ci \
    bash -c "id && ls ~/.config/yazi/"

# uid=0(root) gid=0(root) groups=0(root)
# (liste du contenu de ~/.config/yazi/ sans erreur)
```

### 3.3 — Équivalence avec Distrobox

[Distrobox](https://github.com/89luca89/distrobox) utilise le même principe sur tous les
OS en mode rootless : il lance le container avec `uid=0` dans le namespace, ce qui mappe
automatiquement vers l'UID de l'utilisateur hôte. L'installation `--userns keep-id` sur
Bazzite/Fedora y fonctionne en plus car le kernel Fedora supporte les overlayfs en user
namespace, ce que le kernel Debian stock ne permet pas.

---

## 4. Changements effectués dans le repo

### 4.1 — `Justfile` : recette `lab`

Avant :

```just
podman run -it --rm --name {{container_name}}-run \
    --security-opt label=disable --userns keep-id --network host \
    -v $HOME:$HOME \
    -e IN_LAB=true \
    -e TERM -e COLORTERM -e XDG_RUNTIME_DIR -e GHOSTTY_BIN_DIR -e GHOSTTY_RESOURCES_DIR \
    --workdir $(pwd) {{container_name}} bash
```

Après :

```just
podman run -it --rm --name {{container_name}}-run \
    --security-opt label=disable --network host \
    --user root -e USER={{user_name}} -e HOME=$HOME \
    -v $HOME:$HOME \
    -e IN_LAB=true \
    -e TERM -e COLORTERM -e XDG_RUNTIME_DIR -e GHOSTTY_BIN_DIR -e GHOSTTY_RESOURCES_DIR \
    --workdir $(pwd) {{container_name}} bash
```

**Changements** :
- Suppression de `--userns keep-id` (incompatible avec le kernel Debian stock)
- Ajout de `--user root` (mappe root container → uid=1000 hôte en rootless)
- Ajout de `-e USER={{user_name}} -e HOME=$HOME` (certains outils lisent `$USER` et `$HOME`
  pour retrouver leur config ; sans ces variables, ils cherchent dans `/root/` du container
  au lieu du `$HOME` hôte monté)

### 4.2 — `~/.config/containers/containers.conf` (système local, hors repo)

Fichier créé pour utiliser `crun` à la place de `runc` de `containerd.io`. Bien que
`crun` seul ne résolve pas le problème d'overlay, il est recommandé pour le mode rootless :

```toml
[engine]
runtime = "crun"
```

### 4.3 — `check_links.sh`

Modifié pour accepter un fichier en argument optionnel `$1`, avec fallback sur la
détection automatique de `*Environ.md`. Permet de vérifier les liens de n'importe quel
fichier `.md` du repo :

```bash
./check_links.sh Podman-Rootless-Permissions.md
```

---

## 5. Références

| Ressource | URL |
|---|---|
| Podman rootless documentation (officiel) | https://docs.podman.io/en/latest/markdown/podman_rootless.1.html |
| `podman-run(1)` — `--user` et `--userns` | https://docs.podman.io/en/latest/markdown/podman-run.1.html |
| Podman architecture & design | https://docs.podman.io/en/latest/ |
| `crun` — OCI runtime C (Red Hat) | https://github.com/containers/crun |
| `runc` — OCI runtime Go (OCI) | https://github.com/opencontainers/runc |
| `fuse-overlayfs` — overlay FUSE pour containers rootless | https://github.com/containers/fuse-overlayfs |
| Distrobox — containers transparents | https://github.com/89luca89/distrobox |

---

## 6. Implications & Points de vigilance

- **Portabilité** : Cette configuration fonctionne sur Debian 13 et sur Bazzite/Fedora
  (où `--userns keep-id` fonctionnerait aussi, mais `--user root` est équivalent).
- **Sécurité** : Pas de régression. En rootless Podman, `root` dans le container n'a
  aucun privilège hôte au-delà de ceux de l'utilisateur appelant.
- **`$USER` vs identité** : Sans `-e USER=latty`, des outils comme `git`, `tmux` ou des
  scripts lisant `$(whoami)` ou `$USER` retourneraient `root` au lieu de `latty`. D'où
  l'ajout explicite de cette variable.
- **Fichiers créés dans `$HOME`** : Tous les fichiers créés par le container dans `$HOME`
  appartiennent à `uid=1000` (latty) sur l'hôte — comportement correct et identique à ce
  que `--userns keep-id` aurait donné.
