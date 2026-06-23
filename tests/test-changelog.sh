#!/usr/bin/env bash
# Structural lint for CHANGELOG.md.
# Checks format integrity; does NOT enforce whether the file was modified in a
# given PR (that is the job of the changelog-gate CI workflow).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cl="$root/CHANGELOG.md"
ok=1

if [[ ! -f "$cl" ]]; then
  echo "CHANGELOG.md not found" >&2
  exit 1
fi

if ! grep -q '^## \[Unreleased\]' "$cl"; then
  echo "CHANGELOG.md: missing ## [Unreleased] section" >&2
  ok=0
fi

if ! grep -q 'keepachangelog\.com' "$cl"; then
  echo "CHANGELOG.md: missing Keep a Changelog reference" >&2
  ok=0
fi

if ! grep -q 'semver\.org' "$cl"; then
  echo "CHANGELOG.md: missing Semantic Versioning reference" >&2
  ok=0
fi

[[ "$ok" -eq 1 ]]
