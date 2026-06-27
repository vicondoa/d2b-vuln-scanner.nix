#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
ok=1

# ---------------------------------------------------------------------------
# 1. No private consumer paths in any tracked source or docs.
# ---------------------------------------------------------------------------
search_targets=(
  "$root/README.md"
  "$root/docs"
  "$root/bin"
  "$root/.github"
  "$root/tests"
  "$root/Makefile"
  "$root/flake.nix"
  "$root/skills"
)
# Only add directories/files that actually exist so grep doesn't error.
existing_targets=()
for t in "${search_targets[@]}"; do
  [[ -e "$t" ]] && existing_targets+=("$t")
done

if grep -R -n -E '/etc/nixos|paydro|work-aad|personal-dev' \
    "${existing_targets[@]}" \
    "$root/hmModules" "$root/nixosModules" 2>/dev/null \
    | grep -v 'tests/test-policy\.sh'; then
  echo "POLICY: private consumer detail leaked into upstream project" >&2
  ok=0
fi

# ---------------------------------------------------------------------------
# 2. CI structure: pr.yml must call make, not duplicate test logic.
# ---------------------------------------------------------------------------
pr_yml="$root/.github/workflows/pr.yml"
if [[ ! -f "$pr_yml" ]]; then
  echo "POLICY: .github/workflows/pr.yml not found" >&2
  ok=0
else
  if ! grep -q 'make check' "$pr_yml"; then
    echo "POLICY: pr.yml does not call 'make check'" >&2
    ok=0
  fi
  if ! grep -q 'permissions:' "$pr_yml"; then
    echo "POLICY: pr.yml missing explicit permissions block" >&2
    ok=0
  fi
  if ! grep -q 'contents: read' "$pr_yml"; then
    echo "POLICY: pr.yml missing 'contents: read' least-privilege permission" >&2
    ok=0
  fi
  if ! grep -q '^\s*check:' "$pr_yml"; then
    echo "POLICY: pr.yml job is not named 'check' (required for branch protection)" >&2
    ok=0
  fi
fi

# ---------------------------------------------------------------------------
# 3. Changelog gate: changelog workflow and PR template reference skip-changelog.
# ---------------------------------------------------------------------------
changelog_yml="$root/.github/workflows/changelog.yml"
if [[ ! -f "$changelog_yml" ]]; then
  echo "POLICY: .github/workflows/changelog.yml not found" >&2
  ok=0
else
  if ! grep -q 'skip-changelog' "$changelog_yml"; then
    echo "POLICY: changelog.yml does not reference skip-changelog escape hatch" >&2
    ok=0
  fi
fi

pr_template="$root/.github/PULL_REQUEST_TEMPLATE.md"
if [[ -f "$pr_template" ]]; then
  if ! grep -q 'skip-changelog' "$pr_template"; then
    echo "POLICY: PULL_REQUEST_TEMPLATE.md does not mention skip-changelog" >&2
    ok=0
  fi
fi

# ---------------------------------------------------------------------------
# 4. Scheduled flake-lock workflow must exist.
# ---------------------------------------------------------------------------
flake_lock_yml="$root/.github/workflows/flake-lock.yml"
if [[ ! -f "$flake_lock_yml" ]]; then
  echo "POLICY: .github/workflows/flake-lock.yml not found" >&2
  ok=0
fi

# ---------------------------------------------------------------------------
# 5. Skills: must anchor downstream scope, not scanner maintenance.
# ---------------------------------------------------------------------------
for skill_file in "$root/skills"/*/d2b-vuln-remediation/SKILL.md; do
  [[ -f "$skill_file" ]] || continue

  if ! grep -q 'd2b-vm' "$skill_file"; then
    echo "POLICY: $skill_file missing d2b VM source label documentation" >&2
    ok=0
  fi

  if ! grep -q 'cache' "$skill_file"; then
    echo "POLICY: $skill_file missing cache-safe Nix remediation guidance" >&2
    ok=0
  fi

  if ! grep -qi 'rescan\|re-run\|re-scan\|post-fix' "$skill_file"; then
    echo "POLICY: $skill_file missing post-fix re-scan requirement" >&2
    ok=0
  fi

  if ! grep -qi 'downstream\|consumer' "$skill_file"; then
    echo "POLICY: $skill_file does not state downstream/consumer scope" >&2
    ok=0
  fi

  # Must explicitly state it is NOT for scanner repo maintenance.
  if ! grep -q 'scanner repository' "$skill_file"; then
    echo "POLICY: $skill_file does not exclude scanner repository maintenance" >&2
    ok=0
  fi

  # Must prohibit silent deploy/apply.
  if ! grep -qi 'silently\|MUST NOT' "$skill_file"; then
    echo "POLICY: $skill_file missing explicit deploy/apply prohibition" >&2
    ok=0
  fi
done

# ---------------------------------------------------------------------------
# 6. Remediate script: must not contain shell-string execution patterns.
# ---------------------------------------------------------------------------
remediate_bin="$root/bin/d2b-vuln-remediate"
if [[ -f "$remediate_bin" ]]; then
  # eval or $(...) used as an exec target is a shell-string execution anti-pattern.
  if grep -nE '^\s*eval\b|exec eval\b' "$remediate_bin"; then
    echo "POLICY: d2b-vuln-remediate contains eval (shell-string execution)" >&2
    ok=0
  fi
fi

# ---------------------------------------------------------------------------
# 7. Consumer migration guide: required content.
# ---------------------------------------------------------------------------
migration_guide="$root/docs/consumer-migration.md"
if [[ ! -f "$migration_guide" ]]; then
  echo "POLICY: docs/consumer-migration.md not found" >&2
  ok=0
else
  # Must document rollback steps.
  if ! grep -qi 'rollback\|roll back\|revert\|disable the module' "$migration_guide"; then
    echo "POLICY: consumer-migration.md missing rollback guidance" >&2
    ok=0
  fi

  # Must mention Waybar autowiring.
  if ! grep -qi 'autowire\|autowiring' "$migration_guide"; then
    echo "POLICY: consumer-migration.md missing Waybar autowiring guidance" >&2
    ok=0
  fi

  # Must document remediation opt-in.
  if ! grep -qi 'remediation' "$migration_guide"; then
    echo "POLICY: consumer-migration.md missing remediation opt-in documentation" >&2
    ok=0
  fi

  # Must be scoped to d2b-native consumers.
  if ! grep -qi 'd2b' "$migration_guide"; then
    echo "POLICY: consumer-migration.md does not mention d2b scope" >&2
    ok=0
  fi

  # Must not contain private consumer details.
  if grep -nE '/etc/nixos|paydro|work-aad|personal-dev' "$migration_guide"; then
    echo "POLICY: consumer-migration.md contains private consumer detail" >&2
    ok=0
  fi

  # Must describe flake input wiring.
  if ! grep -qi 'inputs\.' "$migration_guide"; then
    echo "POLICY: consumer-migration.md missing flake input wiring guidance" >&2
    ok=0
  fi
fi

[[ "$ok" -eq 1 ]]

