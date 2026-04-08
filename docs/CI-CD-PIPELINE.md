# CI/CD Pipeline Documentation

## Overview

The `labo-ignition` repository uses GitHub Actions to automate quality checks and container image publishing. The CI/CD pipeline consists of two workflows:

1. **CI** — Validates code quality, shell script compliance, documentation integrity, and Dockerfile linting
2. **Docker** — Builds and publishes container images to GitHub Container Registry (GHCR)

Both workflows are triggered on:
- **Push** to `master` or `main` branches
- **Pull Requests** against any branch
- Manual dispatch via GitHub UI

## Workflow: CI

**Purpose:** Ensure all source code changes meet quality standards before merging to master.

**Trigger Conditions:**
- Any push to `master` or `main`
- Any pull request creation/update
- Manual workflow dispatch

**Jobs:**

### 1. Shell And Integration Tests (20 min timeout)
**What it does:**
- Installs `shellcheck` on Ubuntu runner
- Validates all shell scripts in the repository:
  - `check_links.sh`, `test_infra.sh`
  - All files in `scripts/` and `tests/` directories
- Executes the Ghostty integration test suite (`tests/test-ghostty-integration.sh`)

**Interpreting Results:**
- ✅ **PASS**: All shell scripts conform to best practices, and integration tests pass (27 test cases)
- ❌ **FAIL**: Either shellcheck found violations (syntax/style issues) OR integration tests failed
  - Check the "Lint shell scripts" step for shellcheck errors
  - Check the "Run Ghostty integration suite" step for test failures (look for line-by-line assertion output)

