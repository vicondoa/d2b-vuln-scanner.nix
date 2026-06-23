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
in
{
  options.programs.d2b-vuln-scanner = {
    enable = lib.mkEnableOption "nixling-native vulnerability scanning";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Package providing the d2b-vuln-* commands. Null means resolve commands from PATH.";
    };

    nixling = {
      cliPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Optional nixling package. When set, cliPath defaults to this package's executable.";
      };
      cliPath = lib.mkOption {
        type = lib.types.str;
        default =
          if cfg.nixling.cliPackage != null
          then lib.getExe cfg.nixling.cliPackage
          else "nixling";
        defaultText = lib.literalExpression "lib.getExe cfg.nixling.cliPackage or \"nixling\"";
        description = "Path or command name used for nixling CLI discovery.";
      };
      manifestPath = lib.mkOption {
        type = lib.types.path;
        default = "/run/current-system/sw/share/nixling/vms.json";
        description = "Public nixling manifest path used as fallback metadata.";
      };
      includeNetVms = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether scans include nixling net VMs by default.";
      };
    };

    scan = {
      flake = lib.mkOption {
        type = lib.types.str;
        default = ".";
        description = "Consumer flake path used for selected source/input scanning.";
      };
      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.stateHome}/d2b-vuln-scanner";
        description = "XDG state directory for reports, summaries, locks, and remediation logs.";
      };
      hostClosurePath = lib.mkOption {
        type = lib.types.str;
        default = "/run/current-system";
        description = "Host closure path to scan.";
      };
    };

    timer = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable the user timer.";
      };
      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "systemd OnCalendar value for the scanner timer.";
      };
      randomizedDelaySec = lib.mkOption {
        type = lib.types.str;
        default = "30min";
        description = "RandomizedDelaySec for the scanner timer.";
      };
      fixedRandomDelay = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether systemd should keep the randomized delay stable per machine.";
      };
    };

    notifications.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether scanner commands may send standard D-Bus notifications.";
    };

    integrations.waybar = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Install Waybar helper command and snippets.";
      };
      autowire = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Explicitly opt into Home Manager Waybar autowiring for the d2b-vuln module.";
      };
    };

    remediation = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to install remediation helper integration.";
      };
      autoStartOnSuccess = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether successful scans should start remediation. Disabled by default.";
      };
      agent.argv = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Argv vector for the vulnerability-fixing agent. Use {prompt_file} as placeholder.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf (cfg.package != null) [ cfg.package ];

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

