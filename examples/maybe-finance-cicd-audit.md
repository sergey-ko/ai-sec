# CI/CD Security Audit Report: maybe-finance

**Target:** maybe-finance (Maybe — personal finance OS)
**Date:** 2026-03-28
**Methodology:** OWASP CI/CD Top 10
**Auditor:** AI-Sec CI/CD Auditor

---

## Executive Summary

Maybe-finance has a **reasonably structured CI/CD pipeline** with clear separation between CI testing and Docker image publishing. However, the audit identified **6 FAIL** findings across the OWASP CI/CD Top 10, primarily around action pinning (supply chain risk), missing workflow-level permissions, credential exposure in compose files, and absent artifact integrity controls. The pipeline's overall security posture is **moderate** — foundational hygiene is present but critical hardening gaps remain.

**Compliance: 4 PASS / 6 FAIL (40% pass rate)**

---

## Phase 1: CI/CD Attack Surface Map

### Workflow Inventory

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| CI | `.github/workflows/ci.yml` | `workflow_call` (reusable) | Brakeman scan, importmap audit, rubocop lint, biome lint, full test suite |
| Pull Request | `.github/workflows/pr.yml` | `pull_request` | Calls CI workflow |
| Publish Docker | `.github/workflows/publish.yml` | `push` to `main`, `push` tags `v*`, `workflow_dispatch` | CI + Docker build + push to GHCR |

### Pipeline Flow

```
PR opened
  └─ pr.yml (pull_request trigger)
       └─ ci.yml (workflow_call)
            ├─ scan_ruby (Brakeman)
            ├─ scan_js (importmap audit)
            ├─ lint (rubocop)
            ├─ lint_js (biome)
            └─ test (Postgres + Redis services, unit/integration/system tests)

Push to main / tag v*
  └─ publish.yml
       ├─ ci.yml (workflow_call) — gate
       └─ build (needs: ci)
            ├─ Checkout (with ref input)
            ├─ QEMU + Buildx setup
            ├─ GHCR login (GITHUB_TOKEN)
            ├─ Metadata extraction
            └─ Docker build + push (multi-arch amd64/arm64)
```

### Build Artifacts
- Docker images pushed to `ghcr.io/maybe-finance/maybe`
- Tags: `sha-<commit>`, `<semver>`, `latest` (main), `stable` (tags)
- Test failure screenshots uploaded as GitHub artifacts

### Infrastructure
- Dockerfile: multi-stage Ruby build, runs as non-root user (UID 1000)
- Docker Compose (example): Postgres 16, Redis latest, Rails app + Sidekiq worker
- Dependabot: configured for `bundler` and `github-actions` (weekly)

---

## Phase 2: OWASP CI/CD Top 10 Assessment

### CICD-SEC-1: Insufficient Flow Control Mechanisms — PASS

**Assessment:** The publish workflow gates Docker builds behind CI completion (`needs: [ci]`). The PR workflow triggers CI on all pull requests. Branch protection rules are a repository-level setting (not auditable from workflow files alone), but the pipeline structure enforces CI-before-publish.

**Evidence:**
- `publish.yml` line 30: `needs: [ ci ]` — build cannot proceed without CI passing
- `pr.yml` triggers CI on every PR via `workflow_call`
- CI includes security scanning (Brakeman, importmap audit) as required gates

**Note:** Branch protection rules (required reviews, status checks) must be verified in GitHub repository settings. The workflow structure supports enforcement but does not guarantee it alone.

---

### CICD-SEC-2: Inadequate Identity and Access Management — PARTIAL FAIL

**Assessment:** The `publish.yml` workflow defines explicit `permissions` blocks (good), but `ci.yml` and `pr.yml` have **no `permissions` block**, inheriting the repository default (often broad `write` across all scopes).

**Evidence:**

`publish.yml` lines 21-22 — workflow-level permissions (GOOD):
```yaml
permissions:
  contents: read
```

`publish.yml` lines 37-38 — job-level permissions (GOOD):
```yaml
permissions:
  contents: read
  packages: write
```

`ci.yml` — **NO permissions block** (FAIL):
```yaml
name: CI
on:
  workflow_call:
jobs:
  scan_ruby:
    runs-on: ubuntu-latest
    # No permissions defined — inherits caller's permissions
```

