# Changelog

All notable changes to `d2b-vuln-scanner.nix` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/) and the
project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Renamed the scanner's d2b integration surface from the old product naming to
  `d2b`: Home Manager options now use `programs.d2b-vuln-scanner.d2b.*`,
  scan environment variables use `D2B_CLI` / `D2B_MANIFEST`, and VM findings are
  labeled as `nix:d2b-vm:<name>`.

### Added

- d2b VM scans now read `guestClosureOutPath` directly from
  `d2b list --json`, with an explicit older-generation inspect fallback and
  fail-closed errors when no public closure path is available.
- Home Manager Waybar autowiring now adds the `custom/d2b-vuln` module when
  `programs.d2b-vuln-scanner.integrations.waybar.autowire = true`.
- QEMU-media d2b VMs without a NixOS guest closure are skipped during VM
  closure scanning instead of being reported as closure-path errors.
- The Home Manager scan service no longer sets `RuntimeMaxSec` on its oneshot
  unit, avoiding systemd's ignored-setting warning.
- Initial d2b-native vulnerability scanner flake skeleton with CLI commands,
  Home Manager/NixOS module placeholders, ADRs, CI, tests, and remediation skills.
- Hardened d2b scanner contracts with richer status/remediation behavior,
  module eval checks, CI policy gates, consumer migration docs, and downstream
  vulnerability-fixing skills.
