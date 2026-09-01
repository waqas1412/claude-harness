---
name: pr
description: Write or draft a minimal GitHub PR description: a tracker close line plus a compact summary of what changed and why, and nothing else (no headings, no Testing block, no screenshots table). Project tokens (repo, tracker prefix, verify commands) are read from .claude/harness/profile.md. Use when running gh pr create / gh pr edit or when asked to write a PR description/body.
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

## Body
The body is a tracker close line plus a compact summary of what changed and why. Nothing else: no
section headings, no Testing block, no Screenshots table, no breaking-changes assertion, no
notes-for-review.

Default to bullets, not a paragraph: 2 to 4 short bullets, one line each, each naming a change and
its why. Fall back to a single sentence only when the change is genuinely one idea and a lone bullet
would look odd. Never a wall of prose, and never a file-by-file restatement.

The exact template, the pre-submit checklist, and the deliberately-skipped list live in
`references/pr-template.md` (in this skill's directory). Read that file when actually authoring, and
fill it from the profile tokens.

Verification is unchanged: lint, build, and change-scoped tests still run fresh before the PR is
opened, and results are reported in chat. They just do not go in the body.

## Composes with (does not override)
- Avoid-em-dash rule: no em dashes anywhere in title/body/commit.
- Verify-before-git-ops: run and report lint / test / scoped E2E fresh before opening the PR.
- Commit authorship: no `Co-Authored-By` trailer (sole author).
- PR no reviewers: `gh pr create` with title/body/base only; no `--reviewer`, no requested_reviewers mutations.
- PR always draft: every `gh pr create` carries `--draft`. The author flips it to ready for review himself, the same way he requests reviewers himself.
- PR commits: push review fixes and follow-ups as additional commits; do not amend and force-push to keep the branch at one commit.

Apply via `gh pr create --draft` (title via `--title`, body via `--body` or `--body-file`). Governs description content and structure only.

## Gotchas
- No `.claude/harness/profile.md`: proceeding on guessed tokens instead of running `/harness-init` first leaves `TICKET_PREFIX`/`LINT_CMD` inferred rather than resolved; infer and note it, but prefer generating the profile.
- Hand-rolling the body from memory instead of reading `references/pr-template.md`, which drifts back toward the old multi-section format over time.
- Re-adding the old `## Summary` / `## Testing` / `## Screenshots` headings out of habit. The body carries no headings at all now.
- Treating the dropped Testing block as permission to skip verification: lint, build, and scoped tests still run fresh, they are just reported in chat instead of in the body.
- Padding the summary into a file-by-file diff restatement. It states intent and behavior, and stops.
- Writing the summary as one dense paragraph. Bullets are the default shape; prose is the exception for a single-idea change.
- Letting a bullet run to three lines or nest sub-bullets. One line per bullet, flat list.
