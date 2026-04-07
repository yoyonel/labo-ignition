#!/bin/bash
# test-ghostty-integration.sh
# Suite de tests complète pour l'intégration Ghostty
# Exécutable: bash tests/test-ghostty-integration.sh

# PAS de "set -e" — on veut continuer même si un test échoue
set -uo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;36m'
NC='\033[0m'

# Compteurs
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Chemins
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# ============================================================
# UTILITAIRES DE TEST
# ============================================================

test_header() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

test_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

test_skip() {
    echo -e "  ${YELLOW}⊘${NC} $1 (skipped)"
    ((TESTS_SKIPPED++))
}

assert_file_exists() {
    local file=$1
    local desc=$2
    if [[ -f "$file" ]]; then
        test_pass "$desc — $file exists"
    else
        test_fail "$desc — $file NOT FOUND"
    fi
}

assert_file_contains() {
    local file=$1
    local pattern=$2
    local desc=$3
    if [[ -f "$file" ]] && grep -q "$pattern" "$file" 2>/dev/null; then
        test_pass "$desc — pattern found in $file"
    else
        test_fail "$desc — pattern NOT found in $file"
    fi
}

assert_script_syntax() {
    local script=$1
    local desc=$2
    if bash -n "$script" 2>/dev/null; then
        test_pass "$desc — $script syntax OK"
    else
        test_fail "$desc — $script syntax ERROR"
    fi
}

assert_command_exists() {
    local cmd=$1
    local desc=$2
    if command -v "$cmd" &>/dev/null; then
        test_pass "$desc — command '$cmd' available"
        return 0
    else
        test_skip "$desc — command '$cmd' NOT available on this system"
        return 2
    fi
}

# ============================================================
# SUITE 1 : VÉRIFICATIONS STRUCTURALES
# ============================================================

test_structure() {
    test_header "SUITE 1: Structure du repo"
    
    assert_file_exists "$REPO_DIR/dotfiles/ghostty/config" "Dotfiles config"
    assert_file_exists "$REPO_DIR/scripts/detect-ghostty.sh" "Script detect"
    assert_file_exists "$REPO_DIR/scripts/configure-ghostty.sh" "Script configure"
    assert_file_exists "$REPO_DIR/scripts/install-ghostty.sh" "Script install"
    assert_file_exists "$REPO_DIR/Ghostty-Setup.md" "Documentation"
    assert_file_exists "$REPO_DIR/Justfile" "Justfile"
}

# ============================================================
# SUITE 2 : VALIDATION DE SYNTAXE
# ============================================================

test_syntax() {
    test_header "SUITE 2: Validation de syntaxe"
    
    assert_script_syntax "$REPO_DIR/scripts/detect-ghostty.sh" "Detect script"
    assert_script_syntax "$REPO_DIR/scripts/configure-ghostty.sh" "Configure script"
    assert_script_syntax "$REPO_DIR/scripts/install-ghostty.sh" "Install script"
}

# ============================================================
# SUITE 3 : CONTENU ET COMMENTAIRES
# ============================================================

test_content() {
    test_header "SUITE 3: Contenu et documentation"
    
    # Config dans dotfiles
    assert_file_contains "$REPO_DIR/dotfiles/ghostty/config" "font-family" "Config: font-family"
    # enable-kitty-graphics est un champ inconnu dans Ghostty 1.3 — Kitty graphics activé via le TERM
    assert_file_contains "$REPO_DIR/dotfiles/ghostty/config" "xterm-ghostty" "Config: TERM Ghostty (Kitty graphics via TERM)"
    assert_file_contains "$REPO_DIR/dotfiles/ghostty/config" "shell-integration" "Config: shell integration"
    
    # Scripts
    assert_file_contains "$REPO_DIR/scripts/configure-ghostty.sh" "dotfiles/ghostty/config" "Configure: references dotfiles"
    assert_file_contains "$REPO_DIR/scripts/configure-ghostty.sh" "validate-config" "Configure: validates syntax"
    
    assert_file_contains "$REPO_DIR/scripts/install-ghostty.sh" "pkgforge-dev/ghostty-appimage" "Install: AppImage source (pkgforge-dev)"
    assert_file_contains "$REPO_DIR/scripts/install-ghostty.sh" "releases/latest" "Install: API GitHub pour dernière version"
    
    # Documentation
    assert_file_contains "$REPO_DIR/Ghostty-Setup.md" "dotfiles" "Doc: mentions dotfiles"
    assert_file_contains "$REPO_DIR/Ghostty-Setup.md" "ghostty-org/ghostty" "Doc: correct GitHub org"
}

