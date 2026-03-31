# OWASP Top 10 CI/CD Security Risks (2023) — Checklist

Reference: https://owasp.org/www-project-top-10-ci-cd-security-risks/

This checklist covers all 10 risks with specific verification checks for each. Use during CI/CD pipeline security audits and DevSecOps assessments.

---

## CICD-SEC-1: Insufficient Flow Control Mechanisms

**Risk:** Ability to push code or artifacts through the pipeline without required approvals, reviews, or checks.

### Checks
- [ ] CICD-SEC-1.1: Branch protection rules are enforced on main/release branches (no direct push)
- [ ] CICD-SEC-1.2: Pull requests require at least one approval from a code owner before merge
- [ ] CICD-SEC-1.3: Pull request approvals are dismissed on new commits (stale review protection)
- [ ] CICD-SEC-1.4: Force push to protected branches is disabled
- [ ] CICD-SEC-1.5: Branch deletion of protected branches is disabled
- [ ] CICD-SEC-1.6: Status checks (CI tests, security scans) are required to pass before merge
- [ ] CICD-SEC-1.7: Merge queue or serialized merging prevents race conditions
- [ ] CICD-SEC-1.8: Deployment to production requires manual approval gate
- [ ] CICD-SEC-1.9: Self-approval of pull requests is prohibited
- [ ] CICD-SEC-1.10: Commit signing is enforced (GPG/SSH signed commits required)
- [ ] CICD-SEC-1.11: Tag protection rules prevent unauthorized release tagging
- [ ] CICD-SEC-1.12: Pipeline execution on forks requires explicit approval
- [ ] CICD-SEC-1.13: Artifact promotion between environments requires approval
- [ ] CICD-SEC-1.14: Rollback procedures exist and require appropriate authorization

---

## CICD-SEC-2: Inadequate Identity and Access Management

**Risk:** Overly permissive identities (human and machine) across the CI/CD pipeline.

### Checks
- [ ] CICD-SEC-2.1: SCM (GitHub/GitLab/Bitbucket) access follows least privilege principle
- [ ] CICD-SEC-2.2: CI/CD platform access roles are regularly reviewed and minimized
- [ ] CICD-SEC-2.3: Service accounts/machine identities use unique credentials per service
- [ ] CICD-SEC-2.4: Personal Access Tokens (PATs) have minimal scope and expiration dates
- [ ] CICD-SEC-2.5: SSH keys are unique per user/service and rotated regularly
- [ ] CICD-SEC-2.6: Multi-factor authentication (MFA) is enforced for all human accounts
- [ ] CICD-SEC-2.7: Inactive accounts are automatically disabled after defined period
- [ ] CICD-SEC-2.8: Admin/owner roles are limited to minimum required personnel
- [ ] CICD-SEC-2.9: Bot/integration accounts have restricted repository access (not org-wide)
- [ ] CICD-SEC-2.10: OAuth app authorizations are reviewed and unnecessary apps are revoked
- [ ] CICD-SEC-2.11: SAML/SSO is configured for the organization (no local-only accounts)
- [ ] CICD-SEC-2.12: GitHub Actions / CI runners use short-lived credentials (OIDC) instead of long-lived secrets
- [ ] CICD-SEC-2.13: Repository visibility is appropriate (no accidental public repos with internal code)
- [ ] CICD-SEC-2.14: Audit logs for access changes are enabled and monitored
- [ ] CICD-SEC-2.15: Deploy keys have read-only access unless write is explicitly required

---

## CICD-SEC-3: Dependency Chain Abuse

**Risk:** Exploiting flaws in dependency management to inject malicious code via packages, images, or modules.

