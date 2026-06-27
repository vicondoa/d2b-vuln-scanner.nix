# Consumer migration guide

This guide walks through integrating `d2b-vuln-scanner.nix` into a d2b
consumer — a NixOS or Home Manager configuration that already uses d2b to
manage microVMs.

All names in this guide are synthetic (e.g. `your-org`, `youruser`,
`work-vm`). Replace them with your own.

---

## 1. Add the flake input

In your consumer `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # ... your other inputs ...
    d2b-vuln-scanner = {
      url = "github:vicondoa/d2b-vuln-scanner.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, d2b-vuln-scanner, ... }: {
    # pass d2b-vuln-scanner through to your NixOS/HM config
  };
}
```

`inputs.nixpkgs.follows = "nixpkgs"` keeps the dependency tree in sync and
avoids a second Nixpkgs evaluation. Omit if your consumer pins a different
version of Nixpkgs.

---

## 2. Import the Home Manager module

The scanner ships a Home Manager module at `homeManagerModules.default`.

### Option A — Home Manager as a NixOS module

```nix
# In your NixOS flake outputs:
nixosConfigurations.my-desktop = nixpkgs.lib.nixosSystem {
  modules = [
    home-manager.nixosModules.home-manager
    {
      home-manager.users.youruser =
        import ./home/youruser;   # your per-user HM entry point
      home-manager.sharedModules = [
        d2b-vuln-scanner.homeManagerModules.default
      ];
    }
    # ...
  ];
};
```

### Option B — standalone Home Manager

```nix
# In your home.nix or flake-based HM config:
{ inputs, ... }: {
  imports = [
    inputs.d2b-vuln-scanner.homeManagerModules.default
  ];
}
```

---

## 3. Configure the module

A minimal working configuration inside your Home Manager user file:

```nix
programs.d2b-vuln-scanner = {
  enable = true;

  # Optional: pin the package explicitly (recommended for reproducibility).
  # Remove to resolve d2b-vuln-* commands from PATH instead.
  package = inputs.d2b-vuln-scanner.packages.${pkgs.system}.default;

  d2b = {
    # Point at your d2b CLI package if d2b is not on the system PATH.
    # cliPackage = inputs.d2b.packages.${pkgs.system}.default;

    # Or supply an explicit path:
    # cliPath = "/run/current-system/sw/bin/d2b";

    # Override the fallback manifest if your consumer places it elsewhere.
    # manifestPath = "/run/current-system/sw/share/d2b/vms.json";

    # Scan net VMs (default: true). Set false to exclude them.
    includeNetVms = true;
  };

  scan = {
    # Flake path for osv-scanner dep scanning; "." means the consumer repo root.
    flake = "/etc/yourconfig";

    # Override scan state if you need a non-default location.
    # stateDir = "${config.xdg.stateHome}/d2b-vuln-scanner";

    # Host NixOS system closure (default: /run/current-system).
    # hostClosurePath = "/run/current-system";
  };

  # Allow desktop notifications (default: true).
  notifications.enable = true;
};
```

---

## 4. Scan timer (opt-in)

The timer is **off by default**. Enable it explicitly:

```nix
programs.d2b-vuln-scanner = {
  enable = true;

  timer = {
    enable           = true;   # daily systemd user timer
    onCalendar       = "daily";
    randomizedDelaySec = "30min"; # spread load across a fleet
    fixedRandomDelay = true;   # stable across reboots
  };
};
```

After activation, verify:

```bash
systemctl --user list-timers d2b-vuln-scan.timer
systemctl --user status d2b-vuln-scan.service
```

Run a manual scan at any time:

```bash
systemctl --user start d2b-vuln-scan.service
journalctl --user -u d2b-vuln-scan.service -f
```

---

## 5. Status helpers

Expose `D2B_STATE_DIR` automatically in user sessions so `d2b-vuln-status`,
`d2b-vuln-waybar`, and `d2b-vuln-open` can find scan state without
`--state-dir` on every invocation:

```nix
programs.d2b-vuln-scanner = {
  enable = true;
  statusHelper.enable = true;
};
```

Quick status check once active:

```bash
d2b-vuln-status          # plain text
d2b-vuln-status --json   # structured output
```

---

## 6. Waybar integration (optional)

Desktop integration is **consumer-owned**. Two layers are available:

### Manual snippet (recommended unless Home Manager fully owns your Waybar config)

Add to `~/.config/waybar/config`:

```jsonc
"custom/d2b-vuln": {
  "exec": "d2b-vuln-waybar",
  "interval": 3600,
  "return-type": "json",
  "on-click": "d2b-vuln-open"
}
```

Add to `~/.config/waybar/style.css`:

```css
#custom-d2b-vuln.critical { color: #ff5555; }
#custom-d2b-vuln.warning  { color: #ffb86c; }
#custom-d2b-vuln.stale    { color: #888888; }
#custom-d2b-vuln.error    { color: #ff5555; }
```

