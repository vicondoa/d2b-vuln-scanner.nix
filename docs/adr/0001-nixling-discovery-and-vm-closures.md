# ADR 0001: Nixling discovery and VM closures

Status: Accepted

The scanner is nixling-native. It discovers VM inventory through
`nixling list --json` and reads `guestClosureOutPath` from each VM row when
present. It may use the public manifest for fallback metadata. It must not infer
VM identity from private package-name regexes.

`sbomnix` requires absolute store paths for closures. The preferred upstream
surface is `guestClosureOutPath` on `nixling list --json`; an inspect-like
fallback is accepted only for compatibility with older nixling generations. If
nixling does not expose a VM guest closure out path, the correct fix is an
upstream nixling surface, not a private consumer convention.
