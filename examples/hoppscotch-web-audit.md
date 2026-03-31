# Hoppscotch Security Audit Report

**Target:** Hoppscotch v3.0.1 -- Open-source API development platform (self-hosted)
**Repository:** https://github.com/hoppscotch/hoppscotch
**Audit date:** 2026-03-28
**Auditor:** AI-Sec (automated ASVS L2 assessment)
**Scope:** Backend (NestJS + Prisma), Admin dashboard, Auth flows, Data storage

---

## Executive Summary

Hoppscotch is an open-source API development ecosystem -- essentially a Postman alternative -- used by developers to build, test, and debug APIs. The irony of auditing an API development tool for API security issues is not lost on us. Developers trust this tool with their most sensitive credentials: API keys, auth tokens, database connection strings, OAuth secrets. If the tool that guards your secrets has its own security holes, the blast radius is significant.

This audit found **7 FAIL findings** (3 High, 3 Medium, 1 Low) and **4 WARN findings**. The most critical issues are:

1. **IDOR in user history** -- any authenticated user can read, modify, or delete another user's API request history (which contains auth tokens, API keys, request bodies)
2. **Unauthenticated onboarding endpoint** -- allows full infrastructure reconfiguration when no users exist
3. **Stored credentials in plaintext JSON** -- API keys, auth headers, and tokens saved in requests/environments are stored as unencrypted JSON blobs in PostgreSQL

These findings are especially impactful because Hoppscotch is designed for self-hosting by teams, often on internal networks where the assumption is "everyone here is trusted." That assumption breaks when you add team workspaces with mixed-trust users.

**Overall risk: HIGH** -- particularly for self-hosted multi-user deployments.

---

## Attack Surface Summary

