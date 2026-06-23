# d2b-vuln-scanner.nix

`d2b-vuln-scanner.nix` is a nixling-native vulnerability scanner flake for
nixling hosts and VM closures.

It is intentionally reusable across nixling consumers: this repository contains
no private workstation paths, hostnames, VM names, compositor configuration, or
local operational policy. Consumers provide their own nixling configuration,
desktop wiring, remediation agent, and deploy workflow.

## What it does

- discovers nixling VMs through public nixling interfaces such as
  `nixling list --json`;
- scans the host and nixling VM closures with `sbomnix | grype`;
- scans selected flake inputs with `osv-scanner`;
- writes stable local state under XDG state/cache directories;
- exposes generic status output plus an optional Waybar adapter;
- can launch a configured vulnerability-fixing agent through an argv-only
  prompt-file contract.

## Quick start

```bash
nix run github:vicondoa/d2b-vuln-scanner.nix#scan -- --dry-run
nix run github:vicondoa/d2b-vuln-scanner.nix#status -- --json
```

For a Nix/Home Manager consumer, import `homeManagerModules.default`, configure
`programs.d2b-vuln-scanner.*`, and choose your own desktop integration.

See:

- [docs/nixling-integration.md](docs/nixling-integration.md)
- [docs/configuration.md](docs/configuration.md)
- [docs/desktop-integration.md](docs/desktop-integration.md)
- [docs/remediation.md](docs/remediation.md)