Enable the Waybar helper in your HM config so `d2b-vuln-waybar` is on PATH
and `D2B_STATE_DIR` is set:

```nix
programs.d2b-vuln-scanner = {
  enable = true;
  integrations.waybar = {
    enable   = true;  # installs d2b-vuln-waybar and sets D2B_STATE_DIR
    autowire = false; # leave false when Waybar config is not Home-Manager-managed
  };
};
```

### Autowiring (when Home Manager fully manages Waybar)

If your Waybar configuration is declared entirely through
`programs.waybar` in Home Manager, you can let the module wire itself:

```nix
programs.d2b-vuln-scanner = {
  enable = true;
  integrations.waybar = {
    enable   = true;
    autowire = true; # adds the custom module to programs.waybar automatically
  };
};
```

`autowire` is `false` by default to avoid unexpected Waybar config
mutations when consumers manage the bar config outside Home Manager.
See [desktop-integration.md](desktop-integration.md) for the full JSON
status contract and CSS class reference.

---

## 7. Remediation agent (opt-in)

Automated remediation is **off by default**. To enable:

```nix
programs.d2b-vuln-scanner = {
  enable = true;

  remediation = {
    enable = true;   # install the d2b-vuln-remediate systemd user service

    # argv array passed to d2b-vuln-remediate --agent-argv-json.
    # Use {prompt_file} as the path placeholder (file mode), or omit it to
    # pipe prompt content to stdin instead.
    agent.argv = [ "my-agent" "--model" "fast" "--prompt" "{prompt_file}" ];

    # Auto-start remediation after every successful scan (off by default).
    autoStartOnSuccess = false;
  };
};
```

Trigger a manual remediation run:

```bash
systemctl --user start d2b-vuln-remediate.service
journalctl --user -u d2b-vuln-remediate.service -f
```

See [remediation.md](remediation.md) for the full prompt-file contract,
exit codes, stdin vs. `{prompt_file}` mode, and bundled skill definitions.

---

## 8. Validation commands

After rebuilding (`nixos-rebuild switch` or `home-manager switch`):

```bash
# Confirm the module is active and binaries are available
which d2b-vuln-scan d2b-vuln-status d2b-vuln-waybar

# Check the systemd scan service is registered
systemctl --user cat d2b-vuln-scan.service

# Check the timer (only if timer.enable = true)
systemctl --user list-timers d2b-vuln-scan.timer

# Check the state-dir env var (only if statusHelper.enable = true)
echo "$D2B_STATE_DIR"

# Run a one-shot scan and tail logs
systemctl --user start d2b-vuln-scan.service
journalctl --user -u d2b-vuln-scan.service -f

# Inspect the result
d2b-vuln-status --json
d2b-vuln-open --print-path
```

---

## 9. Rollback procedure

If you need to back out the integration:

1. **Disable the module** in your Home Manager config:

   ```nix
   programs.d2b-vuln-scanner.enable = false;
   ```

   This removes the systemd units, session variables, and package from the
   build. If you want a full clean remove, you may also delete the input
   from `flake.nix` and update `flake.lock`.

2. **Stop and disable timers/services** before the next rebuild, if the
   service is currently running:

   ```bash
   systemctl --user stop  d2b-vuln-scan.timer d2b-vuln-scan.service
   systemctl --user disable d2b-vuln-scan.timer
   systemctl --user stop  d2b-vuln-remediate.service 2>/dev/null || true
   ```

3. **Restore Waybar snippets** if you added the custom module manually:
   remove the `"custom/d2b-vuln"` block from `~/.config/waybar/config` and
   the `#custom-d2b-vuln.*` rules from `~/.config/waybar/style.css`, then
   reload or restart Waybar.

   If you used `autowire = true`, Home Manager removes the Waybar entry
   automatically on the next activation once the option is disabled.

4. **Apply consumer activation**:

   ```bash
   # NixOS + Home Manager as NixOS module:
   sudo nixos-rebuild switch --flake /path/to/your-config#your-host

   # Standalone Home Manager:
   home-manager switch --flake /path/to/your-config#youruser
   ```

5. **Optionally reset local scan state** (removes reports and summary JSON
   from the XDG state directory):

   ```bash
   d2b-vuln-state reset --yes
   ```

   This is reversible only if you have a backup of the state directory.
   Skip this step if you want to preserve historical scan results.

---

## Cross-references

- [configuration.md](configuration.md) — full option reference and defaults
- [desktop-integration.md](desktop-integration.md) — JSON status contract,
  Waybar JSON schema, CSS classes, `d2b-vuln-open` viewer selection
- [remediation.md](remediation.md) — prompt-file contract, agent invocation
  modes, exit codes, skill definitions
- [d2b-integration.md](d2b-integration.md) — how the scanner
  discovers d2b VMs and labels findings

