# Audit Findings Verification Report

> **Date:** 2026-04-01
> **Verified by:** AI-Sec re-verification (manual cross-check against live repos)
> **Method:** For each finding, fetched the referenced file from the repo's main branch on GitHub and confirmed the vulnerability pattern exists as described.

## Summary

| Repo | Total Web Findings | Confirmed | Partially Confirmed | Inaccurate | False Positive |
|------|-------------------|-----------|-------------------|------------|----------------|
| maybe-finance | 25 | 25 (100%) | 0 | 0 | 0 |
| Documenso | 13 | 13 (100%) | 0 | 0 | 0 |
| Hoppscotch | 11 | 10 (91%) | 1 | 0 | 0 |
| **Total** | **49** | **48** | **1** | **0** | **0** |

**98% of findings fully confirmed. Zero hallucinated findings.**

---

## maybe-finance (25/25 confirmed)

Repo: https://github.com/maybe-finance/maybe (main branch)

| # | Finding | Severity | Status | Evidence |
|---|---------|----------|--------|----------|
| CRITICAL-01 | OTP Secret Stored in Plaintext | CRITICAL | CONFIRMED | `db/schema.rb`: `t.string "otp_secret"`, no `encrypts` in `user.rb` |
| CRITICAL-02 | Plaid Tokens Conditionally Encrypted | CRITICAL | CONFIRMED | `plaid_item.rb`: conditional check against `credentials.active_record_encryption` which is never set for self-hosted |
| CRITICAL-03 | Session Cookie Missing `secure` Flag | CRITICAL | CONFIRMED | `authentication.rb`: no `secure: true`, no `same_site` |
| CRITICAL-04 | No Content Security Policy | CRITICAL | CONFIRMED | `content_security_policy.rb` entirely commented out |
| CRITICAL-05 | Sidekiq Web Unauthenticated Non-Prod | CRITICAL | CONFIRMED | Auth wrapped in `if Rails.env.production?`, default creds `maybe/maybe` |
| HIGH-01 | Lookbook Mounted Without Auth | HIGH | CONFIRMED | `routes.rb`: `mount Lookbook::Engine` with no auth gate |
| HIGH-02 | API Errors Leak Internal State | HIGH | CONFIRMED | Multiple controllers return `e.message` in JSON response |
| HIGH-03 | MFA Disable Without Re-Auth | HIGH | CONFIRMED | `mfa_controller.rb`: no password/OTP check before `disable_mfa!` |
| HIGH-04 | Password Change No Session Invalidation | HIGH | CONFIRMED | `passwords_controller.rb`: just `update` + redirect, no session cleanup |
| HIGH-05 | Permanent Session Cookie | HIGH | CONFIRMED | `cookies.signed.permanent` with no expiry/rotation |
| HIGH-06 | Impersonation `complete` Missing Auth | HIGH | CONFIRMED | `before_action :require_super_admin!` excludes `complete` |
| MEDIUM-01 | No Rate Limiting on Login | MEDIUM | CONFIRMED | `rack_attack.rb`: no throttle for `POST /sessions` |
| MEDIUM-02 | No SameSite on Session Cookie | MEDIUM | CONFIRMED | Same cookie line, no `same_site` attribute |
| MEDIUM-03 | Permissions Policy Not Configured | MEDIUM | CONFIRMED | `permissions_policy.rb` entirely commented out |
| MEDIUM-04 | Mass Assignment of Sensitive Attrs | MEDIUM | CONFIRMED | `user_params` permits `onboarded_at` and other timestamps |
| MEDIUM-05 | Invitation Role Controllable by Inviter | MEDIUM | CONFIRMED | `permit(:email, :role)` with no role validation |
| MEDIUM-06 | OAuth Token Expiry 1 Year | MEDIUM | CONFIRMED | `doorkeeper.rb`: `access_token_expires_in 1.year` |
| MEDIUM-07 | SQL Wildcard Injection in Search | MEDIUM | CONFIRMED | `"%#{params[:search]}%"` without `sanitize_sql_like` |
| LOW-01 | API Key Source Not Set | LOW | CONFIRMED | No `source: "web"` in create action |
| LOW-02 | Webhook Errors Expose Details | LOW | CONFIRMED | `error.message` in webhook response |
| LOW-03 | No Host Authorization in Production | LOW | CONFIRMED | `config.hosts` commented out |
| LOW-04 | Development Allows All Hosts | LOW | CONFIRMED | `config.hosts = nil` |
| INFO-01 | Doorkeeper SSL Disabled | INFO | CONFIRMED | `force_ssl_in_redirect_uri false` |
| INFO-02 | Encryption Keys from SECRET_KEY_BASE | INFO | CONFIRMED | SHA256 derivation from single key |
| INFO-03 | Faker in Development Group | INFO | CONFIRMED | Gemfile dev group |

---

