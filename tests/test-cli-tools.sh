#!/bin/bash
# test-cli-tools.sh
# Suite de tests d'intégration pour les outils CLI modernes
# Exécutable: bash tests/test-cli-tools.sh

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
        test_pass "$desc"
    else
        test_fail "$desc — $file NOT FOUND"
    fi
}

assert_file_contains() {
    local file=$1
    local pattern=$2
    local desc=$3
    if [[ -f "$file" ]] && grep -q "$pattern" "$file" 2>/dev/null; then
        test_pass "$desc"
    else
        test_fail "$desc — pattern '$pattern' NOT found in $file"
    fi
}

assert_command_exists() {
    local cmd=$1
    local desc=$2
    if command -v "$cmd" &>/dev/null; then
        test_pass "$desc — '$cmd' available"
        return 0
    else
        test_fail "$desc — '$cmd' NOT FOUND"
        return 1
    fi
}

assert_command_runs() {
    local desc=$1
    shift
    if "$@" &>/dev/null; then
        test_pass "$desc"
    else
        test_fail "$desc — command failed: $*"
    fi
}

assert_command_output_contains() {
    local desc=$1
    local pattern=$2
    shift 2
    local output
    output=$("$@" 2>&1) || true
    if echo "$output" | grep -qi "$pattern"; then
        test_pass "$desc"
    else
        test_fail "$desc — pattern '$pattern' not found in output"
    fi
}

# ============================================================
# SUITE 1 : STRUCTURE DU REPO (dotfiles & configs)
# ============================================================

test_structure() {
    test_header "SUITE 1: Structure du repo — fichiers de configuration"

    assert_file_exists "$REPO_DIR/dotfiles/shell/aliases.sh" "Shell aliases"
    assert_file_exists "$REPO_DIR/dotfiles/shell/init.sh" "Shell init"
    assert_file_exists "$REPO_DIR/dotfiles/starship/starship.toml" "Starship config"
    assert_file_exists "$REPO_DIR/dotfiles/delta/delta.gitconfig" "Delta gitconfig"
    assert_file_exists "$REPO_DIR/dotfiles/btop/btop.conf" "Btop config"
    assert_file_exists "$REPO_DIR/dotfiles/procs/procs.toml" "Procs config"
    assert_file_exists "$REPO_DIR/dotfiles/glow/glow.yml" "Glow config"
    assert_file_exists "$REPO_DIR/docs/CLI-TOOLS.md" "Documentation CLI tools"
}

# ============================================================
# SUITE 2 : SYNTAXE DES SCRIPTS SHELL
# ============================================================

test_syntax() {
    test_header "SUITE 2: Syntaxe des scripts shell"

    for script in "$REPO_DIR/dotfiles/shell/aliases.sh" "$REPO_DIR/dotfiles/shell/init.sh"; do
        local name
        name=$(basename "$script")
        if bash -n "$script" 2>/dev/null; then
            test_pass "$name — syntax OK"
        else
            test_fail "$name — syntax ERROR"
        fi
    done
}

# ============================================================
# SUITE 3 : CONTENU DES CONFIGURATIONS
# ============================================================

