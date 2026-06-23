---
name: d2b-vuln-remediation
description: Remediate d2b-vuln-scanner findings in nixling consumer repositories.
---

# d2b vulnerability remediation

Use this skill when a d2b-vuln-scanner report identifies Critical/High findings
in a nixling consumer repository.

Required workflow:

1. Read the prompt file supplied by `d2b-vuln-remediate`.
2. Read the referenced report and summary.
3. Bucket findings by `nix:host`, `nix:nixling-vm:<vm>`, and `dep:<input>`.
4. Prefer cache-safe Nix input bumps or upstream nixling fixes over private
   consumer overrides.
5. Propose changes for review. Do not silently commit, merge, apply, or deploy.
6. Re-run `d2b-vuln-scan` after changes and document residual findings.

This skill is for downstream vulnerability-fixing agents, not for maintaining
the scanner repository itself.

