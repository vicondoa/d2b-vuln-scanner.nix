#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

PASS=0
FAIL=0

check() {
  local label="$1"
  if "${@:2}"; then
    echo "PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label" >&2
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

make_state() {
  local dir="$1"
  local ts="${2:-$(date -u +%Y%m%dT%H%M%SZ)}"
  mkdir -p "$dir"
  jq -n --arg ts "$ts" \
    '{ts:$ts, high_critical:2, new_high_critical:1, errors:0,
      totals:{critical:1, high:1, total:2},
      nixling:{vm_count:2}}' > "$dir/summary.json"
  printf '%s\n' "SEVERITY  ID             PACKAGE  SOURCE                    FIXED" \
                "Critical  CVE-2024-0001  foo 1.0  nix:host                  1.1" \
                "High      CVE-2024-0002  bar 2.0  nix:nixling-vm:my-vm      2.1" \
    > "$dir/report-${ts}.txt"
  ln -sfn "report-${ts}.txt" "$dir/latest.txt"
}

fresh_dir() {
  local base="$1"
  local name="$2"
  local d="$base/$name"
  mkdir -p "$d"
  echo "$d"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

base="$(mktemp -d -t d2b-remediate-test.XXXXXX)"
trap 'rm -rf "$base"' EXIT

# --- 1. Missing state → exit 75 ---
d="$(fresh_dir "$base" missing)"
rc=0
D2B_STATE_DIR="$d" "$root/bin/d2b-vuln-remediate" 2>/dev/null || rc=$?
check "missing state exits 75" [ "$rc" -eq 75 ]

# --- 2. Stale summary → exit 75 ---
d="$(fresh_dir "$base" stale)"
old_ts="20200101T000000Z"
make_state "$d" "$old_ts"
rc=0
D2B_REMEDIATION_MAX_SCAN_AGE_SECONDS=60 D2B_STATE_DIR="$d" \
  "$root/bin/d2b-vuln-remediate" 2>/dev/null || rc=$?
check "stale summary exits 75" [ "$rc" -eq 75 ]

# --- 3. Missing summary.json only → exit 75 ---
d="$(fresh_dir "$base" noreport)"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
jq -n --arg ts "$ts" '{ts:$ts,high_critical:0,errors:0,totals:{critical:0,high:0,total:0},nixling:{vm_count:0}}' \
  > "$d/summary.json"
rc=0
D2B_STATE_DIR="$d" "$root/bin/d2b-vuln-remediate" 2>/dev/null || rc=$?
check "missing report exits 75" [ "$rc" -eq 75 ]

# --- 4. Summary with no .ts field → exit 75 ---
d="$(fresh_dir "$base" nots)"
make_state "$d"
jq 'del(.ts)' "$d/summary.json" > "$d/summary.json.tmp" && mv "$d/summary.json.tmp" "$d/summary.json"
rc=0
D2B_STATE_DIR="$d" "$root/bin/d2b-vuln-remediate" 2>/dev/null || rc=$?
check "missing ts field exits 75" [ "$rc" -eq 75 ]

# --- 5. Fresh state → prompt written, exit 0 (no agent) ---
d="$(fresh_dir "$base" fresh)"
make_state "$d"
out="$d/remediate.out"
rc=0
D2B_STATE_DIR="$d" "$root/bin/d2b-vuln-remediate" > "$out" 2>&1 || rc=$?
check "fresh state exits 0 without agent"  [ "$rc" -eq 0 ]
check "stdout reports prompt written"       grep -q 'prompt written' "$out"

# --- 6. Prompt file exists ---
check "prompt file created" \
  [ -n "$(find "$d/remediation" -name 'prompt-*.md' -print -quit)" ]

# --- 7. Prompt content: required fields ---
prompt_file="$(find "$d/remediation" -name 'prompt-*.md' -print -quit)"
check "prompt has Scanner state directory"  grep -q 'Scanner state directory' "$prompt_file"
check "prompt has Summary JSON"            grep -q 'Summary JSON'            "$prompt_file"
check "prompt has Latest report"           grep -q 'Latest report'           "$prompt_file"
check "prompt has Scan timestamp"          grep -q 'Scan timestamp'          "$prompt_file"
check "prompt has nix:host label"          grep -q 'nix:host'                "$prompt_file"
check "prompt has nix:nixling-vm label"    grep -q 'nix:nixling-vm'          "$prompt_file"
check "prompt has dep: label"              grep -q 'dep:'                    "$prompt_file"
check "prompt has scan command"            grep -q 'd2b-vuln-scan'           "$prompt_file"
check "prompt has residual instruction"    grep -q 'residual:'               "$prompt_file"
check "prompt has consumer boundary rules" grep -q 'MUST NOT'                "$prompt_file"
check "prompt has cache-safe policy"       grep -q 'cache-safe\|cache.nixos' "$prompt_file"
check "prompt has deploy prohibition"      grep -qi 'deploy'                  "$prompt_file"

# --- 8. Prompt has VM label from report ---
check "prompt captures VM label from report" grep -q 'my-vm' "$prompt_file"

# --- 9. Prompt is mode 600 ---
perms="$(stat -c '%a' "$prompt_file")"
check "prompt file is mode 600" [ "$perms" = "600" ]

# --- 10. argv {prompt_file} placeholder substitution ---
d2="$(fresh_dir "$base" argv_placeholder)"
make_state "$d2"
capture="$d2/agent-saw-prompt.txt"
# Agent argv: cat {prompt_file} > $capture
agent_json="$(jq -cn --arg out "$capture" '["bash","-c","cat \"$1\" > \"$2\"","--","{prompt_file}",$out]')"
rc=0
D2B_STATE_DIR="$d2" D2B_AGENT_ARGV_JSON="$agent_json" \
  "$root/bin/d2b-vuln-remediate" > "$d2/remediate.out" 2>&1 || rc=$?