test_config_content() {
    test_header "SUITE 3: Contenu des fichiers de configuration"

    # Starship
    assert_file_contains "$REPO_DIR/dotfiles/starship/starship.toml" \
        "git_branch" "Starship: module git_branch"
    assert_file_contains "$REPO_DIR/dotfiles/starship/starship.toml" \
        "cmd_duration" "Starship: module cmd_duration"
    assert_file_contains "$REPO_DIR/dotfiles/starship/starship.toml" \
        "character" "Starship: module character"

    # Delta
    assert_file_contains "$REPO_DIR/dotfiles/delta/delta.gitconfig" \
        "side-by-side" "Delta: side-by-side enabled"
    assert_file_contains "$REPO_DIR/dotfiles/delta/delta.gitconfig" \
        "line-numbers" "Delta: line-numbers enabled"
    assert_file_contains "$REPO_DIR/dotfiles/delta/delta.gitconfig" \
        "navigate" "Delta: navigate enabled"

    # Btop
    assert_file_contains "$REPO_DIR/dotfiles/btop/btop.conf" \
        "proc_tree" "Btop: proc_tree configured"
    assert_file_contains "$REPO_DIR/dotfiles/btop/btop.conf" \
        "show_temps" "Btop: show_temps configured"

    # Procs
    assert_file_contains "$REPO_DIR/dotfiles/procs/procs.toml" \
        "Cpu" "Procs: CPU column configured"
    assert_file_contains "$REPO_DIR/dotfiles/procs/procs.toml" \
        "TcpPort" "Procs: TcpPort column configured"

    # Glow
    assert_file_contains "$REPO_DIR/dotfiles/glow/glow.yml" \
        "pager" "Glow: pager configured"

    # Aliases
    assert_file_contains "$REPO_DIR/dotfiles/shell/aliases.sh" \
        'alias ll=' "Aliases: ll defined"
    assert_file_contains "$REPO_DIR/dotfiles/shell/aliases.sh" \
        'alias la=' "Aliases: la defined"
    assert_file_contains "$REPO_DIR/dotfiles/shell/aliases.sh" \
        'alias lt=' "Aliases: lt (tree) defined"
    assert_file_contains "$REPO_DIR/dotfiles/shell/aliases.sh" \
        'alias du=' "Aliases: du (dust) defined"
    assert_file_contains "$REPO_DIR/dotfiles/shell/aliases.sh" \
        'alias bench=' "Aliases: bench (hyperfine) defined"
    assert_file_contains "$REPO_DIR/dotfiles/shell/aliases.sh" \
        'alias pst=' "Aliases: pst (procs tree) defined"
    assert_file_contains "$REPO_DIR/dotfiles/shell/aliases.sh" \
        'alias md=' "Aliases: md (glow) defined"

    # Init
    assert_file_contains "$REPO_DIR/dotfiles/shell/init.sh" \
        "zoxide init" "Init: zoxide initialization"
    assert_file_contains "$REPO_DIR/dotfiles/shell/init.sh" \
        "starship init" "Init: starship initialization"
}

# ============================================================
# SUITE 4 : DISPONIBILITÉ DES OUTILS (binaires)
# ============================================================

test_tool_availability() {
    test_header "SUITE 4: Disponibilité des outils CLI"

    assert_command_exists "eza" "eza (ls replacement)"
    assert_command_exists "zoxide" "zoxide (cd replacement)"
    assert_command_exists "starship" "starship (prompt)"
    assert_command_exists "delta" "delta (git diff pager)"
    assert_command_exists "dust" "dust (du replacement)"
    assert_command_exists "btop" "btop (system monitor)"
    assert_command_exists "procs" "procs (ps replacement)"
    assert_command_exists "hyperfine" "hyperfine (benchmarking)"
    assert_command_exists "glow" "glow (markdown renderer)"
}

# ============================================================
# SUITE 5 : TESTS FONCTIONNELS (exécution réelle)
# ============================================================

test_eza_functional() {
    test_header "SUITE 5a: eza — tests fonctionnels"

    if ! command -v eza &>/dev/null; then
        test_skip "eza not available"
        return
    fi

    assert_command_runs "eza: listing courant" eza
    assert_command_runs "eza: listing long" eza -l
    assert_command_runs "eza: listing avec icônes" eza --icons
    assert_command_runs "eza: tree mode" eza --tree --level=1 "$REPO_DIR"
    assert_command_runs "eza: git integration" eza -l --git "$REPO_DIR"
    assert_command_output_contains "eza: affiche les fichiers du repo" "Brewfile" \
        eza "$REPO_DIR"
}

test_zoxide_functional() {
    test_header "SUITE 5b: zoxide — tests fonctionnels"

    if ! command -v zoxide &>/dev/null; then
        test_skip "zoxide not available"
        return
    fi

    assert_command_runs "zoxide: init bash produit du code shell" zoxide init bash

    # Cycle complet : add → query → vérifier que le chemin est retrouvé
    zoxide add /tmp 2>/dev/null
    local query_output
    query_output=$(zoxide query --list 2>&1) || true
    if echo "$query_output" | grep -q "/tmp"; then
        test_pass "zoxide: add + query retrouve /tmp"
    else
        test_fail "zoxide: /tmp non retrouvé après add"
    fi

    # Tester la résolution par fragment (simule le comportement de `z`)
    local resolved
    resolved=$(zoxide query tmp 2>&1) || true
    if [[ "$resolved" == "/tmp" ]]; then
        test_pass "zoxide: query 'tmp' résout vers /tmp"
    else
        test_fail "zoxide: query 'tmp' a retourné '$resolved' au lieu de '/tmp'"
    fi

    # Vérifier que le score est incrémenté
    local score_output
    score_output=$(zoxide query --list --score 2>&1) || true
    if echo "$score_output" | grep -q "/tmp"; then
        test_pass "zoxide: scoring fonctionne (score associé à /tmp)"
    else
        test_fail "zoxide: pas de score pour /tmp"
    fi
}

