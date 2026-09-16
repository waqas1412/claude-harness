---
name: ticket
description: "Write or draft a tracker ticket in product language and rich text: the core issue in two lines, a numbered middle of about five steps, then a pair of results. Bugs use steps to reproduce with actual versus expected; stories, tasks and spikes use the same skeleton with their own middle and pair. Project tokens read from .claude/harness/profile.md. Use when drafting any ticket or backlog markdown."
argument-hint: "[bug | story | refactor]"
allowed-tools: Read, Grep, Glob, Bash
---

# Tracker ticket (product language, profile-driven)

First, load `.claude/harness/profile.md` for this project's tokens (`TICKET_PREFIX`, `TRACKER`,
`TRACKER_BROWSE_URL`). If no profile exists, infer from the repo (run `/harness-init`) and proceed.
Ticket keys use `TICKET_PREFIX` (e.g. `PROJ-1234`); if the project has no tracker, write the ticket as
a backlog markdown file and link a GitHub issue instead.

## Body
EVERY type shares one skeleton, so a reader who has seen one ticket can read any of them: the core
issue in two lines, a numbered middle of about five steps, then a pair of results shown as two panels.
Only the middle's name and the pair change with the type:

- Bug: Steps to reproduce, then Actual result and Expected result.
- Story or feature: Steps the person takes, then Today and After this ships.
- Task or refactor: What changes, then Today and After this ships. A refactor's After says plainly that
  nothing a person can see changes, and what proves it.
- Spike: What to investigate, then Open question and What a good answer settles.

Five is a target, not a quota. A bug needing ten steps is usually two bugs; a task with ten changes is
usually two tasks.

Write it in product language a non-engineer can act on, in everyday vocabulary: name the surface, the
wrong behaviour, and the wanted behaviour. No identifiers, file paths, function names, formulas,
library names, or migration numbers; those live in the PR and the code. Prefer the common word over the
impressive one, and keep every number, name and behaviour exact. When the work came from someone's
report, close with `Reported by <name> in [#channel](<url>).`

Publish it as RICH TEXT (ADF for Jira), not escaped markdown: bold lead-ins rather than heading nodes,
an ordered list for the steps, a bulleted expected result, bold on the values that carry the bug, and a
coloured panel for each result (error for actual, success for expected).

Say what should HAPPEN, not how to fix it. A ticket that prescribes the mechanism takes a decision that
belongs to the change, and it ages badly when the design turns out differently.

A ticket states only what is true now. Rewriting a stale or wrong ticket means replacing the text, not
appending a correction: carry no history of its own earlier versions and no "previously we thought".
When the work settles a user-visible behaviour the ticket never mentioned, add it to the expected
result; do not narrate the decision.

The exact templates, the Definition of Ready, the rich-text notes and the deliberately-skipped list
live in `references/ticket-templates.md` (in this skill's directory). Read that file when actually
drafting and fill it from the profile tokens.

Verification is unchanged: when the work is done, lint, build, and change-scoped tests still run fresh
and are reported in chat. They are just not restated in the ticket.

## Composes with (does not override)
Avoid-em-dash rule; plain-words rule; characterization-tests-first (still how a refactor is executed,
just not spelled out in the ticket); verify-before-git-ops.

## Gotchas
- No `.claude/harness/profile.md`: drafting against an assumed tracker prefix instead of falling back to a backlog markdown file plus a linked GitHub issue when no tracker is configured.
- Publishing escaped markdown into a rich-text field, so the reader sees literal asterisks and numbers instead of formatting.
- Believing a read-back about panels: the Atlassian MCP tools downconvert the description to markdown on read even when ADF is requested, and markdown has no panel, so the read-back can neither prove nor disprove that panels landed. Confirm in the browser or fetch the raw field.
- Using heading nodes for the three sections. Bold lead-ins carry them; a ticket this short does not need headings.
- Padding the steps to exactly five when the work needs four, or stretching one repro to ten steps when it is really two bugs.
- Giving a story or a task a bug's middle. A story's middle is the journey the person walks, a task's is the surfaces that change; neither is a reproduction.
- Writing a refactor whose After promises a visible improvement. A refactor's After says nothing a person can see changes, and names what proves it.
- Leaving a spike's pair vague. The open question must say what is assumed in the meantime, and the answer half must say what evidence would make it trustworthy.
- Treating the dropped verification gate as permission to skip verification when the ticket is implemented.
- Padding the body into a file-by-file implementation plan, or prescribing the fix instead of the wanted behaviour.
- Letting engineering vocabulary into the body: identifiers, file paths, formulas, or library names make it unreadable for the reporter and the product side. Describe the surface and the behaviour instead.
- Appending a correction when a ticket turns out stale or wrong, or narrating what the ticket used to say. Replace the text with what is true now.
- Forgetting that an expected result must also name what has to be PRESERVED (a choice someone already made, data already on the device) and anything that must happen without a reload.
- Losing the reporter and the source thread when the ticket came from a colleague's report.
