# 🚀 Labo-Ignition

Industrialized Debian 13 (Trixie) Containerized Development Environment.

This repository contains the configuration for a robust, autonomous development lab based on Debian 13, designed to mirror a modern host environment (like Bazzite) while remaining completely isolated.

## ✨ Features

- **Isolated & Autonomous**: No dependencies on the host configuration for visuals.
- **Visual Prompt Identity**: Automatically identifies the container with a `🧪 LAB` indicator in the prompt via a custom Starship wrapper.
- **Modern Tooling**: Includes `yazi`, `uv`, `starship`, `just`, `fzf`, `rg`, `bat`, `fd`, etc.
- **Persistent Home**: Mounts your host `$HOME` for productivity while maintaining environment distinction.
- **Hardened Rendering**: Fixed terminal rendering for Ghostty and modern terminal emulators.

## 🛠️ Usage

### Prerequisites
- Podman installed on the host.
- `just` (optional, but recommended).

### Commands
Build the image:
```bash
just build
```

Launch the lab:
```bash
just lab
```

## 📜 License
This project is licensed under the **GPL-3.0 License**.
