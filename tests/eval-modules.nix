# Module evaluation smoke tests.
#
# Evaluates hmModules/default.nix with minimal Home Manager infrastructure
# stubs and asserts option structure, defaults, and conditional outputs.
#
# Standalone usage (Makefile):
#   nix-instantiate --eval --strict --arg nixpkgsPath '"<path>"' tests/eval-modules.nix
#
# Flake check usage:
#   pkgs.writeText "results" (builtins.toJSON (import ./tests/eval-modules.nix { nixpkgsPath = pkgs.path; }))
# Returns a plain list of result records; wrapping in writeText forces build-time assertion.
{ nixpkgsPath ? <nixpkgs> }:
let
  lib = (import nixpkgsPath { system = "x86_64-linux"; }).lib;
  pkgsForModule = import nixpkgsPath { system = "x86_64-linux"; };

  # ── Minimal Home Manager infrastructure stubs ───────────────────────────
  # Declare only the options that hmModules/default.nix sets. Anything not
  # declared here would cause an "undefined option" error during eval.
  hmStubs = {
    options = {
      xdg.stateHome = lib.mkOption {
        type = lib.types.str;
        default = "/home/testuser/.local/state";
      };
      home.packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
      };
      home.sessionVariables = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
      };
      systemd.user.services = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
      systemd.user.timers = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
      programs.waybar.settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
    };
  };

  # Evaluate the HM module with extra per-test config modules.
  evalHm = extraModules:
    (lib.evalModules {
      modules = [
        { _module.args = { pkgs = pkgsForModule; }; }
        hmStubs
        (import ../hmModules/default.nix)
      ] ++ extraModules;
    }).config;

  # ── Test helpers ─────────────────────────────────────────────────────────
  assertEq = name: got: expected:
    if got == expected
    then { result = "PASS"; test = name; }
    else throw "FAIL ${name}: expected ${builtins.toJSON expected} got ${builtins.toJSON got}";

  assertHas = name: attrset: key:
    if attrset ? ${key}
    then { result = "PASS"; test = name; }
    else throw "FAIL ${name}: expected key '${key}' not found in ${builtins.toJSON (builtins.attrNames attrset)}";

  assertLacks = name: attrset: key:
    if !(attrset ? ${key})
    then { result = "PASS"; test = name; }
    else throw "FAIL ${name}: unexpected key '${key}' present";

  # ── Test cases ───────────────────────────────────────────────────────────

  # 1. Disabled default: enable = false → nothing installed, no units, no vars
  testDisabledDefault =
    let c = evalHm [{ config.programs.d2b-vuln-scanner.enable = false; }]; in
    [
      (assertEq "disabled/no-packages" c.home.packages [ ])
      (assertEq "disabled/no-services" c.systemd.user.services { })
      (assertEq "disabled/no-timers" c.systemd.user.timers { })
      (assertEq "disabled/no-session-vars" c.home.sessionVariables { })
    ];

  # 2. Scan-only defaults: enable = true, all sub-options at default values →
  #    scan service exists, no timer, no remediation service, no session var
  testScanOnly =
    let c = evalHm [{ config.programs.d2b-vuln-scanner.enable = true; }]; in
    [
      (assertHas   "scan-only/scan-service"    c.systemd.user.services "d2b-vuln-scan")
      (assertLacks "scan-only/no-timer"        c.systemd.user.timers   "d2b-vuln-scan")
      (assertLacks "scan-only/no-remediate"    c.systemd.user.services "d2b-vuln-remediate")
      (assertLacks "scan-only/no-state-dir"    c.home.sessionVariables "D2B_STATE_DIR")
    ];

  # 3. statusHelper.enable → D2B_STATE_DIR exported in user session
  testStatusHelper =
    let c = evalHm [{
      config.programs.d2b-vuln-scanner = {
        enable = true;
        statusHelper.enable = true;
      };
    }]; in
    [
      (assertHas "status-helper/state-dir-var" c.home.sessionVariables "D2B_STATE_DIR")
    ];

  # 4. integrations.waybar.enable → D2B_STATE_DIR exported (waybar needs it)
  testWaybarHelper =
    let c = evalHm [{
      config.programs.d2b-vuln-scanner = {
        enable = true;
        integrations.waybar.enable = true;
      };
    }]; in
    [
      (assertHas "waybar-helper/state-dir-var" c.home.sessionVariables "D2B_STATE_DIR")
    ];

  # 4b. integrations.waybar.autowire → custom Waybar module is declared.
  testWaybarAutowire =
    let c = evalHm [{
      config.programs.d2b-vuln-scanner = {
        enable = true;
        integrations.waybar = {
          enable = true;
          autowire = true;
        };
      };
    }]; in
    [
      (assertHas "waybar-autowire/mainbar" c.programs.waybar.settings "mainBar")
      (assertHas "waybar-autowire/custom-module" c.programs.waybar.settings.mainBar "custom/d2b-vuln")
      (assertEq "waybar-autowire/return-type"
        c.programs.waybar.settings.mainBar."custom/d2b-vuln".return-type
        "json")
    ];

  # 5. remediation.enable → remediate service present alongside scan service
  testRemediationEnabled =
    let c = evalHm [{
      config.programs.d2b-vuln-scanner = {
        enable = true;
        remediation.enable = true;
      };
    }]; in
    [
      (assertHas "remediation/remediate-service" c.systemd.user.services "d2b-vuln-remediate")
      (assertHas "remediation/scan-service"      c.systemd.user.services "d2b-vuln-scan")
    ];

  # 6. timer.enable → timer unit declared
  testTimerEnabled =
    let c = evalHm [{
      config.programs.d2b-vuln-scanner = {
        enable = true;
        timer.enable = true;
      };
    }]; in
    [
      (assertHas "timer/timer-unit" c.systemd.user.timers "d2b-vuln-scan")
    ];

  allTests =
    testDisabledDefault
    ++ testScanOnly
    ++ testStatusHelper
    ++ testWaybarHelper
    ++ testWaybarAutowire
    ++ testRemediationEnabled
    ++ testTimerEnabled;

in
# builtins.deepSeq forces evaluation of every test assertion.
# Any assert failure surfaces as a Nix evaluation error.
# Returns a plain list of result records — safe to evaluate with --strict.
builtins.deepSeq allTests allTests