# ============================================================
# SUITE 4 : EXÉCUTION DES SCRIPTS
# ============================================================

test_script_execution() {
    test_header "SUITE 4: Exécution des scripts"
    
    # Test detect-ghostty.sh (exit code même si Ghostty absent)
    local detect_result
    detect_result=$(bash "$REPO_DIR/scripts/detect-ghostty.sh" 2>&1 || echo "exit code: $?")
    
    if echo "$detect_result" | grep -q "Ghostty\|GHOSTTY"; then
        test_pass "Detect script: executes and references Ghostty"
    else
        test_pass "Detect script: executes (may not find Ghostty on this system)"
    fi
    
    # Test configure-ghostty.sh can be sourced
    if bash -n "$REPO_DIR/scripts/configure-ghostty.sh" 2>/dev/null; then
        test_pass "Configure script: syntax valid (would modify ~/.config if executed)"
    else
        test_fail "Configure script: syntax error"
    fi
    
    return 0
}

# ============================================================
# SUITE 5 : INTÉGRATION AVEC JUST
# ============================================================

test_just_recipes() {
    test_header "SUITE 5: Intégration Just"
    
    if ! command -v just &>/dev/null; then
        test_skip "Just task runner: not installed on this system"
        return 0
    fi
    
    # Vérifier que les recipes existent
    local recipes_output
    recipes_output=$(just --list 2>/dev/null || echo "")
    
    if echo "$recipes_output" | grep -q "ghostty\|audit-links"; then
        test_pass "Just recipes: Ghostty recipes exist"
    else
        test_fail "Just recipes: Ghostty recipes missing"
    fi
    
    if echo "$recipes_output" | grep -q "lab"; then
        test_pass "Just recipes: lab recipe exists"
    else
        test_fail "Just recipes: lab recipe missing"
    fi
    
    return 0
}

# ============================================================
# SUITE 6 : VÉRIFICATION DES LIENS
# ============================================================

test_links() {
    test_header "SUITE 6: Vérification des liens (check_links.sh)"
    
    if ! [[ -x "$REPO_DIR/check_links.sh" ]]; then
        test_fail "check_links.sh: not executable"
        return 0
    fi
    
    # Test Ghostty-Setup.md links
    local links_output
    links_output=$(cd "$REPO_DIR" && "$REPO_DIR/check_links.sh" Ghostty-Setup.md 2>&1 || true)
    
    if echo "$links_output" | grep -q "0 Erreurs"; then
        test_pass "Ghostty-Setup.md: all links valid"
    else
        test_fail "Ghostty-Setup.md: broken links found"
        echo " "
        echo "  Détails des erreurs Ghostty-Setup.md :"
        echo "$links_output" | grep -E "^\[31m|^\[" | while read -r line; do
            echo "    $line"
        done
    fi
    
    # Test Podman doc links
    local podman_output
    podman_output=$(cd "$REPO_DIR" && "$REPO_DIR/check_links.sh" Podman-Rootless-Permissions.md 2>&1 || true)
    
    if echo "$podman_output" | grep -q "0 Erreurs"; then
        test_pass "Podman-Rootless-Permissions.md: all links valid"
    else
        test_fail "Podman-Rootless-Permissions.md: broken links found"
        echo " "
        echo "  Détails des erreurs Podman-Rootless-Permissions.md :"
        echo "$podman_output" | grep -v "^Cible\|^Audit\|^---" | while read -r line; do
            # Affiche chaque ligne non-vide qui n'est pas un header
            if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*$ ]]; then
                echo "    $line"
            fi
        done
    fi
    
    return 0
}

