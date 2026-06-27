# Configuration

Home Manager options live under `programs.d2b-vuln-scanner.*`.

Important defaults:

- `d2b.includeNetVms = true` for secure coverage.
- `timer.enable = false`; consumers opt into scheduling.
- `remediation.enable = false`; consumers opt into agent execution.
- `integrations.waybar.autowire = false`; desktop autowiring is explicit.

Generated option docs belong in [options.md](options.md).

For a step-by-step integration walkthrough including flake wiring, d2b
CLI/manifest configuration, Waybar snippets, and rollback guidance, see
[consumer-migration.md](consumer-migration.md).