### Checks
- [ ] CICD-SEC-3.1: All dependencies are pinned to specific versions (no floating ranges like ^, ~, latest)
- [ ] CICD-SEC-3.2: Lock files (package-lock.json, yarn.lock, Pipfile.lock, go.sum) are committed and verified
- [ ] CICD-SEC-3.3: Dependency integrity verification is enabled (npm audit signatures, pip --require-hashes)
- [ ] CICD-SEC-3.4: Private registry/proxy is used to cache and verify packages (Artifactory, Nexus, GitHub Packages)
- [ ] CICD-SEC-3.5: Dependency confusion prevention — internal package names are reserved on public registries, or scoped namespaces are used
- [ ] CICD-SEC-3.6: Container base images are pinned by digest, not just tag
- [ ] CICD-SEC-3.7: Container images are pulled from a trusted registry (not directly from Docker Hub unverified publishers)
- [ ] CICD-SEC-3.8: Automated dependency vulnerability scanning runs on every PR (Dependabot, Snyk, Trivy, Grype)
- [ ] CICD-SEC-3.9: Known vulnerable dependencies are blocked from being merged (scanner configured as required check)
- [ ] CICD-SEC-3.10: Software Bill of Materials (SBOM) is generated and maintained
- [ ] CICD-SEC-3.11: Pre-install/post-install scripts in dependencies are reviewed or disabled
- [ ] CICD-SEC-3.12: Typosquatting prevention — dependency names are reviewed for suspicious similarities
- [ ] CICD-SEC-3.13: Build reproducibility — builds from the same source produce the same output

---

## CICD-SEC-4: Poisoned Pipeline Execution (PPE)

**Risk:** Attacker modifies CI/CD pipeline configuration to execute malicious code during the build process.

### Checks
- [ ] CICD-SEC-4.1: Pipeline configuration files (.github/workflows, .gitlab-ci.yml, Jenkinsfile) are protected by branch protection rules
- [ ] CICD-SEC-4.2: Pipeline changes require the same review process as code changes
- [ ] CICD-SEC-4.3: Pipelines triggered by forks run with reduced permissions (no access to secrets)
- [ ] CICD-SEC-4.4: `pull_request_target` (GitHub) is not used with checkout of PR head (prevents injection from forks)
- [ ] CICD-SEC-4.5: Pipeline scripts do not use user-controlled input unsanitized (PR title, branch name, commit message injection)
- [ ] CICD-SEC-4.6: Self-hosted runners are not shared across repositories with different trust levels
- [ ] CICD-SEC-4.7: Pipeline definition is loaded from the protected branch, not from the PR branch (for CI systems that support this)
- [ ] CICD-SEC-4.8: Dynamic pipeline generation does not incorporate untrusted input
- [ ] CICD-SEC-4.9: Inline scripts in pipeline files are minimized — prefer calling versioned, reviewed scripts
- [ ] CICD-SEC-4.10: `workflow_run` triggered workflows verify the triggering workflow's context
- [ ] CICD-SEC-4.11: Third-party CI/CD actions/orbs/templates are pinned to specific SHAs (not tags that can be moved)
- [ ] CICD-SEC-4.12: GitHub Actions `uses:` references are pinned to commit SHA, not branch/tag

---

## CICD-SEC-5: Insufficient PBAC (Pipeline-Based Access Control)

**Risk:** Pipelines have excessive access to resources, credentials, and systems beyond what is needed for the build.

### Checks
- [ ] CICD-SEC-5.1: CI/CD jobs use the minimum required permissions (GitHub: `permissions:` block in workflow)
- [ ] CICD-SEC-5.2: GITHUB_TOKEN (or equivalent) permissions are restricted to read-only by default
- [ ] CICD-SEC-5.3: Secrets are scoped to specific environments, not available to all jobs/branches
- [ ] CICD-SEC-5.4: Production secrets are only accessible from production deployment jobs, not from PR/test jobs
- [ ] CICD-SEC-5.5: Runners/agents do not have standing access to production infrastructure
- [ ] CICD-SEC-5.6: Build jobs cannot access deployment credentials
- [ ] CICD-SEC-5.7: Environment protection rules gate access to production credentials
- [ ] CICD-SEC-5.8: Service connections/integrations follow least privilege (cloud IAM roles are scoped)
- [ ] CICD-SEC-5.9: Artifact repositories have role-based access (build can push, deploy can pull, dev has read-only)
- [ ] CICD-SEC-5.10: Network segmentation — build environments cannot reach production networks directly
- [ ] CICD-SEC-5.11: Pipeline service accounts are unique per pipeline/environment (not shared)

---

## CICD-SEC-6: Insufficient Credential Hygiene

