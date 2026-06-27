# AGENTS.md

Operating manual for contributors and coding agents working on
`vicondoa/d2b-vuln-scanner.nix`.

## Project scope

This is a d2b-native vulnerability scanner flake. It may use public d2b
contracts such as `d2b list --json` and the public manifest schema, but it
must not encode private consumer paths, VM names, hostnames, compositor config,
or local operational policy.

The `skills/` directory is for vulnerability-fixing agents that consume scanner
findings in downstream d2b consumer repositories. Those skills are not the
workflow for maintaining this scanner repository.

## Validate

Use the Makefile interface:

```bash
make check
make test
nix flake check --no-build --all-systems
```

CI must call Makefile targets rather than duplicating command logic.

## Panel review

Multi-wave work requires panel sign-off before implementation and before
advancing waves. Minimum reviewers: software, test, nix, d2b, security,
docs, product, desktop-integration, agent-automation, github-ci, and ops.

Reviewers return JSON:

```json
{"reviewer":"d2b","signoff":true,"summary":"...","recommendations":[]}
```

`signoff` is true iff `recommendations` is empty.

## Skills and remediation

The `skills/` directory ships `d2b-vuln-remediation` skill definitions
(GitHub and Claude variants) for **downstream vulnerability-fixing agents**
that operate on scanner findings in consumer repositories.  These skills are
not the contributor workflow for this scanner repository.

Key skill policies:
- Bucket findings by `nix:host`, `nix:d2b-vm:<name>`, and `dep:<input>`
  source labels before proposing fixes.
- Prefer cache-safe Nix input bumps over local source overrides.
- Always propose changes for review; never silently commit, merge, or deploy.
- Re-run the scanner after fixes and document residual findings.
- Never embed private consumer paths, hostnames, or VM names.

`d2b-vuln-remediate` writes a structured prompt file and optionally launches
an agent argv vector (`{prompt_file}` placeholder or stdin mode).  See
`docs/remediation.md` for the full prompt-file contract, invocation modes,
retention settings, and exit codes.

- Apache-2.0 license.
- Keep a Changelog + Semantic Versioning.
- Shell commands are argv-first; no shell-string agent configuration.
- Prefer XDG state/cache locations.
- No private consumer details in committed examples except clearly synthetic
  fixtures.

