---
name: pr
description: Write or draft a GitHub PR description to a portable house template (Summary + tracker close line, What changed, Why, Breaking-changes-asserted, Testing with red->green proof, Screenshots Before|After, Notes). Project tokens (repo, tracker prefix, verify commands) are read from .claude/harness/profile.md. Lean and skippable; delete non-applicable sections. Use when running gh pr create / gh pr edit or when asked to write a PR description/body.
---

# PR description (house standard, profile-driven)

First, load `.claude/harness/profile.md` for this project's tokens (`REPO`, `TICKET_PREFIX`,
`TRACKER_BROWSE_URL`, `TRACKER_CLOSE_KEYWORD`, `DEFAULT_BRANCH`, `COMMIT_TYPES`, `LINT_CMD`,
`UNIT_TEST_CMD`, `E2E_TEST_CMD`, `BUILD_CMD`, `WEB_UI`). If no profile exists, infer them from the repo
(run `/harness-init` to create one) and proceed; if there is no tracker, use GitHub `Fixes #<n>` and
drop the tracker-close line.

Write every PR description to this template. Delete every section that does not apply; ship no empty
headings or boilerplate. The repo `.github/PULL_REQUEST_TEMPLATE.md`, if present, is the minimum floor.

## Title (goes in GitHub's title field, NOT the body)
`<type>: <TICKET-KEY> <imperative one-line summary>`
- type is one of `COMMIT_TYPES` (default: feat | fix | refactor | chore | perf | docs | test).
- Append `!` for a breaking change (e.g. `feat!: <TICKET-KEY> ...`). Optional module scope: `feat(area): ...`.
- `<TICKET-KEY>` uses `TICKET_PREFIX` (e.g. `WEB-1234`); omit if the project has no tracker.
- Must stand alone in history; never "fix", "updates", "phase 1".

## Body template
```markdown
## Summary

<TRACKER_CLOSE_KEYWORD> [<TICKET-KEY>](<TRACKER_BROWSE_URL><TICKET-KEY>).
<!-- 1 to 3 sentences: what changed and why, readable without the diff. Note parent/sub-task/dependent-PR linkage when relevant. -->

## What changed
<!-- 3 to 5 scannable bullets: intent and behavior in plain language, NOT a file-by-file diff restatement. A subtle one-liner fix may use a small before/after fence instead of prose. -->
-

## Why
<!-- Problem solved and why this approach. Omit if Summary already makes it obvious.
Defect PRs: add a "Root cause:" line naming the regressing commit/PR (git blame, File:Line).
Cite the source of truth where applicable (design link, ticket AC, lib docs) so rationale is fact, not preference. -->

## Breaking changes
<!-- REQUIRED to state either way; never leave to silence. Doubles as the scope/risk line.
None: "None. Asserted explicitly:" plus evidence (enum/string values, event names, testids, persisted storage, rendered labels unchanged; for refactors "no behavioral change, characterization-covered").
Breaking: what breaks, migration steps, deploy ordering (mirror the title's !). -->
None. Asserted explicitly:

## Screenshots / visual proof  (UI changes only)
<!-- Before/after at relevant breakpoints; a short clip is fine for interaction changes.
Behavior-preserving work: do NOT omit silently, state why ("rendered strings are byte-identical, no visual delta"). -->
| Before | After |
| --- | --- |
| <img/clip> | <img/clip> |

## Testing
<!-- MANDATORY. Repo verification order with results; scoped test path, not the full suite.
Self-attest with ticked boxes. Name the spec that proves the behavior. -->
- [ ] `<LINT_CMD>`: green
- [ ] `<UNIT_TEST_CMD>`: green NNN/NNN
- [ ] `<E2E_TEST_CMD> <change-scoped/path>`: N passed, N skipped  (if the project has E2E)
- Regression proof: `<spec File:Line>` fails without the change, passes with it (or characterization tests green before and after for a behavior-preserving refactor).
<!-- Add `<BUILD_CMD>` only when build/export behavior was touched. Fold long logs in <details><summary>. -->

## Notes for review  (optional)
<!-- Pick what helps; delete the rest: reading order and feedback wanted; stacked-on base PR + merge order + retarget-to-<DEFAULT_BRANCH> plan; part of <epic/arc>, follows #<prevPR>; alternatives rejected; deliberate omissions / follow-up debt (ticketed); risks; untested edge cases. -->
```

## Pre-submit checklist
0. No em dashes in the title, body, or commit message; restructure with commas, colons, parentheses, or periods (en dash in numeric ranges is exempt). Grep the body for the long dash before `gh pr create` / `gh pr edit`.
1. Title `<type>: <TICKET-KEY> <imperative summary>` (append `!` if breaking; optional module scope); stands alone in history.
2. Summary links the ticket (if any) AND explains the change in prose (ticket supplements, never replaces).
3. PR is single-purpose and right-sized; a sprawling diff is a signal to split it.
4. Every non-applicable section deleted; no empty headings or boilerplate.
5. Breaking changes stated explicitly (either "None" plus evidence, or what breaks plus migration plus deploy order).
6. UI change: before/after table at relevant breakpoints; behavior-preserving: state why none.
7. Testing reports, in order: `<LINT_CMD>`, `<UNIT_TEST_CMD>` (NNN/NNN), change-scoped `<E2E_TEST_CMD>` if any, plus the red->green / characterization-green proof line.
8. Stacked PR: a "Stacked on" note gives base PR, merge order, and retarget plan.
9. Tracker close line present when there is a tracker (GitHub `Fixes #` does not close an external tracker; use the tracker's own keyword).

## Composes with (does not override)
- Avoid-em-dash rule: no em dashes anywhere in title/body/commit.
- Verify-before-git-ops: run and report lint / test / scoped E2E fresh before opening the PR.
- Commit authorship: no `Co-Authored-By` trailer (sole author).
- PR no reviewers: `gh pr create` with title/body/base only; no `--reviewer`, no requested_reviewers mutations.

Apply via `gh pr create` (title via `--title`, body via `--body` or `--body-file`). Governs description content and structure only.
