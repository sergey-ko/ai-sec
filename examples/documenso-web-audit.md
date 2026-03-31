# Security Audit: Documenso (Open-Source E-Signing Platform)

**Target:** Documenso v2.8.1 — `c:\Projects\ai-sec\examples\documenso\`
**Auditor:** AI-Sec (automated static analysis)
**Date:** 2026-03-28
**Methodology:** OWASP ASVS L2, manual source review
**Scope:** Web application (Remix + Hono), API (tRPC + ts-rest), Auth, Document lifecycle, Signing infrastructure

---

## Executive Summary

Documenso is a well-architected e-signing platform with solid fundamentals: proper session management (SHA-256 hashed tokens, signed cookies), CSRF protection on login, rate limiting on auth endpoints, bcrypt password hashing (cost 12), and a layered authorization model for document access. The PDF signing uses industry-standard CAdES detached signatures with optional HSM support.

However, several findings could undermine the legal validity and security guarantees that an e-signing platform **must** provide. The most critical issues involve **webhook secret transmission in plaintext headers** (enabling signature forgery notifications), **commented-out encryption key validation** (allowing production deployment with default/missing keys), and **insufficient recipient token entropy validation** that could enable signing link enumeration.

**Risk Rating:** MEDIUM-HIGH for an e-signing platform (findings #1-4 would be MEDIUM for a typical SaaS, but are elevated due to the legal/compliance nature of e-signatures)

---

## Architecture Overview

| Component | Technology | Security-Relevant Notes |
|-----------|-----------|------------------------|
| Frontend | Remix (React Router 7) | SSR, Hono middleware |
| API (public) | ts-rest (v1) + tRPC OpenAPI (v2) | Bearer token auth (SHA-512 hashed API keys) |
| API (internal) | tRPC | Session-based auth with middleware |
| Auth | Custom (Hono routes) | Session cookies (signed, httpOnly), bcrypt, TOTP 2FA, WebAuthn/Passkeys |
| Database | PostgreSQL (Prisma ORM) | |
| PDF Signing | @libpdf/core + P12/PKCS#12 or Google Cloud HSM | CAdES detached signatures, optional TSA |
| File Storage | Database (base64) or S3 | Presigned URLs with 1hr expiry |
| Encryption | XChaCha20-Poly1305 (@noble/ciphers) | For secondary data; session signing via HMAC |

### Attack Surface Map

| Surface | Endpoints | Auth Required | Notes |
|---------|-----------|--------------|-------|
| Document signing | `/embed/v0/sign/:token`, `/sign/:token` | Token only (recipient token) | Core signing flow |
| Direct template signing | `/embed/v0/direct/:token` | Template direct link token | Creates document + signs in one request |
| tRPC (internal) | `/api/trpc/*` | Session or API key | `procedure` = unauthenticated, `authenticatedProcedure` = required |
| REST API v1 | `/api/v1/*` | Bearer API key | Full document CRUD |
| tRPC OpenAPI v2 | Various paths | Bearer API key | Public API surface |
| Auth routes | `/api/auth/*` | Varies | Login, signup, password reset, 2FA, OAuth |
| Webhook trigger | `/api/webhook/trigger` | Signed body (`x-webhook-signature`) | Internal webhook dispatch |
| Stripe webhook | `/api/stripe/webhook` | Stripe signature | Payment events |
| Document share links | `/share/:slug` | Slug only | View completed documents |
| QR access tokens | `/d/:token` | QR token only | View completed documents via certificate QR code |
| Admin panel | `/_authenticated/admin/*` | Admin role check | Full platform management |
| Embeds | `/embed/v1/*`, `/embed/v2/*` | Varies | Iframe-embeddable authoring + signing |

---

## Findings

### CRITICAL

#### FINDING-01: Encryption Key Validation Commented Out in Production

**ASVS:** V8.3.1 (Sensitive Data Protection), V6.2.1 (Cryptographic Algorithms)
**File:** `packages/lib/constants/crypto.ts`

The entire encryption key validation block is commented out:

```typescript
// if (typeof window === 'undefined') {
//   if (!DOCUMENSO_ENCRYPTION_KEY || !DOCUMENSO_ENCRYPTION_SECONDARY_KEY) {
//     throw new Error('Missing DOCUMENSO_ENCRYPTION_KEY or DOCUMENSO_ENCRYPTION_SECONDARY_KEY keys');
//   }
//   if (DOCUMENSO_ENCRYPTION_KEY === DOCUMENSO_ENCRYPTION_SECONDARY_KEY) {
//     throw new Error(
//       'DOCUMENSO_ENCRYPTION_KEY and DOCUMENSO_ENCRYPTION_SECONDARY_KEY cannot be equal',
//     );
//   }
// }
```

This means:
1. The application can start **without encryption keys** -- `encryptSecondaryData()` will only throw at runtime when first called.
2. There is no guard against using **default/weak keys** (the `CAFEBABE` check is also commented out).
3. Primary and secondary keys can be **identical**, defeating the purpose of key separation.

The `DOCUMENSO_ENCRYPTION_SECONDARY_KEY` is used for the internal webhook signature verification (`sign.ts` / `verify.ts`) and for `encryptSecondaryData` which protects miscellaneous sensitive data. Without this key or with a weak key, internal webhook trigger endpoints can be spoofed.

**Impact:** An attacker who guesses or discovers the default encryption key can forge internal webhook signatures and trigger arbitrary webhook events. For self-hosted instances, the default `.env.example` key would be known publicly.

**Remediation:** Uncomment and enforce the validation. Add a startup check that fails hard if keys are missing or default. Consider using environment variable validation (e.g., Zod) at application bootstrap.

---

### HIGH

#### FINDING-02: Webhook Secret Sent as Plaintext Header (No HMAC)

**ASVS:** V13.3.1 (API Security), V8.1.1 (Data Protection)
**File:** `packages/lib/server-only/webhooks/execute-webhook-call.ts`

Webhook secrets are transmitted as a **static plaintext header** rather than as an HMAC signature of the payload:

```typescript
headers: {
  'Content-Type': 'application/json',
  'X-Documenso-Secret': secret ?? '',
},
```

Problems:
1. The secret is sent in **every request** as a static value, making it vulnerable to interception via MITM, logging, or any proxy that captures headers.
2. There is **no HMAC over the request body**. A webhook consumer cannot verify that the payload was not tampered with in transit.
3. An empty string is sent when no secret is configured (`secret ?? ''`), which means the header is always present -- consumers may incorrectly assume they are "verified."

Compare with industry standard (e.g., Stripe `Stripe-Signature`, GitHub `X-Hub-Signature-256`): the secret is never transmitted; instead, `HMAC-SHA256(secret, body)` is sent and the consumer recomputes it locally.

**Impact:** Webhook consumers for document lifecycle events (DOCUMENT_SIGNED, DOCUMENT_COMPLETED) cannot reliably verify event authenticity. An attacker who intercepts one webhook call can replay the secret indefinitely. For an e-signing platform, this means signing completion events could be forged.

**Remediation:** Replace `X-Documenso-Secret` with `X-Documenso-Signature: sha256=HMAC(secret, body)`. Provide client libraries for signature verification. Deprecate the plaintext header.

---

#### FINDING-03: Recipient Signing Tokens Use `nanoid()` Default Length (21 chars)

**ASVS:** V4.2.1 (Access Control), V2.5.4 (Credential Recovery)
**File:** `packages/lib/server-only/recipient/set-document-recipients.ts` (line: `token: nanoid()`)

Recipient tokens are the sole authentication mechanism for signing a document. They are generated with `nanoid()` at default length (21 characters, alphabet a-zA-Z0-9_-, 64 chars = 6 bits/char = 126 bits of entropy).

While 126 bits is strong in isolation, the security depends on the full chain:

1. **No rate limiting on signing endpoints.** The `signFieldWithToken` and `completeDocumentWithToken` tRPC procedures use `procedure` (unauthenticated, no rate limit middleware), not `authenticatedProcedure`:

```typescript
// packages/trpc/server/field-router/router.ts
signFieldWithToken: procedure  // <-- No auth, no rate limit
  .input(ZSignFieldWithTokenMutationSchema)
  .mutation(async ({ input, ctx }) => { ... })
```

2. **Tokens are indexed** (`@@index([token])` on Recipient), meaning database lookups are fast.

3. **No account lockout or alerting** when invalid tokens are submitted.

For a targeted attack where the attacker knows a document exists (e.g., from a leaked email notification), the token is the only barrier. The lack of rate limiting means automated brute-force attempts face no server-side throttling.

**Impact:** While the 126-bit token space makes random brute force infeasible, the lack of rate limiting on signing endpoints creates unnecessary risk. A partial token leak (e.g., from URL referer headers, browser history, email logs) combined with no rate limiting could enable enumeration.

**Remediation:**
1. Add rate limiting to `signFieldWithToken`, `removeSignedFieldWithToken`, and `completeDocumentWithToken` endpoints.
2. Consider adding a honeypot/alerting mechanism for repeated invalid token attempts.
3. Add `Referrer-Policy: no-referrer` headers for signing pages to prevent token leakage via HTTP Referer.

---

#### FINDING-04: SSRF Protection Fails Open on DNS Timeout

**ASVS:** V13.1.1 (API Security), V5.2.6 (Sanitization)
**File:** `packages/lib/server-only/webhooks/assert-webhook-url.ts`

The SSRF protection for webhook URLs has a **fail-open** design in the DNS resolution path:

```typescript
} catch (err) {
  if (err instanceof AppError) {
    throw err;
  }
  return; // <-- Silently allows the URL through on any non-AppError
}
```

The DNS lookup timeout is only **250ms**. If DNS resolution takes longer (common for internal DNS, slow resolvers, or deliberate slowloris-style DNS responses), the check passes silently, and the webhook request proceeds to the potentially private URL.

Additionally, the `isPrivateUrl` check only validates the initial URL string, not resolved addresses for all DNS resolution paths. A DNS rebinding attack where the initial resolution returns a public IP and a subsequent resolution (during actual fetch) returns a private IP would bypass this check entirely.

**Impact:** An attacker with webhook creation permissions (requires team MANAGE_TEAM role) could configure a webhook URL that resolves to internal services, potentially exfiltrating document data or accessing internal APIs.

**Remediation:**
1. Change the catch block to fail-closed: deny the request on any DNS resolution error/timeout.
2. Increase the DNS timeout or make it configurable.
3. Consider using a dedicated HTTP proxy for webhook delivery that blocks private IP ranges at the network level.
4. Pin the resolved IP and use it for the actual fetch to prevent DNS rebinding.

---

### MEDIUM

#### FINDING-05: Document Visibility Bypass via Team Email

**ASVS:** V4.1.2 (Access Control)
**File:** `packages/lib/server-only/envelope/get-envelope-by-id.ts`

The `getEnvelopeWhereInput` function grants document access if the requesting user belongs to a team whose team email matches the document sender's email:

```typescript
// Allow access to documents sent from the team email.
if (team.teamEmail) {
  envelopeOrInput.push({
    user: {
      email: team.teamEmail.email,
    },
  });
}
```

This query has no `teamId` constraint on the inner user lookup. If Team A configures their team email to match the email of a user in Team B, members of Team A could potentially access documents owned by that user in Team B, **regardless of document visibility settings**.

**Impact:** Cross-team document access if team emails can be configured to match arbitrary user emails. The severity depends on whether team email configuration is validated against email ownership.

**Remediation:** Add `teamId` filtering to the team email access check to ensure it only grants access within the same team context.

---

#### FINDING-06: `signFieldWithToken` and `removeSignedFieldWithToken` Use Unauthenticated Procedure

**ASVS:** V4.1.1 (Access Control)
**File:** `packages/trpc/server/field-router/router.ts`

Both `signFieldWithToken` and `removeSignedFieldWithToken` use `procedure` (fully unauthenticated) rather than `maybeAuthenticatedProcedure`:

```typescript
signFieldWithToken: procedure      // No session check at all
removeSignedFieldWithToken: procedure  // No session check at all
```

While these endpoints require a valid recipient token, the use of `procedure` means:
1. No session information is available for audit logging (the user context may be null).
2. No CSRF token validation occurs for these mutation endpoints.
3. The endpoints appear in tRPC batch calls alongside authenticated endpoints, potentially leaking the session state.

Since signing is the core business operation, it should capture maximum context for audit trails and legal defensibility.

**Remediation:** Use `maybeAuthenticatedProcedure` instead of `procedure` to capture session context when available. This preserves the ability for unauthenticated recipients to sign while enriching audit logs when the signer is logged in.

---

#### FINDING-07: Webhook Secret Stored in Plaintext in Database

**ASVS:** V8.3.1 (Data Protection)
**File:** `packages/prisma/schema.prisma` (Webhook model)

```prisma
model Webhook {
  secret String?  // <-- Plaintext
}
```

The webhook secret is stored as a nullable plaintext string. Combined with FINDING-02 (secret sent as plaintext header), a database breach exposes all webhook secrets, allowing the attacker to impersonate Documenso webhook deliveries to all configured endpoints.

**Remediation:** Encrypt webhook secrets at rest using the application encryption key. Only decrypt when executing webhook calls.

---

#### FINDING-08: No Content-Security-Policy or Security Headers Enforcement

**ASVS:** V14.4.3 (HTTP Security Headers)
**File:** `apps/remix/server/middleware.ts`

The application middleware does not set security headers:
- No `Content-Security-Policy` header
- No `Strict-Transport-Security` header
- No `X-Content-Type-Options` header
- No `X-Frame-Options` header (especially important given embed support)
- No `Referrer-Policy` header (important for signing token protection)

For the embed use case (`/embed/*` routes), the absence of `X-Frame-Options` is intentional, but there should be a strict CSP with `frame-ancestors` to control which domains can embed the signing experience.

**Remediation:** Add a security headers middleware that sets appropriate headers for each route group (main app, embed routes, API routes).

---

#### FINDING-09: API Token Expiration Not Enforced at Team Level

**ASVS:** V3.3.1 (Session Timeout)
**File:** `packages/prisma/schema.prisma` (ApiToken model)

```prisma
model ApiToken {
  expires DateTime?  // <-- Optional
}
```

API tokens can be created without an expiration date (`expires` is nullable). For an e-signing platform handling legally binding documents, long-lived API tokens represent a significant risk if compromised. There is no mechanism for:
1. Maximum token lifetime enforcement
2. Automatic token rotation
3. Team-level policies on token expiration

**Remediation:** Consider adding a maximum token lifetime (e.g., 1 year) enforced at creation time. Add token last-used tracking for inactive token detection.

---

### LOW

#### FINDING-10: Session Cookie `sameSite: 'none'` in Production

**ASVS:** V3.4.3 (Cookie-Based Session Management)
**File:** `packages/auth/server/lib/session/session-cookies.ts`

```typescript
export const sessionCookieOptions = {
  sameSite: useSecureCookies ? 'none' : 'lax',
  secure: useSecureCookies,
};
```

In production (HTTPS), the session cookie is set to `SameSite=None`. While the `Secure` flag is also set, `SameSite=None` allows the cookie to be sent in cross-origin requests, which is required for the embed use case but weakens CSRF protection.

CSRF is mitigated by the explicit CSRF token check on login, but other authenticated mutation endpoints (tRPC) rely on the trpc middleware which does not perform CSRF validation.

**Impact:** Lower risk due to signed cookies and CSRF checks on login, but cross-origin requests to tRPC mutation endpoints may succeed if other CSRF protections are bypassed.

**Remediation:** Consider setting `SameSite=Lax` for the main application and using a separate cookie configuration for embed routes.

---

#### FINDING-11: Share Link Slugs Use Limited Entropy

**ASVS:** V4.2.1 (Access Control)
**File:** `packages/lib/server-only/share/create-or-get-share-link.ts`

Document share links use `alphaid(14)` which generates a 14-character string from a 36-character alphabet (lowercase alphanumeric):

```typescript
slug: alphaid(14), // 36^14 ~= 6.1 * 10^21 ~= 72 bits of entropy
```

72 bits is generally acceptable but lower than the 126 bits used for recipient tokens. Share links provide read access to completed documents, which may contain sensitive legal agreements.

**Remediation:** Increase to `alphaid(21)` to match the entropy level of other tokens in the system.

---

#### FINDING-12: QR Token Uses `prefixedId('qr')` with 16-Character Length

**ASVS:** V4.2.1 (Access Control)
**File:** `packages/lib/jobs/definitions/internal/seal-document.handler.ts`

The QR code token used to view completed documents via the certificate QR code is generated with:

```typescript
qrToken: prefixedId('qr') // "qr_" + fancyId(16) where fancyId uses 22-char alphabet
```

`fancyId(16)` uses a 22-character alphabet (`abcdefhiklmnorstuvwxyz`), giving 16 * log2(22) ~= 71 bits of entropy. While the QR token only grants access to completed (already signed) documents, the reduced alphabet (missing `g`, `j`, `p`, `q`) is unusual and suggests an intentional restriction, though no documentation explains the rationale.

**Remediation:** Document the alphabet choice or increase token length to compensate.

---

#### FINDING-13: Error Messages in API May Leak Internal State

**ASVS:** V7.4.1 (Error Handling)
**File:** `packages/api/v1/middleware/authenticated.ts`

```typescript
} catch (err) {
  console.log({ err }); // Logs full error object to console
  // ...
  if (err instanceof AppError) {
    message = err.message; // Returns AppError message to client
  }
}
```

The `console.log({ err })` in the API middleware logs the full error object (including stack traces) to stdout. In container environments, this may end up in log aggregation services. The error message is also returned to the client when it's an AppError, which may contain internal details depending on how AppErrors are constructed throughout the codebase.

**Remediation:** Use structured logging (`logger.error()`) instead of `console.log()` for errors. Sanitize error messages before returning to API clients.

---

## ASVS L2 Compliance Summary

| ASVS Chapter | Status | Notes |
|--------------|--------|-------|
| V2: Authentication | PASS (with notes) | Bcrypt cost 12, rate limiting on all auth endpoints, CSRF on login, email verification required. 2FA (TOTP + passkeys) well-implemented. Note: OIDC has `NEXT_PRIVATE_OIDC_SKIP_VERIFY` option that can bypass email verification. |
| V3: Session Management | PASS | SHA-256 hashed session tokens, signed cookies, 30-day lifetime with sliding window (15-day renewal), proper invalidation on password change/reset. |
| V4: Access Control | PARTIAL FAIL | Strong document access control (`getEnvelopeWhereInput` with multi-reviewer comment). FINDING-05 (team email bypass), FINDING-03 (no rate limit on signing), FINDING-06 (unauthenticated signing procedures). |
| V5: Validation | PASS | Zod schemas on all inputs, Prisma parameterized queries (no raw SQL injection surface), Hono sValidator on auth routes. |
| V7: Error Handling | PARTIAL FAIL | FINDING-13 (error message leakage). Good: consistent AppError usage throughout. |
| V8: Data Protection | PARTIAL FAIL | FINDING-01 (encryption key validation), FINDING-07 (plaintext webhook secrets). Good: signed cookies, hashed API tokens, encrypted secondary data. |
| V13: API Security | PARTIAL FAIL | FINDING-02 (webhook secret as plaintext), FINDING-04 (SSRF fail-open). Good: proper auth middleware, typed API contracts. |
| V14: Configuration | PARTIAL FAIL | FINDING-08 (missing security headers). Good: secure cookie configuration in production, environment-based configuration. |

---

## Positive Security Properties

1. **Document integrity chain.** PDFs are digitally signed with CAdES detached signatures (or ETSI-compliant subfilter). The signing uses either local P12 certificates or Google Cloud HSM, with optional timestamping authority (TSA) and long-term validation (LTV) support. This is strong.

2. **Comprehensive audit logging.** Every document action (create, open, field insert, sign, complete) generates typed audit logs with IP address, user agent, and user context. Audit logs are embedded into the signed PDF as a certificate page.

3. **Defense-in-depth on document access.** `getEnvelopeWhereInput` has explicit "do not modify" comments, requires minimum two reviewers, includes backup validation checks, and constructs layered OR queries for access control. This is unusually careful for open-source software.

4. **Session security.** Sessions use SHA-256 hashed tokens stored server-side (not JWTs), signed cookies via HMAC, proper expiration with sliding window, and full invalidation on password change.

5. **Rate limiting on auth endpoints.** Login, signup, email verification, password reset, and forgot password all have per-IP and per-identifier rate limiting.

6. **API token hashing.** API tokens are hashed with SHA-512 before storage, so a database breach does not immediately expose API credentials.

7. **Multi-factor document auth.** Documents can require account authentication, password, TOTP 2FA, or WebAuthn passkeys for both access and signing actions. This is a differentiated security feature.

---

## Recommendations Priority

| Priority | Finding | Effort | Impact |
|----------|---------|--------|--------|
| P0 | #01: Uncomment encryption key validation | 1 hour | Prevents production deployment with missing/weak keys |
| P0 | #02: Replace plaintext webhook secret with HMAC | 4 hours | Industry-standard webhook verification |
| P1 | #03: Rate limit signing endpoints | 2 hours | Prevents token brute-force |
| P1 | #04: Fix SSRF fail-open to fail-closed | 1 hour | Prevents internal network access |
| P1 | #08: Add security headers middleware | 2 hours | Prevents XSS, clickjacking, token leakage |
| P2 | #05: Fix team email access bypass | 2 hours | Prevents cross-team access |
| P2 | #06: Upgrade signing procedures to maybeAuthenticated | 1 hour | Better audit trails |
| P2 | #07: Encrypt webhook secrets at rest | 3 hours | Defense in depth |
| P3 | #09: Enforce API token expiration | 2 hours | Reduces long-lived credential risk |
| P3 | #10: Use SameSite=Lax for non-embed routes | 1 hour | CSRF hardening |
| P3 | #11-12: Increase token entropy | 30 min | Consistency |
| P3 | #13: Structured error logging | 1 hour | Prevents info leakage |

---

*Audit performed by AI-Sec automated security analysis. Findings are based on static source code review without runtime testing. False positives are possible. A penetration test is recommended to validate exploitability.*
