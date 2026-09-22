# House style (cross-cutting rules) and anti-patterns

Evidence-based rules from the Backend corpus. Follow these to sound native; they apply on top of
whichever archetype skeleton you picked.

## Voice and register

- Informal first-person plural, engineer to engineer: "We need...", "Let's not add it". Present
  tense for facts; future tense with a named owner for plans ("Toni will do on wk 27").
- Direct and unceremonious; light humor tolerated; opinions are signed ("[Ville's note]: ...",
  "(suggested by <person>)"). Keep the candid register but write clean grammar: the corpus's
  typos are tolerated, not a convention to reproduce.
- No em dashes in authored prose (user rule): commas, periods, parentheses, colons.
- Evidence over assertion: quantify (failure rates, row counts, before/after benchmarks with the
  test setup stated) and state the operational consequence. Emphasize load-bearing constraints
  plainly ("MUST be a response header, a hard requirement").
- Pin claims in time: "as of 2026-07-02", "30M+ rows as of 01/2025".

## Structure

- Bullet-first: nested bullets carry most content; paragraphs short and rare.
- Headings: sentence case, short noun phrases; question-form allowed ("How to access?").
  Unnumbered, levels in order (no H1 -> H4 jumps, no manual numbering).
- Long pages open with a toc macro (style=none).
- Formal design docs open with the metadata table: Document status | Author(s) | Reviewer(s) |
  Related rock.
- Link out rather than restate: requirements delegate to the business-design/rock page; canonical
  detail lives in exactly one place; Background links the prior rationale page.
- People and ownership always named: owners in parentheses on hub links, "AP: <name>" action
  points, escalation contacts in runbooks, TODOs assigned via @mention.

## Status, decisions, and history

- Status lozenges: doc lifecycle Blue "work in progress" -> Yellow "ready for review" -> Green
  "approved"; inline badges `ESTIMATE: N days` (Blue), `FIRST RELEASE` (Green),
  `AFTER FIRST RELEASE` (Yellow), "solved" (Green), "future dev" (Purple).
- Decisions are explicit and near the options: literal `Decision: <sentence>` lines or a
  "(selected option)" suffix on the winning heading (pick one marker and use it consistently;
  the corpus is inconsistent, the requirement is that the winner and the why are unmissable).
  Rationale travels with the rejected option ("=> DMS got ruled out: <why>"). Rejected
  alternatives are preserved in full, never deleted.
- Append-only amendment: dated addenda ("[25.03.2026] Tides have turned..."),
  "Update DD.MM.YYYY" sections, "UPD:" prefixes, attributed commentary. Never silently rewrite
  history; supersede with a dated note linking the replacement, keep the old page.
- "Open questions" is the standard closing section of design docs (about a third of the corpus
  carries one; include it in anything TDR-shaped). Mature form: a table
  (# | Question | Status | Resolution) whose rows flip to a Green "solved" lozenge with the
  answer and rationale written into the row; rows never deleted. Loose form: question bullets
  with answers nested underneath; unresolved items routed to a named person.
- Work-in-progress marked honestly: `[DRAFT]` title prefix, "TBD:" / "TODO <owner>:" markers,
  angle-bracket template hints left visible in not-yet-filled TDR sections
  ("<what we believe to be true and rely on>"). Sections that are genuinely irrelevant may be
  dropped (even approved TDRs do); the sin is unfilled boilerplate presented as content, not a
  missing section.

## House dialect

- Arrows: `=>` / `→` for verdicts, consequences, resulting actions; `←` marks a chosen option.
- Dates: Finnish D.M.YYYY, with clock time for as-run logs ("PROD done 23.6. 08:30"). Running
  memo entries titled "D.M.YYYY Weekly", newest first, with a "Present: <names>" line.
- Jira via the inline jira macro placed next to the exact thing it tracks; prefer the macro
  over bare ticket keys (bare keys occur in the corpus but the macro is the norm for tracked
  work). GitHub PRs as raw URLs; Slack permalinks as decision provenance ("=> Done, thread").
- Tables have fixed jobs: doc metadata; option comparison (Pros/Cons or Work
  amount/Limitations/Risk/Pros/Cons); DB data dictionaries (column | type | description);
  open questions; deployment trackers with environment X-marks; Term | Definition glossaries;
  Method | Endpoint | Ticket | Status. API payloads go in code blocks (often inside wide
  expands), not tables.
- draw.io is the standard diagram tool, placed at the top of Proposed solution; big diagrams get
  diagram-only child pages named by role. External visuals (dbdiagram.io, Miro) keep the
  original link plus an image snapshot. (Writer skill: emit placeholders, see storage-format.md.)
- info/note panels for page-lifecycle metadata (role banners, provenance, supersede notices,
  AI-content disclosure) and must-read reader routing; TDR bodies also use info panels for
  emphatic inline notices. Plain "NB:" / "Note!" prose is equally common for inline cautions.
- Secrets referenced by Bitwarden entry name, never inline.

## Anti-patterns (seen in the corpus's worst pages; never reproduce)

- Empty container pages with zero body; a hub must at least index its children with owners.
- Blueprint boilerplate left as content ("Summarize insights from personas...", "Because....",
  "ended up with ______"). Distinct from the accepted angle-bracket TDR hints.
- AI-authoring artifacts pasted in ("Create this as a table in Confluence with the following
  columns...") or a whole AI report dumped into one code block with no native structure. If AI
  content is posted, it needs the info-panel provenance disclosure AND conversion to real
  Confluence content.
- Options docs with no recorded outcome (empty Pros bullets, never-filled Decision section):
  readers can't tell rejected from forgotten. Every options page ends in a decision or a pointer
  to where the decision will happen.
- `[DRAFT]` pages abandoned with no owner, decision, or follow-up link.
- Decisions with no rationale, date, or author ("CDK will be written on python").
- Broken heading hygiene: pages starting at H4, level jumps, ALL-CAPS titles, manual numbering
  that drifts.
- Unnamed diagram files ("Untitled Diagram-1665741401636.drawio"); duplicating a diagram instead
  of transcluding it with a source note.
- Empty template rows / stub sections left as content debt ("Definitions of Done" as empty
  bullets, trailing empty "Framery Mobile:" heading).
- Vendor datasheets pasted wholesale with broken lists; attach via view-file and summarize.
- Inconsistent lozenge casing ("migrated" / "MIGRATED" / "Migrated"); pick one and reuse exactly.
