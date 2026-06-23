#!/usr/bin/env bash
# Module eval tests: runs eval-modules.nix via nix-instantiate.
# Resolves the nixpkgs path from the system registry so the test is hermetic.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

# Resolve nixpkgs store path. Prefer the system registry (fast); fall back to
# evaluating the flake input (slower but works without a registered nixpkgs).
nixpkgs_path="$(
  nix eval --raw 'nixpkgs#path' 2>/dev/null \
  || nix eval --impure --raw \
       '(builtins.getFlake "'"$root"'").inputs.nixpkgs.outPath' 2>/dev/null \
  || true
)"

if [ -z "$nixpkgs_path" ]; then
  echo "test-modules: cannot resolve nixpkgs path; skipping Nix eval tests" >&2
  exit 0
fi

nix-instantiate --eval --strict \
  --arg nixpkgsPath "\"${nixpkgs_path}\"" \
  "${root}/tests/eval-modules.nix" >/dev/null

echo "test-modules: all tests passed"
