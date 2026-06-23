---
name: d2b-vuln-remediation
description: >
  Remediate d2b-vuln-scanner findings in nixling consumer repositories.
  Use when a d2b-vuln-scan report identifies Critical/High vulnerabilities.
---

# d2b vulnerability remediation (Claude skill)

Use this skill when a `d2b-vuln-scan` report identifies Critical/High findings
in a nixling consumer repository.

## Scope

This skill is for **downstream vulnerability-fixing agents** operating on
scanner findings in consumer repositories. It is **not** the workflow for
maintaining the scanner repository itself.

## Required workflow

### Step 1 — Read the prompt file and reports

The prompt file is delivered via the `{prompt_file}` argv placeholder or via
standard input.  It contains:

- Absolute paths to `summary.json` and `latest.txt` (the report).
- Finding counts (critical, high, new since last run, scan errors).
- The list of **VM source labels** present in the report (e.g.
  `nix:nixling-vm:my-vm`).
- The exact scan command for post-fix validation.
- Consumer boundary rules you must not violate.

Read the full report at the path stated in the prompt. The columns are:
`SEVERITY  ID  PACKAGE+VERSION  SOURCE  FIXED-VERSION`.

### Step 2 — Triage by source label

Group findings by the SOURCE column:

| Label                       | Meaning                                               |
|-----------------------------|-------------------------------------------------------|
| `nix:host`                  | Host NixOS closure vulnerability.                     |
| `nix:nixling-vm:<vm-name>`  | Named nixling VM closure vulnerability.               |
| `dep:<input-name>`          | Flake input scanned by osv-scanner.                   |

Treat every `nix:nixling-vm:` finding as a **nixling closure finding**.
When the same CVE appears under both `nix:host` and one or more VM labels,
a single nixpkgs input bump typically resolves all instances at once.

### Step 3 — Propose cache-safe Nix remediation

**Prefer (in this order):**

1. Bump the `nixpkgs` input to a revision that already has a binary substitute
   on `cache.nixos.org`.
2. Bump the upstream nixling input when the fix lives in the nixling package set.
3. Bump the affected flake input (`dep:<name>`) to a patched release.

**Avoid:**

- Local source overrides of core/high-fanout packages (OpenSSL, glibc, LLVM,
  systemd, Python, Perl, GStreamer, ffmpeg, libcap, libgcrypt, libxml2, sqlite).
  These defeat binary caches and force a full local rebuild.
- Broad compiler wrapper changes (`ccacheStdenv`, `rustPlatform.buildRustPackage`
  wrappers) that alter derivation hashes across many packages.

### Step 4 — Propose changes for review (never apply silently)

**You MUST NOT:**

- Silently commit, apply, merge, or deploy any change.
- Push directly to protected branches without a pull request and review.
- Embed private consumer paths, hostnames, VM names, or local operational
  policy into any upstream file or skill document.

**You MUST:**

- Propose all changes as a reviewed diff or pull request.
- List every resolved CVE in the proposal.
- Document residual findings that cannot be remediated right now as:
  `residual: <CVE-ID> <brief reason>`.

### Step 5 — Re-scan and report results

Re-run the scanner using the scan command from the prompt file
(e.g. `d2b-vuln-scan --state-dir ... --flake ...`) after the branch is
available or the fix is applied in a test environment.

Report:
- How many Critical/High findings were resolved.
- How many remain (residual) and why they cannot be fixed right now.

### Step 6 — No private consumer assumptions

Do not hard-code consumer repository names, deployment targets, CI pipeline
names, reviewer lists, secret names, or branch protection rules.  All such
details are consumer-owned and outside this skill's scope.

