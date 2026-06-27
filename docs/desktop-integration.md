# Desktop integration

Desktop integration is **consumer-owned**. The project provides thin, stable
building blocks; consumers wire them into their own panels, launchers, and
notification systems.

Provided tools:
- `d2b-vuln-status` – emit scan status as text or JSON (the stable contract)
- `d2b-vuln-waybar` – thin Waybar adapter built on `d2b-vuln-status`
- `d2b-vuln-open` – open the latest report in a human-readable viewer

## JSON status contract

`d2b-vuln-status --json` always emits a single JSON object. All fields are
stable; consumers may key on them.

| Field            | Type    | Description                                               |
|------------------|---------|-----------------------------------------------------------|
| `state`          | string  | Canonical state name (see table below)                    |
| `class`          | string  | CSS/theme class for adapters (see table below)            |
| `text`           | string  | Short human-readable summary                              |
| `ts`             | string  | Scan timestamp (`YYYYMMDDTHHMMSSz`), empty if unavailable |
| `high_critical`  | integer | Count of high + critical findings                         |
| `errors`         | integer | Total scan error count (all sources)                      |
| `d2b_errors` | integer | Count of errors from d2b VM discovery specifically    |

### States and classes

| `state`            | `class`    | Meaning                                                          |
|--------------------|------------|------------------------------------------------------------------|
| `missing`          | `missing`  | No `summary.json` found; scanner has never run                   |
| `invalid`          | `error`    | `summary.json` present but lacks a parseable timestamp           |
| `stale`            | `stale`    | Scan timestamp older than `D2B_STALE_SECONDS` (default 26 h)    |
| `scanner_failure`  | `error`    | Scan completed but ≥1 non-d2b-discovery error occurred       |
| `d2b_failure`  | `warning`  | Scan completed; all errors were d2b VM-discovery failures    |
| `findings`         | `critical` | Scan clean; high/critical CVEs present                           |
| `clean`            | `clean`    | Scan clean; no high/critical CVEs                                |

Priority when multiple conditions apply: `stale` → `scanner_failure` →
`d2b_failure` → `findings` → `clean`.

`d2b_errors` lets consumers distinguish *all errors are d2b* vs *at
least one non-d2b error* without re-examining `scan_errors`.

## Environment variables

| Variable            | Default                              | Effect                          |
|---------------------|--------------------------------------|---------------------------------|
| `D2B_STATE_DIR`     | `$XDG_STATE_HOME/d2b-vuln-scanner`  | Override scan state directory   |
| `D2B_STALE_SECONDS` | `93600` (26 h)                       | Staleness threshold in seconds  |

Both `d2b-vuln-status` and `d2b-vuln-waybar` also accept `--state-dir DIR`.

## Waybar integration

`d2b-vuln-waybar` is a thin adapter. It calls `d2b-vuln-status --json`,
translates the result, and always emits valid Waybar custom-module JSON:

```json
{ "text": "🐛 3 finding(s)", "class": "critical", "tooltip": "..." }
```

`text` is empty for `clean` and `missing` states (silent unless actionable).
The `class` field maps directly to the CSS class for Waybar theming.

Example `~/.config/waybar/config` snippet:

```jsonc
"custom/d2b-vuln": {
  "exec": "d2b-vuln-waybar",
  "interval": 3600,
  "return-type": "json",
  "on-click": "d2b-vuln-open"
}
```

Example `~/.config/waybar/style.css` hooks:

```css
#custom-d2b-vuln.critical { color: #ff5555; }
#custom-d2b-vuln.warning  { color: #ffb86c; }
#custom-d2b-vuln.stale    { color: #888888; }
#custom-d2b-vuln.error    { color: #ff5555; }
```

## Report opener

`d2b-vuln-open` opens the latest scan report. Viewer selection:

1. `D2B_OPEN_ARGV_JSON` env var – custom argv array; use `{report}` as the path placeholder
2. `--no-pager` flag – write report to stdout (useful for scripts or piping)
3. Stdout is a tty – open with `less -R`
4. Non-tty – launch with `xdg-open`

Custom viewer example:

```bash
export D2B_OPEN_ARGV_JSON='["my-viewer","--theme=dark","{report}"]'
d2b-vuln-open
```

`--print-path` returns the resolved report path without opening it.

## Optional Home Manager autowiring

The Home Manager module (`hmModules.default`) provides opt-in Waybar wiring:

```nix
programs.d2b-vuln-scanner = {
  enable = true;
  integrations.waybar.enable   = true;  # install d2b-vuln-waybar
  integrations.waybar.autowire = false; # set true to let HM wire the Waybar module
};
```

`autowire` is `false` by default. Consumers who manage their Waybar config
outside Home Manager should leave it `false` and add the snippet above
manually. Set it `true` only if your Home Manager config fully owns Waybar.

Remediation integration and scan timers are also opt-in:

```nix
programs.d2b-vuln-scanner = {
  timer.enable = true;           # daily systemd user timer
  notifications.enable = true;   # D-Bus desktop notifications on new findings
  remediation.enable = false;    # remediation agent – off by default
};
```

No integration is enabled unless explicitly set.

