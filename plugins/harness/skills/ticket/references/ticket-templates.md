# Ticket template

Read this when actually drafting a ticket. Token values (`TICKET_PREFIX`, `TRACKER`,
`TRACKER_BROWSE_URL`) come from `.claude/harness/profile.md`. No em dashes.

The body is deliberately minimal: 2 to 4 bullets (3 is typical) of what should change and why, in
product language. Nothing else. No section headings, no user-story formula, no acceptance-criteria
list, no Out-of-scope block, no implementation notes, no verification gate. One template covers
stories, bugs, and refactors; the type field and the title carry the distinction.

## Template
```markdown
TYPE: Story | Bug | Task (Refactor) | Spike · PARENT: <TICKET-KEY> (if any)
TITLE: <Area>: <imperative outcome, or the symptom in one line for a bug>

- <What should change, and why, in one line of product language.>
- <Next part, if it is genuinely separate.>

Reported by <name> in [#<channel>](<thread-url>).
<!-- 2 to 4 bullets, 3 typical, readable by someone who has never seen the code: name the surface, the
wrong behavior, and the wanted behavior. No identifiers, file paths, formulas, or library names. Bugs:
name the reproduction and the wrong behavior in the bullets. Refactors: say it is behavior-preserving.
Link the source of truth inline (design link, spec page, parent epic) rather than in a section. Keep
the reporter line only when the work came from someone's report. -->
```

## Definition of Ready
The bullets say what should change and why, name the type and parent, link the source of truth if
there is one, and read without the code or its vocabulary. Reporter and source thread present when the
work came from a report. Nothing describes an earlier version of the ticket. No em dashes. Tracker key
and links resolve.

## Deliberately skipped (do not re-add)
Section headings of any kind; the "As <persona>, I want ... so that ..." formula; an
acceptance-criteria checklist; a REQUIRED Out-of-scope block; steps-to-reproduce and expected-versus-
actual headings (state it in the prose instead); a characterization-first plan block; a
migrate-then-delete grep-gate block; any history of the ticket's own earlier wording; a verification gate listing lint/test/build commands (those still
run when the work is done, they are just not restated in the ticket); the web/UI extras block.
