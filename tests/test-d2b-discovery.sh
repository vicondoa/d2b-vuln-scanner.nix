#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

chmod +x "$root/tests/fixtures/bin/d2b-list-success"
mkdir -p "$tmp/closure"
D2B_TEST_CLOSURE_PATH="$tmp/closure" \
D2B_CLI="$root/tests/fixtures/bin/d2b-list-success" \
D2B_STATE_DIR="$tmp/state-list-field" \
D2B_HOST_CLOSURE="$tmp/closure" \
  "$root/bin/d2b-vuln-scan" --dry-run --flake "$root" >"$tmp/list-field.out"

jq -e '.d2b.vm_count == 2' "$tmp/state-list-field/summary.json" >/dev/null
jq -e 'all(.scan_errors[]?; (.source | startswith("nix:d2b-vm:") | not))' \
  "$tmp/state-list-field/summary.json" >/dev/null

D2B_TEST_CLOSURE_PATH="/nix/store/inspect-fallback-system" \
D2B_CLI="$root/tests/fixtures/bin/d2b-list-success" \
D2B_LIST_FIXTURE="$root/tests/fixtures/d2b-list-without-closures.json" \
D2B_ALLOW_INSPECT_FALLBACK=1 \
D2B_STATE_DIR="$tmp/state-inspect-fallback" \
D2B_HOST_CLOSURE="$tmp/closure" \
  "$root/bin/d2b-vuln-scan" --dry-run --flake "$root" >"$tmp/inspect-fallback.out"

jq -e '.d2b.vm_count == 2' "$tmp/state-inspect-fallback/summary.json" >/dev/null
jq -e 'all(.scan_errors[]?; (.source | startswith("nix:d2b-vm:") | not))' \
  "$tmp/state-inspect-fallback/summary.json" >/dev/null

D2B_TEST_CLOSURE_PATH="$tmp/closure" \
D2B_CLI="$root/tests/fixtures/bin/d2b-list-success" \
D2B_LIST_FIXTURE="$root/tests/fixtures/d2b-list-without-closures.json" \
D2B_STATE_DIR="$tmp/state-missing-closure" \
D2B_HOST_CLOSURE="$tmp/closure" \
  "$root/bin/d2b-vuln-scan" --dry-run --flake "$root" >"$tmp/missing-closure.out"

jq -e '.scan_errors | map(select(.source | startswith("nix:d2b-vm:"))) | length == 2' \
  "$tmp/state-missing-closure/summary.json" >/dev/null

D2B_CLI="$root/tests/fixtures/bin/d2b-list-success" \
D2B_LIST_FIXTURE="$root/tests/fixtures/d2b-list-relative-closure.json" \
D2B_STATE_DIR="$tmp/state-relative-closure" \
D2B_HOST_CLOSURE="$tmp/closure" \
  "$root/bin/d2b-vuln-scan" --dry-run --flake "$root" >"$tmp/relative-closure.out"

jq -e '
  .scan_errors
  | map(select(.source == "nix:d2b-vm:alpha-vm"
      and .message == "d2b exposed a VM closure out path outside /nix/store"))
  | length == 1' "$tmp/state-relative-closure/summary.json" >/dev/null

D2B_CLI="$root/tests/fixtures/bin/d2b-list-success" \
D2B_LIST_FIXTURE="$root/tests/fixtures/d2b-list-qemu-media.json" \
D2B_STATE_DIR="$tmp/state-qemu-media" \
D2B_HOST_CLOSURE="$tmp/closure" \
  "$root/bin/d2b-vuln-scan" --dry-run --flake "$root" >"$tmp/qemu-media.out"

jq -e '.d2b.vm_count == 2' "$tmp/state-qemu-media/summary.json" >/dev/null
jq -e 'all(.scan_errors[]?; (.source | startswith("nix:d2b-vm:") | not))' \
  "$tmp/state-qemu-media/summary.json" >/dev/null
