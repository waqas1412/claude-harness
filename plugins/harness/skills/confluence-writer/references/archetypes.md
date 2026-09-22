# Doc archetypes (mined from 109 pages under DOS/Backend, 2026-07-02)

Pick ONE archetype before drafting; each has a fixed skeleton readers expect. Sections marked
(optional) may be dropped; in the full TDR, keep unused sections as placeholders instead
(see house-style.md). Exemplar page ids are live pages to fetch when a concrete model helps.

## 1. TDR / Tech design (the default for substantial design work)

When: any design needing cross-team review or approval: new feature backend design, DB or
architecture change, API design. The "Business design" twin uses the same skeleton for the
what/why layer; the TDR covers the how. Pages titled `RFC: <topic>` use this exact skeleton too
(exemplar: 1920860161 RFC: Digest e-mail Lambda timeout solving). "Rock" is Framery's term for a
quarterly goal; for another org substitute epic/initiative.

Skeleton (some pages hoist Summary to top level instead of nesting under an Introduction H1):
- `toc` macro (style=none)
- Metadata table: Document status (status lozenge) | Author(s) | Reviewer(s) | Related rock
- Introduction > Summary (optionally with a Stakeholders subsection naming owner/team/consumers)
- Introduction > Used terminology
- Introduction > Product requirements (often just a link or excerpt-include to the rock page)
- Introduction > Technical requirements
- Introduction > Information security requirements
- Introduction > Out of scope
- Introduction > Assumptions
- Introduction > Relation to other rocks
- Introduction > SOS Data mart dependencies (in the current template; present in both modern exemplars)
- Introduction > Public REST API effects (newer template question: does this design affect the public API?)
- Investigations / Discovery (optional)
- Solutions > Current solution
- Solutions > Considered solution(s): one numbered "Solution N: <name>" subsection per option,
  winner's heading suffixed "(selected option)"; independent decision axes (hosting, auth,
  implementation strategy) each get their own "Considered solutions: <axis>" block
- Solutions > Proposed solution (diagram first, then per-component H3s / per-endpoint H4s)
- Solutions > Risk analysis / threat model (the four threat-modeling questions as H3s: what are we
  working on / what can go wrong / what are we going to do about it / did we do a good job)
- Solutions > Test plan
- Solutions > Monitoring and observability plan
- Solutions > Release and deployment plan
- Solutions > Maintenance and support plan
- Open questions
- Technical Design Review (TDR) notes > Discussion, Decisions (optional)
- Updated solution / "Update DD.MM.YYYY" (optional, appended post-ship)
- Appendixes (optional)

Signature elements: status lifecycle Blue "work in progress" -> Yellow "ready for review" ->
Green "approved"; per-option Pros/Cons (or Work amount/Limitations/Risk/Pros/Cons) evaluation
with the winner marked explicitly (a "(selected option)" heading suffix as in 2005172225, or a
Decision line); twin-delegation idiom: requirements sections reduced to "All requirements are in
above mentioned Business Design wiki page" instead of restating; DB tables as
column | type | description tables labelled (New table)/(Existing); endpoints as one heading per
"METHOD /service/path" with request/response code blocks inside expand macros; rejected
alternatives kept in full; Open questions as a table whose rows flip to a Green "solved"
lozenge. Implementation-planning TDRs (e.g. 1219002371) additionally break the design into
jira-tracked work items with inline `ESTIMATE: N days` (Blue) and release-phase badges; optional
flourish, not core template.

Exemplars: 2067955713 Temperature in Connect; 2005172225 Public REST API - Technical design
(+ Business twin 1942847489); 1148289041 Space Overview Backend Design.

## 2. miniTDR (lightweight design memo ending in a recorded decision)

When: focused single-topic design needing a team decision but not the full template: refactor or
rewrite of one service/lambda, replacing a component, a deprecation. Title: `miniTDR: <topic>`,
usually a verb phrase. (This shape is the 2026 Go-rewrite series convention; it is the modern
replacement for older loose "backend design" pages.)

Skeleton:
- Background (first line `repository: <URL>`; "Extends on the <parent miniTDR>" link if a series)
- Issues with current design (quantified: failure rates, metrics)
- Wishlist
- Design proposal (paired `current:` / `proposed:` architecture, ASCII diagrams in wide code
  blocks; inline `Decision:` lines at sub-choices; time estimates in prose)
