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
              touch $out
            '';
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
