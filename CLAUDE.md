# CLAUDE.md

## What this repo is

AI-Sec is an open-source Claude Code plugin that performs security audits. It ships skills (`/audit`, `/verify`, `/track`) and 6 specialized agents. There is no application code — only prompt files, methodology checklists, and examples.

## Structure

- `.claude/skills/` — user-facing skills (orchestration logic)
- `.claude/agents/` — specialized auditor agents (the actual audit work)
- `.claude-plugin/` — plugin packaging for distribution
- `methodology/` — OWASP/CIS checklists and templates. These are reference material — don't modify unless updating to a new framework version.
- `examples/` — real audit reports on open-source projects. Used for testing and content.

## Working on this repo

- **Test changes** by running `/audit` or `/verify` against repos in `examples/`
- **Agent prompts** are the core product — changes should be precise and tested
- **Methodology checklists** come from published frameworks (OWASP ASVS v4.0.3, MASVS v2.1, CIS EKS v1.5, CI/CD Top 10 2023). Don't invent requirements — cite the source.
- **Finding format** must stay consistent across all agents (see `methodology/finding-template.md`)

## Git

- Repo: `sergey-ko/ai-sec` (personal account, not FCE)
- If push fails: `gh auth switch --user sergey-ko`
- Author: `Sergey Kovalev <44134504+sergey-ko@users.noreply.github.com>`

## Key constraints

- AI-Sec is Sergey's independent product, not FCE's
- Website: ai-sec.pro
- Three-tier model: open-source (this repo) → SaaS → consulting
