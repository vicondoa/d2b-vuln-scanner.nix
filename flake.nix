{
  description = "Nixling-native vulnerability scanner flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
      pkgsFor = system: import nixpkgs { inherit system; };
      mkApp = program: { type = "app"; inherit program; };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          runtimeInputs = with pkgs; [
            bash
            coreutils
            findutils
            gawk
            gnugrep
            grype
            jq
            libnotify
            moreutils
            openssl
            osv-scanner
            sbomnix
            util-linux
            xdg-utils
          ];
          script = name: pkgs.writeShellApplication {
            inherit name runtimeInputs;
            text = builtins.readFile ./bin/${name};
          };
        in
        rec {
          d2b-vuln-scan = script "d2b-vuln-scan";
          d2b-vuln-open = script "d2b-vuln-open";
          d2b-vuln-state = script "d2b-vuln-state";
          d2b-vuln-status = script "d2b-vuln-status";
          d2b-vuln-waybar = script "d2b-vuln-waybar";
          d2b-vuln-remediate = script "d2b-vuln-remediate";
          d2b-vuln-scanner = pkgs.symlinkJoin {
            name = "d2b-vuln-scanner";
            paths = [
              d2b-vuln-scan
              d2b-vuln-open
              d2b-vuln-state
              d2b-vuln-status
              d2b-vuln-waybar
              d2b-vuln-remediate
            ];
          };
          default = d2b-vuln-scanner;
        });

      apps = forAllSystems (system:
        let pkg = self.packages.${system}; in {
          scan = mkApp "${pkg.d2b-vuln-scan}/bin/d2b-vuln-scan";
          open = mkApp "${pkg.d2b-vuln-open}/bin/d2b-vuln-open";
          state = mkApp "${pkg.d2b-vuln-state}/bin/d2b-vuln-state";
          status = mkApp "${pkg.d2b-vuln-status}/bin/d2b-vuln-status";
          waybar = mkApp "${pkg.d2b-vuln-waybar}/bin/d2b-vuln-waybar";
          remediate = mkApp "${pkg.d2b-vuln-remediate}/bin/d2b-vuln-remediate";
          default = mkApp "${pkg.default}/bin/d2b-vuln-scan";
        });

      checks = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          lib = pkgs.lib;
          # ── HM module infrastructure stubs (mirrored in tests/eval-modules.nix)
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
            };
          };
          evalHm = extraModules:
            (lib.evalModules {
              modules = [
                { _module.args = { pkgs = pkgs; }; }
                hmStubs
                (import ./hmModules/default.nix)
              ] ++ extraModules;
            }).config;
          moduleTests = [
            # 1. Disabled default
            (let c = evalHm [{ config.programs.d2b-vuln-scanner.enable = false; }]; in
              assert c.systemd.user.services == { };
              assert c.systemd.user.timers == { };
              assert c.home.packages == [ ];
              assert c.home.sessionVariables == { };
              "disabled-default: PASS")
            # 2. Scan-only defaults
            (let c = evalHm [{ config.programs.d2b-vuln-scanner.enable = true; }]; in
              assert c.systemd.user.services ? "d2b-vuln-scan";
              assert !(c.systemd.user.timers ? "d2b-vuln-scan");
              assert !(c.systemd.user.services ? "d2b-vuln-remediate");
              assert !(c.home.sessionVariables ? "D2B_STATE_DIR");
              "scan-only: PASS")
            # 3. statusHelper.enable sets D2B_STATE_DIR
            (let c = evalHm [{
              config.programs.d2b-vuln-scanner = {
                enable = true;
                statusHelper.enable = true;
              };
            }]; in
              assert c.home.sessionVariables ? "D2B_STATE_DIR";
              "status-helper: PASS")
            # 4. waybar.enable sets D2B_STATE_DIR
            (let c = evalHm [{
              config.programs.d2b-vuln-scanner = {
                enable = true;
                integrations.waybar.enable = true;
              };
            }]; in
              assert c.home.sessionVariables ? "D2B_STATE_DIR";
              "waybar-helper: PASS")
            # 5. Remediation service present when enabled
            (let c = evalHm [{
              config.programs.d2b-vuln-scanner = {
                enable = true;
                remediation.enable = true;
              };
            }]; in
              assert c.systemd.user.services ? "d2b-vuln-remediate";
              "remediation-enabled: PASS")
            # 6. Timer unit present when enabled
            (let c = evalHm [{
              config.programs.d2b-vuln-scanner = {
                enable = true;
                timer.enable = true;
              };
            }]; in
              assert c.systemd.user.timers ? "d2b-vuln-scan";
              "timer-enabled: PASS")
          ];
        in
        {
          shell-tests = pkgs.runCommand "d2b-shell-tests"
            {
              nativeBuildInputs = with pkgs; [ bash shellcheck jq coreutils gnugrep gawk util-linux ];
            }
            ''
              cp -R ${self} src
              cd src
              patchShebangs bin tests
              make test-shell
              make test-fixtures
              make test-policy
              make test-nixling-discovery
              make test-modules
              make test-changelog
              touch $out
            '';
          # Module eval: assertions run at Nix eval time (no build sandbox needed).
          # Any assert failure surfaces as a Nix evaluation error when instantiated.
          module-eval = pkgs.writeText "d2b-module-eval-results"
            (builtins.toJSON (builtins.deepSeq moduleTests moduleTests));
        });

      homeManagerModules.default = import ./hmModules/default.nix;
      nixosModules.default = import ./nixosModules/default.nix;

      devShells = forAllSystems (system:
        let pkgs = pkgsFor system; in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              actionlint
              bash
              gh
              grype
              jq
              osv-scanner
              sbomnix
              shellcheck
              nixfmt
            ];
          };
        });

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);
    };
}
