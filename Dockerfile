# =============================================================================
# Stage 1: Build ripdrag from source (isolé, ne pollue pas l'image finale)
# =============================================================================
FROM debian:trixie-slim AS builder-ripdrag

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates pkg-config libgtk-4-dev gcc libc6-dev \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal \
    && . /root/.cargo/env \
    && cargo install ripdrag \
    && mv /root/.cargo/bin/ripdrag /usr/local/bin/ripdrag \
    && rm -rf /root/.cargo /root/.rustup /tmp/*

# =============================================================================
# Stage 2: Image finale — CLI tools only
# =============================================================================
FROM debian:trixie-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Arguments pour l'utilisateur (UID/GID de l'hôte)
ARG USER_ID=1000
ARG USER_NAME=developer

# 1. Dépendances système & Outils CLI (Debian 13 Trixie)
#    --no-install-recommends évite ~500MB de paquets parasites (LLVM, Mesa, pocketsphinx…)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git tmux bat fzf ripgrep fd-find chafa \
    unzip sudo file less locales tzdata \
    ffmpegthumbnailer poppler-utils jq 7zip direnv \
    ncurses-term btop \
    imagemagick --no-install-recommends \
    libgtk-4-1 libpango-1.0-0 libcairo2 libgdk-pixbuf-2.0-0 \
    && sed -i '/fr_FR.UTF-8/s/^# //' /etc/locale.gen \
    && sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=fr_FR.UTF-8
ENV LC_ALL=fr_FR.UTF-8
ENV TZ=Europe/Paris

# 2. Installation des outils (natif & global)
# hadolint ignore=SC2046
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y \
    && curl -LsSf https://astral.sh/uv/install.sh | sh && mv /root/.local/bin/uv* /usr/local/bin/ \
    && JUMP_VERSION=$(curl -s https://api.github.com/repos/gsamokovarov/jump/releases/latest | grep tag_name | cut -d'"' -f4 | tr -d 'v') \
    && curl -L "https://github.com/gsamokovarov/jump/releases/download/v${JUMP_VERSION}/jump_${JUMP_VERSION}_amd64.deb" -o /tmp/jump.deb \
    && dpkg -i /tmp/jump.deb && rm /tmp/jump.deb \
    && PROCS_URL=$(curl -s https://api.github.com/repos/dalance/procs/releases/latest | grep "browser_download_url" | grep "x86_64" | grep "\.zip" | head -n 1 | cut -d'"' -f4) \
    && curl -L "${PROCS_URL}" -o /tmp/procs.zip \
    && unzip /tmp/procs.zip -d /tmp/procs-pkg && mv /tmp/procs-pkg/procs /usr/local/bin/ && rm -rf /tmp/procs* \
    && LSD_URL=$(curl -s https://api.github.com/repos/lsd-rs/lsd/releases/latest | grep "browser_download_url" | grep "x86_64-unknown-linux-gnu.tar.gz" | head -n 1 | cut -d'"' -f4) \
    && curl -L "${LSD_URL}" -o /tmp/lsd.tar.gz \
    && tar -xzf /tmp/lsd.tar.gz -C /tmp/ && mv /tmp/lsd-*/lsd /usr/local/bin/ && rm -rf /tmp/lsd*  && chmod +x /usr/local/bin/lsd

