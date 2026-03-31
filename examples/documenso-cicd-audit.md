# CI/CD Security Audit: Documenso

**Target:** Documenso (open-source document signing platform)
**Repository:** `c:\Projects\ai-sec\examples\documenso\`
**Audit Date:** 2026-03-28
**Auditor:** AI-Sec CI/CD Auditor
**Scope:** GitHub Actions workflows, Dockerfiles, docker-compose configurations, dependency management, secret handling, deployment pipelines

---

## Executive Summary

Documenso has a moderately mature CI/CD setup with 15 GitHub Actions workflows covering CI, deployment, Docker publishing, E2E testing, CodeQL analysis, translations, and repository automation. The project uses a monorepo architecture (npm workspaces + Turborepo) with multi-stage Docker builds and publishes to both DockerHub and GitHub Container Registry.

**Overall Risk Rating: MEDIUM-HIGH**

Key concerns include hardcoded default encryption keys in Dockerfiles and example configs that can propagate to production, overly broad `pull_request_target` triggers exposing secrets to fork PRs, lack of CODEOWNERS enforcement, missing artifact signing, and disabled Dependabot PR limits that effectively disable automated dependency updates.

---

## OWASP CI/CD Top 10 Compliance Matrix

| # | Risk | Rating | Status | Summary |
|---|------|--------|--------|---------|
| CICD-SEC-1 | Insufficient Flow Control Mechanisms | **HIGH** | FAIL | No CODEOWNERS file, `deploy.yml` triggers on any tag push, no required approvals evident in workflow configs |
| CICD-SEC-2 | Inadequate Identity and Access Management | **MEDIUM** | PARTIAL | Uses `GH_TOKEN` (PAT) alongside `GITHUB_TOKEN`, PAT with `repo` scope used for translations, no evidence of fine-grained tokens |
| CICD-SEC-3 | Dependency Chain Abuse | **MEDIUM** | PARTIAL | Dependabot configured but `open-pull-requests-limit: 0` disables it, `npm ci` used but lockfile not integrity-verified in all paths |
| CICD-SEC-4 | Poisoned Pipeline Execution (PPE) | **HIGH** | FAIL | `pull_request_target` in `pr-labeler.yml` and `semantic-pull-requests.yml` runs code from fork PRs with write permissions |
| CICD-SEC-5 | Insufficient PBAC (Pipeline-Based Access Controls) | **MEDIUM** | PARTIAL | Some workflows declare minimal permissions, but several lack explicit permissions blocks |
| CICD-SEC-6 | Insufficient Credential Hygiene | **HIGH** | FAIL | Hardcoded encryption keys (`CAFEBABE`, `DEADBEEF`) in Dockerfile build args and `.env.example`, telemetry secrets baked into Docker images |
| CICD-SEC-7 | Insecure System Configuration | **MEDIUM** | PARTIAL | Docker runner uses non-root user, but `legacy-peer-deps=true` in `.npmrc` weakens dependency resolution |
| CICD-SEC-8 | Ungoverned Usage of 3rd Party Services | **MEDIUM** | PARTIAL | Crowdin integration, Warp CI runners, Turborepo remote cache -- external services with secrets but no audit trail |
| CICD-SEC-9 | Improper Artifact Integrity Validation | **HIGH** | FAIL | No Docker image signing (cosign/notary), no SBOM generation, no provenance attestation on published images |
| CICD-SEC-10 | Insufficient Logging and Visibility | **LOW** | PARTIAL | Standard GitHub Actions logging, but no explicit audit logging for deployment events or secret access |

---

## Detailed Findings

### CRITICAL

#### C1. Hardcoded Encryption Keys in Docker Build Arguments
**File:** `docker/Dockerfile` (lines 47-51)
```dockerfile
ARG NEXT_PRIVATE_ENCRYPTION_KEY="CAFEBABE"
ENV NEXT_PRIVATE_ENCRYPTION_KEY="$NEXT_PRIVATE_ENCRYPTION_KEY"
ARG NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY="DEADBEEF"
ENV NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY="$NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY"
```
**Risk:** These default values are well-known placeholders. If operators deploy without overriding them, all encryption is performed with publicly known keys. The `ARG` defaults mean even `docker build` without `--build-arg` will bake these into the image layer. The installer stage uses these at build time, meaning they may be embedded in build artifacts.
**Recommendation:** Remove default values from `ARG` directives. Fail the build if these are not provided. Add a runtime startup check that refuses to start with known-bad keys.

#### C2. Telemetry Secrets Baked Into Published Docker Images
**File:** `docker/Dockerfile` (lines 53-58), `.github/workflows/publish.yml` (lines 46-48)
```dockerfile
ARG NEXT_PRIVATE_TELEMETRY_KEY=""
ENV NEXT_PRIVATE_TELEMETRY_KEY="$NEXT_PRIVATE_TELEMETRY_KEY"
```
The `publish.yml` workflow passes actual telemetry secrets as build args:
```yaml
NEXT_PRIVATE_TELEMETRY_KEY: ${{ secrets.NEXT_PRIVATE_TELEMETRY_KEY }}
```
**Risk:** Docker build args are stored in image history/layers. Anyone who pulls the published image can extract these telemetry credentials via `docker history` or `docker inspect`. This is a secret leakage vector.
**Recommendation:** Use Docker secrets or multi-stage builds that do not persist ARG values. Alternatively, inject these at runtime only, never at build time.

#### C3. Poisoned Pipeline Execution via `pull_request_target`
**Files:** `.github/workflows/pr-labeler.yml`, `.github/workflows/semantic-pull-requests.yml`
Both workflows trigger on `pull_request_target`, which runs in the context of the base repository with access to secrets. The `semantic-pull-requests.yml` workflow executes shell commands that interpolate data from the pull request:
```yaml
CREATOR=$(curl -s "https://api.github.com/repos/${{ github.repository }}/pulls/${{ github.event.pull_request.number }}" | jq -r '.user.login')
```
While the current code does not directly checkout fork code, the `pull_request_target` trigger with `pull-requests: write` permission is a known attack surface. A malicious PR title or body could potentially inject commands via the `${{ steps.lint_pr_title.outputs.error_message }}` interpolation in the sticky comment step.
**Recommendation:** Audit all `pull_request_target` workflows for script injection. Use intermediate environment variables instead of direct `${{ }}` interpolation in `run:` blocks. Consider switching to `pull_request` trigger where possible.

---

### HIGH

#### H1. Deploy Workflow Triggers on Any Tag with No Gate
**File:** `.github/workflows/deploy.yml`
```yaml
on:
  push:
    tags:
      - '*'
