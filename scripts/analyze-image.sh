#!/usr/bin/env bash
# scripts/analyze-image.sh
# Analyse de taille et dependances de l'image labo-ci
# Usage: ./scripts/analyze-image.sh [image_name]

set -euo pipefail

IMAGE="${1:-labo-ci}"

BLUE='\033[1;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

header() { echo -e "\n${BLUE}==> $1${NC}"; }

# --- Dive analysis (host-side) ---
if command -v dive &>/dev/null; then
    header "Dive — Layer efficiency analysis"
    dive "podman://${IMAGE}" --ci
else
    echo -e "${YELLOW}[skip] dive non installe (brew install dive)${NC}"
fi

echo ""
header "Image size"
podman images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "REPOSITORY|${IMAGE}"

header "Layer breakdown"
podman history "${IMAGE}" --format "{{.Size}}\t{{.CreatedBy}}" | head -20

# --- In-container analysis ---
header "Top 30 paquets Debian (par taille installee)"
podman run --rm "${IMAGE}" bash -c \
    "dpkg-query -Wf '\${Installed-Size}\t\${Package}\n' | sort -rn | head -30"

header "Total paquets Debian"
podman run --rm "${IMAGE}" bash -c \
    "dpkg-query -Wf '\${Installed-Size}\t\${Package}\n' | awk '{s+=\$1} END{printf \"%d MB\\n\", s/1024}'"

header "Binaires CLI — /usr/local/bin/"
podman run --rm "${IMAGE}" bash -c \
    "du -sh /usr/local/bin/ && ls -lhS /usr/local/bin/"

header "Dependances inverses des gros paquets"
podman run --rm "${IMAGE}" bash -c '
for pkg in libllvm19 mesa-vulkan-drivers pocketsphinx-en-us libflite1 libz3-4 libgs10; do
    SIZE=$(dpkg-query -Wf "\${Installed-Size}" "$pkg" 2>/dev/null || echo "absent")
    [ "$SIZE" = "absent" ] && continue
    RDEPS=$(apt-cache rdepends --installed "$pkg" 2>/dev/null | tail -n +3 | sed "s/^[| ]*//" | grep -v "^$" | tr "\n" ", ")
    printf "%-30s %6s KB  <-- %s\n" "$pkg" "$SIZE" "$RDEPS"
done
'

# --- debtree (if available inside container) ---
header "Graphe de dependances (debtree)"
if podman run --rm "${IMAGE}" bash -c "command -v debtree &>/dev/null" 2>/dev/null; then
    echo "debtree disponible dans le container"
    echo "  Generer un graphe : podman run --rm ${IMAGE} debtree <package> | dot -Tsvg > deps.svg"
else
    echo -e "${YELLOW}debtree non installe dans l'image (paquet Debian optionnel)${NC}"
    echo "  Pour une analyse ponctuelle :"
    echo "    podman run --rm ${IMAGE} bash -c 'apt-get update -qq && apt-get install -y -qq debtree graphviz && debtree libgtk-4-1 | dot -Tsvg' > gtk4-deps.svg"
fi

# --- apt-rdepends (if available inside container) ---
header "Arbre de dependances (apt-rdepends)"
if podman run --rm "${IMAGE}" bash -c "command -v apt-rdepends &>/dev/null" 2>/dev/null; then
    echo "apt-rdepends disponible dans le container"
    echo "  Usage : podman run --rm ${IMAGE} apt-rdepends --dotty <package> | dot -Tsvg > tree.svg"
else
    echo -e "${YELLOW}apt-rdepends non installe dans l'image (paquet Debian optionnel)${NC}"
    echo "  Pour une analyse ponctuelle :"
    echo "    podman run --rm ${IMAGE} bash -c 'apt-get update -qq && apt-get install -y -qq apt-rdepends && apt-rdepends --dotty libgtk-4-1'"
fi

echo ""
echo -e "${GREEN}Analyse terminee.${NC}"
echo "Documentation complete : docs/IMAGE-SIZE-ANALYSIS.md"
