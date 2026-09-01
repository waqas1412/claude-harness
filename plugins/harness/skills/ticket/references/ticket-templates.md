# Ticket template

Read this when actually drafting a ticket. Token values (`TICKET_PREFIX`, `TRACKER`,
`TRACKER_BROWSE_URL`) come from `.claude/harness/profile.md`. No em dashes.

The body is deliberately minimal: a compact summary of what should change and why. Nothing else. No
section headings, no user-story formula, no acceptance-criteria list, no Out-of-scope block, no
implementation notes, no verification gate. One template covers stories, bugs, and refactors; the
type field and the title carry the distinction.

## Template
```markdown
TYPE: Story | Bug | Task (Refactor) | Spike · PARENT: <TICKET-KEY> (if any)
TITLE: <Area>: <imperative outcome, or the symptom in one line for a bug>

<!-- What should change and why, readable by someone who has not seen the code: 1 to 4 sentences, or
up to 4 bullets when the change has genuinely separate parts. Bugs: name the reproduction and the
wrong behavior in the same prose. Refactors: say it is behavior-preserving in the same prose. Link
the source of truth inline (design link, spec page, parent epic) rather than in a section. -->
```

## Definition of Ready
The summary says what should change and why, names the type and parent, links the source of truth if
there is one, and reads without the code. No em dashes. Tracker key and links resolve.

## Deliberately skipped (do not re-add)
Section headings of any kind; the "As <persona>, I want ... so that ..." formula; an
acceptance-criteria checklist; a REQUIRED Out-of-scope block; steps-to-reproduce and expected-versus-
actual headings (state it in the prose instead); a characterization-first plan block; a
migrate-then-delete grep-gate block; a verification gate listing lint/test/build commands (those still
run when the work is done, they are just not restated in the ticket); the web/UI extras block.
