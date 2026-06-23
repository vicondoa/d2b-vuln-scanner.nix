# AGENTS.md

Operating manual for contributors and coding agents working on
`vicondoa/d2b-vuln-scanner.nix`.

## Project scope

This is a nixling-native vulnerability scanner flake. It may use public nixling
contracts such as `nixling list --json` and the public manifest schema, but it
must not encode private consumer paths, VM names, hostnames, compositor config,
or local operational policy.

The `skills/` directory is for vulnerability-fixing agents that consume scanner
findings in downstream nixling consumer repositories. Those skills are not the
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
advancing waves. Minimum reviewers: software, test, nix, nixling, security,
docs, product, desktop-integration, agent-automation, github-ci, and ops.

Reviewers return JSON:

```json
{"reviewer":"nixling","signoff":true,"summary":"...","recommendations":[]}
```

`signoff` is true iff `recommendations` is empty.

## Conventions

- Apache-2.0 license.
- Keep a Changelog + Semantic Versioning.
- Shell commands are argv-first; no shell-string agent configuration.
- Prefer XDG state/cache locations.
- No private consumer details in committed examples except clearly synthetic
  fixtures.