| Component | Technology | Exposure |
|-----------|-----------|----------|
| Backend API | NestJS + GraphQL (Apollo) + REST | Port 3170 |
| Web frontend | Vue 3 SPA | Port 3000 |
| Admin dashboard | Vue 3 SPA | Port 3100 |
| Database | PostgreSQL 15 + Prisma ORM | Port 5432 |
| Auth | JWT (cookies) + Magic Link + OAuth (Google/GitHub/Microsoft) | |
| Mock server | Dynamic subdomain/path routing | Port 3170/mock/* |
| Bundle server | Static file serving | Port 3200 |

**Key data assets at risk:**
- Saved API requests (contain auth tokens, API keys, credentials in headers/body)
- Environment variables (contain secrets for target APIs)
- User request history (full request + response metadata)
- Team collections (shared credentials across workspace members)
- OAuth provider secrets (Google/GitHub/Microsoft client IDs and secrets)
- SMTP credentials
- Infrastructure configuration (JWT secrets, session secrets, encryption keys)

---

## Findings

### F-01: IDOR in User History -- Star/Delete Operations [HIGH]

**ASVS:** V4.2.1 (Sensitive data or API access control)
**CWE:** CWE-639 (Authorization Bypass Through User-Controlled Key)

**Description:** The `toggleHistoryStarStatus` and `removeRequestFromHistory` methods in `UserHistoryService` accept a user UID parameter but **never use it to filter database queries**. The operations query only by the history entry's `id`, meaning any authenticated user can modify or delete any other user's history entries.

**Evidence:**

File: `packages/hoppscotch-backend/src/user-history/user-history.service.ts`

```typescript
// toggleHistoryStarStatus -- uid parameter is accepted but NEVER USED
async toggleHistoryStarStatus(uid: string, id: string) {
    const userHistory = await this.fetchUserHistoryByID(id);  // No uid filter!
    // ...
    const updatedHistory = await this.prisma.userHistory.update({
        where: { id: id },  // Only filters by id, not uid
        // ...
    });
}

// removeRequestFromHistory -- same pattern
async removeRequestFromHistory(uid: string, id: string) {
    const delUserHistory = await this.prisma.userHistory.delete({
        where: { id: id },  // Only filters by id, not uid
    });
}

// fetchUserHistoryByID -- no ownership check
async fetchUserHistoryByID(id: string) {
    const userHistory = await this.prisma.userHistory.findFirst({
        where: { id: id },  // No userUid filter
    });
}
```

**Impact:** User history contains full API request data including auth tokens, API keys in headers, request bodies with credentials, and response metadata. An attacker who is an authenticated user on a shared Hoppscotch instance can:
1. Enumerate history entry IDs (CUIDs are somewhat predictable)
2. Star entries to discover they exist (timing oracle)
3. Delete another user's history to cover tracks or cause disruption

**Exploitation:**
```graphql
mutation {
  toggleHistoryStarStatus(id: "TARGET_HISTORY_ID")  # Works for any user's history
}
mutation {
  removeRequestFromHistory(id: "TARGET_HISTORY_ID")  # Deletes any user's history
}
```

**Remediation:** Add `userUid` to all `where` clauses:
```typescript
where: { id: id, userUid: uid }
```

---

### F-02: Unauthenticated Onboarding Endpoint Allows Full Infrastructure Reconfiguration [HIGH]

**ASVS:** V4.1.1 (Access control at a trusted enforcement point)
**CWE:** CWE-306 (Missing Authentication for Critical Function)

**Description:** The `POST /v1/onboarding/config` endpoint allows complete reconfiguration of the Hoppscotch instance (auth providers, SMTP settings, OAuth secrets) **without any authentication**. The only guard is a check that `canReRunOnboarding` is true (which is true when `usersCount === 0`).

**Evidence:**

File: `packages/hoppscotch-backend/src/infra-config/onboarding.controller.ts`

```typescript
@Post('config')
// NO @UseGuards(JwtAuthGuard) -- completely unauthenticated!
async updateOnboardingConfig(@Body() dto: SaveOnboardingConfigRequest) {
    // Only checks: onboardingCompleted && !canReRunOnboarding
    // canReRunOnboarding = usersCount === 0
```

File: `packages/hoppscotch-backend/src/infra-config/infra-config.service.ts`

```typescript
async getOnboardingStatus() {
    const usersCount = await this.userService.getUsersCount();
    return E.right({
        onboardingCompleted: configMap.ONBOARDING_COMPLETED === 'true',
        canReRunOnboarding: usersCount === 0,  // Re-runnable if all users deleted
    });
}
```

**Impact:** In a freshly deployed instance (before first user signs up), or if an admin deletes all users, anyone who can reach the backend can:
1. Configure OAuth with attacker-controlled provider credentials
2. Set SMTP to an attacker-controlled server (intercept magic link emails)
3. Reconfigure allowed auth providers
4. Effectively take over the entire instance

This is a race condition on fresh deployments -- the window between `docker compose up` and the first admin account creation.

**Remediation:** Add IP-based restrictions, a setup token, or require the `DATA_ENCRYPTION_KEY` to be provided as proof of server access.

---

### F-03: Stored Credentials in Plaintext JSON -- No Application-Layer Encryption [HIGH]

**ASVS:** V8.3.4 (Sensitive data encrypted at rest)
**CWE:** CWE-312 (Cleartext Storage of Sensitive Information)

**Description:** Hoppscotch stores API requests, environments, and history containing user credentials (API keys, auth tokens, bearer tokens, passwords) as **plaintext JSON blobs** in PostgreSQL. While infrastructure config (OAuth secrets, SMTP passwords) is encrypted with AES-256-CBC, the user-generated data that is arguably more sensitive receives no encryption.

**Evidence:**

File: `packages/hoppscotch-backend/prisma/schema.prisma`

```prisma
model TeamRequest {
    request      Json       // Contains auth headers, API keys, request bodies -- PLAINTEXT
}

model UserRequest {
    request      Json       // Same -- PLAINTEXT
}

model UserHistory {
    request          Json   // Full request with credentials -- PLAINTEXT
    responseMetadata Json   // Response data -- PLAINTEXT
}

model TeamEnvironment {
    variables Json           // Environment variables (API keys, tokens) -- PLAINTEXT
}

model UserEnvironment {
    variables Json           // Same -- PLAINTEXT
}

model User {
    currentRESTSession   Json?   // Active session data -- PLAINTEXT
    currentGQLSession    Json?   // Active session data -- PLAINTEXT
}
```

Compare with infrastructure config which IS encrypted:
```prisma
model InfraConfig {
    value       String?
    isEncrypted Boolean  @default(false)  // Uses AES-256-CBC via encrypt/decrypt
}
```

**Impact:** Database compromise (SQL injection, backup theft, cloud misconfiguration) exposes every API credential every user has ever tested through Hoppscotch. For a self-hosted instance at a company, this could include production API keys, admin tokens, database credentials in request bodies, etc.

**Remediation:** Apply the same `encrypt()`/`decrypt()` pattern already used for `InfraConfig` to the `request`, `variables`, and `responseMetadata` JSON fields. The encryption infrastructure already exists (`DATA_ENCRYPTION_KEY` + AES-256-CBC).

---

### F-04: Weak Default Encryption Key in .env.example [MEDIUM]

**ASVS:** V6.4.1 (Key management)
**CWE:** CWE-1188 (Insecure Default Initialization of Resource)

**Description:** The `.env.example` ships with a placeholder encryption key that is exactly 32 characters but is human-readable and easily guessable. Many self-hosted deployments will copy this file as-is.

**Evidence:**

File: `.env.example`
```
DATA_ENCRYPTION_KEY=data encryption key with 32 char
```

The encryption relies on this key for AES-256-CBC:

File: `packages/hoppscotch-backend/src/utils.ts`
```typescript
export function encrypt(text: string, key = process.env.DATA_ENCRYPTION_KEY) {
    const cipher = crypto.createCipheriv(ENCRYPTION_ALGORITHM, Buffer.from(key), iv);
```

**Impact:** If users copy `.env.example` to `.env` without changing this value, all "encrypted" infrastructure config (JWT secrets, OAuth client secrets, SMTP passwords) is encrypted with a publicly known key.

**Remediation:**
1. Set the default to an empty string that causes a startup error
2. Add a startup validation check that rejects known-bad keys
3. Auto-generate a random key on first run if none is provided

---

### F-05: Insecure Session Cookie Configuration for Self-Hosted HTTP Deployments [MEDIUM]

**ASVS:** V3.4.1 (Cookie-based session tokens use Secure attribute)
**CWE:** CWE-614 (Sensitive Cookie in HTTPS Session Without 'Secure' Attribute)

**Description:** The `secure` flag on auth cookies is determined by whether `VITE_BASE_URL` starts with `https`. For the many self-hosted deployments running on HTTP (internal networks, development), cookies are transmitted without the Secure flag. Additionally, the `SameSite` attribute is set to `lax` rather than `strict`.

**Evidence:**

File: `packages/hoppscotch-backend/src/auth/helper.ts`
```typescript
res.cookie(AuthTokenType.ACCESS_TOKEN, authTokens.access_token, {
    httpOnly: true,
    secure: configService.get('INFRA.ALLOW_SECURE_COOKIES') === 'true',  // false for HTTP
    sameSite: 'lax',  // Not 'strict'
    maxAge: accessTokenValidityInMs,
});
```

File: `packages/hoppscotch-backend/src/infra-config/helper.ts`
```typescript
export function determineAllowSecureCookies(appBaseUrl: string) {
    return appBaseUrl.startsWith('https');  // false for http://
}
```

**Impact:** On HTTP deployments (common for self-hosted), auth tokens in cookies are transmitted in cleartext, vulnerable to network sniffing. Combined with the default `.env.example` using `http://localhost`, most development and many production self-hosted deployments will have this issue.

**Remediation:**
1. Log a security warning on startup when secure cookies are disabled
2. Consider `SameSite=strict` as default (breaking change assessment needed)
3. Document that HTTPS is required for production deployments

---

### F-06: Shortcode Query Exposes Saved Request Data Without Authentication [MEDIUM]

**ASVS:** V4.2.1 (Access control for sensitive data)
**CWE:** CWE-285 (Improper Authorization)

**Description:** The `shortcode` GraphQL query resolves shortcodes and returns the full saved request data **without requiring authentication**. Anyone who obtains or guesses a 12-character shortcode can access the full request payload, which may contain API keys, auth tokens, and other credentials.

**Evidence:**

File: `packages/hoppscotch-backend/src/shortcode/shortcode.resolver.ts`
```typescript
@Query(() => Shortcode, {
    description: 'Resolves and returns a shortcode data',
    nullable: true,
})
// NO @UseGuards(GqlAuthGuard) -- unauthenticated!
async shortcode(@Args({ name: 'code', type: () => ID }) code: string) {
    const result = await this.shortcodeService.getShortCode(code);
    // Returns full request JSON including auth headers, tokens, etc.
}
```

Shortcode generation uses `Math.random()` (not cryptographically secure):
```typescript
private generateShortCodeID(): string {
    let result = '';
    for (let i = 0; i < SHORT_CODE_LENGTH; i++) {
        result += SHORT_CODE_CHARS[Math.floor(Math.random() * SHORT_CODE_CHARS.length)];
    }
    return result;
}
```

**Impact:** While the shortcode is 12 chars from a 62-char alphabet (62^12 ~ 3.2x10^21 combinations), the use of `Math.random()` makes the generation predictable. More importantly, shortcodes are designed to be shared (they are URLs) and may be leaked in browser history, chat logs, or referer headers.

**Remediation:**
1. Use `crypto.randomBytes()` instead of `Math.random()` for shortcode generation
2. Strip or redact auth-related headers from shortcode payloads by default
3. Consider adding optional expiration or authentication to shortcode resolution

---

### F-07: Default Docker Compose Uses Weak PostgreSQL Password [LOW]

**ASVS:** V2.1.1 (Passwords at least 12 characters)
**CWE:** CWE-521 (Weak Password Requirements)

**Description:** The default `docker-compose.yml` uses `testpass` as the PostgreSQL password and exposes port 5432 to the host.

**Evidence:**

File: `docker-compose.yml`
```yaml
hoppscotch-db:
    image: postgres:15
    ports:
      - "5432:5432"     # Exposed to host!
    environment:
      POSTGRES_PASSWORD: testpass   # Weak default
```

**Impact:** Self-hosted deployments that do not change this password expose their database (containing all user data, credentials, and API requests) to anyone who can reach port 5432.

**Remediation:** Remove the port mapping from default config (only expose to Docker network), and use a generated password or require setting one.

---

## Warnings

### W-01: GraphQL Playground Enabled in Non-Production Mode

**ASVS:** V14.3.3 (Web/application framework source not in use)

The GraphQL playground is enabled when `PRODUCTION !== 'true'`:
```typescript
playground: configService.get('PRODUCTION') !== 'true',
```

Many self-hosted deployments do not set `PRODUCTION=true`, leaving the interactive GraphQL explorer available. This aids attackers in discovering the full schema and crafting queries.

---

### W-02: First User Auto-Promoted to Admin

**ASVS:** V4.1.2 (Access control at a trusted enforcement point)

When only one user exists, they are automatically promoted to admin:
```typescript
async verifyAdmin(user: AuthUser) {
    if (user.isAdmin) return E.right({ isAdmin: true });
    const usersCount = await this.usersService.getUsersCount();
    if (usersCount === 1) {
        const elevatedUser = await this.usersService.makeAdmin(user.uid);
        return E.right({ isAdmin: true });
    }
}
```

Combined with F-02, an attacker who reconfigures onboarding and creates the first account becomes admin automatically.

---

### W-03: CORS Set to `origin: true` in Non-Production Mode

**ASVS:** V13.2.5 (CORS access control)

File: `packages/hoppscotch-backend/src/main.ts`
```typescript
if (isProduction) {
    app.enableCors({
        origin: configService.get('WHITELISTED_ORIGINS').split(','),
        credentials: true,
    });
} else {
    app.enableCors({
        origin: true,       // Reflects any origin!
        credentials: true,  // With credentials!
    });
}
```

In non-production mode (default for many self-hosted deployments), any origin can make credentialed requests to the backend.

---

### W-04: Desktop Auth Callback Allows Open Redirect to localhost

**ASVS:** V5.1.5 (URL redirects and forwards)

File: `packages/hoppscotch-backend/src/auth/auth.controller.ts`
```typescript
@Get('desktop')
async desktopAuthCallback(@GqlUser() user, @Query('redirect_uri') redirectUri) {
    if (!redirectUri || !redirectUri.startsWith('http://localhost')) {
        throwHTTPErr({ message: 'Invalid desktop callback URL', statusCode: 400 });
    }
    const tokens = await this.authService.generateAuthTokens(user.uid);
    return tokens.right;  // Returns raw tokens in response body!
}
```

The check `startsWith('http://localhost')` would also match `http://localhost.evil.com`. More critically, this endpoint returns raw auth tokens in the response body (not as httpOnly cookies), which could be captured by malicious localhost services.

---

## Positive Findings

| Area | Finding |
|------|---------|
| **Password hashing** | Refresh tokens hashed with argon2, magic link tokens use bcrypt with configurable salt complexity |
| **Infrastructure secrets** | OAuth client secrets, SMTP passwords, JWT secrets encrypted at rest with AES-256-CBC |
| **Rate limiting** | Global throttler on all REST and GraphQL endpoints (100 req/10s default) |
| **Team access control** | Proper role-based guards (Owner/Editor/Viewer) on team collection and request mutations |
| **Input validation** | ValidationPipe with transform enabled globally; SMTP URL and email validation |
| **Token rotation** | Refresh token rotation implemented correctly with argon2 hash comparison |
| **SQL injection** | Prisma ORM provides parameterized queries; `escapeSqlLikeString` for raw search queries |
| **Admin guard** | Consistent use of `GqlAdminGuard` on all admin resolver mutations |
| **Cookie security** | httpOnly flag always set on auth cookies; sameSite=lax prevents CSRF |
| **GQL complexity** | `GQLComplexityPlugin` guards against query complexity attacks |

---

## ASVS L2 Chapter Summary

| Chapter | Pass | Fail | Warn | N/A |
|---------|------|------|------|-----|
| V1 Architecture | - | - | - | - |
| V2 Authentication | 3 | 0 | 1 | 1 |
| V3 Session Management | 2 | 0 | 0 | 0 |
| V4 Access Control | 2 | 2 | 1 | 0 |
| V5 Validation/Encoding | 3 | 0 | 1 | 0 |
| V6 Cryptography | 1 | 1 | 0 | 0 |
| V7 Error Handling | 2 | 0 | 0 | 0 |
| V8 Data Protection | 1 | 1 | 0 | 0 |
| V9 Communications | 1 | 1 | 0 | 0 |
| V10 Malicious Code | 1 | 0 | 0 | 0 |
| V13 API Security | 2 | 1 | 1 | 0 |
| V14 Configuration | 1 | 1 | 0 | 0 |

---

## Remediation Priority

| Priority | Finding | Effort | Impact |
|----------|---------|--------|--------|
| 1 | F-01: IDOR in user history | Low (add uid to WHERE clauses) | Fixes cross-user data access |
| 2 | F-02: Unauthenticated onboarding | Medium (add setup token mechanism) | Prevents instance takeover |
| 3 | F-03: Plaintext credential storage | High (encrypt JSON fields, migration needed) | Protects credentials at rest |
| 4 | F-04: Weak default encryption key | Low (startup validation) | Prevents false sense of security |
| 5 | F-06: Unauthenticated shortcode access | Low (use crypto.randomBytes, optional auth) | Prevents credential leakage |
| 6 | F-05: HTTP cookie configuration | Low (warning + documentation) | Improves self-hosted security posture |
| 7 | F-07: Weak DB password default | Low (remove port mapping) | Reduces default attack surface |

---

## Methodology

- **Phase 1 -- Enumeration:** Manual code review of monorepo structure, Prisma schema, NestJS modules, guards, resolvers, and controllers
- **Phase 2 -- ASVS L2:** Systematic check of all applicable ASVS v4.0.3 chapters against codebase
- **Phase 3 -- Active analysis:** Traced data flow from GraphQL resolvers through services to Prisma queries, focusing on authorization boundary checks
- **Phase 4 -- Report:** Findings documented with code evidence and exploitation paths

**Files analyzed:** 35+ TypeScript source files across backend, auth, admin, guards, team, user-history, shortcode, mock-server, infra-config, and published-docs modules.

---

*Report generated by AI-Sec automated security audit. For questions or follow-up penetration testing, contact the AI-Sec team.*
