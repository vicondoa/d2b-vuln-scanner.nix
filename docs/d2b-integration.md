# d2b integration

The scanner uses d2b public contracts:

- `d2b list --json` for VM inventory and status.
- The public VM manifest as fallback metadata.
- `guestClosureOutPath` on each `d2b list --json` VM row for absolute guest
  closure store paths under `/nix/store`. Older d2b generations may require
  an inspect-like fallback; the scanner must not infer private paths when both
  surfaces are absent.

Reports label VM closure findings as `nix:d2b-vm:<vm>`.

VM rows with `runtimeKind = "qemu-media"` do not have a NixOS guest closure and
are skipped when no closure path is exposed.

If d2b does not expose a needed closure out path, add or request a d2b
surface. Do not rely on private package-name conventions.
