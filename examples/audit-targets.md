# AI-Sec Audit Targets

Open-source projects to audit for content (YouTube videos, case studies, demos).

## Completed

| Project | Stars | Stack | Findings | Report |
|---------|-------|-------|----------|--------|
| **maybe-finance** | 35K+ | Ruby on Rails | 25 web + 7 CI/CD | [web](maybe-finance-web-audit.md), [cicd](maybe-finance-cicd-audit.md) |

## Next Up

| # | Project | Stars | Stack | Why | Headline |
|---|---------|-------|-------|-----|----------|
| 1 | **Documenso** | 8K+ | Next.js + Prisma | E-signing = legally binding. Security is existential. | "Your e-signatures might not be legally valid" |
| 2 | **Hoppscotch** | 65K+ | Vue + Node | API testing tool — ironic if insecure | "We audited the API security tool. It has API security issues." |
| 3 | **Twenty** | 20K+ | Next.js + Node | Open-source CRM, handles customer PII | "Your open-source CRM is leaking customer data" |
| 4 | **Papermark** | 4K+ | Next.js | Doc sharing — access control IS the product | "The doc sharing app that lets anyone see your files" |
| 5 | **Dub.co** | 18K+ | Next.js + Prisma | Link management, high traffic, simple but popular | "The URL shortener with X security holes" |

## Selection Criteria

- High stars (visibility for content)
- Handles sensitive data (security findings are meaningful)
- Popular stack (Next.js, Rails, Django — relatable to audience)
- Irony factor (security tools that are insecure, finance apps with plaintext secrets)
- Good headline potential (shareable, slightly scary)