- Other comments? (optional parking lot; attendee input via @mention, answered inline)
- Conclusion: a time-stamped meeting memo (`time: DD.MM.YYYY HH:MM`, "Meeting with <@mentions>",
  prose recap of who argued what) ending in a literal final `Decision: <sentence>` line
- Update DD-MM-YYYY (optional, appended later instead of rewriting)

Signature: the mandatory `Decision:` last line; ASCII architecture diagrams in wide code blocks
(one page adds a legend line, "(L) stands for a lambda"); `TODO: Needs a separate miniTDR
session` to spawn follow-ups; casual estimates ("probably like a week"); NO metadata table or
lozenges.

Exemplars: 1975091245, 1975812099, 1975353355 (also 1976401921, 2042232859).

## 3. Investigation / spike report

When: performance analysis, feasibility study, tooling comparison; any "should we?" answered
with measurements and hands-on trials.

Skeleton: context paragraph (what question, why now, link to motivating page) -> toc (long pages)
-> Measurements / trials (raw evidence: SQL, EXPLAIN plans, logs, graphs, back-of-envelope math
with assumptions shown) -> optional interim "Short conclusions at this point" -> Options, each
with a per-option verdict and `=> ruled out` arrows -> Conclusion ("In short, ...") -> optional
Recommendations (actions, distinct from findings) -> optional Open questions.

