# AI-Sec

**AI-powered security audit that reasons about your architecture, not just regex patterns.**

AI-Sec uses Claude to read your entire codebase and systematically check it against industry-standard security frameworks — OWASP ASVS, MASVS, CIS benchmarks, and CI/CD Top 10. It finds the things scanners miss: broken auth flows, IDORs, business logic holes, webhook forgery, privilege escalation.

## Quick Start

```bash
# Clone AI-Sec alongside your project
git clone https://github.com/sergey-ko/ai-sec.git

# In Claude Code, from your project directory:
/audit
```

That's it. AI-Sec auto-detects your stack and runs the relevant security checks.

## What It Finds (That Scanners Miss)

| Category | Example Finding | Why Scanners Miss It |
|----------|----------------|---------------------|
| **Broken Auth** | JWT tokens with 30-day expiry and no rotation | Requires understanding the auth flow, not just the token format |
| **IDOR** | `/api/users/:id` returns any user's data regardless of session | Pattern matching can't reason about authorization logic |
| **Business Logic** | Price can be set to negative via API, bypassing validation | Requires understanding what the code is supposed to do |
| **Webhook Forgery** | HMAC verification uses parsed body instead of raw bytes | Requires tracing data flow through middleware |
| **CI/CD Supply Chain** | GitHub Actions pinned to mutable tags, not SHA | Requires understanding the threat model of CI/CD |
| **Infra Drift** | EKS API server publicly accessible, no CIDR restriction | Requires reading Terraform and understanding cloud security |

## How It Works

```
/audit
  │
  ├── Detects: Next.js app + GitHub Actions + Dockerfile
  │
  ├── Runs in parallel:
  │   ├── web-app-auditor    → OWASP ASVS L2 (auth, sessions, access control, XSS, API)
  │   ├── api-auditor        → API + webhook security (ASVS V13, V2.10)
  │   └── cicd-auditor       → OWASP CI/CD Top 10 (pipelines, deps, secrets)
  │
  └── Output: ai-sec-report.md
      ├── 12 findings (2 Critical, 4 High, 3 Medium, 2 Low, 1 Info)
      └── ASVS compliance matrix (47 checks: 31 PASS, 12 FAIL, 4 N/A)
```

## Agents

AI-Sec includes 5 specialized auditor agents. Each follows a 4-phase process: **Enumerate → Check → Test → Report.**

| Agent | Framework | What It Audits |
|-------|-----------|---------------|
| `web-app-auditor` | OWASP ASVS v4.0.3 L2 | Auth, sessions, access control, input validation, data protection, config |
| `api-auditor` | ASVS V13 + V2.10 | REST/GraphQL endpoints, webhooks, rate limiting, schema validation |
| `cicd-auditor` | OWASP CI/CD Top 10 | GitHub Actions, Docker, dependencies, secrets, branch protection |
| `infra-auditor` | CIS Benchmarks | Kubernetes, AWS/GCP/Azure, Terraform, network, IAM, secrets |
| `mobile-auditor` | OWASP MASVS v2.1 L1 | Storage, crypto, auth, network, platform security |

You can run agents individually:
```
Claude, run the web-app-auditor agent on this codebase
```

## Finding Format

Every finding includes severity, CVSS score, framework reference, code evidence, impact, and fix guidance:

```markdown
### [HIGH] AUTH-03: JWT tokens never expire

**CVSS:** 7.5 (AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N)
**Framework:** ASVS V3.5.3
**Component:** src/auth/jwt.service.ts:42

JWT tokens are issued with no expiration claim. Once issued, a token
is valid forever — a stolen token grants permanent access.

**Evidence:**
const token = jwt.sign({ userId }, SECRET);
// No expiresIn option — token never expires

**Impact:** Stolen tokens (via XSS, log exposure, or network interception)
grant permanent access to the victim's account.

**Recommendation:**
const token = jwt.sign({ userId }, SECRET, { expiresIn: '15m' });
// Add refresh token rotation for long-lived sessions
```

## Methodology

AI-Sec doesn't guess. Each agent uses a published industry framework with explicit requirements:

- **[OWASP ASVS v4.0.3](https://owasp.org/www-project-application-security-verification-standard/)** — 286 requirements across 14 chapters
- **[OWASP MASVS v2.1](https://mas.owasp.org/)** — Mobile security requirements across 7 categories
- **[CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)** — Cloud and Kubernetes hardening controls
- **[OWASP CI/CD Top 10](https://owasp.org/www-project-top-10-ci-cd-security-risks/)** — Pipeline security risks

Full checklists are in the [`methodology/`](methodology/) folder.

## Battle-Tested

Built from real audit methodology that found **87+ findings across 5 security zones** on a VARA-regulated crypto exchange in production. This isn't a toy — it's the same methodology used on a platform handling real money under regulatory oversight.

## What AI-Sec Is NOT

- **Not a replacement for pentesting.** AI-Sec does white-box code review. It doesn't test running applications.
- **Not a SAST scanner.** It doesn't pattern-match CVEs. It reasons about your architecture.
- **Not perfect.** It catches ~60-70% of what a senior security consultant finds. The delta is why [consulting tiers exist](https://sergey-ko.github.io/ai-sec-site/pricing).

## Want More?

| Need | Solution |
|------|----------|
| Quick scan of a public repo | Use this tool — it's free |
| Full audit with expert review | [Book a call](https://sergey-ko.github.io/ai-sec-site/contact) — starts at $2K |
| Compliance-ready report (SOC 2, ISO 27001) | [Enterprise tier](https://sergey-ko.github.io/ai-sec-site/pricing) — from $10K |
| Continuous monitoring | SaaS coming soon — [join waitlist](https://sergey-ko.github.io/ai-sec-site/) |

## Built By

**Sergey Kovalev** — CTO at a VARA-regulated crypto exchange. Building security tools because the vibecoding era needs them.

- [LinkedIn](https://www.linkedin.com/in/skovalev/)
- [Website](https://sergey-ko.github.io/ai-sec-site/)

## License

MIT — use it, fork it, audit everything.
