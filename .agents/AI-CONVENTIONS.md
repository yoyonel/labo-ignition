# AI Guidelines & Repository Context

Ce document sert de mémoire contextuelle pour les agents IA travaillant sur ce dépôt. Il définit les conventions et les pièges à éviter.

## Gestion du Terminal & du Shell
- **Contexte Hôte** : Bazzite (Fedora Silverblue/Atomic). L'hôte est immuable.
- **Piège des sorties** : Les commandes comme gh ou podman peuvent parfois bloquer la capture de sortie de l'agent. 
- **Solution** : En cas de log vide, se référer aux indices visuels de l'invite de commande (prompt) dans l'interface utilisateur.
- **Timeouts** : Augmenter systématiquement le temps d'attente des commandes (WaitMsBeforeAsync > 1000ms) pour laisser le temps au shell atomique de répondre.

## Recettes Just & Setup
- **Initialisation** : Toujours utiliser just setup après un clone pour synchroniser le Brewfile (hôte) et les hooks git.
- **Workflow Lab** : 
    - just lab : Build local (lent mais modifiable).
    - just lab-remote : Pull GHCR (instantané). À privilégier si aucune modification du Dockerfile n'est prévue.

## Architecture Image
- **Permissions** : Le conteneur tourne via scripts/lab-run.sh avec --user root. Dans un contexte Podman rootless, cela mappe root (UID 0) au developer (UID 1000) de l'hôte, garantissant un accès sans friction au $HOME monté.
- **Ghostty** : Le rendu d'image haute performance (Yazi/Chafa) dépend de la propagation correcte des variables GHOSTTY_*.

## Documentation & Qualité (Strict)
- **Documentation continue** : Chaque nouveau réglage, outil installé ou changement de configuration doit être documenté immédiatement dans le fichier .md concerné. 
- **Zéro lien mort** : Avant de valider une mise à jour de documentation, il est obligatoire de vérifier la validité des liens (internes et externes) via le script ./check_links.sh ou la recette just audit-links. Aucun lien mort ne doit subsister dans le dépôt.

## Code Style & Maintenance (Modularité)
- **Justfile** : Ne pas surcharger le Justfile de commandes complexes. Il doit servir d'orchestrateur. Privilégier la création de scripts dans scripts/*.sh appelés par les recettes Just.
- **Injection de Config** : Ne jamais utiliser cat ou des redirections de texte brut dans les scripts pour générer des configurations. Toutes les configurations doivent résider dans le dossier dotfiles/ du projet pour être maintenables.

## Philosophie du Projet (Agnosticisme)
- **Portabilité & Agnosticisme** : Toujours privilégier des solutions qui ne sont pas liées à une spécificité unique de l'hôte actuel. Le code, les scripts et les outils doivent rester portables et réutilisables sur d'autres postes, OS ou protocoles. Toute adhérence à l'environnement local doit être minimisée ou rendue configurable.

## Processus de Validation (Strict)
- **Vérification locale** : Avant tout commit, il est obligatoire de passer le linter, le formateur et les tests unitaires.
- **Tests pré-push** : Une suite complète de tests (just ci-local) doit être exécutée avec succès avant chaque push sur le dépôt distant.
- **Vigilance CI/CD** : Après chaque push, le workflow de CI/CD doit être surveillé jusqu'à sa complétion. En cas d'échec, le correctif doit être apporté et poussé immédiatement pour maintenir la branche master stable.

## Esthétique et Communication
- **Sobriété visuelle** : Limiter drastiquement l'usage des emojis dans la documentation, les messages de commit et les communications. Privilégier un style sobre et professionnel.