`pr.yml` — **NO permissions block** (FAIL):
```yaml
name: Pull Request
on:
  pull_request:
jobs:
  ci:
    uses: ./.github/workflows/ci.yml
    # No permissions restriction
```

**Risk:** CI jobs (Brakeman, tests) run with more permissions than needed. A compromised action or malicious PR could exploit excess permissions.

**Recommendation:** Add `permissions: contents: read` to both `ci.yml` and `pr.yml` workflow level.

---

### CICD-SEC-3: Dependency Chain Abuse — FAIL

**Assessment:** GitHub Actions are pinned to **major version tags** (e.g., `@v4`, `@v3`), not SHA digests. This is a significant supply chain risk — a compromised action maintainer could push malicious code under an existing tag.

**Evidence:**

`ci.yml` — all actions pinned to mutable tags:
```yaml
# Line 12
uses: actions/checkout@v4

# Line 15
uses: ruby/setup-ruby@v1

# Line 63
uses: actions/setup-node@v4

# Line 128
uses: actions/upload-artifact@v4
```

`publish.yml` — all actions pinned to mutable tags:
```yaml
# Line 47
uses: docker/setup-qemu-action@v3

# Line 49
uses: docker/setup-buildx-action@v3

# Line 52
uses: docker/login-action@v3

# Line 60
uses: docker/metadata-action@v5

# Line 72
uses: docker/build-push-action@v6
```

**Positive:** Dependabot is configured for `github-actions` updates (weekly), and `Gemfile.lock` exists for Ruby dependency pinning. `package-lock.json` exists for npm.

**Risk:** An attacker who compromises any of these action repositories can inject code into Maybe's CI pipeline on the next run without any code change in Maybe's repo.

**Recommendation:** Pin all actions to full SHA digests. Example:
```yaml
uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1
```

---

### CICD-SEC-4: Poisoned Pipeline Execution (PPE) — PASS

**Assessment:** The PR workflow uses `pull_request` trigger (not `pull_request_target`), which is safe — it runs the PR author's code in a sandboxed context without access to secrets. No workflow uses `pull_request_target` with checkout of PR head. No unsafe input interpolation detected.

**Evidence:**
- `pr.yml` line 4: `on: pull_request:` (safe trigger)
- `publish.yml` line 44: `ref: ${{ github.event.inputs.ref || github.ref }}` — only used on `workflow_dispatch` and `push` triggers (not PR-accessible)
- No instances of `${{ github.event.pull_request.title }}` or similar untrusted input in `run:` steps

---

### CICD-SEC-5: Insufficient PBAC (Pipeline-Based Access Controls) — FAIL

**Assessment:** Secret scoping issues identified. The CI test job exposes hardcoded test credentials as environment variables. While these are test values, the pattern normalizes credential exposure in workflow files. More critically, `ci.yml` lacks permissions blocks (see SEC-2).

**Evidence:**

`ci.yml` lines 79-84 — hardcoded credentials in workflow env:
```yaml
env:
  PLAID_CLIENT_ID: foo
  PLAID_SECRET: bar
  DATABASE_URL: postgres://postgres:postgres@localhost:5432
  REDIS_URL: redis://localhost:6379
  RAILS_ENV: test
```

**Risk:** Developers may copy this pattern with real credentials. The `postgres:postgres` password is weak even for CI.

**Recommendation:** Use GitHub Actions secrets even for test credentials, or at minimum add a comment explicitly marking these as non-sensitive test fixtures.

---

### CICD-SEC-6: Insufficient Credential Hygiene — FAIL

**Assessment:** Multiple credential hygiene issues found across the project.

**Evidence:**

1. `compose.example.yml` line 37 — **hardcoded SECRET_KEY_BASE**:
```yaml
SECRET_KEY_BASE: ${SECRET_KEY_BASE:-a7523c3d0ae56415046ad8abae168d71074a79534a7062258f8d1d51ac2f76d3c3bc86d86b6b0b307df30d9a6a90a2066a3fa9e67c5e6f374dbd7dd4e0778e13}
```
This is a full 128-character secret key in a file committed to the repository. Even as a "default," users who don't override it will run production with a publicly known secret key — enabling session forgery, CSRF bypass, and credential decryption.

