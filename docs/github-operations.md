# GitHub operations

## Overview

The repository uses:

- **Makefile-driven CI** — `make check` is the single stable validation interface;
  all CI workflows call Makefile targets and do not duplicate test logic.
- **Least-privilege workflow permissions** — workflows declare only the minimum
  GitHub token scopes required. The main PR check uses `contents: read` only.
- **Pinned actions** — GitHub Actions are pinned to a specific version tag.
  Dependabot (`dependabot.yml`) keeps them current.
- **Branch protection** — the required check is the job named `check` in
  `.github/workflows/pr.yml`. Do not rename that job.
- **Changelog gate** — every PR must either update `CHANGELOG.md` or carry the
  `skip-changelog` label (see below).
- **Scheduled flake-lock updates** — `flake.lock` is updated weekly via an
  automated PR (see below).

## PR workflow: `pr.yml`

Triggers on every pull request and every push to `main`.

| Job | What it does |
|-----|-------------|
| `check` | Runs `make check` (shellcheck, fixture tests, `nix flake check`, policy tests, changelog lint, nixling discovery). |

`check` is the required status for branch protection. Do not rename it.

## Changelog gate: `changelog.yml`

Triggers on pull-request open/sync/label events.

**Rule:** A PR must either:
1. Modify `CHANGELOG.md` (add an entry under `## [Unreleased]`), **or**
2. Carry the `skip-changelog` label.

**When to use `skip-changelog`:** CI/infra-only changes, lock-file bumps,
typo fixes, and documentation-only changes that have no user-visible impact.

**How to apply the label:**

```
gh pr edit <number> --add-label skip-changelog
```

Or click *Labels → skip-changelog* in the GitHub PR UI.

The structural integrity of `CHANGELOG.md` (presence of `[Unreleased]`,
format references) is also enforced via `make test-changelog` / `make check`.

## Scheduled flake-lock updates: `flake-lock.yml`

Runs every Monday at 08:00 UTC and on manual `workflow_dispatch`.

- Calls `nix flake update`.
- Opens a PR on branch `flake-lock-update` if `flake.lock` changed.
- Force-pushes subsequent runs to the same branch (idempotent).
- The PR body reminds reviewers to run `make check` before merging, and
  notes that `skip-changelog` is appropriate for lock-only updates.

The workflow needs `contents: write` and `pull-requests: write` because it
commits and opens PRs; all other workflows use `contents: read`.

## Dependabot

`dependabot.yml` pins GitHub Actions to the latest release tag, weekly.

## Policy tests

`tests/test-policy.sh` (run via `make check`) verifies:

1. No private consumer paths, hostnames, or VM names appear in tracked source,
   docs, CI, or test files.
2. `pr.yml` calls `make check` (no duplicated logic).
3. `pr.yml` has `permissions: contents: read`.
4. `pr.yml` job is named `check`.
5. `changelog.yml` references the `skip-changelog` escape hatch.
6. `flake-lock.yml` exists.

