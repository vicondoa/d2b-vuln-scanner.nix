---
name: d2b-vuln-remediation
description: >
  Remediate d2b-vuln-scanner findings in nixling consumer repositories.
  Use when a d2b-vuln-scan report identifies Critical/High vulnerabilities.
---

# d2b vulnerability remediation (GitHub skill)

Use this skill when a `d2b-vuln-scan` report identifies Critical/High findings
in a nixling consumer repository.

## Scope

This skill is for **downstream vulnerability-fixing agents** operating on
scanner findings in consumer repositories. It is **not** the workflow for
maintaining the scanner repository itself.

## Required workflow

### Step 1 — Read the prompt file and reports

The prompt file path is supplied by `d2b-vuln-remediate` via the `{prompt_file}`
argv placeholder or stdin.  It contains:

- Paths to `summary.json` and `latest.txt` (the report).
- Finding counts (critical, high, new since last run, scan errors).
- The list of **VM source labels** present in the report (e.g.
  `nix:nixling-vm:my-vm`).
- The scan command for re-validation.
- Consumer boundary rules.

Read the report at the path specified in the prompt.  The report columns are:
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
a single nixpkgs input bump typically resolves all instances.

### Step 3 — Propose cache-safe Nix remediation

**Prefer (in this order):**

1. Bump the `nixpkgs` input to a revision that already has a binary substitute
   on `cache.nixos.org`.  Check the NixOS security tracker or the nixpkgs
   commit log for the fix.
2. Bump the upstream nixling input if the fix lives in the nixling package set.
3. Bump the affected flake input (`dep:<name>`) to a patched release.

**Avoid:**

- Local source overrides of core/high-fanout packages (OpenSSL, glibc, LLVM,
  systemd, Python, Perl, GStreamer, ffmpeg, libcap, libgcrypt, libxml2, sqlite).
  These invalidate binary caches and force a full local rebuild.
- Broad `ccacheStdenv` or `rustPlatform.buildRustPackage` wrappers that alter
  derivation hashes.

### Step 4 — Open a pull request (do not silently apply)

**You MUST NOT:**

- Commit, merge, apply, or deploy any change without a pull request and review.
- Push directly to protected branches.
- Embed private consumer paths, hostnames, VM names, or local operational
  policy into any upstream file or skill document.

**You MUST:**

- Propose all changes as a GitHub pull request with a descriptive title and body.
- List every resolved CVE in the PR body.
- Document residual findings that cannot be remediated right now as:
  `residual: <CVE-ID> <brief reason>` in the PR description.

### Step 5 — Re-scan and report results

After the branch is available, re-run the scanner using the command from the
prompt file (e.g. `d2b-vuln-scan --state-dir ... --flake ...`).

Include the updated finding count in the PR body or as a follow-up comment:
- How many Critical/High findings were resolved.
- How many remain (residual), and why.

### Step 6 — No private consumer assumptions

Do not hard-code consumer repository names, branch protection rules, CI
pipeline names, deployment targets, secret names, or reviewer lists.  All
such details are consumer-owned and outside this skill's scope.