2. `compose.example.yml` lines 31-33 — weak default database credentials:
```yaml
POSTGRES_USER: ${POSTGRES_USER:-maybe_user}
POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-maybe_password}
```

3. `.env.example` line 15 — placeholder with non-obvious format:
```yaml
SECRET_KEY_BASE=secret-value
```
While this is clearly a placeholder, there is no validation that it gets changed before deployment.

4. `publish.yml` line 57 — uses `secrets.GITHUB_TOKEN` for GHCR login (GOOD, this is the standard pattern).

**Risk:** The hardcoded `SECRET_KEY_BASE` in `compose.example.yml` is the highest-severity credential finding. Any self-hosted Maybe instance using defaults has a compromised secret key.

**Recommendation:** Remove the default value for `SECRET_KEY_BASE` entirely and require users to generate their own. Add a startup check that refuses to boot with the example key.

---

### CICD-SEC-7: Insecure Configuration of the Build System — PASS

**Assessment:** Build system configuration is generally sound.

- All jobs have `timeout-minutes` set (10 min for CI, 60 min for publish)
- Docker build uses GitHub Actions cache (`type=gha`) — cache poisoning risk is limited since cache is scoped per-branch
- Dockerfile uses multi-stage build, runs as non-root user (UID 1000)
- `.dockerignore` properly excludes `.env*`, credentials, `.git/`
- Service containers (Postgres, Redis) use ephemeral instances

**Evidence:**
- `ci.yml` line 9: `timeout-minutes: 10`
- `Dockerfile` line 59: `USER 1000:1000`
- `.dockerignore` lines 11-12: `/.env*` excluded

---

### CICD-SEC-8: Ungoverned Usage of Third-Party Services — PARTIAL FAIL

**Assessment:** The pipeline uses well-known first-party and Docker-official actions, but relies on a community action (`ruby/setup-ruby@v1`) and pulls service container images without pinning.

**Evidence:**

1. `ruby/setup-ruby@v1` — community-maintained action, not a GitHub-official action. Pinned to mutable `@v1` tag.

2. `ci.yml` lines 88-100 — unpinned service container images:
```yaml
services:
  postgres:
    image: postgres     # No tag — pulls :latest
  redis:
    image: redis        # No tag — pulls :latest
```

3. `compose.example.yml` line 93: `image: redis:latest` — mutable tag.

**Risk:** Unpinned `:latest` images for Postgres and Redis in CI mean a compromised or breaking upstream image change could affect builds. The `ruby/setup-ruby` action is widely used but remains a third-party trust dependency.

**Recommendation:** Pin service images to specific versions (e.g., `postgres:16`, `redis:7.2`). Pin `ruby/setup-ruby` to SHA.

---

### CICD-SEC-9: Improper Artifact Integrity Validation — FAIL

**Assessment:** Docker images are built and pushed without signing, attestation, or SBOM generation.

**Evidence:**

`publish.yml` line 82:
```yaml
provenance: false    # Explicitly disabled!
```

No image signing (cosign/sigstore) is configured. No SBOM generation step exists. No attestation of the build process is recorded.

**Risk:** Consumers of `ghcr.io/maybe-finance/maybe` images cannot verify that the image was built from the claimed source code. Supply chain attacks via image tampering are undetectable.

**Recommendation:**
1. Enable provenance: `provenance: true`
2. Add cosign signing step after build
3. Generate and attach SBOM (e.g., using `anchore/sbom-action`)

---

### CICD-SEC-10: Insufficient Logging and Visibility — PASS

**Assessment:** GitHub Actions provides built-in audit logging for all workflow runs. The pipeline does not actively suppress logs or disable visibility features.

- Workflow runs are visible in the Actions tab
- Test failure screenshots are preserved as artifacts (`upload-artifact@v4`)
- Brakeman scan output is visible in CI logs
- GitHub's audit log captures workflow execution events

**Note:** There is no explicit alerting on CI failures (e.g., Slack/email notifications), but this is a convenience concern rather than a security risk.

---

## Phase 3: Findings Summary

