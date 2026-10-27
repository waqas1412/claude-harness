---
name: pr
description: "Write or draft a minimal GitHub PR title and body: a linked tracker close line, a short what-changed list, and how-to-test steps only when the reviewer has something to run, sized to the PR, in plain words. Use when running gh pr create / gh pr edit or when asked for a PR description."
argument-hint: "[ticket key, or blank to infer from branch]"
allowed-tools: Read, Grep, Glob, Bash
---

# PR description (house standard, profile-driven)

First, load `.claude/harness/profile.md` for this project's tokens (`REPO`, `TICKET_PREFIX`,
`TRACKER_BROWSE_URL`, `TRACKER_CLOSE_KEYWORD`, `DEFAULT_BRANCH`, `COMMIT_TYPES`, `LINT_CMD`,
`UNIT_TEST_CMD`, `E2E_TEST_CMD`, `BUILD_CMD`). In a multi-repo profile the four command tokens are
the per-repo table's Lint / Test / Build / E2E columns for the repo you are in, and `-` there means the
step genuinely does not exist. If no profile exists, infer from the repo
(run `/harness-init` to create one) and proceed; if there is no tracker, use GitHub `Fixes #<n>` and
drop the tracker-close line.

## Title (goes in GitHub's title field, NOT the body)
`<type>: <TICKET-KEY> <imperative one-line summary>`
- type is one of `COMMIT_TYPES` (default: feat | fix | refactor | chore | perf | docs | test).
- Append `!` for a breaking change (e.g. `feat!: <TICKET-KEY> ...`). Optional module scope: `feat(area): ...`.
- `<TICKET-KEY>` uses `TICKET_PREFIX` (e.g. `PROJ-1234`); omit if the project has no tracker.
- Must stand alone in history; never "fix", "updates", "phase 1".

## Body
The body is written for the next dev or reviewer, in simple everyday words. It is the tracker close line,
a `## What changed` section, and a `## How to test` section when one helps. Nothing else: no other
headings, no Screenshots table, no breaking-changes assertion, no notes-for-review.

Size it to the PR each time. Each list has 1 to 3 bullets, never more: a one-idea change gets one
bullet, and a wider change is grouped to fit in three.

- **What changed**: what's new, like a release note. Each bullet is one thing the reader can check:
  what a user now sees or can do on screen, or what a reviewer will find in the code, in present tense
  ("Admins can now filter rooms by floor", "The sync job now skips offline pods instead of failing"),
  then the why in plain words. One sentence per bullet, about 25 words at most, readable without the
  diff. Not a log of actions ("Added", "Updated", "Refactored").
