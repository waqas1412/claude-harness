---
name: pr
description: Write or draft a GitHub PR description to a portable house template (Summary + tracker close line, What changed, Why, Breaking-changes-asserted, Testing with red->green proof, Screenshots Before|After, Notes). Project tokens (repo, tracker prefix, verify commands) are read from .claude/harness/profile.md. Lean and skippable; delete non-applicable sections. Use when running gh pr create / gh pr edit or when asked to write a PR description/body.
argument-hint: "[ticket key, or blank to infer from branch]"
allowed-tools: Read, Grep, Glob, Bash
---

# PR description (house standard, profile-driven)

First, load `.claude/harness/profile.md` for this project's tokens (`REPO`, `TICKET_PREFIX`,
`TRACKER_BROWSE_URL`, `TRACKER_CLOSE_KEYWORD`, `DEFAULT_BRANCH`, `COMMIT_TYPES`, `LINT_CMD`,
`UNIT_TEST_CMD`, `E2E_TEST_CMD`, `BUILD_CMD`, `WEB_UI`). If no profile exists, infer from the repo
(run `/harness-init` to create one) and proceed; if there is no tracker, use GitHub `Fixes #<n>` and
drop the tracker-close line.

## Title (goes in GitHub's title field, NOT the body)
`<type>: <TICKET-KEY> <imperative one-line summary>`
- type is one of `COMMIT_TYPES` (default: feat | fix | refactor | chore | perf | docs | test).
- Append `!` for a breaking change (e.g. `feat!: <TICKET-KEY> ...`). Optional module scope: `feat(area): ...`.
- `<TICKET-KEY>` uses `TICKET_PREFIX` (e.g. `PROJ-1234`); omit if the project has no tracker.
- Must stand alone in history; never "fix", "updates", "phase 1".

## Body and checklist
The full body template, the pre-submit checklist, and the deliberately-skipped list live in
`references/pr-template.md` (in this skill's directory). Read that file when actually authoring, and
fill it from the profile tokens. Delete every section that does not apply; ship no empty headings.

## Composes with (does not override)
- Avoid-em-dash rule: no em dashes anywhere in title/body/commit.
- Verify-before-git-ops: run and report lint / test / scoped E2E fresh before opening the PR.
- Commit authorship: no `Co-Authored-By` trailer (sole author).
- PR no reviewers: `gh pr create` with title/body/base only; no `--reviewer`, no requested_reviewers mutations.

Apply via `gh pr create` (title via `--title`, body via `--body` or `--body-file`). Governs description content and structure only.

## Gotchas
- No `.claude/harness/profile.md`: proceeding on guessed tokens instead of running `/harness-init` first leaves `TICKET_PREFIX`/`LINT_CMD` inferred rather than resolved; infer and note it, but prefer generating the profile.
- Hand-rolling the body from memory instead of reading `references/pr-template.md`, which drifts from the house Testing/Screenshots structure over time.
- Leaving an empty section heading (for example an unused Screenshots block) instead of deleting it, which reads as unfinished rather than a deliberate skip.