**Risk:** Credentials scattered across pipeline configurations, code, logs, and artifacts.

### Checks
- [ ] CICD-SEC-6.1: No secrets hardcoded in source code (run secret scanning: gitleaks, truffleHog, GitHub secret scanning)
- [ ] CICD-SEC-6.2: No secrets in pipeline configuration files (use secret management features)
- [ ] CICD-SEC-6.3: No secrets in container images (scan with tools like dive, docker history)
- [ ] CICD-SEC-6.4: No secrets in build artifacts or release packages
- [ ] CICD-SEC-6.5: No secrets printed in CI/CD logs (verify masking works, check for base64 encoded leaks)
- [ ] CICD-SEC-6.6: Secrets use the platform's native secret management (GitHub Secrets, GitLab CI Variables masked/protected)
- [ ] CICD-SEC-6.7: External secret management is used for production credentials (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault)
- [ ] CICD-SEC-6.8: Credentials are rotated regularly (automated rotation preferred)
- [ ] CICD-SEC-6.9: Short-lived credentials are preferred over long-lived ones (OIDC federation, temporary tokens)
- [ ] CICD-SEC-6.10: Leaked credentials are immediately revoked and rotated (incident response process exists)
- [ ] CICD-SEC-6.11: Git history is clean of secrets (or historical leaks are documented and credentials rotated)
- [ ] CICD-SEC-6.12: `.env` files and credential files are in `.gitignore`
- [ ] CICD-SEC-6.13: Pre-commit hooks prevent committing secrets (gitleaks pre-commit, detect-secrets)

---

## CICD-SEC-7: Insecure System Configuration

**Risk:** Security misconfigurations in CI/CD platform settings, runner configurations, and integrations.

### Checks
- [ ] CICD-SEC-7.1: CI/CD platform is updated to the latest stable version
- [ ] CICD-SEC-7.2: Default credentials on CI/CD tools are changed (Jenkins, Nexus, SonarQube, etc.)
- [ ] CICD-SEC-7.3: CI/CD management interfaces are not publicly accessible (or protected by VPN/IP allow list)
- [ ] CICD-SEC-7.4: Self-hosted runners/agents are hardened (minimal OS, no unnecessary software)
- [ ] CICD-SEC-7.5: Self-hosted runners use ephemeral/disposable execution environments (containers, VMs that are destroyed after each job)
- [ ] CICD-SEC-7.6: Runner registration tokens are protected and rotated
- [ ] CICD-SEC-7.7: CI/CD audit logging is enabled and forwarded to SIEM/log aggregator
- [ ] CICD-SEC-7.8: Network policies restrict runner egress (runners cannot reach arbitrary internet destinations)
- [ ] CICD-SEC-7.9: Built-in security features are enabled (GitHub: code scanning, secret scanning, Dependabot)
- [ ] CICD-SEC-7.10: Webhook endpoints validate signatures (GitHub: webhook secret, GitLab: token)
- [ ] CICD-SEC-7.11: Concurrent build limits prevent resource abuse
- [ ] CICD-SEC-7.12: Build caches are isolated between projects/tenants
- [ ] CICD-SEC-7.13: TLS is enforced for all CI/CD system communications

---

## CICD-SEC-8: Ungoverned Usage of Third-Party Services

**Risk:** Third-party services and integrations with excessive access to the development ecosystem.

### Checks
- [ ] CICD-SEC-8.1: All third-party integrations are inventoried with documented access scope
- [ ] CICD-SEC-8.2: GitHub Apps/OAuth apps have minimal required permissions
- [ ] CICD-SEC-8.3: Third-party CI/CD services (Codecov, Snyk, SonarCloud) access is reviewed quarterly
- [ ] CICD-SEC-8.4: Marketplace actions/integrations are evaluated for security before adoption
- [ ] CICD-SEC-8.5: Third-party services do not have write access to repositories unless required
- [ ] CICD-SEC-8.6: Webhooks to third-party services use HTTPS and signature verification
- [ ] CICD-SEC-8.7: Decommissioned integrations are promptly removed (no orphaned access)
- [ ] CICD-SEC-8.8: Third-party service incidents are monitored (supply chain attack awareness)
- [ ] CICD-SEC-8.9: Data shared with third-party services is reviewed for sensitivity
- [ ] CICD-SEC-8.10: Third-party services have documented incident response contacts and SLAs