- **Group by effect, not by cause**: one bullet per thing the reader will notice, 3 at most. A fix with
  no effect of its own that anyone can see joins the bullet it supports. For a defect, the new behaviour
  comes first, then the cause told as what went wrong for the user ("gaps followed each label's text
  width"), never through a library option, prop or function name. A code-facing bullet may name the
  repo's own component or module the reviewer will open in the diff, never third-party internals.
- **How to test**: only when the reviewer has something real to do: the page and click path, the
  command, or the request, plus what they should see. Steps can be 1 to 3 bullets. Drop the
  section when there is nothing to run by hand (a docs, config, rename or CI-only change, or a refactor
  whose proof is the existing tests). Never "lint passed" or "tests green"; those are your checks, not
  their steps.
- No self notes: nothing written to yourself or about how you got there (no "I tried", "turned out",
  "TODO", "verified locally", "as discussed", no mention of agents, tools or AI). Every line is useful
  to a reader who was not in the room.

The close line is a link: `<TRACKER_CLOSE_KEYWORD> [<TICKET-KEY>](<TRACKER_BROWSE_URL><TICKET-KEY>).`
When there is no ticket, open the body with the source thread as a link instead. When the work came
from someone's report, close the body with `Reported by <name> in [#channel](<url>).`

A body describes the head it is on. Whenever a commit lands, the scope moves, or review
feedback lands, reconcile the body in the same step rather than leaving it describing an older head.

The exact template, the pre-submit checklist, and the deliberately-skipped list live in
`references/pr-template.md` (in this skill's directory). Read that file when actually authoring, and
fill it from the profile tokens.

Verification is unchanged: lint, build, and change-scoped tests still run fresh before the PR is
opened, and results are reported in chat. Their results do not go in the body; **How to test** is the
reviewer's steps, not your gate output.

## Composes with (does not override)
- Avoid-em-dash rule: no em dashes anywhere in title/body/commit.
- Verify-before-git-ops: run and report lint / test / scoped E2E fresh before opening the PR.
- Commit authorship: no `Co-Authored-By` trailer (sole author).
- PR no reviewers: `gh pr create` with title/body/base only; no `--reviewer`, no requested_reviewers mutations.
- PR always draft: every `gh pr create` carries `--draft`. The author flips it to ready for review himself, the same way he requests reviewers himself.
- PR commits: push review fixes and follow-ups as additional commits; do not amend and force-push to keep the branch at one commit.

Apply via `gh pr create --draft` (title via `--title`, body via `--body` or `--body-file`). Governs description content and structure only.

## Stacked PRs
Before opening, check whether this PR sits on another unmerged branch: its base would be a feature
branch rather than `DEFAULT_BRANCH`, or `gh stack view` already lists the branch. If so, open it through
`gh stack` (the `github/gh-stack` extension), not `gh pr create`:
- New stack: `gh stack init <bottom> <next> ...` (bottom to top; existing branches are adopted), then
  `gh stack submit --auto`, which pushes every branch and creates the missing PRs as drafts.
- Branches or PRs that already exist without stack tracking: `gh stack link <bottom> <next> ...`
  (branch names, PR numbers or URLs, bottom to top; `--base` when the trunk is not the default branch).
- Then set each new PR's title and body from this skill with `gh pr edit <n> --title ... --body-file ...`.
  `--auto` titles are placeholders.
- Never pass `--open`, and never run `submit` without `--auto` from a script: its editor makes new PRs
  ready for review by default. Drafts only, same as the rule above.

Single PR on `DEFAULT_BRANCH`: plain `gh pr create --draft`, no stack.

## Gotchas
- No `.claude/harness/profile.md`: proceeding on guessed tokens instead of running `/harness-init` first leaves `TICKET_PREFIX`/`LINT_CMD` inferred rather than resolved; infer and note it, but prefer generating the profile.
- Hand-rolling the body from memory instead of reading `references/pr-template.md`, which drifts toward the old format over time.
- Re-adding `## Summary` / `## Testing` / `## Screenshots` headings out of habit. The only headings are `## What changed` and, when it applies, `## How to test`.
- Going past 3 bullets in either list, or padding to a count: splitting one idea into three bullets, or inventing test steps for a change with nothing to try by hand. Write what the PR needs and stop.
- Filling **How to test** with your own gate results ("lint, build, tests pass"). Give the reviewer steps they can run and what they should see.
- Padding **What changed** into a file-by-file diff restatement. It states intent and behavior, and stops.
- Writing **What changed** as an action log ("Added X", "Updated Y", "Refactored Z"). Say what is new from the reader's side: what now works, shows or happens.
- Self notes leaking in: process history, things tried and reverted, TODOs, "verified locally", references to agents or AI.
- Letting a bullet run to two sentences or nest sub-bullets. One sentence per bullet, flat list.
- Explaining a fix through the code ("keeps the class the chart library reads the size from", "parsed as local days instead of UTC"). Say what the reader will notice; the mechanism belongs in the commit message.
- One bullet per cause when the reader sees one effect. Three internal fixes behind one visible change are one bullet.
- Copying the wording of the brief or the diff. Draft from the before and after a user or reviewer would notice, then check each bullet against it.
- Leaving the body describing an earlier head after a new commit, a scope change, or a review fix. Reconcile it in the same step; being asked "is the PR body up to date" means it already drifted.
- Opening a PR based on another feature branch with plain `gh pr create --base <branch>`: GitHub sees no stack, so the chain is not linked or merged in order. Use `gh stack`.
- Dropping the reporter attribution when the work came from a colleague's thread, or burying the source link mid-paragraph instead of the top (no ticket) or the foot (reporter).
