# Copilot Instructions — labo-ignition

## Projet

Environnement de développement conteneurisé (Debian Trixie Slim) piloté par Podman rootless + Just.
Hôte : Bazzite (Fedora Atomic/Silverblue), immuable.

## Structure

```
Dockerfile          # Multi-stage : builder-ripdrag → image finale (~750 MB)
Justfile            # Orchestrateur — ne jamais y mettre de logique complexe
scripts/*.sh        # Logique extraite des recettes Just
tests/              # test-cli-tools.sh (85 tests), test-ghostty-integration.sh
dotfiles/           # Toutes les configs : NE JAMAIS générer de config via cat/heredoc dans les scripts
docs/               # PORTABILITY-AUDIT, CI-CD-PIPELINE, CLI-TOOLS, TEST-SUITE-ARCHITECTURE
.agents/            # AI-CONVENTIONS.md (version agnostique pour tous les agents)
```

## Commandes essentielles

| Action | Commande |
|---|---|
| Build image locale | `just build` |
| Lancer le labo | `just lab` |
| Labo via GHCR (rapide) | `just lab-remote` |
| CI locale complète | `just ci-local` |
| Lint shell | `just lint-shell` |
| Lint Dockerfile | `just lint-dockerfile` |
| Tests CLI dans container | `just test-cli-tools` |
| Analyse taille image | `just analyze-image` |
| Explorer image (TUI) | `just dive` |
| Graphe deps paquet | `just debtree <pkg>` |
| Arbre deps paquet | `just apt-rdepends <pkg>` |
| Vérifier liens docs | `just audit-links` |

## Règles strictes

1. **Avant tout commit** : linter + tests doivent passer.
2. **Avant tout push** : `just ci-local` doit être vert (shellcheck + ghostty tests + liens + hadolint + build + 85 tests CLI).
3. **Après tout push** : surveiller les workflows GitHub Actions (CI + Docker) jusqu'à complétion. Corriger immédiatement si échec.
4. **Documentation** : tout changement non-trivial doit être documenté dans le `.md` concerné. Vérifier les liens avec `just audit-links`.
5. **Zéro lien mort** dans le repo.

## Conventions Dockerfile

- Base : `debian:trixie-slim` (pas `debian:trixie`).
- Toujours `--no-install-recommends` sur `apt-get install`.
- `SHELL ["/bin/bash", "-o", "pipefail", "-c"]` dans chaque stage (hadolint DL4006).
- Outils compilés (ripdrag) : multi-stage build, `COPY --from=` du binaire uniquement.
- Configs dans `dotfiles/`, jamais inline.

## Conventions Code

- **Justfile** : orchestrateur simple. Dès qu'une recette dépasse ~3 lignes, extraire dans `scripts/*.sh`.
- **Portabilité** : ne pas lier au hôte spécifique (Bazzite). Rendre configurable.
- **Emojis** : usage sobre dans la documentation et les commits. Style professionnel.
- **Commits** : conventional commits (`feat`, `fix`, `perf`, `docs`, `ci`...).

## Pièges connus

- `gh run list` / `podman` peuvent ouvrir un pager ou bloquer la capture de sortie → utiliser `| head` ou `--json ... | cat`.
- Le builder-ripdrag (Rust + GTK4) prend ~8-10 min sur CI/local. Ne pas timeout prématurément.
- Podman rootless : `--user root` dans le container = UID 1000 hôte (pas de vrais privilèges).
- SELinux : volumes montés avec `:z` ou `:Z` pour le relabeling.
