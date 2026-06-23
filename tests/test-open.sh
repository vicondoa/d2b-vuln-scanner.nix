#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$tmp/state"
echo "vulnerability report content" > "$tmp/state/report-test.txt"
ln -s report-test.txt "$tmp/state/latest.txt"

# --print-path resolves the symlink and returns the target path
path="$(D2B_STATE_DIR="$tmp/state" "$root/bin/d2b-vuln-open" --print-path)"
[ "$path" = "$tmp/state/report-test.txt" ] || fail "--print-path: got '$path'"

# --no-pager writes report contents to stdout
pager_out="$(D2B_STATE_DIR="$tmp/state" "$root/bin/d2b-vuln-open" --no-pager)"
[ "$pager_out" = "vulnerability report content" ] || fail "--no-pager: got '$pager_out'"

# D2B_OPEN_ARGV_JSON substitutes {report} and executes the command
argv_out="$(D2B_OPEN_ARGV_JSON='["echo","{report}"]' \
  D2B_STATE_DIR="$tmp/state" "$root/bin/d2b-vuln-open")"
[ "$argv_out" = "$tmp/state/report-test.txt" ] || fail "D2B_OPEN_ARGV_JSON: got '$argv_out'"

# D2B_OPEN_ARGV_JSON preserves newlines inside a single argv element
newline_out="$tmp/newline-arg.txt"
newline_json="$(jq -cn --arg out "$newline_out" --arg arg $'first\nsecond' '["bash","-c","printf %s \"$1\" > \"$2\"","--",$arg,$out]')"
D2B_OPEN_ARGV_JSON="$newline_json" D2B_STATE_DIR="$tmp/state" "$root/bin/d2b-vuln-open"
[ "$(cat "$newline_out")" = $'first\nsecond' ] || fail "D2B_OPEN_ARGV_JSON split newline-containing argv"

# Invalid viewer JSON is a usage error, not a silent fallback
rc=0
D2B_OPEN_ARGV_JSON='["unterminated"' D2B_STATE_DIR="$tmp/state" \
  "$root/bin/d2b-vuln-open" 2>/dev/null || rc=$?
[ "$rc" -eq 64 ] || fail "invalid D2B_OPEN_ARGV_JSON: expected exit 64, got $rc"

# Missing report → exit 66
rc=0
D2B_STATE_DIR="$tmp/nostate" "$root/bin/d2b-vuln-open" --print-path 2>/dev/null || rc=$?
[ "$rc" -eq 66 ] || fail "missing report: expected exit 66, got $rc"

echo "test-open: all tests passed"
