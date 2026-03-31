# CI/CD Security Audit Report: Hoppscotch

**Target:** [hoppscotch/hoppscotch](https://github.com/hoppscotch/hoppscotch)
**Audit Date:** 2026-03-28
**Auditor:** AI-Sec CI/CD Auditor (automated)
**Scope:** GitHub Actions workflows, Docker build pipeline, dependency management, supply chain controls
**Framework:** OWASP CI/CD Security Top 10 (2023)

---

## Executive Summary

Hoppscotch is a mature open-source API development platform with 5 GitHub Actions workflows covering testing, Docker release, CodeQL analysis, and desktop/agent builds. The project demonstrates several strong practices -- multi-stage Docker builds with checksum verification, CODEOWNERS enforcement, code-signing across all platforms, and CodeQL scanning. However, the audit identified **9 HIGH**, **8 MEDIUM**, and **5 LOW** severity findings across the OWASP CI/CD Top 10 categories. The most critical issues are hardcoded credentials in CI, unpinned third-party actions, and an overly permissive `workflow_dispatch` trigger on the Docker release pipeline.

**Overall Risk Rating: MEDIUM-HIGH**

---

## OWASP CI/CD Top 10 Compliance Matrix

| # | Risk | Rating | Status | Key Findings |
|---|------|--------|--------|-------------|
| CICD-SEC-1 | Insufficient Flow Control Mechanisms | MEDIUM | Partial | CODEOWNERS present but no required reviews enforced in workflows; `workflow_dispatch` allows manual bypass |
| CICD-SEC-2 | Inadequate Identity and Access Management | MEDIUM | Partial | PAT token (`HOPPSCOTCH_GITHUB_CHECKOUT_TOKEN`) used for cross-repo access; no evidence of least-privilege scoping |
| CICD-SEC-3 | Dependency Chain Abuse | MEDIUM | Partial | Dependabot configured but `open-pull-requests-limit: 0` disables automated PRs; lockfile present but no integrity verification in CI |
| CICD-SEC-4 | Poisoned Pipeline Execution (PPE) | HIGH | Weak | PR-triggered workflows run on `pull_request` (safe fork behavior) but no explicit `permissions` block on most workflows |
| CICD-SEC-5 | Insufficient PBAC (Pipeline-Based Access Controls) | MEDIUM | Partial | Only CodeQL workflow has explicit `permissions`; all others run with default token permissions |
| CICD-SEC-6 | Insufficient Credential Hygiene | HIGH | Weak | Hardcoded test credentials in CI and docker-compose; secrets referenced via env but no rotation evidence |
| CICD-SEC-7 | Insecure System Configuration | MEDIUM | Partial | Runners use `ubuntu-latest` (non-deterministic); deprecated `actions-rs/toolchain@v1` in use |
| CICD-SEC-8 | Ungoverned Usage of Third-Party Services | HIGH | Weak | Actions not pinned to SHA digests; external binaries downloaded via curl without signature verification |
| CICD-SEC-9 | Improper Artifact Integrity Validation | LOW | Good | Docker digest-based builds, SHA256 checksums for desktop artifacts, Tauri signing, Go/NPM checksum verification in Dockerfile |
| CICD-SEC-10 | Insufficient Logging and Visibility | LOW | Acceptable | Standard GitHub Actions logging; no evidence of SIEM integration but adequate for project scale |

---

## Detailed Findings

### CRITICAL / HIGH Severity

#### H1. Hardcoded Database Credentials in CI Workflow
- **File:** `.github/workflows/tests.yml` (line 41-42)
- **Risk:** CICD-SEC-6
- **Detail:** `DATABASE_URL` and `DATA_ENCRYPTION_KEY` are hardcoded as plaintext environment variables in the test workflow. While these are test-only values, this normalizes credential hardcoding patterns.
  ```yaml
  DATABASE_URL: postgresql://postgres:testpass@localhost:5432/hoppscotch
  DATA_ENCRYPTION_KEY: "12345678901234567890123456789012"
  ```
- **Impact:** Pattern normalization; if copy-pasted to production workflows, leads to credential exposure.
- **Recommendation:** Use GitHub Actions secrets even for test credentials. Document that these are intentionally non-sensitive test values via comments.

#### H2. Hardcoded Default Database Password in docker-compose
- **Files:** `docker-compose.yml` (line 157), `docker-compose.deploy.yml` (line 10), `.env.example` (line 3)
- **Risk:** CICD-SEC-6
- **Detail:** `POSTGRES_PASSWORD: testpass` is hardcoded in both docker-compose files. The comment says "Please UPDATE THIS PASSWORD!" but there is no enforcement mechanism.
- **Impact:** Self-hosted deployments that don't change defaults are immediately vulnerable. This is a well-known attack vector for open-source projects.
- **Recommendation:** Use environment variable substitution with no default (fail if not set), or generate a random password on first run.

#### H3. Third-Party GitHub Actions Not Pinned to SHA Digests
- **Files:** All workflow files
- **Risk:** CICD-SEC-8
- **Detail:** All GitHub Actions are referenced by version tag, not commit SHA:
  - `actions/checkout@v4` / `@v3`
  - `docker/login-action@v2`
  - `docker/build-push-action@v4`
  - `actions/setup-node@v4` / `@v3`
  - `pnpm/action-setup@v3` / `@v4`
  - `actions-rs/toolchain@v1`
  - `apple-actions/import-codesign-certs@v3`
  - `github/codeql-action/init@v2`
  - `actions/cache@v4`
  - `actions/upload-artifact@v4`
  - `actions/download-artifact@v4`
  - `docker/setup-qemu-action@v3`
  - `docker/setup-buildx-action@v3`
- **Impact:** A compromised tag (via repository takeover, forced push, or supply chain attack) could inject malicious code into the CI pipeline with full access to secrets.
- **Recommendation:** Pin all actions to full SHA digests with version comments, e.g.:
  ```yaml
  uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1
  ```

#### H4. Unsigned External Binaries Downloaded via curl in CI
- **Files:** `build-hoppscotch-agent.yml` (lines 85-88, 293-301), `build-hoppscotch-desktop.yml` (lines 77-80, 384-393)
- **Risk:** CICD-SEC-8
- **Detail:** Tauri CLI and Trunk binaries are downloaded from GitHub Releases via `curl -LO` without any checksum or signature verification:
  ```yaml
  curl -LO "https://github.com/tauri-apps/tauri/releases/download/tauri-cli-v2.0.1/cargo-tauri-x86_64-apple-darwin.zip"
  unzip cargo-tauri-x86_64-apple-darwin.zip
  chmod +x cargo-tauri
  sudo mv cargo-tauri /usr/local/bin/tauri
  ```
- **Impact:** MITM or compromised release could inject a trojanized binary that runs with full CI privileges, including access to signing keys and secrets.
- **Recommendation:** Add SHA256 checksum verification for all downloaded binaries (the Dockerfile already demonstrates this pattern for Go and Caddy downloads).

#### H5. trusted-signing-cli Downloaded Without Verification
- **Files:** `build-hoppscotch-agent.yml` (lines 463-468), `build-hoppscotch-desktop.yml` (lines 181-188)
- **Risk:** CICD-SEC-8
- **Detail:** `trusted-signing-cli.exe` is downloaded from a third-party GitHub repository (`Levminer/trusted-signing-cli`) without checksum verification and placed on PATH. This binary then receives Azure code-signing credentials.
- **Impact:** If the Levminer repository is compromised, an attacker gains access to Azure code-signing certificates and can sign arbitrary executables.
- **Recommendation:** Verify SHA256 checksum of the downloaded binary. Consider vendoring the tool or using an official Microsoft-provided signing solution.

#### H6. workflow_dispatch on Docker Release with No Input Validation
- **File:** `release-push-docker.yml` (lines 7-9)
- **Risk:** CICD-SEC-1
- **Detail:** The Docker release workflow can be triggered manually via `workflow_dispatch` with no inputs required. Anyone with write access to the repository can push arbitrary Docker images to Docker Hub.
- **Impact:** A compromised maintainer account could push malicious Docker images tagged as official releases.
- **Recommendation:** Add required approval steps or restrict `workflow_dispatch` to specific actors. Consider requiring a tag match for the `workflow_dispatch` path.

#### H7. Desktop Build Workflow Accepts Arbitrary Repository/Branch Input
- **File:** `build-hoppscotch-desktop.yml` (lines 8-19)
- **Risk:** CICD-SEC-1, CICD-SEC-4
- **Detail:** The workflow accepts `repository` and `branch` as free-text inputs, checked out with a PAT token:
  ```yaml
  repository: ${{ inputs.repository }}
  ref: ${{ inputs.tag != '' && inputs.tag || inputs.branch }}
  token: ${{ secrets.HOPPSCOTCH_GITHUB_CHECKOUT_TOKEN }}
  ```
- **Impact:** A user with workflow dispatch permissions could checkout code from any repository using the project's PAT token, potentially exfiltrating the token to an attacker-controlled repo.
- **Recommendation:** Remove the `repository` input or restrict to a validated allowlist. Ensure the PAT has minimal scope.

#### H8. No Explicit permissions Block on Most Workflows
- **Files:** `tests.yml`, `release-push-docker.yml`, `build-hoppscotch-agent.yml`, `build-hoppscotch-desktop.yml`
- **Risk:** CICD-SEC-4, CICD-SEC-5
- **Detail:** Only the CodeQL workflow defines explicit `permissions`. All other workflows inherit the default repository token permissions, which may include write access to contents, packages, and deployments.
- **Impact:** If a workflow is compromised, the token has broader access than necessary.
- **Recommendation:** Add minimal `permissions` blocks to all workflows:
  ```yaml
  permissions:
    contents: read
  ```

#### H9. Secret Interpolation in Shell Commands (Potential Injection)
- **Files:** `build-hoppscotch-agent.yml` (line 473), `build-hoppscotch-desktop.yml` (line 194)
- **Risk:** CICD-SEC-4
- **Detail:** Secrets are interpolated directly into shell commands:
  ```yaml
  WINDOWS_SIGN_COMMAND: trusted-signing-cli -e ${{ secrets.AZURE_ENDPOINT }} -a ${{ secrets.AZURE_CODE_SIGNING_NAME }} -c ${{ secrets.AZURE_CERT_PROFILE_NAME }} %1
  ```
  While these are organization secrets (not user-controlled inputs), this pattern is fragile. If secret values ever contain shell metacharacters, it could lead to command injection.
- **Impact:** Low probability but high impact if secret values are changed to include special characters.
- **Recommendation:** Pass secrets via environment variables rather than direct interpolation in `run` commands. Use intermediate environment variables in the shell.

---

### MEDIUM Severity

#### M1. Dependabot Configured with `open-pull-requests-limit: 0`
- **File:** `.github/dependabot.yml` (line 8)
- **Risk:** CICD-SEC-3
- **Detail:** Dependabot is configured for npm but `open-pull-requests-limit: 0` means it will never automatically create pull requests for vulnerable dependencies.
- **Impact:** The project relies entirely on manual dependency updates, increasing the window of exposure to known vulnerabilities.
- **Recommendation:** Set `open-pull-requests-limit` to at least 5-10 and configure auto-merge for patch-level updates. The project already has pnpm overrides for several CVE patches -- automation would reduce this manual burden.

#### M2. Deprecated `actions-rs/toolchain@v1` in Use
- **Files:** `build-hoppscotch-agent.yml`, `build-hoppscotch-desktop.yml` (multiple jobs)
- **Risk:** CICD-SEC-7, CICD-SEC-8
- **Detail:** `actions-rs/toolchain@v1` is archived and unmaintained. The `actions-rs` organization is effectively abandoned.
- **Impact:** No security patches will be released for this action. It could contain latent vulnerabilities.
- **Recommendation:** Migrate to `dtolnay/rust-toolchain` or use `rustup` directly in a `run` step.

#### M3. Non-Deterministic Runner Versions
- **Files:** All workflows using `ubuntu-latest`, `macos-latest`, `windows-latest`
- **Risk:** CICD-SEC-7
- **Detail:** All workflows use `-latest` runner images which change over time without notice.
- **Impact:** Builds are not reproducible. A runner update could introduce different behavior or vulnerabilities.
- **Recommendation:** Pin to specific runner versions (e.g., `ubuntu-24.04`) for release workflows. `ubuntu-22.04` is already used for some Linux desktop builds, which is good.

#### M4. No Branch Protection Enforcement Evidence in Workflows
- **Risk:** CICD-SEC-1
- **Detail:** While CODEOWNERS is configured, there is no evidence of required status checks, required reviews, or branch protection rules being enforced within the workflow definitions. The test workflow runs on `push` and `pull_request` to `main/next/patch` but does not gate merges.
- **Impact:** Code could potentially be merged without passing CI checks if branch protection is not configured at the repository level.
- **Recommendation:** Ensure GitHub branch protection rules require: (1) status checks to pass, (2) at least 1 review from CODEOWNERS, (3) up-to-date branches before merge. This is a repository setting, not a workflow file issue.

#### M5. CodeQL Uses Outdated v2 Actions
- **File:** `codeql-analysis.yml` (lines 40, 49, 63)
- **Risk:** CICD-SEC-7, CICD-SEC-8
- **Detail:** CodeQL actions are pinned to `@v2` while `@v3` has been available for over a year with improved analysis capabilities and security fixes.
- **Impact:** Missing improved vulnerability detection and potential security fixes in the CodeQL tooling itself.
- **Recommendation:** Upgrade to `github/codeql-action/init@v3`, `github/codeql-action/autobuild@v3`, `github/codeql-action/analyze@v3`.

#### M6. PAT Token Used for Cross-Repository Checkout
- **Files:** `build-hoppscotch-agent.yml`, `build-hoppscotch-desktop.yml`
- **Risk:** CICD-SEC-2
- **Detail:** `HOPPSCOTCH_GITHUB_CHECKOUT_TOKEN` is used to checkout code. This is a Personal Access Token (or fine-grained token) that likely has broader permissions than `GITHUB_TOKEN`.
- **Impact:** If this token has broad scope (e.g., `repo` access), compromise of the workflow could grant access to other repositories.
- **Recommendation:** Use a GitHub App installation token with minimal repository-scoped permissions instead of a PAT. Document the required token scope.

#### M7. ENV_FILE_CONTENT Secret Written to Disk Unprotected
- **File:** `build-hoppscotch-desktop.yml` (lines 110-118, 207-215, 309-317, 406-414)
- **Risk:** CICD-SEC-6
- **Detail:** The `ENV_FILE_CONTENT` secret is echoed directly to a `.env` file on the runner filesystem. If the workflow has any upload or caching step that inadvertently includes this file, secrets would leak.
- **Impact:** Secrets written to disk could be captured by artifact uploads, cache poisoning, or other steps.
- **Recommendation:** Use environment variables directly rather than writing secrets to files. If file-based env is required, ensure the file path is in `.gitignore` and excluded from all artifact/cache steps.

#### M8. Docker Images Tagged as `latest` Without Immutability
- **File:** `release-push-docker.yml` (lines 151, 162, 172, 181)
- **Risk:** CICD-SEC-9
- **Detail:** Every release overwrites the `:latest` tag on Docker Hub. There is no immutable tag policy.
- **Impact:** Users pulling `:latest` cannot verify they are running a specific audited version. A compromised release would immediately affect all `:latest` users.
- **Recommendation:** Encourage users to pin to versioned tags. Consider signing Docker images with cosign/Sigstore for verification.

---

### LOW Severity

#### L1. Netlify Configuration Uses Node.js 14
- **File:** `netlify.toml` (line 2)
- **Risk:** CICD-SEC-7
- **Detail:** `NODE_VERSION = "14"` is configured for Netlify builds. Node.js 14 reached end-of-life in April 2023.
- **Impact:** Netlify builds use an unsupported runtime with known vulnerabilities. This appears to be legacy configuration.
- **Recommendation:** Update to Node.js 20 or 22 (current LTS).

#### L2. No SBOM Generation in Build Pipeline
- **Risk:** CICD-SEC-9
- **Detail:** Neither the Docker build nor the desktop build pipelines generate a Software Bill of Materials (SBOM).
- **Impact:** Users cannot verify the complete dependency tree of shipped artifacts.
- **Recommendation:** Add SBOM generation using `syft` or Docker's built-in `--sbom` flag for container builds.

#### L3. Docker Compose Exposes Database Port to Host
- **File:** `docker-compose.yml` (line 150)
- **Detail:** PostgreSQL port 5432 is mapped to the host, making it accessible beyond the Docker network.
- **Impact:** Combined with the default `testpass` password, this creates a directly exploitable attack surface for self-hosted deployments.
- **Recommendation:** Remove the host port mapping or bind to `127.0.0.1:5432:5432` by default.

#### L4. No Artifact Attestation or Provenance
- **Risk:** CICD-SEC-9
- **Detail:** Build artifacts (Docker images, desktop binaries) do not include SLSA provenance attestations.
- **Impact:** Users cannot cryptographically verify that artifacts were built from the claimed source code in the claimed CI environment.
- **Recommendation:** Adopt `actions/attest-build-provenance` for SLSA Level 2+ provenance on released artifacts.

#### L5. Inconsistent Action Versions Across Workflows
- **Risk:** CICD-SEC-7
- **Detail:** Different workflows use different versions of the same actions:
  - `actions/checkout@v3` (agent/desktop) vs `@v4` (tests, docker, codeql)
  - `actions/setup-node@v3` (agent/desktop) vs `@v4` (tests)
  - `pnpm/action-setup@v3` (tests) vs `@v4` (agent/desktop)
- **Impact:** Older versions may lack security fixes. Inconsistency complicates auditing and maintenance.
- **Recommendation:** Standardize on the latest version of each action across all workflows.

---

## Positive Security Practices Observed

The following security controls are already in place and should be maintained:

1. **Multi-stage Docker builds** -- `prod.Dockerfile` uses a well-structured multi-stage build that separates build-time and runtime dependencies, reducing final image attack surface.
2. **Checksum verification in Dockerfile** -- Go tarball, Caddy source, and NPM tarball all have SHA256 checksum verification before use. This is excellent supply chain hygiene.
3. **CVE patching in Dockerfile** -- Active patching of Go dependencies (quic-go, crypto, smallstep) and npm packages (glob, tar) with comments referencing specific CVEs.
4. **CODEOWNERS file** -- Clear ownership assignment for all major packages and infrastructure files.
5. **Code-signing on all platforms** -- Apple code-signing, Azure Trusted Signing for Windows, Tauri update signatures.
6. **CodeQL analysis** -- SAST scanning on push, PR, and weekly schedule with security-extended queries.
7. **Husky pre-commit hooks** -- Lint and typecheck enforced locally before commit.
8. **Commitlint** -- Enforced conventional commit format.
9. **Security policy (SECURITY.md)** -- Clear vulnerability reporting process via GHSA.
10. **Digest-based Docker image publishing** -- Images are pushed by digest then assembled into manifests.
11. **PR template** -- Structured pull request template encourages review.
12. **pnpm with overrides** -- Proactive dependency patching via `pnpm.overrides` in package.json.
13. **Healthchecks** -- Docker containers include health check definitions.
14. **`.dockerignore`** -- Well-configured to exclude `.git`, `.env`, `node_modules`, tests, and other non-production files.

---

## Remediation Priority

| Priority | Finding | Effort | Impact |
|----------|---------|--------|--------|
| P0 | H3 - Pin actions to SHA digests | Medium | Prevents supply chain attacks on CI |
| P0 | H4/H5 - Verify downloaded binaries | Low | Prevents trojanized tooling |
| P1 | H8 - Add permissions blocks | Low | Limits blast radius of compromise |
| P1 | H6/H7 - Restrict workflow_dispatch | Low | Prevents unauthorized releases |
| P1 | M1 - Enable Dependabot PRs | Low | Automates vulnerability patching |
| P2 | H1/H2 - Address hardcoded credentials | Low | Eliminates credential hygiene anti-patterns |
| P2 | M2 - Replace deprecated actions | Low | Removes unmaintained dependencies |
| P2 | M5 - Upgrade CodeQL to v3 | Low | Improves vulnerability detection |
| P3 | M3 - Pin runner versions | Low | Improves reproducibility |
| P3 | L1 - Update Netlify Node version | Low | Removes EOL runtime |
| P3 | L2/L4 - Add SBOM and provenance | Medium | Improves supply chain transparency |

---

## Methodology

This audit examined:
- 5 GitHub Actions workflow files (`.github/workflows/`)
- 1 Dockerfile (`prod.Dockerfile`) with 11 build stages
- 2 docker-compose files
- Root `package.json` with pnpm workspace config and lockfile
- `CODEOWNERS`, `.github/dependabot.yml`, `SECURITY.md`
- `.env.example`, `.dockerignore`, `netlify.toml`
- Husky hooks and commitlint configuration

Analysis was performed against the OWASP CI/CD Security Top 10 (2023 edition) framework with additional checks for Docker security best practices and GitHub Actions hardening guidelines.

---

*Report generated by AI-Sec CI/CD Auditor. For questions or to schedule a manual review, contact the AI-Sec team.*
