# Changelog

All notable changes to `d2b-vuln-scanner.nix` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/) and the
project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Nixling VM scans now read `guestClosureOutPath` directly from
  `nixling list --json`, with an explicit older-generation inspect fallback and
  fail-closed errors when no public closure path is available.
- Home Manager Waybar autowiring now adds the `custom/d2b-vuln` module when
  `programs.d2b-vuln-scanner.integrations.waybar.autowire = true`.
- Initial nixling-native vulnerability scanner flake skeleton with CLI commands,
  Home Manager/NixOS module placeholders, ADRs, CI, tests, and remediation skills.
- Hardened nixling scanner contracts with richer status/remediation behavior,
  module eval checks, CI policy gates, consumer migration docs, and downstream
  vulnerability-fixing skills.
