---
name: d2b-vuln-remediation
description: Remediate d2b-vuln-scanner findings in nixling consumer repositories.
---

# d2b vulnerability remediation

Follow the same workflow as the GitHub skill:

- read the generated prompt, report, and summary;
- respect nixling VM source labels;
- keep remediation cache-safe;
- propose changes for review rather than silently applying or deploying them;
- re-run the scanner and document residual findings.

This skill is for downstream vulnerability-fixing agents, not for maintaining
the scanner repository itself.