## Documenso (13/13 confirmed)

Repo: https://github.com/documenso/documenso (main branch)

| # | Finding | Severity | Status | Evidence |
|---|---------|----------|--------|----------|
| FINDING-01 | Encryption Key Validation Commented Out | CRITICAL | CONFIRMED | `crypto.ts`: entire validation block commented out |
| FINDING-02 | Webhook Secret as Plaintext Header | HIGH | CONFIRMED | `execute-webhook-call.ts`: `X-Documenso-Secret: secret ?? ''` |
| FINDING-03 | No Rate Limiting on Signing Endpoints | HIGH | CONFIRMED | `signFieldWithToken` uses unauthenticated `procedure` |
| FINDING-04 | SSRF Fails Open on DNS Timeout | HIGH | CONFIRMED | `assert-webhook-url.ts`: catch block returns silently for non-AppError |
| FINDING-05 | Document Visibility Bypass via Team Email | MEDIUM | CONFIRMED | `get-envelope-by-id.ts`: no `teamId` constraint |
| FINDING-06 | Unauthenticated Signing Procedures | MEDIUM | CONFIRMED | Uses plain `procedure`, not `maybeAuthenticatedProcedure` |
| FINDING-07 | Webhook Secret Plaintext in DB | MEDIUM | CONFIRMED | Prisma schema: `secret String?` with no encryption |
| FINDING-08 | Missing Security Headers | MEDIUM | CONFIRMED | No CSP/HSTS/X-Frame-Options in middleware |
| FINDING-09 | API Token Expiration Not Enforced | MEDIUM | CONFIRMED | `expires DateTime?` nullable, no max lifetime |
| FINDING-10 | SameSite=None in Production | LOW | CONFIRMED | `sameSite: useSecureCookies ? 'none' : 'lax'` |
| FINDING-11 | Share Link Limited Entropy | LOW | CONFIRMED | `alphaid(14)` with 36-char alphabet |
| FINDING-12 | QR Token Limited Entropy | LOW | CONFIRMED | `prefixedId('qr')` with 22-char alphabet, 16 chars |
| FINDING-13 | Error Message Leakage | LOW | CONFIRMED | `console.log({ err })` + AppError messages returned |

---

## Hoppscotch (10/11 confirmed, 1 partially confirmed)

Repo: https://github.com/hoppscotch/hoppscotch (main branch)

| # | Finding | Severity | Status | Evidence |
|---|---------|----------|--------|----------|
| F-01 | IDOR in User History | HIGH | CONFIRMED | `user-history.service.ts`: uid accepted but never used in where clause |
| F-02 | Unauthenticated Onboarding | HIGH | CONFIRMED | `onboarding.controller.ts`: no `JwtAuthGuard`, only `ThrottlerBehindProxyGuard` |
| F-03 | Stored Credentials in Plaintext JSON | HIGH | CONFIRMED | Prisma schema: all request/environment Json fields unencrypted |
| F-04 | Weak Default Encryption Key | MEDIUM | CONFIRMED | `.env.example`: human-readable placeholder string |
| F-05 | Insecure Session Cookie Config | MEDIUM | CONFIRMED | `secure` tied to env var, `sameSite: 'lax'` not `strict` |
| F-06 | Shortcode Query Unauthenticated | MEDIUM | CONFIRMED | No `GqlAuthGuard` + `Math.random()` for ID generation |
| F-07 | Weak Default DB Password | LOW | CONFIRMED | `docker-compose.yml`: `testpass` with port 5432 exposed |
| W-01 | GraphQL Playground Enabled | WARN | CONFIRMED | Enabled when `PRODUCTION !== 'true'` |
| W-02 | First User Auto-Admin | WARN | CONFIRMED | `usersCount === 1` triggers `makeAdmin()` |
| W-03 | CORS origin: true Non-Prod | WARN | CONFIRMED | `enableCors({ origin: true })` |
| W-04 | Desktop Auth Open Redirect | WARN | **PARTIALLY CONFIRMED** | Raw tokens in response body: YES. Open redirect via `localhost.evil.com`: NO — code uses proper URL parsing with `new URL()`, not naive `startsWith()`. Report overstated this vector. |

### W-04 Detail

The report claimed the redirect-uri validation uses `startsWith('http://localhost')` which would allow `http://localhost.evil.com`. The actual code in `redirect-uri.validator.ts` uses `new URL(uri)` with exact hostname matching against `['localhost', '127.0.0.1', '[::1]']`. The open redirect vector is not exploitable. The raw-tokens-in-response-body concern remains valid.

---

## CI/CD Audits (not yet verified)

The 3 CI/CD audit reports (maybe-finance: 9 findings, Documenso: ~13 findings, Hoppscotch: ~10 findings) have not been cross-checked yet. These reference GitHub Actions workflows, Dockerfiles, and CI configuration files.
