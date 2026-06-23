#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/state"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
jq -n --arg ts "$ts" '{ts:$ts,high_critical:1,errors:0}' > "$tmp/state/summary.json"
echo "report" > "$tmp/state/report-test.txt"
ln -s report-test.txt "$tmp/state/latest.txt"

D2B_STATE_DIR="$tmp/state" "$root/bin/d2b-vuln-remediate" >/tmp/d2b-remediate.out
grep -q 'prompt written' /tmp/d2b-remediate.out
test -n "$(find "$tmp/state/remediation" -name 'prompt-*.md' -print -quit)"

