#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

check_status() {
  local label="$1" dir="$2" want_state="$3" want_class="$4"
  local out
  out="$(D2B_STATE_DIR="$dir" "$root/bin/d2b-vuln-status" --json)"
  local got_state got_class
  got_state="$(jq -r '.state' <<<"$out")"
  got_class="$(jq -r '.class' <<<"$out")"
  [ "$got_state"  = "$want_state"  ] || fail "$label: state expected=$want_state got=$got_state"
  [ "$got_class"  = "$want_class"  ] || fail "$label: class expected=$want_class got=$got_class"
  # JSON contract: all required keys must be present
  jq -e 'has("state","class","text","ts","high_critical","errors","d2b_errors")' \
    <<<"$out" >/dev/null || fail "$label: JSON contract violation – missing key(s)"
}

check_waybar() {
  local label="$1" dir="$2" want_class="$3"
  local out
  out="$(D2B_STATE_DIR="$dir" PATH="$root/bin:$PATH" "$root/bin/d2b-vuln-waybar")"
  local got_class
  got_class="$(jq -r '.class' <<<"$out")"
  [ "$got_class" = "$want_class" ] || fail "$label (waybar): class expected=$want_class got=$got_class"
  # Waybar output must always be valid JSON with text/class/tooltip
  jq -e 'has("text","class","tooltip")' <<<"$out" >/dev/null \
    || fail "$label (waybar): invalid JSON contract"
}

now_ts="$(date -u +%Y%m%dT%H%M%SZ)"
stale_ts="19700101T000001Z"

# 1. missing – no summary.json
mkdir -p "$tmp/missing"
check_status "missing" "$tmp/missing" "missing" "missing"
check_waybar "missing" "$tmp/missing" "missing"

# 2. invalid – summary.json lacks a ts field
mkdir -p "$tmp/invalid"
echo '{"high_critical":0,"errors":0}' > "$tmp/invalid/summary.json"
check_status "invalid" "$tmp/invalid" "invalid" "error"
check_waybar "invalid" "$tmp/invalid" "error"

# 3. stale – ts is in the distant past
mkdir -p "$tmp/stale"
jq -n --arg ts "$stale_ts" '{ts:$ts,high_critical:0,errors:0,scan_errors:[]}' \
  > "$tmp/stale/summary.json"
check_status "stale" "$tmp/stale" "stale" "stale"
check_waybar "stale" "$tmp/stale" "stale"

# 4. clean – fresh ts, no findings, no errors
mkdir -p "$tmp/clean"
jq -n --arg ts "$now_ts" '{ts:$ts,high_critical:0,errors:0,scan_errors:[]}' \
  > "$tmp/clean/summary.json"
check_status "clean" "$tmp/clean" "clean" "clean"
check_waybar "clean" "$tmp/clean" "clean"
# text output (non-JSON) should say "clean"
text_out="$(D2B_STATE_DIR="$tmp/clean" "$root/bin/d2b-vuln-status")"
[ "$text_out" = "clean" ] || fail "clean: text output expected='clean' got='$text_out'"

# 5. findings – fresh ts, high_critical > 0, no errors
mkdir -p "$tmp/findings"
jq -n --arg ts "$now_ts" '{ts:$ts,high_critical:3,errors:0,scan_errors:[],
  totals:{critical:1,high:2,total:3}}' > "$tmp/findings/summary.json"
check_status "findings" "$tmp/findings" "findings" "critical"
check_waybar "findings" "$tmp/findings" "critical"
# Waybar display text must mention the count
wb_out="$(D2B_STATE_DIR="$tmp/findings" PATH="$root/bin:$PATH" "$root/bin/d2b-vuln-waybar")"
jq -e '.text | contains("3")' <<<"$wb_out" >/dev/null \
  || fail "findings (waybar): display text should contain finding count"

# 6. d2b_failure – all errors are d2b-discovery
mkdir -p "$tmp/d2b"
jq -n --arg ts "$now_ts" '{ts:$ts,high_critical:0,errors:1,
  scan_errors:[{source:"d2b-discovery",message:"d2b not found"}]}' \
  > "$tmp/d2b/summary.json"
check_status "d2b_failure" "$tmp/d2b" "d2b_failure" "warning"
check_waybar "d2b_failure" "$tmp/d2b" "warning"
nle="$(D2B_STATE_DIR="$tmp/d2b" "$root/bin/d2b-vuln-status" --json | jq -r '.d2b_errors')"
[ "$nle" = "1" ] || fail "d2b_failure: d2b_errors expected=1 got=$nle"

# 7. scanner_failure – at least one non-d2b error
mkdir -p "$tmp/scfail"
jq -n --arg ts "$now_ts" '{ts:$ts,high_critical:0,errors:2,
  scan_errors:[
    {source:"d2b-discovery",message:"d2b not found"},
    {source:"nix:host",message:"sbomnix failed"}]}' \
  > "$tmp/scfail/summary.json"
check_status "scanner_failure" "$tmp/scfail" "scanner_failure" "error"
check_waybar "scanner_failure" "$tmp/scfail" "error"
sf_ne="$(D2B_STATE_DIR="$tmp/scfail" "$root/bin/d2b-vuln-status" --json | jq -r '.d2b_errors')"
[ "$sf_ne" = "1" ] || fail "scanner_failure: d2b_errors expected=1 got=$sf_ne"
sf_e="$( D2B_STATE_DIR="$tmp/scfail" "$root/bin/d2b-vuln-status" --json | jq -r '.errors')"
[ "$sf_e"  = "2" ] || fail "scanner_failure: errors expected=2 got=$sf_e"

echo "test-status-adapters: all tests passed"

