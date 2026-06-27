# Nixling integration

The scanner uses nixling public contracts:

- `nixling list --json` for VM inventory and status.
- The public VM manifest as fallback metadata.
- `guestClosureOutPath` on each `nixling list --json` VM row for absolute guest
  closure store paths under `/nix/store`. Older nixling generations may require
  an inspect-like fallback; the scanner must not infer private paths when both
  surfaces are absent.

Reports label VM closure findings as `nix:nixling-vm:<vm>`.

If nixling does not expose a needed closure out path, add or request a nixling
surface. Do not rely on private package-name conventions.