| # | Finding | Severity | OWASP Risk | File | Lines |
|---|---------|----------|------------|------|-------|
| 1 | Actions pinned to mutable version tags, not SHA digests | **HIGH** | CICD-SEC-3 | `ci.yml`, `publish.yml` | Multiple |
| 2 | Hardcoded SECRET_KEY_BASE default in compose file | **HIGH** | CICD-SEC-6 | `compose.example.yml` | 37 |
| 3 | Provenance explicitly disabled on Docker builds | **HIGH** | CICD-SEC-9 | `publish.yml` | 82 |
| 4 | No permissions block on CI and PR workflows | **MEDIUM** | CICD-SEC-2 | `ci.yml`, `pr.yml` | Entire file |
| 5 | Unpinned service container images in CI | **MEDIUM** | CICD-SEC-8 | `ci.yml` | 88, 97 |
| 6 | Hardcoded test credentials in workflow env | **LOW** | CICD-SEC-5 | `ci.yml` | 79-84 |
| 7 | No Docker image signing (cosign) | **HIGH** | CICD-SEC-9 | `publish.yml` | N/A (missing) |
| 8 | No SBOM generation for container images | **MEDIUM** | CICD-SEC-9 | `publish.yml` | N/A (missing) |
| 9 | Default database credentials in compose example | **LOW** | CICD-SEC-6 | `compose.example.yml` | 31-33 |

---

## Phase 4: OWASP CI/CD Top 10 Compliance Matrix

| OWASP Risk | Control | Status | Details |
|------------|---------|--------|---------|
| CICD-SEC-1 | Flow Control | **PASS** | CI gates publish; PR triggers CI |
| CICD-SEC-2 | IAM / Permissions | **FAIL** | `publish.yml` has permissions; `ci.yml` and `pr.yml` do not |
| CICD-SEC-3 | Dependency Chain | **FAIL** | All actions use mutable version tags instead of SHA pins |
| CICD-SEC-4 | Poisoned Pipeline | **PASS** | Uses safe `pull_request` trigger; no input injection |
| CICD-SEC-5 | PBAC | **FAIL** | Hardcoded test credentials; missing permissions scoping |
| CICD-SEC-6 | Credential Hygiene | **FAIL** | Hardcoded SECRET_KEY_BASE in compose; weak DB defaults |
| CICD-SEC-7 | System Config | **PASS** | Timeouts set; non-root Docker; proper .dockerignore |
| CICD-SEC-8 | Third-Party Services | **FAIL** | Unpinned service images; community action on mutable tag |
| CICD-SEC-9 | Artifact Integrity | **FAIL** | Provenance disabled; no signing; no SBOM |
| CICD-SEC-10 | Logging | **PASS** | Standard GitHub Actions logging; artifact preservation |

### Score: 4/10 PASS (40%)

---

## Positive Security Practices Observed

1. **Brakeman SAST** integrated into CI (Ruby security scanner)
2. **importmap audit** for JavaScript dependency vulnerabilities
3. **Dependabot** configured for both bundler and github-actions ecosystems
4. **Multi-stage Docker build** with non-root runtime user
5. **Explicit permissions** on the publish workflow (least privilege for build job)
6. **CI gate before publish** — images cannot be pushed without passing all checks
7. **Lockfiles present** — both `Gemfile.lock` and `package-lock.json` exist
8. **Proper .dockerignore** — excludes secrets, env files, git history
9. **Job timeouts** configured on all workflow jobs
10. **GHCR authentication** via `GITHUB_TOKEN` (no external credentials needed)

---

## Priority Remediation Roadmap

### Immediate (Week 1)
1. **Pin all GitHub Actions to SHA digests** — eliminates supply chain risk from tag mutation
2. **Remove default SECRET_KEY_BASE** from `compose.example.yml` — force users to generate their own
3. **Add `permissions: contents: read`** to `ci.yml` and `pr.yml`

### Short-term (Week 2-3)
4. **Enable provenance** on Docker builds (`provenance: true`)
5. **Pin service container images** to specific versions
6. **Add cosign signing** to published Docker images

### Medium-term (Month 1)
7. **Generate and attach SBOM** to Docker images
8. **Add CI failure notifications** (Slack/email)
9. **Add CODEOWNERS file** for workflow file changes to require security review

---

*Report generated by AI-Sec CI/CD Auditor. For questions or remediation support, contact the AI-Sec team.*
