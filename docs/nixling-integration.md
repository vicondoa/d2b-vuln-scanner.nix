# Nixling integration

The scanner uses nixling public contracts:

- `nixling list --json` for VM inventory and status.
- The public VM manifest as fallback metadata.
- A documented nixling closure/inspect surface for absolute guest closure store
  paths.

Reports label VM closure findings as `nix:nixling-vm:<vm>`.

If nixling does not expose a needed closure out path, add or request a nixling
surface. Do not rely on private package-name conventions.

