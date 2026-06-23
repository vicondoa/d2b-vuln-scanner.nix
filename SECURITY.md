# Security policy

`d2b-vuln-scanner.nix` reads local nixling inventory metadata and scanner output.
Reports contain package names, versions, advisory IDs, source labels, and VM
labels; they must not contain source contents or secrets.

Scanner tools may fetch vulnerability databases unless consumers configure
offline or cached databases. Optional telemetry should be disabled where the
underlying tools support it.

Remediation is disabled by default. When enabled, the agent command is an argv
vector and receives a generated prompt file. The default posture is to propose
changes for review, not silently commit, merge, apply, or deploy them.