**Common Issues:**
- `shellcheck` violations: undefined variables, unquoted variables, improper quoting patterns
  - **Fix:** Run `shellcheck <script>` locally to identify violations, see [Shellcheck docs](https://www.shellcheck.net/wiki/)
- Integration test failures: 
  - Usually indicates Ghostty binary is misconfigured or dependencies are missing
  - Check test output for specific assertion failures

---

### 2. Documentation Quality (20 min timeout)
**What it does:**
- Validates all Markdown files in repository root and subdirectories (`.md` files up to 2 levels deep)
- Checks for broken links, invalid references, and malformed URLs

**Interpreting Results:**
- ✅ **PASS**: All links in documentation are valid and reachable
- ❌ **FAIL**: Documentation has broken links or invalid references
  - Check the step output for exact filenames and line numbers
  - Fix broken links in the identified files
  - For external links: verify they still exist online

**Common Issues:**
- Relative path links pointing to deleted files
- Typos in file paths (e.g., `Dockerfile` vs `dockerfile`)
- External URLs that have changed or moved

---

### 3. Dockerfile Lint (10 min timeout)
**What it does:**
- Runs `hadolint` (a Dockerfile static analysis tool) via image `hadolint/hadolint:latest`
- Validates Dockerfile compliance against best practices
- Uses repository's `.hadolint.yaml` policy configuration

**Interpreting Results:**
- ✅ **PASS**: Dockerfile follows best practices; no violations detected
- ❌ **FAIL**: Dockerfile has linting violations
  - Check step output for specific error codes (e.g., `DL3008`, `SC2016`)
  - Visit [hadolint GitHub wiki](https://github.com/hadolint/hadolint/wiki) for error explanations

**Policy:**
The `.hadolint.yaml` file ignores these non-actionable rules:
- `DL3008`: Version pinning policies not enforced (image layers managed via CI context)
- `DL3015`: `--no-install-recommends` conflicts with this repository's build philosophy
- `DL3046`: UID handling appropriate for user namespace mapping and Podman

**Common Issues:**
- `SC2016`: Dollar expressions in single quotes (intended for literal shell fragments — use `# hadolint ignore=SC2016`)
- `DL4006`: Missing `SHELL` directive with `pipefail` (added at Dockerfile top: `SHELL ["/bin/bash", "-o", "pipefail", "-c"]`)

---

## Workflow: Docker

**Purpose:** Build container images and publish to GitHub Container Registry (GHCR) on successful CI checks.

**Trigger Conditions:**
- **Push** to `master` or `main` branches AND modified files include: `Dockerfile`, `Justfile`, `test_infra.sh`, `scripts/`, `dotfiles/`, or `.github/workflows/docker.yml`
- **Pull Requests** with changes to same paths
- Manual workflow dispatch

**Jobs:**

### 1. Build Container Image (30 min timeout)
**What it does:**
- Sets up Docker Buildx multi-platform builder
- Builds container image from `Dockerfile` with arguments: `USER_ID=1000`, `USER_NAME=github`
- **Does NOT push** — smoke test only
- Caches build layers in GitHub Actions cache

**Interpreting Results:**
- ✅ **PASS**: Dockerfile builds successfully; no compilation errors
- ❌ **FAIL**: Dockerfile has runtime errors (invalid commands, missing dependencies)
  - Check build output for specific errors (usually near the failing `RUN` step)
  - Verify dependencies are installed before use
  - Check for typos in commands

---

### 2. Publish To GHCR (30 min timeout)
**Conditions:**
- Only runs on successful **push** to `master` or `main` (not on PRs)
- Requires successful completion of "Build Container Image" job

**What it does:**
- Authenticates to GHCR using GitHub-provided `GITHUB_TOKEN`
- Extracts Docker metadata (repository name, tags)
- Builds image with tags:
  - `latest` — always points to most recent master commit
  - `<short-sha>` — commit hash (short form)
- Pushes built image to `ghcr.io/yoyonel/labo-ignition:<tag>`

**Interpreting Results:**
- ✅ **PASS**: Image pushed to GHCR; available at `ghcr.io/yoyonel/labo-ignition:latest`
- ❌ **FAIL**: Either build failed or authentication/push failed
  - Build failures: see "Build Container Image" output
  - Authentication: `GITHUB_TOKEN` may be misconfigured (unlikely if other pushes work)
  - Push failures: GHCR registry may be temporarily unavailable

**Using Published Images:**
La méthode recommandée pour utiliser ces images tout en conservant tes permissions utilisateur (`UID/GID`) et ton `$HOME` est d'utiliser les recettes `just` :

```bash
# Utilisation optimisée (Recommandé - Zéro build local)
just lab-remote

# Ou manuellement via Podman
podman pull ghcr.io/yoyonel/labo-ignition:latest
podman run -it ghcr.io/yoyonel/labo-ignition:latest bash
```

**Avantage :** L'utilisation de `just lab-remote` permet d'économiser environ 15 à 20 minutes de build CPU (notamment la compilation de `ripdrag` et le téléchargement des outils CLI modernes).

---

## Monitoring & Debugging

### View CI/CD Status in Web UI

**Via GitHub UI:**
1. Navigate to repository: https://github.com/yoyonel/labo-ignition
2. Click **Actions** tab
3. Select workflow ("CI" or "Docker")
4. Click run to see detailed job and step logs

**For failed runs:**
- Click job name to expand
- Click step that failed
- Scroll to see full error output and context

---

### View via GitHub CLI

```bash
# List recent workflow runs
gh run list --branch master --limit 10

# View specific run details (with specific run ID)
gh run view <RUN_ID> --json

# Watch a specific run in real-time
gh run watch <RUN_ID>

# Check PR status for a PR
gh pr checks <PR_NUMBER>
```

---

### Local Validation (Before Push)

Preferred local entrypoint:

```bash
just ci-local
```

This recipe replays the CI prerequisites locally before push. For manual debugging, the equivalent commands are:

```bash
# Check shell scripts
shellcheck check_links.sh test_infra.sh scripts/*.sh tests/*.sh

# Run integration tests
bash tests/test-ghostty-integration.sh

# Check documentation links
./check_links.sh <markdown-file>

# Lint Dockerfile locally
podman run --rm -i -v "$PWD:/work:Z" -w /work docker.io/hadolint/hadolint hadolint Dockerfile

# Build container image locally
podman build --build-arg USER_ID=$(id -u) --build-arg USER_NAME=$(whoami) -t labo-test .
```

To enforce this automatically before each push:

```bash
pre-commit install
pre-commit install --hook-type pre-push
```

Or with the repository helper:

```bash
just install-hooks
```

---

## Branch Protection Rules

The `master` branch is protected to require:
- ✅ CI workflow passing (all 3 jobs: shell tests, documentation, Dockerfile lint)
- ✅ Docker workflow passing (build and publish jobs)
- These checks must **pass before** any PR can be merged
- Enforces code quality and prevents broken images from being published to GHCR

---

## Concurrency & Cancellation

Both workflows use GitHub Actions concurrency to avoid redundant execution:

```yaml
concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

**Behavior:**
- If a new push occurs on the same branch while a workflow is running, the previous run is **cancelled**
- Prevents resource waste when rapid commits happen (e.g., fixing linter errors)
- Ensures latest commit is always validated

---

## Security & Permissions

**CI Workflow Permissions:**
- `contents: read` — Can read repository contents (checkout, files)

**Docker Workflow Permissions:**
- `contents: read` — Can read repository contents
- `packages: write` — Can write container images to GHCR (required for publishing)

Workflows do **not** have permission to modify repository code or create commits.

---

## Troubleshooting Guide

| Symptom | Likely Cause | Solution |
|---------|-------------|----------|
| "Shell And Integration Tests" fails with shellcheck error | Shell script syntax issue | Run `shellcheck <script>` locally, fix and re-push |
| "Documentation Quality" fails | Broken link in `.md` file | Fix path in link or remove if external URL changed |
| "Dockerfile Lint" fails | Dockerfile linting violation | Check `hadolint` output, fix issue, or add `# hadolint ignore=<CODE>` if intentional |
| "Build Container Image" fails | Dockerfile compilation error | Check Docker build output; verify `RUN` commands are valid |
| "Publish To GHCR" fails but build passed | Registry authentication issue | Verify `GITHUB_TOKEN` has `packages: write` scope (usually automatic) |
| Workflow doesn't trigger on PR | Paths filter excludes change | Docker workflow only runs if specific files changed; CI always runs |

---

## Architecture Decisions

### Why Separate CI and Docker Workflows?
- **CI** runs on every commit and PR — catches issues early
- **Docker** only publishes from `master`/`main` after CI passes — prevents broken images from being public

### Why Concurrency with Cancel?
- Prevents resource waste when fixing linter errors (commit → fail → fix → commit again)
- Latest commit always validated

### Why Ignore DL3008, DL3015, DL3046?
- See `.hadolint.yaml` — these rules conflict with development environment philosophy
- Explicitly ignored to keep CI green and avoid noisy false-positives

---

## Next Steps

- Monitor workflow runs after each push via GitHub UI or `gh run list`
- If designing new features with environment changes, test Dockerfile locally first
- For substantial changes, run full local validation suite before pushing
