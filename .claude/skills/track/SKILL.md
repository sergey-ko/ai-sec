---
name: track
description: Manage the AI-Sec findings registry — track, verify, and diff findings across audit runs.
user-invocable: true
---

# /track — Findings Registry Manager

Manage the findings registry to track security findings across audit runs. The registry enables fast grep-based verification instead of full code re-review.

## Usage

```
/track              — show registry summary (open/resolved counts by severity)
/track init         — create findings-registry.yaml from the last audit report
/track verify       — run registry-based verification on all open findings
/track update       — update registry with findings from latest audit report
/track diff         — show what changed since last verification
```

## Commands

### /track (no arguments) — Summary

1. Read `findings-registry.yaml` from the project root
2. If not found, tell the user: "No findings registry found. Run `/track init` to create one from your last audit report."
3. If found, display a summary:

```
Findings Registry: {project name}
Last audit: {date}

| Severity | Open | Resolved | Total |
|----------|------|----------|-------|
| Critical | X    | X        | X     |
| High     | X    | X        | X     |
| Medium   | X    | X        | X     |
| Low      | X    | X        | X     |
| Info     | X    | X        | X     |
| **Total**| **X**| **X**    | **X** |

Top open findings:
  1. [CRITICAL] AUTH-01: JWT tokens never expire
  2. [HIGH] CICD-03: Secrets in plain-text env vars
  ...
```

### /track init — Create Registry

1. Find the most recent `ai-sec-report.md` in the project (check project root, then `examples/`)
2. If no report found, tell the user to run `/audit` first
3. Parse all findings from the report. For each finding, extract:
   - ID, severity, title, category (web-app/api/cicd/infra/mobile)
   - Referenced file paths
   - The vulnerability pattern described
4. Generate `verify` blocks for each finding:
   - Analyze the vulnerability description to determine what grep pattern would detect the fix or the vulnerability
   - Set `expect: absent` when the pattern detects a fix (fix absent = still vulnerable)
   - Set `expect: present` when the pattern detects the vulnerability itself (vuln present = still vulnerable)
   - Use specific, targeted patterns — avoid overly broad regexes
5. Write `findings-registry.yaml` to the project root using the template from `methodology/findings-registry-template.yaml`
6. Tell the user: "Registry created with {N} findings. Run `/track verify` to check current status."

**Pattern generation guidelines:**
- For missing authentication/authorization: look for auth middleware, decorators, guards
- For hardcoded secrets: look for the literal string patterns
- For missing validation: look for validation calls on the specific input
- For missing encryption: look for encryption function calls
- For missing headers: look for the header name in response configuration
- For CI/CD issues: look for the specific pipeline configuration pattern
- Always specify narrow `paths` — don't search the whole repo

### /track verify — Run Verification

1. Read `findings-registry.yaml`
2. Spawn the `verify-auditor` agent in registry mode:
   ```
   Verify findings from the registry at {registry-path} against the project at {project-root}.
   Use registry mode (Mode B) — grep patterns from the registry.
   Only check findings with status: open.
   ```
3. Display the verification results
4. Ask the user: "Apply registry updates? (y/n)" before modifying the registry file

### /track update — Add New Findings

1. Read the latest `ai-sec-report.md`
2. Read the existing `findings-registry.yaml`
3. Compare: find findings in the report that are NOT already in the registry (match by ID or by title+category)
4. For new findings, generate verify blocks (same logic as `/track init`)
5. Add new findings to the registry
6. For findings in the registry that are NOT in the new report:
   - Do NOT auto-resolve them (they may just not have been checked this run)
   - Flag them: "Note: {N} registry findings not mentioned in latest report — run `/track verify` to check status"
7. Update `last_audit` date
8. Save the registry

### /track diff — Show Changes

1. Read `findings-registry.yaml`
2. Show findings grouped by status change:
   - **Newly added** (since last audit date)
   - **Recently resolved** (resolved_date within last 30 days)
   - **Long-standing** (open for more than 30 days — these need attention)
3. Format as a clear summary the user can paste into a status update or PR description

## Registry File Location

The registry always lives at `{project-root}/findings-registry.yaml`. This is the project being audited, not the ai-sec repo itself.

## Implementation Notes

- The verify-auditor agent handles the actual grep-based verification (Mode B)
- This skill handles registry CRUD and report parsing
- Always preserve existing findings when updating — never overwrite the registry, only append/modify
- Finding IDs must be unique within a registry. Use the format from the audit report (e.g., AUTH-01, CICD-03)
- If a finding has no verify block, it can only be verified in report mode (full code review). Suggest the user add patterns manually.
