# AI-Sec Demo — Terminal Recording
# Render with: vhs demo.tape
# Install VHS: https://github.com/charmbracelet/vhs
# Output: demo.gif (embed in README)

Output demo.gif

Set FontSize 14
Set Width 900
Set Height 500
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms
Set Padding 20

# Title
Type "# AI-Sec — AI-powered security audit"
Enter
Sleep 1s

# Show the clone (or install) step
Type "cd ~/projects/my-nextjs-app"
Enter
Sleep 500ms

# Run the audit
Type "claude /audit"
Enter
Sleep 2s

# Simulated output: stack detection
Type@0 "AI-Sec Stack Detection:"
Enter
Type@0 "  ✓ Web Application: Next.js 14 (TypeScript)"
Enter
Type@0 "  ✓ API Endpoints: 12 REST routes, 3 webhook handlers"
Enter
Type@0 "  ✓ CI/CD Pipeline: GitHub Actions (4 workflows), Dockerfile"
Enter
Type@0 "  ✗ Infrastructure: not found"
Enter
Type@0 "  ✗ Mobile: not found"
Enter
Sleep 1s
Type@0 ""
Enter
Type@0 "Agents to run: web-app-auditor, api-auditor, cicd-auditor"
Enter
Sleep 1s

# Agent dispatch
Type@0 ""
Enter
Type@0 "Launching 3 agents in parallel..."
Enter
Type@0 "  ▸ web-app-auditor  — OWASP ASVS v4.0.3 L2"
Enter
Type@0 "  ▸ api-auditor      — ASVS V13 + V2.10"
Enter
Type@0 "  ▸ cicd-auditor     — OWASP CI/CD Top 10"
Enter
Sleep 2s

# Progress
Type@0 ""
Enter
Type@0 "  ✓ cicd-auditor     complete (4 findings)"
Enter
Sleep 1s
Type@0 "  ✓ api-auditor      complete (5 findings)"
Enter
Sleep 1s
Type@0 "  ✓ web-app-auditor  complete (8 findings)"
Enter
Sleep 1s

# Report summary
Type@0 ""
Enter
Type@0 "═══════════════════════════════════════"
Enter
Type@0 "  AI-Sec Report: my-nextjs-app"
Enter
Type@0 "═══════════════════════════════════════"
Enter
Type@0 ""
Enter
Type@0 "  Zone              CRIT  HIGH  MED  LOW  INFO"
Enter
Type@0 "  ─────────────────────────────────────────────"
Enter
Type@0 "  Web Application     1     3    2    1     1"
Enter
Type@0 "  API Security        1     2    1    1     0"
Enter
Type@0 "  CI/CD Pipeline      0     1    2    1     0"
Enter
Type@0 "  ─────────────────────────────────────────────"
Enter
Type@0 "  Total               2     6    5    3     1"
Enter
Type@0 ""
Enter
Sleep 1s

# Top findings
Type@0 "  Top findings:"
Enter
Type@0 "  [CRIT] AUTH-01: JWT tokens issued with no expiration"
Enter
Type@0 "  [CRIT] API-05:  Webhook HMAC uses parsed body, not raw"
Enter
Type@0 "  [HIGH] AUTH-03: Session fixation — no ID rotation on login"
Enter
Type@0 ""
Enter
Type@0 "  Report: ./ai-sec-report.md"
Enter
Type@0 "  Run /track init to start tracking findings"
Enter
Sleep 3s
