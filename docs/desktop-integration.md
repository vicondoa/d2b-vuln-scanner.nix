# Desktop integration

Desktop integration is consumer-owned. The project provides:

- `d2b-vuln-status --json` and `--text`;
- `d2b-vuln-waybar` as a thin Waybar adapter;
- `d2b-vuln-open` for human-readable report viewing;
- optional Home Manager autowiring for known integrations, disabled by default.

Waybar bindings should be safe by default: click opens the report, right-click
may trigger a manual refresh, and remediation actions are omitted unless
remediation is explicitly enabled.

