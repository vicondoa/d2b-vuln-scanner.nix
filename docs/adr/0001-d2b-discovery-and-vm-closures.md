# ADR 0001: d2b discovery and VM closures

Status: Accepted

The scanner is d2b-native. It discovers VM inventory through
`d2b list --json` and reads `guestClosureOutPath` from each VM row when
present. It may use the public manifest for fallback metadata. It must not infer
VM identity from private package-name regexes.

`sbomnix` requires absolute `/nix/store` paths for closures. The preferred
upstream surface is `guestClosureOutPath` on `d2b list --json`; an
inspect-like fallback is accepted only for compatibility with older d2b
generations. If d2b does not expose a VM guest closure out path, the correct
fix is an upstream d2b surface, not a private consumer convention.
