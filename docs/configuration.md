# Configuration

Home Manager options live under `programs.d2b-vuln-scanner.*`.

Important defaults:

- `nixling.includeNetVms = true` for secure coverage.
- `timer.enable = false`; consumers opt into scheduling.
- `remediation.enable = false`; consumers opt into agent execution.
- `integrations.waybar.autowire = false`; desktop autowiring is explicit.

Generated option docs belong in [options.md](options.md).