```
Any tag push (including from compromised accounts or accidental pushes) triggers a production deployment by merging `main` into the `release` branch. There is no approval gate, no CI check requirement, and no tag signing verification.
**Recommendation:** Restrict tag patterns (e.g., `v*`), require tag signing, add a GitHub Environment with required reviewers for production deployments.

#### H2. PAT Token with Broad `repo` Scope
**Files:** `.github/workflows/translations-pull.yml` (line 49), `.github/workflows/translations-force-pull.yml` (line 45)
```yaml
GITHUB_TOKEN: ${{ secrets.GH_PAT }}
```
The comment explicitly states: "A classic GitHub Personal Access Token with the 'repo' scope selected." Classic PATs with `repo` scope grant full access to all repositories the user can access, not just this one. This is also used alongside `secrets.GH_TOKEN` in other workflows.
**Recommendation:** Migrate to fine-grained personal access tokens scoped to only the necessary repository and permissions. Document which secrets require which scopes.

#### H3. No CODEOWNERS File
**Finding:** No `CODEOWNERS` file exists anywhere in the repository.
**Risk:** Without CODEOWNERS, there is no enforced code review requirement for sensitive paths like `.github/workflows/`, `docker/`, or deployment configurations. Any contributor with merge access can modify CI/CD pipelines without mandatory review from security-aware maintainers.
**Recommendation:** Create a `CODEOWNERS` file requiring review from core maintainers for `.github/`, `docker/`, deployment configs, and `package.json`/lockfiles.

#### H4. No Docker Image Signing or Provenance
**File:** `.github/workflows/publish.yml`
Images are pushed to DockerHub and GHCR without any signing (cosign), SBOM generation, or SLSA provenance attestation.
**Risk:** Consumers of the Docker images cannot verify their integrity or authenticity. Supply chain attacks could replace images without detection.
**Recommendation:** Add cosign signing in the publish workflow. Generate and attach SBOMs (e.g., via `docker buildx build --sbom`). Add SLSA provenance via `actions/attest-build-provenance`.

#### H5. Dependabot Effectively Disabled
**File:** `.github/dependabot.yml`
```yaml
open-pull-requests-limit: 0
```
Both the `github-actions` and `npm` ecosystems have their PR limit set to 0, meaning Dependabot will never open pull requests for vulnerable dependencies.
**Risk:** Known vulnerabilities in dependencies will not be surfaced automatically. The project relies entirely on manual dependency updates.
**Recommendation:** Set a reasonable limit (e.g., 5-10) or use `security-updates-only` mode. At minimum, enable security updates even if version updates are disabled. Also add entries for the `docker` ecosystem and other workspace packages beyond `apps/web`.

---

### MEDIUM

#### M1. Missing Permissions Blocks on Multiple Workflows
**Files:** `ci.yml`, `deploy.yml`, `publish.yml`, `e2e-tests.yml`
These workflows do not declare top-level `permissions:` blocks, meaning they inherit the default repository token permissions (which may be overly broad).
**Recommendation:** Add explicit `permissions:` blocks with minimum required permissions to every workflow. Set repository default token permissions to read-only.

#### M2. Turbo Remote Cache Token in E2E Tests
**File:** `.github/workflows/e2e-tests.yml` (lines 53-54)
```yaml
TURBO_TOKEN: ${{ secrets.TURBO_TOKEN }}
TURBO_TEAM: ${{ vars.TURBO_TEAM }}
```
The Turbo remote cache token is exposed to E2E test runs which also process fork PRs (the workflow triggers on `pull_request`). While GitHub Actions restricts secrets on fork PRs by default, if the repo allows secret access for fork PRs (a repository setting), this could leak.
**Recommendation:** Verify that "Send secrets to workflows from fork pull requests" is disabled in repository settings.

#### M3. Third-Party Actions Without Hash Pinning
Multiple workflows use third-party actions pinned to version tags rather than commit SHAs:
- `actions/first-interaction@v1`
- `actions/stale@v5`
- `actions/labeler@v4`
- `crowdin/github-action@v2`
- `amannn/action-semantic-pull-request@v5`
- `marocchino/sticky-pull-request-comment@v2`
- `actions/github-script@v5` / `@v6`

**Risk:** Tag-based pinning is vulnerable to tag mutation attacks. A compromised upstream action could be re-tagged to inject malicious code.
**Recommendation:** Pin all third-party actions to full commit SHAs. Use Dependabot or Renovate to manage updates.

#### M4. Development Docker Compose Uses Hardcoded Weak Passwords
**File:** `docker/development/compose.yml`
```yaml
POSTGRES_PASSWORD: password
MINIO_ROOT_PASSWORD: password
```
**File:** `docker/testing/compose.yml`
```yaml
NEXTAUTH_SECRET=secret
NEXT_PRIVATE_ENCRYPTION_KEY=CAFEBABE
```
**Risk:** While these are intended for local development, developers may accidentally use these configurations in staging or production. The testing compose also hardcodes secrets that could be committed to derived projects.
**Recommendation:** Use `.env` files for development credentials. Add warnings in compose files. Never use the same patterns as defaults in production Dockerfiles.

#### M5. `.npmrc` Enables `legacy-peer-deps`
**File:** `.npmrc`
```
legacy-peer-deps = true
```
**Risk:** This flag disables peer dependency conflict checking, which means npm will install packages even when their peer dependency requirements conflict. This can lead to unexpected behavior and potentially exploitable version mismatches.
**Recommendation:** Resolve peer dependency conflicts properly rather than bypassing the check.

#### M6. Remix Dockerfiles Run as Root
**Files:** `apps/remix/Dockerfile`, `apps/remix/Dockerfile.bun`, `apps/remix/Dockerfile.pnpm`
The alternative Remix Dockerfiles (not the main `docker/Dockerfile`) do not create a non-root user. The final stage runs as root.
**Risk:** Container escape vulnerabilities are more severe when running as root.
**Recommendation:** Add non-root user creation to all Dockerfiles, matching the pattern in `docker/Dockerfile`.

---

### LOW

#### L1. Deprecated `set-output` Syntax
**File:** `.github/workflows/semantic-pull-requests.yml` (lines 25, 35)
```yaml
echo "::set-output name=is_new::true"
```
**Risk:** The `set-output` command is deprecated and will eventually be removed. It is also potentially vulnerable to log injection if user-controlled data is interpolated.
**Recommendation:** Migrate to `echo "name=value" >> $GITHUB_OUTPUT`.

#### L2. Force Push in Translation Workflow
**File:** `.github/workflows/translations-upload.yml` (line 59)
```yaml
git push origin "$BRANCH" --force
```
**Risk:** Force pushing can destroy commit history on the target branch. While this is a dedicated automation branch, the pattern should be documented and restricted.
**Recommendation:** Acceptable for automation branches, but add branch protection rules to prevent force pushes to `main` and `release`.

#### L3. CodeQL Runs After Build (Suboptimal)
**File:** `.github/workflows/codeql-analysis.yml`
CodeQL initialization happens after the build step, which means it only analyzes the built output rather than performing both source and build analysis.
**Recommendation:** Move `github/codeql-action/init@v3` before the build step to enable autobuild tracing for more comprehensive analysis.

#### L4. No Workflow Concurrency Protection on Deploy
**File:** `.github/workflows/deploy.yml`
The deploy workflow has no `concurrency:` block, meaning multiple tag pushes could trigger parallel deployments to production.
**Recommendation:** Add a concurrency group for the deploy workflow to prevent race conditions.

---

## Dependency Management Assessment

| Aspect | Status | Notes |
|--------|--------|-------|
| Lockfile present | YES | `package-lock.json` (37,726 lines) |
| Lockfile committed | YES | Tracked in git |
| `npm ci` used in CI | YES | In `node-install` composite action |
| `--no-audit` flag | YES | `npm ci --no-audit` skips vulnerability check during install |
| Dependabot configured | DISABLED | `open-pull-requests-limit: 0` on both ecosystems |
| Dependabot for Docker | NO | No `docker` ecosystem entry |
| Dependency pinning | PARTIAL | Some exact versions, many use `^` ranges |
| npm overrides | YES | `lodash`, `pdfjs-dist`, `typescript`, `zod` pinned via overrides |

---

## Docker Security Assessment

| Aspect | Main Dockerfile | Remix Dockerfiles |
|--------|----------------|-------------------|
| Multi-stage build | YES (4 stages) | YES (3-4 stages) |
| Non-root user | YES (`nodejs:1001`) | NO (runs as root) |
| `.dockerignore` | NOT FOUND | NOT FOUND |
| Base image pinned | PARTIAL (`node:22-alpine3.22`) | PARTIAL (`node:20-alpine`) |
| Secrets in build args | YES (encryption keys, telemetry) | NO |
| `npm ci` for reproducibility | YES | YES |
| Health check defined | NO (in Dockerfile) | NO |
| Image scanning | NO | NO |
| Image signing | NO | NO |

---

## Secret Inventory

| Secret | Used In | Risk Notes |
|--------|---------|------------|
| `GH_TOKEN` | deploy.yml, publish.yml | PAT, likely `repo` scope |
| `GH_PAT` | translations-pull.yml, translations-force-pull.yml | Classic PAT, `repo` scope (documented in comments) |
| `GITHUB_TOKEN` | Multiple workflows | Default token, acceptable |
| `DOCKERHUB_USERNAME` | publish.yml | Registry credential |
| `DOCKERHUB_TOKEN` | publish.yml | Registry credential |
| `TURBO_TOKEN` | e2e-tests.yml | Remote cache access |
| `NEXT_PRIVATE_TELEMETRY_KEY` | publish.yml | Baked into Docker image (leaks) |
| `NEXT_PRIVATE_TELEMETRY_HOST` | publish.yml | Baked into Docker image (leaks) |
| `CROWDIN_PROJECT_ID` | translations workflows | Third-party service |
| `CROWDIN_PERSONAL_TOKEN` | translations workflows | Third-party service |

---

## Recommendations Summary (Priority Order)

1. **CRITICAL:** Remove default encryption key values from Dockerfile `ARG` directives; fail builds without explicit keys
2. **CRITICAL:** Stop baking telemetry secrets into Docker images via build args; inject at runtime only
3. **CRITICAL:** Audit `pull_request_target` workflows for script injection; use environment variables for all PR metadata interpolation
4. **HIGH:** Add required reviewers via GitHub Environments for deploy/publish workflows
5. **HIGH:** Create `CODEOWNERS` with mandatory review for `.github/`, `docker/`, and security-sensitive paths
6. **HIGH:** Enable Dependabot security updates (set `open-pull-requests-limit` to at least 5)
7. **HIGH:** Implement Docker image signing with cosign and SLSA provenance attestation
8. **HIGH:** Migrate from classic PATs (`GH_PAT`, `GH_TOKEN`) to fine-grained tokens
9. **MEDIUM:** Pin all third-party GitHub Actions to commit SHAs
10. **MEDIUM:** Add explicit `permissions:` blocks to all workflows; set repo default to read-only
11. **MEDIUM:** Add non-root users to all Remix Dockerfiles
12. **MEDIUM:** Create a `.dockerignore` to prevent `.env`, `.git`, and `node_modules` from being included in build context
13. **LOW:** Fix deprecated `set-output` syntax
14. **LOW:** Add concurrency controls to deploy workflow
15. **LOW:** Reorder CodeQL init before build step

---

## Methodology

This audit examined all files in `.github/workflows/`, `.github/actions/`, `docker/`, `apps/remix/Dockerfile*`, `package.json`, `package-lock.json` (metadata), `.npmrc`, `.gitignore`, `.env.example`, `turbo.json`, `render.yaml`, and `railway.toml`. Analysis was performed against the OWASP CI/CD Security Top 10 (2023) framework. No dynamic testing or runtime analysis was performed.

---

*Report generated by AI-Sec CI/CD Auditor*
