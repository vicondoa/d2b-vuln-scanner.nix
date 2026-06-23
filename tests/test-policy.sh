#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
if grep -R -n -E '/etc/nixos|paydro|work-aad|personal-dev' \
  "$root/README.md" "$root/docs" "$root/bin" "$root/hmModules" "$root/nixosModules" 2>/dev/null; then
  echo "private consumer detail leaked into upstream project" >&2
  exit 1
fi

