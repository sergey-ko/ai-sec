# AI-Sec — Open-Source AI Security Audit

AI-Sec is an AI-powered security audit tool that uses Claude to reason about your codebase architecture — not just pattern-match CVEs. It follows industry-standard frameworks (OWASP ASVS, MASVS, CIS, CI/CD Top 10) and produces structured findings with severity, evidence, and fix guidance.

## How It Works

```
User runs: /audit (or Claude runs the audit skill)
  → Skill reads the repo, detects what's present (web app, API, mobile, CI/CD, infra)
  → Picks relevant agents (web-app, api, cicd, infra, mobile)
  → Agents run in parallel, each covering their OWASP/CIS framework
  → Findings merged into a single report: ai-sec-report.md
```

## Structure

```
ai-sec/
├── .claude/
│   ├── agents/                    # Specialized auditor agents
│   │   ├── web-app-auditor.md     # OWASP ASVS L2 — auth, sessions, access control, XSS, etc.
│   │   ├── api-auditor.md         # API + webhook security — ASVS V13, V2.10
│   │   ├── cicd-auditor.md        # OWASP CI/CD Top 10 — pipelines, deps, secrets
│   │   ├── infra-auditor.md       # CIS benchmarks — cloud, K8s, network, IAM
│   │   ├── mobile-auditor.md      # OWASP MASVS L1 — storage, crypto, network, platform
│   │   └── verify-auditor.md     # Cross-check findings — report mode + registry mode
│   └── skills/
│       ├── audit/SKILL.md         # Orchestrator — detect, dispatch, merge, update registry
│       ├── verify/SKILL.md        # /verify — validate findings are real, not hallucinated
│       └── track/SKILL.md         # /track — manage findings registry across audit runs
├── methodology/
│   ├── asvs-l2-checklist.md       # Full OWASP ASVS v4.0.3 L2 requirements
│   ├── masvs-l1-checklist.md      # Full OWASP MASVS v2.1 L1 requirements
│   ├── cis-eks-checklist.md       # CIS EKS Benchmark v1.5
│   ├── cicd-top10-checklist.md    # OWASP CI/CD Top 10 (2023)
│   ├── finding-template.md        # Standard finding format
│   └── findings-registry-template.yaml  # Template for tracking findings across runs
├── examples/
│   └── maybe-finance/             # First real audit (content piece)
├── README.md                      # GitHub landing page
├── LICENSE                        # MIT
└── CLAUDE.md                      # This file
```

## Agents

Each agent is a specialized security auditor that follows a 4-phase process:

1. **Enumerate** — read the codebase, map attack surface, identify trust boundaries
2. **Check** — systematically verify each framework requirement (PASS/FAIL/PARTIAL/NA)
3. **Test** — for each FAIL, describe exploitation scenario with evidence
4. **Report** — structured findings with severity, CVSS, evidence, fix guidance

Agents are framework-first, not solution-specific. They work on ANY repo by:
- Reading directory structure to find relevant code
- Identifying endpoints, auth flows, data flows
- Applying the checklist to what they find
- Producing findings in standard format

## Finding Format

```markdown
### [SEVERITY] ID: Title

**CVSS:** N.N
**Framework:** ASVS V4.1.1 (or CIS-EKS-3.1, CICD-SEC-1, etc.)
**Component:** file/path:line

Description of the vulnerability.

**Evidence:**
{code snippet or config showing the issue}

**Impact:** What an attacker can do.

**Recommendation:** Specific fix steps.
```

## Findings Registry

AI-Sec can track findings across audit runs using a YAML registry. This enables fast grep-based re-verification instead of full code re-review.

**Workflow:**
1. Run `/audit` to get the initial report
2. Run `/track init` to create `findings-registry.yaml` from the report
3. Fix issues in your code
4. Run `/track verify` to check which findings are resolved (uses grep patterns, not full re-audit)
5. Run `/audit` again periodically, then `/track update` to add new findings

**Commands:**
- `/track` — show open/resolved summary
- `/track init` — create registry from last audit report
- `/track verify` — grep-based verification of all open findings
- `/track update` — add new findings from latest report
- `/track diff` — show what changed since last verification

The registry template is at `methodology/findings-registry-template.yaml`.

## Using AI-Sec

### As a Claude Code skill (recommended)
```bash
# Clone this repo alongside your project
git clone https://github.com/sergey-ko/ai-sec.git

# In Claude Code, from your project directory:
/audit
```

### Agents can also be run individually
```
Claude, run the web-app-auditor agent on this repo
Claude, run the cicd-auditor agent on this repo
```

## Built by

Sergey Kovalev — CTO at a VARA-regulated crypto exchange. Built from real audit methodology that found 87+ findings across 5 security zones on a production fintech platform.

- LinkedIn: https://www.linkedin.com/in/skovalev/
- Website: https://sergey-ko.github.io/ai-sec-site/
