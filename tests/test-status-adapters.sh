#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/state"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
jq -n --arg ts "$ts" '{ts:$ts,high_critical:2,errors:0,totals:{critical:1,high:1,total:2}}' > "$tmp/state/summary.json"

status="$(D2B_STATE_DIR="$tmp/state" "$root/bin/d2b-vuln-status" --json)"
jq -e '.class == "critical" and .high_critical == 2' <<<"$status" >/dev/null

waybar="$(D2B_STATE_DIR="$tmp/state" PATH="$root/bin:$PATH" "$root/bin/d2b-vuln-waybar")"
jq -e '.class == "critical" and (.text | contains("2"))' <<<"$waybar" >/dev/null

