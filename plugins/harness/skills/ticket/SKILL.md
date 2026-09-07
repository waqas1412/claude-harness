---
name: ticket
description: Write or draft a minimal tracker ticket: a type/parent line, a terse "<Area>:" title, and 2 to 4 bullets of what should change and why in product language, and nothing else (no headings, no acceptance criteria, no Out-of-scope block, no verification gate). Project tokens read from .claude/harness/profile.md. Use when drafting any ticket or backlog markdown.
argument-hint: "[bug | story | refactor]"
allowed-tools: Read, Grep, Glob, Bash
---

# Tracker ticket (minimal, profile-driven)

First, load `.claude/harness/profile.md` for this project's tokens (`TICKET_PREFIX`, `TRACKER`,
`TRACKER_BROWSE_URL`). If no profile exists, infer from the repo (run `/harness-init`) and proceed.
Ticket keys use `TICKET_PREFIX` (e.g. `PROJ-1234`); if the project has no tracker, write the ticket as
a backlog markdown file and link a GitHub issue instead.

## Body
A ticket is a type/parent line, a terse `<Area>: <imperative>` title, and 2 to 4 bullets (3 is
typical) of what should change and why. Nothing else: no section headings, no user-story formula, no
acceptance criteria, no Out-of-scope block, no implementation notes, no verification gate.

Write it in product language a non-engineer can act on: name the surface, the wrong behavior, and the
wanted behavior. No identifiers, file paths, function names, formulas, library names, or migration
numbers; those live in the PR and the code. When the work came from someone's report, close with
`Reported by <name> in [#channel](<url>).`

A ticket states only what is true now. Rewriting a stale or wrong ticket means replacing the text, not
appending a correction: carry no history of its own earlier versions and no "previously we thought".

The exact template, the Definition of Ready, and the deliberately-skipped list live in
`references/ticket-templates.md` (in this skill's directory). Read that file when actually drafting
and fill it from the profile tokens.

One template covers every type. The distinction lives in the type field and the title: a bug names the
reproduction and the wrong behavior in its prose, a refactor says in its prose that it is
behavior-preserving.

Verification is unchanged: when the work is done, lint, build, and change-scoped tests still run fresh
and are reported in chat. They are just not restated in the ticket.

## Composes with (does not override)
Avoid-em-dash rule; characterization-tests-first (still how a refactor is executed, just not spelled
out in the ticket); verify-before-git-ops.

## Gotchas
- No `.claude/harness/profile.md`: drafting against an assumed tracker prefix instead of falling back to a backlog markdown file plus a linked GitHub issue when no tracker is configured.
- Re-adding the old `## Acceptance criteria` / `## Out-of-scope` / `## Verification gate` headings out of habit. The body carries no headings at all now.
- Treating the dropped verification gate as permission to skip verification when the ticket is implemented.
- Padding the summary into a file-by-file implementation plan. It states what should change and why, and stops.
- Letting engineering vocabulary into the body: identifiers, file paths, formulas, or library names make it unreadable for the reporter and the product side. Describe the surface and the behavior instead.
- Appending a correction when a ticket turns out stale or wrong, or narrating what the ticket used to say. Replace the text with what is true now.
- Losing the reporter and the source thread when the ticket came from a colleague's report.
