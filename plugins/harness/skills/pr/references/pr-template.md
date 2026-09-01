# PR body template and pre-submit checklist

Read this when actually authoring a PR. Token values (`TICKET_PREFIX`, `TRACKER_BROWSE_URL`,
`TRACKER_CLOSE_KEYWORD`) come from `.claude/harness/profile.md`.

The body is deliberately minimal: a tracker close line plus a compact summary of what changed and
why. Nothing else. No section headings, no Testing block, no Screenshots table, no breaking-changes
assertion, no notes-for-review. Verification still runs, it is just not narrated in the body.

The summary is bulleted by default: 2 to 4 flat one-line bullets, each naming a change and its why.
A single sentence instead of bullets is fine only when the change is one idea.

## Body template
```markdown
<TRACKER_CLOSE_KEYWORD> [<TICKET-KEY>](<TRACKER_BROWSE_URL><TICKET-KEY>).

- <What changed, and why, in one line.>
- <Next change and its why.>
<!-- 2 to 4 flat one-line bullets, readable without the diff. Intent and behavior in plain language,
never a file-by-file restatement. Collapse to a single sentence (no bullets) only for a one-idea
change. Defect PRs: name the root cause in the same breath as the fix. -->
```

Drop the tracker line entirely when the project has no tracker; use GitHub `Fixes #<n>` instead.

## Pre-submit checklist
0. No em dashes in the title, body, or commit message; restructure with commas, colons, parentheses, or periods (en dash in numeric ranges is exempt). Grep the body for the long dash before `gh pr create` / `gh pr edit`.
1. Title `<type>: <TICKET-KEY> <imperative summary>` (append `!` if breaking; optional module scope); stands alone in history.
2. Body is the tracker close line plus the summary, and nothing else.
3. The summary says both what changed and why, and reads without the diff (the ticket supplements, never replaces).
4. PR is single-purpose and right-sized; a sprawling diff is a signal to split it.
5. Breaking change: the title's `!` carries it, and the summary names what breaks in one clause.
6. Tracker close line present when there is a tracker (GitHub `Fixes #` does not close an external tracker; use the tracker's own keyword).

## Deliberately skipped (do not re-add)
Section headings of any kind; a Testing block (lint / test / build still run before the PR, reported in chat, not in the body); a Screenshots or visual-proof table; a standalone breaking-changes assertion; notes-for-review, stacked-on, and follow-up-debt blocks; a "Type of change" checkbox matrix (the conventional-commit type in the title encodes it); AI-authorship disclosure markers (sole author, no Co-Authored-By); per-commit narration headings (split PRs instead); GitHub closing keywords when an external tracker is in use.