Signature: inline arithmetic with assumptions ("209 bytes * 31380516 rows ~ 6.56 GB");
quantified before/after plus the operational consequence ("service is therefore set to scale at
1000 requests per target"); verbatim evidence in code blocks; `Problem: ... / Solution: ...`
paired paragraphs.

Exemplars: 981893124, 155222023. (428245015 shows the evidence style well but ends mid-options
with no recorded outcome; do not copy that ending.)

## 4. Running memo (recurring meeting log)

When: weekly/recurring syncs for a stream; accretes one entry per meeting, newest first; the
audit trail of status, decisions, action items.

Skeleton (modeled on 991068168, the modern form): hidden `excerpt` macro (name="Memo template")
holding a blank copyable entry -> one H2 per meeting titled `D.M.YYYY Weekly` (topic suffix for
ad-hoc), NEWEST FIRST -> per entry: optional `Present: <names>` line (mostly on ad-hoc entries),
jira link to the parent epic, per-workstream status bullets (fixed agenda ending in "Other")
anchored with inline jira macros, `Action items` as a task list ("Name to <verb>" / "AP: Name"),
`Decisions` as decision elements marked DECIDED.

Signature: dense inline jira embeds next to the work they track; `COMPLETED` (Green) lozenge
appended to a finished workstream; Slack permalinks as decision provenance.

Exemplars: 991068168, 1363148835. (151257141 is an older, looser variant: ISO-dated `2023-06-15`
entries, no excerpt template; follow the modern form for new memos.)

## 5. How-to / runbook

When: operational procedures for the next on-call person: vendor-portal troubleshooting, sensor
calibration, manual DB remediation.

Skeleton (modeled on 917995633, the strongest runbook; the other exemplars are looser
precedents): header block BEFORE any heading (system URL + "If you don't have credentials, ask
<name>") -> toc -> optional concept/context section -> Common issues: numbered, each with
"Potential Causes (Most Common First):" then "Solutions in short:" -> Solutions: one H3/H4 per
cause with the full procedure, screenshot per step, UI paths as quoted breadcrumbs -> optional
per-setting reference (Definition / Default+logic with worked example / "When to change:") ->
copy-paste SQL detect/cleanup blocks -> optional post-change steps and future plan.

Signature: exact button labels in quotes; named escalation contacts; secrets referenced by
Bitwarden entry name, never inline; `Q:/A:` diagnostic pairs; appended "Update:" paragraphs when
production config changes.

Exemplars: 917995633, 539721771, 1253310572.

## 6. Migration / deployment plan and tracker

When: rollouts, repo/service migrations, deprecations, go-lives: an ordered deploy sequence
across environments plus a record of what actually happened.

Skeleton (a composite: no single page has every part; 2146664496 is tracker-tables-only, while
1750794246 and 1001357759 carry the plan and as-run sections): Summary/Background (link the
driving epic via jira macro; link prior rationale pages
instead of restating) -> dependency inventory (per-repo table or bullets) -> optional dependency
diagram -> ordered Steps with per-step owner -> tracker table
`Things | Git repo | AWS DEV | AWS PROD | Git branch | Notes` (X-mark = done; Notes =
date-stamped progress bullets) -> optional per-endpoint verification checklist -> optional Risk
(severity call first: "Low risk.", then mitigations) -> "Deployments on DD.MM.YYYY" as-run log
sections appended per deploy day -> "What's left:" running bullets.

Signature: X-marks in DEV/PROD cells, "N/A (ClickOps)" where no repo applies; as-run notes down
to clock time ("PROD done 23.6. 08:30"); work assigned by first name and ISO week ("Toni will do
on wk 27"); deprecate-then-delete: redirect callers -> deprecation warning log -> verify no
calls ~30 days -> delete.

Exemplars: 2146664496, 1750794246, 1001357759.

## 7. Stream hub / project landing page

When: the collector page for a stream or project; routes readers to child TDRs, memos, trackers.
Keep it thin; delegate detail.

Skeleton: optional `info` banner declaring the page's role -> optional General Overview table
(Accountable, Contributors, Objective, Key outcomes, Phase, Overall Status lozenge,
Communication incl. Slack channel) -> Useful links -> Current state (terse bullets) -> Initial
plan ("First step:" / "Assumption:" bullets) -> State/progress as task-list checklists grouped
per area, items carrying jira embeds -> optional Identified issues table
(Potential issue | Effect | Possible fixes) -> optional Scope table (Must have / Nice-to-have /
Not in scope) -> Definitions of Done -> Technical designs (links to child TDRs, one H3 each with
Background:/Goal: stubs) -> optional Team roster.

Signature: child links carry the owner's name in parentheses ("Database Performance Improvements
(Teemu)"); expand collapsibles holding Method | Endpoint | Ticket | Status tables; Yellow
"In progress" overall lozenge; the hub links child designs, never restates them.

Exemplars: 1003388929, 129073201, 990183505. (1003388929 is the richest hub but its manually
numbered headings drifted out of sync; never copy the numbering.)

## 8. Design sub-page (DB schema / diagram child of a TDR)

When: a parent TDR's supporting artifact that deserves its own URL: DB schema, architecture or
sequence diagram, options-comparison for one table family. Named by role ("Database Schema",
"Architecture Diagram").

Skeleton: toc -> Overview (what this documents, which endpoint/feature it supports, data
provenance) -> Related resources (parent TDR, feature spec, sibling diagram pages, Jira) ->
Database design (ER diagram + column tables; wire-format-to-column mapping bullets with `->`) ->
optional Example row (one concrete realistic row) -> optional Access grants table
(# | Grant | Status | Notes with literal SQL, status citing the delivering PR/migration) ->
options variant: one H1 per option with an evaluative name ("Dirty and fast", "Major
refactoring"), identical repeated skeleton (diagram + Description of changes + Actions required +
Pros/Cons + Impact on <consumer>) -> Open questions table (# | Question | Status | Resolution) ->
optional dated MiniTDR Notes (Participants, Discussion, Decisions with arrows and "Rationale:"
lines) -> optional Change log.

Signature: solved question rows flip to a Green "solved" lozenge with rationale in Resolution,
never deleted; explicit ownership boundaries ("no work for the Connect team"); external diagrams
keep the original link plus an image snapshot.

Exemplars: 2119761962, 2114322436, 325156941.

## 9. Decision record (small blueprint page)

When: a single scoped decision that needs a recorded owner and outcome but no design doc:
tooling choice, process change, one-service policy.

Skeleton: metadata table Status | Owner | Contributors | Decision -> Problem statement ->
Research insights (optional) -> Solution hypothesis -> Design options -> Follow up. The Decision
cell/section must end filled and dated; an empty Decision section is the corpus's most common
failure mode for these pages.

Exemplars: 305397809, 325156909.

## Title conventions

Type prefixes are part of the taxonomy: `miniTDR: <verb phrase>`, `RFC: <topic>`,
`Running Memo - <stream>`, `[DRAFT] <topic>` for unreviewed drafts, and cross-page references
use `Feature:`, `Page:`, `Component:`, `Flow:` prefixes. Sub-pages are named by role, not topic.
