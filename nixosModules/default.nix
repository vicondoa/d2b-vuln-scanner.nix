{ config, lib, ... }:

let
  cfg = config.services.d2b-vuln-scanner;
in
{
  options.services.d2b-vuln-scanner = {
    enable = lib.mkEnableOption "system-level defaults for d2b nixling vulnerability scanning";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Optional package to install system-wide.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.mkIf (cfg.package != null) [ cfg.package ];
  };
}

