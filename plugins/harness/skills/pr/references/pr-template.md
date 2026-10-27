# PR body template and pre-submit checklist

Read this when actually authoring a PR. Token values (`TICKET_PREFIX`, `TRACKER_BROWSE_URL`,
`TRACKER_CLOSE_KEYWORD`) come from `.claude/harness/profile.md`.

The body is written for the next dev or reviewer in simple everyday words: a tracker close line, a
`## What changed` section and, when the reviewer has something to run, a `## How to test` section.
Nothing else. No other headings, no Screenshots
table, no breaking-changes assertion, no notes-for-review, no self notes. Verification still runs, its
results are reported in chat, not in the body.

## Body template
```markdown
<TRACKER_CLOSE_KEYWORD> [<TICKET-KEY>](<TRACKER_BROWSE_URL><TICKET-KEY>).

## What changed
- <One thing the reader can check: what a user now sees or does on screen, or what a reviewer will find in the code, then why in plain words. One sentence, about 25 words, present tense, never "Added/Updated/Refactored". One bullet per visible effect, 3 at most.>

## How to test
- <Where to go or what to run, what to do, and what they should see. Split into up to 3 bullets only if the steps need it.>

Reported by <name> in [#<channel>](<thread-url>).
<!-- 1 to 3 bullets per list, sized to the PR, never padded: flat one-line bullets, plain words, readable without
the diff. Drop How to test when there is nothing to run by hand. Defect PRs:
name the root cause in the same breath as the fix. How to test is the reviewer's steps, never your
lint/build/test results. Keep the reporter line only when the work came from someone's report. -->
```

## Bad and good, for a defect
- Bad: "Labels are measured at their real font size, because the custom tick now keeps the class the chart library reads the size from." (the subject is code, the why is library internals)
- Bad: "The header row wraps based on the real width of its content, not a fixed breakpoint." (explains the mechanism, says nothing the reader will see)
- Good: "Chart dates are now evenly spaced in every date format and window width; before, the gaps followed each label's text width."
- Good: "On phones, the date range now sits on its own line under the page title, instead of squeezing into a thin column."

Drop the tracker line entirely when the project has no tracker; use GitHub `Fixes #<n>` instead. When
there is no ticket at all, the first line is the source thread as a link (`Slack thread: [#<channel>](<url>)`)
so the origin still opens from the top of the body.

## Pre-submit checklist
0. No em dashes in the title, body, or commit message; restructure with commas, colons, parentheses, or periods (en dash in numeric ranges is exempt). Grep the body for the long dash before `gh pr create` / `gh pr edit`.
1. Title `<type>: <TICKET-KEY> <imperative summary>` (append `!` if breaking; optional module scope); stands alone in history.
2. Body is the tracker close line, **What changed** and (only when it applies) **How to test**, and nothing else. Each list has 1 to 3 bullets sized to the change, nothing padded.
3. **What changed** reads as what's new (what now works, shows or happens, in present tense), says why, and reads without the diff (the ticket supplements, never replaces). No action-log verbs like "Added" or "Refactored".
3a. **How to test**, when present, gives steps a reviewer can follow and the expected result, not your gate output.
3b. No self notes: no process history, things tried, TODOs, "verified locally", or mention of agents, tools or AI.
3c. Each **What changed** bullet passes the subject test: its subject is something a user sees on screen or a reviewer finds in the diff, never a library option, prop, function or internal step. One sentence, about 25 words.
3d. Bullets are grouped by visible effect: a fix with no effect of its own joins the bullet it supports.
4. PR is single-purpose and right-sized; a sprawling diff is a signal to split it.
5. Breaking change: the title's `!` carries it, and **What changed** names what breaks in one clause.
6. Body matches the current head: re-read it after any amend, scope change, or review fix, and edit it in the same step.
7. Reporter attribution present when the work came from a colleague's report; source thread linked at the top when there is no ticket.
8. Tracker close line present when there is a tracker (GitHub `Fixes #` does not close an external tracker; use the tracker's own keyword).

## Deliberately skipped (do not re-add)
Section headings beyond `## What changed` and `## How to test`; a fixed bullet count; lint / build / test results in the body (they are reported in chat); a Screenshots or visual-proof table; a standalone breaking-changes assertion; notes-for-review, stacked-on, and follow-up-debt blocks; a "Type of change" checkbox matrix (the conventional-commit type in the title encodes it); AI-authorship disclosure markers (sole author, no Co-Authored-By); per-commit narration headings (split PRs instead); GitHub closing keywords when an external tracker is in use.