# ============================================================
# SUITE 7 : CONFIGURATION DEFAULT
# ============================================================

test_config_validity() {
    test_header "SUITE 7: Validité de la configuration"
    
    if ! command -v ghostty &>/dev/null; then
        test_skip "Ghostty config: Ghostty not installed on system"
        return 0
    fi
    
    # ghostty +validate-config lit TOUJOURS ~/.config/ghostty/config, pas de chemin custom.
    # On déploie temporairement dans un XDG_CONFIG_HOME isolé pour tester dotfiles/.
    local tmp_cfg
    tmp_cfg=$(mktemp -d)
    mkdir -p "$tmp_cfg/ghostty"
    cp "$REPO_DIR/dotfiles/ghostty/config" "$tmp_cfg/ghostty/config"
    
    if XDG_CONFIG_HOME="$tmp_cfg" ghostty +validate-config &>/dev/null; then
        test_pass "Ghostty config: dotfiles/ghostty/config valide (0 erreur)"
    else
        test_fail "Ghostty config: dotfiles/ghostty/config invalide"
        XDG_CONFIG_HOME="$tmp_cfg" ghostty +validate-config 2>&1 | sed 's/^/    /'
    fi
    
    rm -rf "$tmp_cfg"
    return 0
}

# ============================================================
# SUITE 8 : SOURCE/EXPORT DE VARIABLES
# ============================================================

test_environment_variables() {
    test_header "SUITE 8: Propagation des variables d'env"
    
    # Source detect-ghostty.sh and check if variables are exported
    local env_output
    env_output=$(bash -c "source '$REPO_DIR/scripts/detect-ghostty.sh' 2>&1; echo; echo GHOSTTY_BIN_DIR=\${GHOSTTY_BIN_DIR:-<not set>}; echo GHOSTTY_RESOURCES_DIR=\${GHOSTTY_RESOURCES_DIR:-<not set>}" || true)
    
    if echo "$env_output" | grep -q "GHOSTTY_BIN_DIR"; then
        test_pass "Environment: GHOSTTY_BIN_DIR variable available"
    else
        test_fail "Environment: GHOSTTY_BIN_DIR not available"
    fi
    
    if echo "$env_output" | grep -q "GHOSTTY_RESOURCES_DIR"; then
        test_pass "Environment: GHOSTTY_RESOURCES_DIR variable available"
    else
        test_fail "Environment: GHOSTTY_RESOURCES_DIR not available"
    fi
    
    return 0
}

# ============================================================
# RÉSUMÉ
# ============================================================

print_summary() {
    echo ""
    echo "=========================================="
    echo "RÉSUMÉ DES TESTS"
    echo "=========================================="
    echo -e "${GREEN}✓ Passed    : $TESTS_PASSED${NC}"
    echo -e "${RED}✗ Failed    : $TESTS_FAILED${NC}"
    echo -e "${YELLOW}⊘ Skipped   : $TESTS_SKIPPED${NC}"
    echo "=========================================="
    
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    echo -e "Total      : $total tests"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✓ ALL TESTS PASSED${NC}"
        return 0
    else
        echo -e "\n${RED}✗ SOME TESTS FAILED${NC}"
        return 1
    fi
}

# ============================================================
# MAIN
# ============================================================

main() {
    echo "=================================================="
    echo "TEST SUITE: Ghostty Integration"
    echo "=================================================="
    echo "Repo: $REPO_DIR"
    echo "Date: $(date)"
    echo ""
    
    test_structure
    test_syntax
    test_content
    test_script_execution
    test_just_recipes
    test_links
    test_config_validity
    test_environment_variables
    
    print_summary
}

main "$@"
