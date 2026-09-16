# Ticket template

Read this when actually drafting a ticket. Token values (`TICKET_PREFIX`, `TRACKER`,
`TRACKER_BROWSE_URL`) come from `.claude/harness/profile.md`. No em dashes.

Everything is in product language a non-engineer can act on, with everyday vocabulary: no identifiers,
file paths, function names, formulas, library names, or migration numbers. Pick the common word over
the impressive one. Keep every number, name and behaviour exact.

## One skeleton, four fillings
Every type shares the same three-part skeleton. Only the middle section's name and the pair at the end
change, so a reader who has seen one ticket can read any of them.

1. **The core issue in two lines.** What is wrong or missing, and who it happens to. No preamble, no
   restating the title.
2. **A numbered middle**, five steps as the target. Its name depends on the type.
3. **A pair of results**, one panel each, so the gap between the two is the whole point of the ticket.

| Type | Middle section | Pair at the end |
|---|---|---|
| Bug | Steps to reproduce | Actual result / Expected result |
| Story, feature | Steps the person takes | Today / After this ships |
| Task, refactor | What changes | Today / After this ships |
| Spike, investigation | What to investigate | Open question / What a good answer settles |

Five is a target, not a quota: four or six is fine when the work needs it, but a bug needing ten steps
is usually two bugs, and a task with ten changes is usually two tasks.

## Bug
```markdown
TYPE: Bug · PARENT: <TICKET-KEY> (if any)
TITLE: <Area>: <the wanted behaviour in one short line>

<Two lines: what is wrong, and who it happens to.>

**Steps to reproduce**
1. <Start from a signed-out or clean state, and name the account or setup that matters.>
2. <The action, and what to confirm on screen so the reader knows they are in the right place.>
3. <...>
4. <...>
5. <Open the surfaces where the wrong behaviour shows.>

**Actual result**
<What happens, whether anything tells the person something is wrong, and how long it persists.>

**Expected result**
- <The corrected behaviour.>
- <What must be preserved: a choice someone already made, data already on the device.>
- <Anything that must happen without a reload or a second visit.>
```

## Story or feature
The middle is the journey, not a repro: the path the person walks to reach the new thing.
```markdown
TYPE: Story · PARENT: <TICKET-KEY> (if any)
TITLE: <Area>: <imperative outcome>

<Two lines: what someone cannot do today, and who needs it.>

**Steps the person takes**
1. <Where they start.>
2. <What they do.>
3. <...>
4. <...>
5. <Where they end up, and how they know it worked.>

**Today**
<What they hit instead, and what they do to work around it.>

**After this ships**
- <The new behaviour at that step.>
- <What must keep working exactly as it does now.>
- <What the person should see or be told, if anything.>
```

## Task or refactor
The middle is the surfaces that change. A refactor's "After" states plainly that behaviour is identical.
```markdown
TYPE: Task (Refactor) · PARENT: <TICKET-KEY> (if any)
TITLE: <Area>: <imperative outcome>

<Two lines: what is awkward or risky today, and who feels it.>

**What changes**
1. <One surface or behaviour, named the way a non-engineer would name it.>
2. <...>
3. <...>

**Today**
<What this costs now: the work it forces, the mistake it invites, the thing it blocks.>

**After this ships**
- <The wanted state.>
- <For a refactor: nothing a person can see changes, and here is what proves it.>
- <What becomes possible or cheaper next.>
```

## Spike or investigation
The middle is where to look. The pair is the question and what would count as an answer.
```markdown
TYPE: Spike · PARENT: <TICKET-KEY> (if any)
TITLE: <Area>: <the question, short>

<Two lines: the decision waiting on this, and who is blocked.>

**What to investigate**
1. <A place to look or a thing to try.>
2. <...>
3. <...>

**Open question**
<What cannot be answered today, and what has been assumed in the meantime.>

**What a good answer settles**
- <The decision it unblocks.>
- <The evidence it must carry to be trusted.>
- <A time box, if there is one.>
```

## Closing line, every type
When the work came from someone's report, close with:
`Reported by <name> in [#<channel>](<thread-url>).`

## Rich text
Publish through the tracker's rich-text format (ADF for Jira), not escaped markdown:

- **Bold** lead-ins for the middle section and both results. Do NOT use heading nodes; they are too
  heavy for a ticket this short.
- An ordered list for the middle, a bulleted list for the second half of the pair.
- Bold the values that carry the point (the units, the states, the numbers) so a skim lands on them.
- A panel for each half of the pair. Bug: `panelType: "error"` then `"success"`. Story, task and spike:
  `"info"` then `"success"`.

GOTCHA: the Atlassian MCP tools downconvert the description to markdown on read, even when the read is
asked for in ADF, and markdown has no panel. So a read-back showing plain bold lead-ins neither proves
nor disproves that panels landed. Confirm in the browser, or fetch the raw field through the REST API,
before claiming either way.

## Definition of Ready
Two lines of core issue. A numbered middle someone else could follow, named for the type. Both halves
of the pair present, and the second half also names what must be PRESERVED and anything that must
happen without a reload. Type and parent named, source of truth linked if there is one, reads without
the code or its vocabulary, reporter and source thread present when the work came from a report.
Nothing describes an earlier version of the ticket. No em dashes. Tracker key and links resolve.

## Deliberately skipped (do not re-add)
Heading nodes; the "As <persona>, I want ... so that ..." formula; a separate acceptance-criteria
checklist (the second half of the pair IS the criteria); a REQUIRED Out-of-scope block; a
characterization-first plan block; a migrate-then-delete grep-gate block; any history of the ticket's
own earlier wording; a verification gate listing lint/test/build commands (those still run when the work
is done, they are just not restated in the ticket); the web/UI extras block. Do not prescribe the FIX:
say what should happen, not which mechanism to use, because that decision belongs to the change.
