---
name: ticket
description: Write or draft a tracker ticket to portable house templates (Story/Feature/Epic, Bug, Refactor/Spike). INVEST + named persona + 3 to 5 testable acceptance criteria, terse "<Area>:" title, REQUIRED Out-of-scope, characterization-first plan for refactors, migrate-then-delete grep gate, lint/test/build gate. Project tokens read from .claude/harness/profile.md. Lean and skippable. Use when drafting any ticket or backlog markdown.
argument-hint: "[bug | story | refactor]"
allowed-tools: Read, Grep, Glob, Bash
---

# Tracker ticket (house standard, profile-driven)

First, load `.claude/harness/profile.md` for this project's tokens (`TICKET_PREFIX`, `TRACKER`,
`TRACKER_BROWSE_URL`, `LINT_CMD`, `UNIT_TEST_CMD`, `E2E_TEST_CMD`, `BUILD_CMD`, `WEB_UI`). If no
profile exists, infer from the repo (run `/harness-init`) and proceed. Ticket keys use `TICKET_PREFIX`
(e.g. `PROJ-1234`); if the project has no tracker, write the ticket as a backlog markdown file and link
a GitHub issue instead.

Every ticket is INVEST (Independent, Negotiable, Valuable, Estimable, Small, Testable), names a
persona, and carries 3 to 5 testable acceptance criteria. Title is terse: `<Area>: <imperative>`.
Out-of-scope is REQUIRED on every ticket. Delete sections that do not apply; no empty headings.

## When to use which template
- **Story / Feature / Epic:** new user-facing capability or a parent that groups sub-tasks.
- **Bug:** observed defect with a reproduction and a fix expectation.
- **Refactor / Tech-debt / Spike:** internal change with no intended behavior change, or a timeboxed
  investigation.

## Templates
The three full templates (Story/Feature/Epic, Bug, Refactor/Spike) plus the web/UI-only block live in
`references/ticket-templates.md` (in this skill's directory). Read that file when actually drafting
and fill it from the profile tokens.

## Definition of Ready
INVEST holds; persona named; 3 to 5 testable AC; Out-of-scope present; verification gate lists the
resolved profile commands; no em dashes anywhere; tracker key and links resolve.

## Composes with (does not override)
Avoid-em-dash rule; characterization-tests-first; migrate-then-delete grep gate; verify-before-git-ops.

## Gotchas
- No `.claude/harness/profile.md`: drafting against an assumed tracker prefix instead of falling back to a backlog markdown file plus a linked GitHub issue when no tracker is configured.
- Skipping Out-of-scope because it "seems obvious," when the template requires it on every ticket.
- Writing a refactor ticket that jumps straight to the intended change instead of a characterization-first plan (pin current behavior green, then refactor, then red to green).
