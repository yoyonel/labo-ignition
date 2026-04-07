FROM debian:trixie

# Arguments pour l'utilisateur (UID/GID de l'hôte)
ARG USER_ID=1000
ARG USER_NAME=developer

# 1. Dépendances système & Outils CLI (Debian 13 Trixie)
RUN apt-get update && apt-get install -y \
    curl git tmux bat fzf ripgrep fd-find imagemagick chafa \
    build-essential unzip sudo file less \
    ffmpegthumbnailer poppler-utils jq 7zip direnv \
    ncurses-term \
    && rm -rf /var/lib/apt/lists/*

# 2. Installation des outils (natif & global)
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y \
    && curl -LsSf https://astral.sh/uv/install.sh | sh && mv /root/.local/bin/uv* /usr/local/bin/ \
    && JUMP_VERSION=$(curl -s https://api.github.com/repos/gsamokovarov/jump/releases/latest | grep tag_name | cut -d'"' -f4 | tr -d 'v') \
    && curl -L "https://github.com/gsamokovarov/jump/releases/download/v${JUMP_VERSION}/jump_${JUMP_VERSION}_amd64.deb" -o /tmp/jump.deb \
    && dpkg -i /tmp/jump.deb && rm /tmp/jump.deb \
    && PROCS_URL=$(curl -s https://api.github.com/repos/dalance/procs/releases/latest | grep "browser_download_url" | grep "x86_64" | grep "\.zip" | head -n 1 | cut -d'"' -f4) \
    && curl -L "${PROCS_URL}" -o /tmp/procs.zip \
    && unzip /tmp/procs.zip -d /tmp/procs-pkg && mv /tmp/procs-pkg/procs /usr/local/bin/ && rm -rf /tmp/procs*

# 2. Création de l'utilisateur identique à l'hôte
RUN useradd -m -u ${USER_ID} -s /bin/bash ${USER_NAME} \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 3. YAZI (Dernière version pré-compilée)
RUN YAZI_VERSION=$(curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest | grep tag_name | cut -d'"' -f4) \
    && curl -L "https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-x86_64-unknown-linux-gnu.zip" -o /tmp/yazi.zip \
    && unzip -o /tmp/yazi.zip -d /tmp/yazi-pkg \
    && mv /tmp/yazi-pkg/yazi-x86_64-unknown-linux-gnu/yazi /usr/local/bin/ \
    && mv /tmp/yazi-pkg/yazi-x86_64-unknown-linux-gnu/ya /usr/local/bin/ 2>/dev/null || true \
    && rm -rf /tmp/yazi.zip /tmp/yazi-pkg

# 4. Configuration globale & Neutralisation Brew
RUN echo 'alias fd=fdfind' >> /etc/bash.bashrc && \
    echo 'alias bat=batcat' >> /etc/bash.bashrc && \
    mkdir -p /home/linuxbrew/.linuxbrew/bin && \
    ln -s /usr/bin/true /home/linuxbrew/.linuxbrew/bin/brew && \
    echo 'export PS1="🧪 LABO-CI $PS1"' >> /etc/bash.bashrc

# 5. Compatibilité Ghostty
ENV TERM=xterm-256color

# On bascule sur l'utilisateur identique à l'hôte
RUN mv /usr/local/bin/starship /usr/local/bin/starship.bin && \
    printf '#!/bin/sh\nif [ "$1" = "prompt" ]; then\n  shift\n  printf "🧪 LAB " && exec /usr/local/bin/starship.bin prompt "$@"\nelse\n  exec /usr/local/bin/starship.bin "$@"\nfi\n' > /usr/local/bin/starship && \
    chmod +x /usr/local/bin/starship

# 6. User final
USER ${USER_NAME}
WORKDIR /home/${USER_NAME}/project

CMD ["bash"]
