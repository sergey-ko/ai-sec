# /verify — Cross-Check Audit Findings Against Source Code

Verify that findings in an AI-Sec audit report are real and not hallucinated by checking each finding against the actual source code of the audited repository.

## Usage

```
/verify <audit-report-path> <repo-url-or-path>
```

**Examples:**
```
/verify examples/maybe-finance-web-audit.md https://github.com/maybe-finance/maybe
/verify examples/documenso-web-audit.md ./examples/documenso
/verify examples/hoppscotch-web-audit.md https://github.com/hoppscotch/hoppscotch
```

## What It Does

1. Parses the audit report and extracts all findings with their file references
2. For each finding, fetches the actual source file from the target repo
3. Checks whether the vulnerability described in the finding actually exists in the code
4. Produces a verification report with CONFIRMED / PARTIALLY_CONFIRMED / FIXED / NOT_FOUND / INACCURATE status per finding

## Process

1. **Read the audit report** — parse all findings, extract file paths and code patterns
2. **Spawn the verify-auditor agent** — pass it the report and repo URL
3. **Agent checks each finding** against real source code
4. **Output** — verification report saved alongside the audit report as `{name}-verification.md`

## When to Run

- **After every audit** — before publishing or sharing results
- **Periodically** — to check if findings have been fixed
- **Before citing findings** — on the website, in proposals, or in content

## Implementation

Spawn the `verify-auditor` agent with this prompt:

```
Verify the findings in {audit-report-path} against the repository at {repo-url}.

For each finding in the report:
1. Fetch the referenced file from the repo
2. Check if the vulnerability exists as described
3. Classify as CONFIRMED / PARTIALLY_CONFIRMED / FIXED / CHANGED / NOT_FOUND / INACCURATE
4. Document the evidence

Output a verification report in markdown format.
Save the report to {output-path}.
```

The agent definition is at `.claude/agents/verify-auditor.md`.