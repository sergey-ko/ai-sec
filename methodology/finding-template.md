# Finding Template — AI-Sec Standard Format

All findings MUST use this template. Consistency enables automated parsing, severity tracking, and client-ready report generation.

## Template

```markdown
### [SEVERITY] {ID}: {Title}

**CVSS:** {N.N} ({vector string})
**Framework:** {e.g., ASVS V4.1.1, CIS-K8S-3.1, CICD-SEC-1, MASVS-STORAGE-1}
**Component:** {file/path:line}
**Status:** OPEN

{1-2 sentence description of the vulnerability.}

**Evidence:**
\`\`\`{language}
{code snippet showing the issue}
\`\`\`

**Impact:** {What an attacker can do. Be specific — "allows unauthorized access to user X's data" not "security issue".}

**Recommendation:**
{Specific fix. Code example if possible.}

---
```

## Severity Mapping

| Severity | CVSS Range | Criteria | SLA |
|----------|-----------|----------|-----|
| CRITICAL | 9.0 - 10.0 | Exploitable now, high business impact. RCE, auth bypass, data exfil at scale. | Fix within 24 hours |
| HIGH | 7.0 - 8.9 | Exploitable with moderate effort, moderate-to-high impact. Privilege escalation, SSRF, SQL injection. | Fix within 7 days |
| MEDIUM | 4.0 - 6.9 | Possible exploitation, moderate impact. XSS, CSRF, info disclosure of non-sensitive data. | Fix within 30 days |
| LOW | 0.1 - 3.9 | Low impact or requires local/physical access. Verbose errors, missing headers, minor misconfigs. | Fix within 90 days |
| INFO | N/A | No direct security impact. Process improvements, documentation gaps, defense-in-depth suggestions. | Advisory only |

## Finding ID Format

`{AUDIT-CODE}-{SEQ}` — e.g., `ACME-001`, `ACME-002`.

- `AUDIT-CODE` is assigned per engagement (usually client name abbreviated)
- `SEQ` is a zero-padded sequential number across all findings in the engagement
- Findings are numbered in discovery order, NOT by severity

## CVSS v3.1 Quick Reference

Vector string format: `CVSS:3.1/AV:{N|A|L|P}/AC:{L|H}/PR:{N|L|H}/UI:{N|R}/S:{U|C}/C:{N|L|H}/I:{N|L|H}/A:{N|L|H}`

| Metric | Values |
|--------|--------|
| Attack Vector (AV) | Network (N), Adjacent (A), Local (L), Physical (P) |
| Attack Complexity (AC) | Low (L), High (H) |
| Privileges Required (PR) | None (N), Low (L), High (H) |
| User Interaction (UI) | None (N), Required (R) |
| Scope (S) | Unchanged (U), Changed (C) |
| Confidentiality (C) | None (N), Low (L), High (H) |
| Integrity (I) | None (N), Low (L), High (H) |
| Availability (A) | None (N), Low (L), High (H) |

### Common Patterns

| Vulnerability | Typical CVSS | Typical Vector |
|--------------|-------------|----------------|
| Unauthenticated RCE | 9.8 | AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H |
| SQL Injection (auth bypass) | 9.8 | AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H |
| Auth bypass | 9.1 | AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:N |
| SSRF (internal network) | 7.5 | AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N |
| Stored XSS | 6.1 | AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N |
| CSRF | 4.3 | AV:N/AC:L/PR:N/UI:R/S:U/C:N/I:L/A:N |
| Missing security headers | 3.7 | AV:N/AC:H/PR:N/UI:N/S:U/C:L/I:N/A:N |
| Verbose error messages | 2.6 | AV:N/AC:H/PR:L/UI:R/S:U/C:L/I:N/A:N |

## Writing Guidelines

1. **Title**: Short, specific. "Hardcoded AWS credentials in config.py" not "Credential management issue".
2. **Description**: 1-2 sentences. What is wrong and where.
3. **Evidence**: Always include code/config snippets. Redact actual secrets but show the pattern.
4. **Impact**: Attacker-centric. "An unauthenticated attacker can retrieve all user records via the /api/users endpoint" — not "data could be compromised".
5. **Recommendation**: Actionable. Include code if possible. "Replace hardcoded key with environment variable loaded via `os.environ['AWS_KEY']`" — not "use better credential management".

## Status Values

| Status | Meaning |
|--------|---------|
| OPEN | Finding confirmed, not yet remediated |
| IN PROGRESS | Client has acknowledged and is working on fix |
| REMEDIATED | Client reports fix applied, awaiting verification |
| VERIFIED | Fix confirmed via retest |
| ACCEPTED | Client accepts the risk (must document rationale) |
| FALSE POSITIVE | Finding was incorrect after further analysis |

## Example Finding

### [HIGH] ACME-003: SQL Injection in User Search Endpoint

**CVSS:** 8.6 (CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:L/A:L)
**Framework:** ASVS V5.3.4
**Component:** src/api/users.py:47
**Status:** OPEN

The `/api/v1/users/search` endpoint concatenates user input directly into a SQL query without parameterization, allowing an unauthenticated attacker to extract or modify database contents.

**Evidence:**
```python
# src/api/users.py:47
query = f"SELECT * FROM users WHERE name LIKE '%{request.args['q']}%'"
cursor.execute(query)
```

**Impact:** An unauthenticated attacker can extract all database contents including user credentials, PII, and API keys. With `INSERT`/`UPDATE` privileges, the attacker can modify user roles or inject backdoor accounts.

**Recommendation:**
Use parameterized queries:
```python
query = "SELECT * FROM users WHERE name LIKE ?"
cursor.execute(query, (f"%{request.args['q']}%",))
```

---