test_starship_functional() {
    test_header "SUITE 5c: starship — tests fonctionnels"

    if ! command -v starship &>/dev/null; then
        test_skip "starship not available"
        return
    fi

    assert_command_output_contains "starship: version" "starship" \
        starship --version

    # Tester que notre config TOML est parsable par starship
    if [[ -f "$REPO_DIR/dotfiles/starship/starship.toml" ]]; then
        export STARSHIP_CONFIG="$REPO_DIR/dotfiles/starship/starship.toml"

        # Générer un prompt réel — doit produire du texte non vide
        local prompt_output
        prompt_output=$(starship prompt 2>&1) || true
        if [[ -n "$prompt_output" ]]; then
            test_pass "starship: prompt généré avec notre config"
        else
            test_fail "starship: prompt vide avec notre config"
        fi

        # Vérifier que le module character fonctionne (❯ dans la config)
        local module_output
        module_output=$(starship module character 2>&1) || true
        if [[ -n "$module_output" ]]; then
            test_pass "starship: module character produit une sortie"
        else
            test_fail "starship: module character vide"
        fi

        # Tester le module directory
        module_output=$(starship module directory 2>&1) || true
        if [[ -n "$module_output" ]]; then
            test_pass "starship: module directory produit une sortie"
        else
            test_fail "starship: module directory vide"
        fi

        # Vérifier qu'aucune erreur de config n'est émise
        local explain_output
        explain_output=$(starship explain 2>&1) || true
        if ! echo "$explain_output" | grep -qi 'error\|invalid\|unknown'; then
            test_pass "starship: explain ne signale aucune erreur"
        else
            test_fail "starship: explain signale des erreurs de config"
        fi

        unset STARSHIP_CONFIG
    fi
}

test_delta_functional() {
    test_header "SUITE 5d: delta — tests fonctionnels"

    if ! command -v delta &>/dev/null; then
        test_skip "delta not available"
        return
    fi

    assert_command_output_contains "delta: version" "delta" \
        delta --version

    # Tester un diff réel (delta retourne exit code 1 quand les fichiers diffèrent — c'est normal)
    local tmp_a tmp_b
    tmp_a=$(mktemp)
    tmp_b=$(mktemp)
    echo "hello" > "$tmp_a"
    echo "world" > "$tmp_b"
    local diff_output
    diff_output=$(delta "$tmp_a" "$tmp_b" 2>&1) || true
    if [[ -n "$diff_output" ]]; then
        test_pass "delta: diff entre deux fichiers"
    else
        test_fail "delta: diff entre deux fichiers — output vide"
    fi
    rm -f "$tmp_a" "$tmp_b"

    assert_command_runs "delta: list syntax-themes" delta --list-syntax-themes
}

test_dust_functional() {
    test_header "SUITE 5e: dust — tests fonctionnels"

    if ! command -v dust &>/dev/null; then
        test_skip "dust not available"
        return
    fi

    assert_command_runs "dust: version" dust --version
    assert_command_runs "dust: analyse /tmp" dust -n 5 /tmp
    assert_command_runs "dust: profondeur limitée" dust -d 1 "$REPO_DIR"
}

test_btop_functional() {
    test_header "SUITE 5f: btop — tests fonctionnels"

    if ! command -v btop &>/dev/null; then
        test_skip "btop not available"
        return
    fi

    assert_command_output_contains "btop: version" "btop" \
        btop --version

    # Vérifier que la locale UTF-8 est disponible (btop refuse de démarrer sans)
    if locale -a 2>/dev/null | grep -qi 'utf.*8\|utf-8'; then
        test_pass "btop: locale UTF-8 disponible"
    else
        test_fail "btop: locale UTF-8 absente — btop crashera au lancement"
    fi

    # Test réel : btop est un TUI interactif, il ne peut pas tourner dans un `podman run` sans PTY.
    # On vérifie qu'il démarre bien et échoue uniquement à cause du TTY manquant (pas d'erreur de config/locale).
    local btop_output
    btop_output=$(btop --utf-force 2>&1 || true)
    if echo "$btop_output" | grep -qi "No tty detected"; then
        test_pass "btop: démarrage OK (arrêt attendu : pas de TTY en non-interactif)"
    elif echo "$btop_output" | grep -qi "No UTF-8 locale"; then
        test_fail "btop: locale UTF-8 manquante malgré l'installation"
    else
        test_fail "btop: erreur inattendue — $btop_output"
    fi

    # Vérifier que /proc est accessible (btop en a besoin pour les métriques)
    if [[ -d /proc/stat ]] || [[ -f /proc/stat ]]; then
        test_pass "btop: /proc/stat accessible (métriques CPU)"
    else
        test_fail "btop: /proc/stat inaccessible — btop ne pourra pas collecter les métriques"
    fi
}

