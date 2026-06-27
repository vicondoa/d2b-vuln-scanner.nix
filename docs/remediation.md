# Remediation

Remediation is disabled by default. To activate it you must configure an agent
argv vector (`--agent-argv-json` or `$D2B_AGENT_ARGV_JSON`).

## Overview

`d2b-vuln-remediate` reads the most recent scan state, builds a structured
prompt file describing the findings, and optionally invokes an external
remediation agent.

```
d2b-vuln-remediate [--agent-argv-json JSON] [--state-dir DIR] [--flake PATH]
```

## Prompt-file contract

Every invocation writes a Markdown prompt to
`$state_dir/remediation/prompt-<timestamp>.md` (mode 0600).  The file
contains:

| Field                      | Description                                                   |
|----------------------------|---------------------------------------------------------------|
| Scanner state directory    | Absolute path to the scan state dir.                          |
| Summary JSON               | Absolute path to `summary.json`.                              |
| Latest report              | Absolute path to `latest.txt` (symlink to most recent report).|
| Scan timestamp             | ISO-8601 UTC timestamp of the last scan.                      |
| Critical / High counts     | Finding counts from `summary.json`.                           |
| New critical+high          | Findings new since the previous scan run.                     |
| Scan errors                | Count of scan-phase errors (e.g. unreachable closures).       |
| d2b VMs discovered     | VM count from the d2b discovery phase.                    |
| VM source labels           | `nix:d2b-vm:<name>` labels present in the report.         |
| Source label taxonomy      | Explanation of `nix:host`, `nix:d2b-vm:`, `dep:` prefixes.|
| Scan command               | Shell command to re-run the scan for post-fix validation.     |
| Residual finding policy    | How to document findings that cannot be remediated.           |
| Nix remediation policy     | Cache-safe rules: prefer input bumps over source overrides.   |
| Consumer-owned boundaries  | What the agent must not do (deploy, push, embed private data).|
| Skills reference           | Points to the bundled `d2b-vuln-remediation` skill.           |

### Stale/missing state

`d2b-vuln-remediate` exits **75** if:

- `summary.json` is missing or empty.
- `latest.txt` does not exist.
- `summary.json` has no `.ts` field.
- The scan timestamp is older than `$D2B_REMEDIATION_MAX_SCAN_AGE_SECONDS`
  (default: 7200 = 2 hours).

Re-run `d2b-vuln-scan` first to refresh state.

## Agent invocation

Agent invocation is **argv-only** — no shell-string execution.  Supply a JSON
array of strings:

```bash
D2B_AGENT_ARGV_JSON='["my-agent","--model","fast"]' d2b-vuln-remediate
# or equivalently:
d2b-vuln-remediate --agent-argv-json '["my-agent","--model","fast"]'
```

### Invocation modes (auto-detected)

**`{prompt_file}` mode** — if any element of the argv array contains the
literal text `{prompt_file}`, it is replaced with the absolute path of the
generated prompt file before execution:

```json
["copilot", "agent", "--prompt", "{prompt_file}"]
```

**stdin mode** — if no element contains `{prompt_file}`, the prompt content
is piped to the agent on standard input:

```json
["my-agent", "--read-stdin"]
```

The two modes are mutually exclusive.  Detection is based on the original JSON
before substitution.

### Locking

A per-state-dir `flock` lock (`remediate.lock`) prevents concurrent
invocations from racing on the same state directory.

### Log and prompt retention

Prompt files older than the `$D2B_REMEDIATION_PROMPT_RETENTION` newest
(default: 20) are deleted after each run.

Log files older than the `$D2B_REMEDIATION_LOG_RETENTION` newest
(default: 20) are deleted after each run.

### Exit codes

| Code | Meaning                                                    |
|------|------------------------------------------------------------|
| 0    | Prompt written; agent ran successfully (or no agent set).  |
| 64   | Usage error (unknown flag).                                |
| 75   | Scan state missing or stale.                               |
| *    | Agent's own exit status forwarded.                         |

## Bundled skills

The `skills/` directory ships two skill definitions for use with
vulnerability-fixing agents that operate on scanner findings in **consumer**
repositories:

- `skills/github/d2b-vuln-remediation/SKILL.md` — for GitHub-hosted agents.
- `skills/claude/d2b-vuln-remediation/SKILL.md` — for Claude-based agents.

Both skills cover:

- Triaging findings by source label (`nix:host`, `nix:d2b-vm:`, `dep:`).
- Cache-safe Nix remediation rules (input bumps preferred over source overrides).
- Post-fix re-scan and residual finding documentation.
- Consumer-owned deploy/apply boundaries.

These skills are **not** the workflow for contributing to this scanner
repository.

