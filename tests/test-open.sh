#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/state"
echo "report" > "$tmp/state/report-test.txt"
ln -s report-test.txt "$tmp/state/latest.txt"

path="$(D2B_STATE_DIR="$tmp/state" "$root/bin/d2b-vuln-open" --print-path)"
[ "$path" = "$tmp/state/report-test.txt" ]