# 2b. Outils CLI modernes (GitHub releases)
# hadolint ignore=SC2046
RUN EZA_URL=$(curl -s https://api.github.com/repos/eza-community/eza/releases/latest | grep "browser_download_url" | grep "x86_64-unknown-linux-gnu.tar.gz" | grep -v "man" | head -n 1 | cut -d'"' -f4) \
    && curl -L "${EZA_URL}" -o /tmp/eza.tar.gz \
    && tar -xzf /tmp/eza.tar.gz -C /usr/local/bin/ && chmod +x /usr/local/bin/eza && rm -rf /tmp/eza* \
    && ZOXIDE_URL=$(curl -s https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest | grep "browser_download_url" | grep "x86_64-unknown-linux-musl.tar.gz" | head -n 1 | cut -d'"' -f4) \
    && curl -L "${ZOXIDE_URL}" -o /tmp/zoxide.tar.gz \
    && tar -xzf /tmp/zoxide.tar.gz -C /tmp/ && mv /tmp/zoxide /usr/local/bin/ && rm -rf /tmp/zoxide* \
    && DELTA_URL=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest | grep "browser_download_url" | grep "x86_64-unknown-linux-musl.tar.gz" | head -n 1 | cut -d'"' -f4) \
    && curl -L "${DELTA_URL}" -o /tmp/delta.tar.gz \
    && tar -xzf /tmp/delta.tar.gz -C /tmp/ && mv /tmp/delta-*/delta /usr/local/bin/ && rm -rf /tmp/delta* \
    && DUST_URL=$(curl -s https://api.github.com/repos/bootandy/dust/releases/latest | grep "browser_download_url" | grep "x86_64-unknown-linux-musl.tar.gz" | head -n 1 | cut -d'"' -f4) \
    && curl -L "${DUST_URL}" -o /tmp/dust.tar.gz \
    && tar -xzf /tmp/dust.tar.gz -C /tmp/ && mv /tmp/dust-*/dust /usr/local/bin/ && rm -rf /tmp/dust* \
    && HF_URL=$(curl -s https://api.github.com/repos/sharkdp/hyperfine/releases/latest | grep "browser_download_url" | grep "x86_64-unknown-linux-musl.tar.gz" | head -n 1 | cut -d'"' -f4) \
    && curl -L "${HF_URL}" -o /tmp/hyperfine.tar.gz \
    && tar -xzf /tmp/hyperfine.tar.gz -C /tmp/ && mv /tmp/hyperfine-*/hyperfine /usr/local/bin/ && rm -rf /tmp/hyperfine* \
    && GLOW_URL=$(curl -s https://api.github.com/repos/charmbracelet/glow/releases/latest | grep "browser_download_url" | grep "Linux_x86_64.tar.gz" | head -n 1 | cut -d'"' -f4) \
    && curl -L "${GLOW_URL}" -o /tmp/glow.tar.gz \
    && mkdir -p /tmp/glow-pkg && tar -xzf /tmp/glow.tar.gz -C /tmp/glow-pkg/ \
    && find /tmp/glow-pkg -name glow -type f -exec mv {} /usr/local/bin/ \; && rm -rf /tmp/glow*

# 3. Création de l'utilisateur identique à l'hôte
RUN useradd -m -u ${USER_ID} -s /bin/bash ${USER_NAME} \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 4. ripdrag (copié depuis le builder stage)
COPY --from=builder-ripdrag /usr/local/bin/ripdrag /usr/local/bin/ripdrag

# 5. YAZI (Dernière version pré-compilée)
RUN YAZI_VERSION=$(curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest | grep tag_name | cut -d'"' -f4) \
    && curl -L "https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-x86_64-unknown-linux-gnu.zip" -o /tmp/yazi.zip \
    && unzip -o /tmp/yazi.zip -d /tmp/yazi-pkg \
    && mv /tmp/yazi-pkg/yazi-x86_64-unknown-linux-gnu/yazi /usr/local/bin/ \
    && mv /tmp/yazi-pkg/yazi-x86_64-unknown-linux-gnu/ya /usr/local/bin/ 2>/dev/null || true \
    && rm -rf /tmp/yazi.zip /tmp/yazi-pkg

# 6. Configuration globale & Aliases
# hadolint ignore=SC2016
RUN echo 'alias fd=fdfind' >> /etc/bash.bashrc && \
    echo 'alias bat=batcat' >> /etc/bash.bashrc && \
    echo 'alias ls=lsd' >> /etc/bash.bashrc && \
    mkdir -p /home/linuxbrew/.linuxbrew/bin && \
    ln -s /usr/bin/true /home/linuxbrew/.linuxbrew/bin/brew && \
    echo 'export PS1="🧪 LABO-CI $PS1"' >> /etc/bash.bashrc

# 7. Copie des configurations dotfiles
COPY dotfiles/ /tmp/dotfiles/

# 8. Compatibilité Ghostty & Yazi
ENV TERM=xterm-256color
ENV YAZI_TMUX=1

# On bascule sur l'utilisateur identique à l'hôte
# hadolint ignore=SC2016
RUN mv /usr/local/bin/starship /usr/local/bin/starship.bin && \
    printf '#!/bin/sh\nif [ "$1" = "prompt" ]; then\n  shift\n  printf "🧪 LAB " && exec /usr/local/bin/starship.bin prompt "$@"\nelse\n  exec /usr/local/bin/starship.bin "$@"\nfi\n' > /usr/local/bin/starship && \
    chmod +x /usr/local/bin/starship

# 9. User final
USER ${USER_NAME}
WORKDIR /home/${USER_NAME}/project

CMD ["bash"]