---

## CICD-SEC-9: Improper Artifact Integrity Validation

**Risk:** Artifacts (builds, packages, images) are not validated for integrity, enabling supply chain attacks.

### Checks
- [ ] CICD-SEC-9.1: Build artifacts are signed (code signing, container image signing with cosign/Notary)
- [ ] CICD-SEC-9.2: Artifact signatures are verified before deployment
- [ ] CICD-SEC-9.3: Container images are signed and verified before pulling in production (admission controller)
- [ ] CICD-SEC-9.4: SLSA provenance is generated for builds (or equivalent attestation)
- [ ] CICD-SEC-9.5: Artifact checksums are verified during promotion between environments
- [ ] CICD-SEC-9.6: Package publishing requires authentication and authorization
- [ ] CICD-SEC-9.7: Artifact registry has immutable tags/versions (published versions cannot be overwritten)
- [ ] CICD-SEC-9.8: Build metadata (who built it, from which commit, on which runner) is recorded
- [ ] CICD-SEC-9.9: Reproducible builds are achievable — same source produces same artifact
- [ ] CICD-SEC-9.10: Artifact retention policies exist (old artifacts are cleaned up but release artifacts are preserved)

---

## CICD-SEC-10: Insufficient Logging and Visibility

**Risk:** Lack of logging and monitoring across the CI/CD pipeline makes it difficult to detect and investigate attacks.

### Checks
- [ ] CICD-SEC-10.1: SCM audit logs are enabled (who did what, when — git pushes, PR merges, permission changes)
- [ ] CICD-SEC-10.2: CI/CD platform audit logs are enabled (pipeline executions, configuration changes, secret access)
- [ ] CICD-SEC-10.3: Artifact registry audit logs are enabled (pushes, pulls, deletions)
- [ ] CICD-SEC-10.4: Cloud/infrastructure audit logs capture deployment events
- [ ] CICD-SEC-10.5: Logs are forwarded to a centralized SIEM or log aggregator
- [ ] CICD-SEC-10.6: Log retention meets compliance requirements (minimum 90 days, ideally 1 year)
- [ ] CICD-SEC-10.7: Alerts are configured for critical events:
  - [ ] Branch protection rule changes
  - [ ] New deploy keys or SSH keys added
  - [ ] New OAuth/GitHub App installations
  - [ ] Admin role grants
  - [ ] Secret access from unexpected contexts
  - [ ] Pipeline configuration changes
  - [ ] Failed deployment attempts
- [ ] CICD-SEC-10.8: Log integrity is protected (logs cannot be tampered with by pipeline actors)
- [ ] CICD-SEC-10.9: Periodic review of CI/CD logs for anomalies is scheduled
- [ ] CICD-SEC-10.10: Incident response runbook includes CI/CD-specific scenarios (compromised runner, leaked secret, poisoned pipeline)

---

## Audit Notes

**How to use this checklist:**
1. Copy this file and rename for the engagement
2. Mark items: `[x]` passed, `[!]` finding raised, `[-]` N/A (with justification)
3. For each `[!]`, create a finding using finding-template.md with framework reference `CICD-SEC-{N}`
4. Prioritize: CICD-SEC-4 (PPE) and CICD-SEC-6 (credentials) are the most commonly exploited

**Assessment approach:**
1. **Configuration review** — Export and review SCM/CI/CD platform settings
2. **Pipeline analysis** — Review all pipeline definition files for security anti-patterns
3. **Secret scanning** — Run automated tools against repo history and current codebase
4. **Access audit** — Export and review all identities, permissions, and integrations
5. **Artifact chain** — Trace an artifact from source to production, verify integrity at each step

**Common tools:**
- Secret scanning: gitleaks, truffleHog, GitHub Advanced Security
- Pipeline analysis: Legitimate/custom scripts analyzing workflow files
- Configuration audit: ScoutSuite, Prowler (for cloud), custom GitHub API scripts
- Container scanning: Trivy, Grype, Snyk Container
- SBOM generation: Syft, CycloneDX
