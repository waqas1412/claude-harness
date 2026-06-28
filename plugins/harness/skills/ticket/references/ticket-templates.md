# Ticket templates

Read this when actually drafting a ticket. Token values (`TICKET_PREFIX`, `TRACKER`,
`TRACKER_BROWSE_URL`, `LINT_CMD`, `UNIT_TEST_CMD`, `E2E_TEST_CMD`, `BUILD_CMD`, `WEB_UI`) come from
`.claude/harness/profile.md`. Every ticket is INVEST, names a persona, carries 3 to 5 testable
acceptance criteria, has a terse `<Area>:` title, and a REQUIRED Out-of-scope section. No em dashes.

## Template A: Story / Feature / Epic
```markdown
TYPE: Story (or Feature/Epic) · PARENT EPIC: <TICKET-KEY> (if any)
TITLE: <Area>: <imperative outcome>

## User story
As <persona>, I want <capability> so that <value>.

## Context / why now
<1 to 3 sentences. Link the source of truth (design link, parent epic, data).>

## Acceptance criteria  (3 to 5, each testable)
- [ ] Given <state>, when <action>, then <observable outcome>.
- [ ] ...

## Out-of-scope  (REQUIRED)
- <what this ticket explicitly does NOT do; name the follow-up ticket if deferred>

## Implementation notes  (optional)
- Name precise file/symbol targets where known. Cite the precedent pattern to mirror.

## Verification gate
- [ ] `<LINT_CMD>`
- [ ] `<UNIT_TEST_CMD>` expected green NNN/NNN
- [ ] `<E2E_TEST_CMD> <change-scoped/path>`  (if the project has E2E)
- [ ] `<BUILD_CMD>` ONLY if build/export behavior changes
```

## Template B: Bug
```markdown
TYPE: Bug · PARENT EPIC: <TICKET-KEY> (if any)
TITLE: <Area>: <symptom in one line>

## Steps to reproduce
1. ...
## Expected vs actual
- Expected: ...
- Actual: ...
## Root cause  (if known)
<name the regressing commit/PR via git blame, File:Line>

## Acceptance criteria  (3 to 5, each testable)
- [ ] The reproduction above no longer occurs.
- [ ] A regression test fails without the fix and passes with it (name the spec).

## Out-of-scope  (REQUIRED)
- <related defects deliberately not addressed here>

## Verification gate
- [ ] `<LINT_CMD>`
- [ ] `<UNIT_TEST_CMD>` (regression spec named, red->green)
- [ ] `<E2E_TEST_CMD> <scoped/path>`  (if applicable)
```

## Template C: Refactor / Tech-debt / Spike
```markdown
TYPE: Task (Refactor) or Spike · PARENT EPIC: <TICKET-KEY> (if any)
TITLE: <Area>: <imperative, e.g. "extract X", "spike: evaluate Y">

## Goal
<the internal improvement; for a Spike, the question to answer and the timebox>

## No behavior change  (refactors)
- State it explicitly: output stays byte-identical; characterization-covered.

## Plan  (characterization-first)
1. Pin existing behavior with characterization tests; get them green FIRST.
2. Refactor.
3. Migrate-then-delete: introduce the new path, migrate call sites, then a grep gate proves the old
   path has zero references before deletion (`grep -rn "<oldSymbol>" <src>` returns nothing).

## Acceptance criteria  (3 to 5, each testable)
- [ ] Characterization tests green before and after.
- [ ] `grep -rn "<oldSymbol>"` returns no production references after migration.

## Out-of-scope  (REQUIRED)
- <adjacent cleanups deliberately not bundled in>

## Verification gate
- [ ] `<LINT_CMD>`
- [ ] `<UNIT_TEST_CMD>` green NNN/NNN
- [ ] `<BUILD_CMD>` ONLY if build/export behavior changed
```

## Web / UI projects only  (when WEB_UI is true)
Add to AC and notes: precise component/file targets and path aliases; design-system primitive usage
and any wrapper-over-raw-library convention; analytics event naming convention and limits; design-tool
deep links (cite the exact frame and node IDs, not the whole file); known framework gotchas. Omit this
whole block for non-UI repos (services, libraries, CLIs).