check "{prompt_file} placeholder: agent exits 0" [ "$rc" -eq 0 ]
check "{prompt_file} placeholder: agent received prompt" \
  [ -s "$capture" ]
check "{prompt_file} placeholder: content is prompt"     \
  grep -q 'Remediation Prompt' "$capture"

# --- 11. Stdin mode (no {prompt_file} in argv) ---
d3="$(fresh_dir "$base" stdin_mode)"
make_state "$d3"
capture2="$d3/agent-stdin.txt"
# Agent reads stdin and writes it to $capture2
agent_json2="$(jq -cn --arg out "$capture2" '["bash","-c","cat > \"$1\"","--",$out]')"
rc=0
D2B_STATE_DIR="$d3" D2B_AGENT_ARGV_JSON="$agent_json2" \
  "$root/bin/d2b-vuln-remediate" > "$d3/remediate.out" 2>&1 || rc=$?
check "stdin mode: agent exits 0" [ "$rc" -eq 0 ]
check "stdin mode: agent received prompt via stdin" \
  [ -s "$capture2" ]
check "stdin mode: stdin content is prompt" \
  grep -q 'Remediation Prompt' "$capture2"

# --- 12. Agent non-zero exit is forwarded ---
d4="$(fresh_dir "$base" agent_fail)"
make_state "$d4"
agent_fail_json='["bash","-c","exit 42"]'
rc=0
D2B_STATE_DIR="$d4" D2B_AGENT_ARGV_JSON="$agent_fail_json" \
  "$root/bin/d2b-vuln-remediate" > "$d4/remediate.out" 2>&1 || rc=$?
check "agent failure exit status forwarded" [ "$rc" -eq 42 ]

# --- 13. Invalid agent JSON is a usage error ---
d_bad="$(fresh_dir "$base" invalid_agent_json)"
make_state "$d_bad"
rc=0
D2B_STATE_DIR="$d_bad" D2B_AGENT_ARGV_JSON='["unterminated"' \
  "$root/bin/d2b-vuln-remediate" > "$d_bad/remediate.out" 2>&1 || rc=$?
check "invalid agent JSON exits 64" [ "$rc" -eq 64 ]

# --- 14. Newlines inside argv elements are preserved ---
d_newline="$(fresh_dir "$base" newline_agent_arg)"
make_state "$d_newline"
newline_capture="$d_newline/newline.txt"
newline_agent_json="$(jq -cn --arg out "$newline_capture" --arg arg $'first\nsecond' '["bash","-c","printf %s \"$1\" > \"$2\"","--",$arg,$out,"{prompt_file}"]')"
rc=0
D2B_STATE_DIR="$d_newline" D2B_AGENT_ARGV_JSON="$newline_agent_json" \
  "$root/bin/d2b-vuln-remediate" > "$d_newline/remediate.out" 2>&1 || rc=$?
check "newline argv: agent exits 0" [ "$rc" -eq 0 ]
check "newline argv: single argument preserved" \
  [ "$(cat "$newline_capture")" = $'first\nsecond' ]

# --- 15. Bounded prompt retention: only N newest kept ---
d5="$(fresh_dir "$base" retention)"
make_state "$d5"
mkdir -p "$d5/remediation"
for i in $(seq 1 5); do
  touch -d "2020-01-0${i}" "$d5/remediation/prompt-202001-000${i}.md"
done
D2B_STATE_DIR="$d5" D2B_REMEDIATION_PROMPT_RETENTION=3 \
  "$root/bin/d2b-vuln-remediate" > "$d5/retention.out" 2>&1 || true
count="$(find "$d5/remediation" -name 'prompt-*.md' | wc -l)"
check "prompt retention keeps ≤ N files" [ "$count" -le 3 ]

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
