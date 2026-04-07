#!/bin/bash
set -e

echo -e "\n\e[1;34m[1/4] Préparation de la machine vierge (Debian)...\e[0m"
apt-get update -qq && apt-get install -y -qq curl git > /dev/null

echo -e "\n\e[1;34m[2/4] Installation de Chezmoi...\e[0m"
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
brew install chezmoi > /dev/null

echo -e "\n\e[1;34m[3/4] Simulation du déploiement...\e[0m"
# On simule le comportement classique : copier les fichiers dans l'arborescence cible
mkdir -p ~/.config/ghostty ~/.config/yazi
cp /mnt/dotfiles/ghostty/config ~/.config/ghostty/config
cp /mnt/dotfiles/yazi/yazi.toml ~/.config/yazi/yazi.toml
cp /mnt/dotfiles/.tmux.conf ~/.tmux.conf

# On fait avaler tout ça à Chezmoi pour vérifier que ça passe
chezmoi init
chezmoi add ~/.config/ghostty/config ~/.tmux.conf ~/.config/yazi/yazi.toml
chezmoi apply --force > /dev/null

echo -e "\n\e[1;34m[4/4] Exécution des Assertions...\e[0m"
grep -q "allow-passthrough on" ~/.tmux.conf || (echo "ERREUR: Config Tmux invalide" && exit 1)
grep -q 'image_preview_method = "kitty"' ~/.config/yazi/yazi.toml || (echo "ERREUR: Config Yazi invalide" && exit 1)
grep -q 'theme = "Catppuccin Mocha"' ~/.config/ghostty/config || (echo "ERREUR: Config Ghostty invalide" && exit 1)

echo -e "\n\e[1;32m✅ SUCCÈS ABSOLU : L'Infrastructure est valide.\e[0m\n"