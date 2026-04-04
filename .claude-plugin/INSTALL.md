## Installation

### Option 1: Plugin (recommended)
```bash
# Add the AI-Sec marketplace
/plugin marketplace add sergey-ko/ai-sec

# Install the audit plugin
/plugin install ai-sec

# Run an audit
/audit
```

### Option 2: Clone (manual)
```bash
git clone https://github.com/sergey-ko/ai-sec.git
# In Claude Code, from your project directory:
/audit
```

## What's included

### Skills
- `/audit` — Run a security audit against OWASP ASVS, MASVS, CIS, or CI/CD Top 10 frameworks
- `/verify` — Verify and cross-check security audit findings

### Agents
- `web-app-auditor` — Web application security auditor (OWASP ASVS)
- `api-auditor` — API security auditor
- `mobile-auditor` — Mobile application security auditor (OWASP MASVS)
- `infra-auditor` — Infrastructure security auditor (CIS benchmarks)
- `cicd-auditor` — CI/CD pipeline security auditor (CI/CD Top 10)
- `verify-auditor` — Cross-check and verify audit findings
