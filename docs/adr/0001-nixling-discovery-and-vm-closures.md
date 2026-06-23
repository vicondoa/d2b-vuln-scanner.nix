# ADR 0001: Nixling discovery and VM closures

Status: Accepted

The scanner is nixling-native. It discovers VM inventory through
`nixling list --json` and may use the public manifest for fallback metadata.
It must not infer VM identity from private package-name regexes.

`sbomnix` requires absolute store paths for closures. If nixling does not expose
a VM guest closure out path, the correct fix is an upstream nixling surface such
as a manifest field or inspect command, not a private consumer convention.

