#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

chmod +x "$root/tests/fixtures/bin/nixling-list-success"
mkdir -p "$tmp/closure"
D2B_TEST_CLOSURE_PATH="$tmp/closure" \
D2B_NIXLING_CLI="$root/tests/fixtures/bin/nixling-list-success" \
D2B_STATE_DIR="$tmp/state" \
D2B_HOST_CLOSURE="$tmp/closure" \
  "$root/bin/d2b-vuln-scan" --dry-run --flake "$root" >/tmp/d2b-test-nixling.out

jq -e '.nixling.vm_count == 2' "$tmp/state/summary.json" >/dev/null