test_procs_functional() {
    test_header "SUITE 5g: procs — tests fonctionnels"

    if ! command -v procs &>/dev/null; then
        test_skip "procs not available"
        return
    fi

    assert_command_output_contains "procs: version" "procs" \
        procs --version
    assert_command_runs "procs: listing" procs
    assert_command_runs "procs: tree mode" procs --tree
    # Chercher le processus bash (devrait exister puisqu'on est dedans)
    assert_command_runs "procs: recherche 'bash'" procs bash
}

test_hyperfine_functional() {
    test_header "SUITE 5h: hyperfine — tests fonctionnels"

    if ! command -v hyperfine &>/dev/null; then
        test_skip "hyperfine not available"
        return
    fi

    assert_command_output_contains "hyperfine: version" "hyperfine" \
        hyperfine --version

    # Benchmark trivial (echo est instantané)
    assert_command_runs "hyperfine: benchmark 'echo hello'" \
        hyperfine --runs 2 --warmup 0 'echo hello'

    # Export JSON
    local tmp_json
    tmp_json=$(mktemp --suffix=.json)
    assert_command_runs "hyperfine: export JSON" \
        hyperfine --runs 2 --export-json "$tmp_json" 'echo test'
    if [[ -f "$tmp_json" ]] && [[ -s "$tmp_json" ]]; then
        test_pass "hyperfine: JSON output non vide"
    else
        test_fail "hyperfine: JSON output vide ou absent"
    fi
    rm -f "$tmp_json"
}

test_glow_functional() {
    test_header "SUITE 5i: glow — tests fonctionnels"

    if ! command -v glow &>/dev/null; then
        test_skip "glow not available"
        return
    fi

    assert_command_output_contains "glow: version" "glow" \
        glow --version

    # Rendre le README du repo
    if [[ -f "$REPO_DIR/README.md" ]]; then
        assert_command_runs "glow: rendu README.md" \
            glow "$REPO_DIR/README.md"
    fi

    # Rendre du markdown depuis stdin
    local output
    output=$(echo "# Hello **world**" | glow - 2>&1) || true
    if [[ -n "$output" ]]; then
        test_pass "glow: rendu stdin markdown"
    else
        test_fail "glow: rendu stdin vide"
    fi
}

# ============================================================
# SUITE 6 : BREWFILE COHÉRENCE
# ============================================================

test_brewfile() {
    test_header "SUITE 6: Cohérence du Brewfile"

    local brewfile="$REPO_DIR/Brewfile"
    assert_file_exists "$brewfile" "Brewfile exists"

    for tool in eza zoxide starship git-delta dust btop procs hyperfine glow; do
        assert_file_contains "$brewfile" "\"$tool\"" "Brewfile: $tool déclaré"
    done
}

# ============================================================
# EXÉCUTION
# ============================================================

main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Tests d'intégration — Outils CLI Modernes          ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

    test_structure
    test_syntax
    test_config_content
    test_tool_availability
    test_eza_functional
    test_zoxide_functional
    test_starship_functional
    test_delta_functional
    test_dust_functional
    test_btop_functional
    test_procs_functional
    test_hyperfine_functional
    test_glow_functional
    test_brewfile

    # Bilan
    echo -e "\n${BLUE}════════════════════════════════════════════════════════${NC}"
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    echo -e "  Total: ${total} tests"
    echo -e "  ${GREEN}✓ Passed: ${TESTS_PASSED}${NC}"
    [[ $TESTS_FAILED -gt 0 ]] && echo -e "  ${RED}✗ Failed: ${TESTS_FAILED}${NC}"
    [[ $TESTS_SKIPPED -gt 0 ]] && echo -e "  ${YELLOW}⊘ Skipped: ${TESTS_SKIPPED}${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "\n${RED}ÉCHEC : ${TESTS_FAILED} test(s) en erreur.${NC}"
        exit 1
    else
        echo -e "\n${GREEN}SUCCÈS : Tous les tests passent.${NC}"
        exit 0
    fi
}

main "$@"
