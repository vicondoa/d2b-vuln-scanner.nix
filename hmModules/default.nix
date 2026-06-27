{ config, lib, pkgs, ... }:

let
  cfg = config.programs.d2b-vuln-scanner;
  exe = name:
    if cfg.package != null then "${cfg.package}/bin/${name}" else name;
  stateDir = cfg.scan.stateDir;
  scanArgs = [
    "--state-dir" stateDir
    "--flake" cfg.scan.flake
  ];
  # Set D2B_STATE_DIR in user sessions when status helpers or Waybar are enabled.
  # This lets d2b-vuln-status, d2b-vuln-waybar, and d2b-vuln-open find scan
  # state without requiring --state-dir on every invocation.
  wantSessionStateDir = cfg.statusHelper.enable || cfg.integrations.waybar.enable;
  waybarModuleName = "custom/d2b-vuln";
in
{
  options.programs.d2b-vuln-scanner = {
    enable = lib.mkEnableOption "nixling-native vulnerability scanning";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        Package supplying the d2b-vuln-* commands. When set, the package is
        added to home.packages. When null, commands are resolved from PATH
        (useful when the scanner is installed system-wide or via a NixOS module).
      '';
    };

    nixling = {
      cliPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = ''
          Optional nixling package. When set, cliPath automatically defaults to
          this package's executable, so no separate cliPath override is needed.
          Takes precedence over cliPath when both are set explicitly.
        '';
      };
      cliPath = lib.mkOption {
        type = lib.types.str;
        default =
          if cfg.nixling.cliPackage != null
          then lib.getExe cfg.nixling.cliPackage
          else "nixling";
        defaultText = lib.literalExpression ''
          if config.programs.d2b-vuln-scanner.nixling.cliPackage != null
          then lib.getExe config.programs.d2b-vuln-scanner.nixling.cliPackage
          else "nixling"
        '';
        description = ''
          Absolute path or bare command name for the nixling CLI. Used as
          D2B_NIXLING_CLI in the scan service environment. Override this when
          nixling is not on the default PATH and you are not setting cliPackage.
        '';
      };
      manifestPath = lib.mkOption {
        type = lib.types.path;
        default = "/run/current-system/sw/share/nixling/vms.json";
        description = ''
          Fallback nixling VM manifest path. Read when nixling list --json is
          unavailable (e.g. nixling is not installed). The scanner normalises this
          into the same VM list schema as the live CLI output.
        '';
      };
      includeNetVms = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Include nixling net VMs in vulnerability scans. Net VMs have access
          to host network interfaces; scanning them by default gives the broadest
          coverage. Set false to limit scans to non-net VMs.
        '';
      };
    };

    scan = {
      flake = lib.mkOption {
        type = lib.types.str;
        default = ".";
        description = ''
          Flake path passed to d2b-vuln-scan --flake. The scanner archives
          selected non-nixpkgs inputs and runs osv-scanner over them. Passed
          via ExecStart argument; does not affect the packaged derivation.
        '';
      };
      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.stateHome}/d2b-vuln-scanner";
        defaultText = lib.literalExpression ''"''${config.xdg.stateHome}/d2b-vuln-scanner"'';
        description = ''
          XDG state directory for reports, the summary JSON, scan locks, and
          remediation prompt logs. Defaults to the XDG_STATE_HOME sub-directory.
          Passed via ExecStart argument; does not affect the packaged derivation.
        '';
      };
      hostClosurePath = lib.mkOption {
        type = lib.types.str;
        default = "/run/current-system";
        description = ''
          Host NixOS system closure path to scan. sbomnix generates a CycloneDX
          SBOM from this path; grype then checks it for known CVEs. Passed via
          D2B_HOST_CLOSURE; does not affect the packaged derivation.
        '';
      };
    };

    statusHelper = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Expose the scan state directory as D2B_STATE_DIR in user sessions.
          When enabled, d2b-vuln-status, d2b-vuln-waybar, and d2b-vuln-open
          locate scan state without needing --state-dir on every invocation.
          Harmless when the scanner is not installed on this machine.
        '';
      };
    };

    timer = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable a systemd user timer that runs d2b-vuln-scan automatically.
          Disabled by default; consumers opt in to scheduled scanning.
        '';
      };
      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "systemd OnCalendar expression for the scan timer.";
      };
      randomizedDelaySec = lib.mkOption {
        type = lib.types.str;
        default = "30min";
        description = "RandomizedDelaySec for the scan timer. Spreads load across a fleet.";
      };
      fixedRandomDelay = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Stabilise the random delay across reboots (FixedRandomDelay=yes).";
      };
    };

    notifications.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Allow the scanner to send D-Bus desktop notifications. When true,
        D2B_NOTIFY_FAILURES and D2B_NOTIFY_FINDINGS are set to 1 in the
        service environment. Set false to suppress all notify-send calls.
      '';
    };

    integrations.waybar = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable Waybar status-bar integration. Also sets D2B_STATE_DIR in
          user sessions (same effect as statusHelper.enable) so d2b-vuln-waybar
          finds scan state without --state-dir. Requires d2b-vuln-waybar to be
          on PATH (set package, or install the scanner system-wide).
        '';
      };
      autowire = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Explicitly opt into Home Manager Waybar module autowiring. When true
          and Home Manager manages programs.waybar, the d2b-vuln custom module
          is added automatically. Leave false when your Waybar config is managed
          outside Home Manager.
        '';
      };
    };

    remediation = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Install the d2b-vuln-remediate systemd user service. Disabled by
          default; consumers opt in to automated remediation agent execution.
        '';
      };
      autoStartOnSuccess = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Start d2b-vuln-remediate.service automatically when a scan succeeds
          (via systemd OnSuccess=). Requires remediation.enable = true.
          Disabled by default for safety; requires explicit opt-in.
        '';
      };
      agent.argv = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Argv vector passed to d2b-vuln-remediate --agent-argv-json. Use the
          literal string {prompt_file} as a placeholder for the generated prompt
          path. Empty list disables agent execution (prompt is written but no
          process is launched).
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

    # Expose the state directory path in user sessions when status helpers or
    # Waybar integration are active. Commands pick this up automatically so
    # consumers do not need to pass --state-dir interactively.
    home.sessionVariables = lib.mkIf wantSessionStateDir {
      D2B_STATE_DIR = stateDir;
    };

    programs.waybar.settings = lib.mkIf (cfg.integrations.waybar.enable && cfg.integrations.waybar.autowire) {
      mainBar = {
        modules-right = lib.mkAfter [ waybarModuleName ];
        ${waybarModuleName} = {
          exec = exe "d2b-vuln-waybar";
          interval = 3600;
          return-type = "json";
          on-click = exe "d2b-vuln-open";
        };
      };
    };

    systemd.user.services.d2b-vuln-scan = {
      Unit = {
        Description = "d2b nixling vulnerability scan";
        X-RestartIfChanged = false;
      } // lib.optionalAttrs cfg.remediation.autoStartOnSuccess {
        OnSuccess = [ "d2b-vuln-remediate.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.escapeShellArgs ([ (exe "d2b-vuln-scan") ] ++ scanArgs);
        Environment = [
          "D2B_NIXLING_CLI=${cfg.nixling.cliPath}"
          "D2B_NIXLING_MANIFEST=${toString cfg.nixling.manifestPath}"
          "D2B_HOST_CLOSURE=${cfg.scan.hostClosurePath}"
          "D2B_INCLUDE_NET_VMS=${if cfg.nixling.includeNetVms then "1" else "0"}"
          "D2B_NOTIFY_FAILURES=${if cfg.notifications.enable then "1" else "0"}"
          "D2B_NOTIFY_FINDINGS=${if cfg.notifications.enable then "1" else "0"}"
        ];
        Nice = 10;
        IOSchedulingClass = "idle";
        IOSchedulingPriority = 7;
        CPUWeight = 50;
        MemoryMax = "1G";
        RuntimeMaxSec = "2h";
      };
    };

    systemd.user.timers.d2b-vuln-scan = lib.mkIf cfg.timer.enable {
      Unit.Description = "d2b nixling vulnerability scan timer";
      Timer = {
        OnCalendar = cfg.timer.onCalendar;
        Persistent = true;
        RandomizedDelaySec = cfg.timer.randomizedDelaySec;
        FixedRandomDelay = cfg.timer.fixedRandomDelay;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    systemd.user.services.d2b-vuln-remediate = lib.mkIf cfg.remediation.enable {
      Unit = {
        Description = "d2b vulnerability remediation agent";
        X-RestartIfChanged = false;
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.escapeShellArgs ([ (exe "d2b-vuln-remediate") "--state-dir" stateDir ]
          ++ lib.optionals (cfg.remediation.agent.argv != [ ])
            [ "--agent-argv-json" (builtins.toJSON cfg.remediation.agent.argv) ]);
      };
    };
  };
}
