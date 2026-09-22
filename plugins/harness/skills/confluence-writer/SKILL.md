---
name: confluence-writer
description: "Write, update or publish a Confluence page in the house style (TDR, miniTDR, RFC, spike report, memo, runbook, decision record). Use when asked to write or publish a Confluence or wiki page."
argument-hint: "[what to write, target space/parent page, or a page URL to update]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Confluence writer (house style, session-cookie publish)

Style spec mined 2026-07-02 from all 109 pages under DOS/Backend (framery.atlassian.net). The
templates generalize to other spaces; when writing outside Backend, still skim 2-3 sibling pages
of the target location first and let local conventions win on conflicts.

## Workflow

1. **Scope**: identify what the page is for, the target space and parent page, and whether this
   is a NEW page or an UPDATE to an existing one.
2. **Pick ONE archetype** from `references/archetypes.md` (TDR, miniTDR, investigation, running
   memo, runbook, deployment plan, stream hub, design sub-page, decision record) and say which
   and why. If the
   user's ask spans several (e.g. "design + rollout"), prefer separate pages linked together,
   like the corpus does (TDR + deployment tracker child).
3. **Gather inputs**: the code/tickets/decisions the page must reflect. For an UPDATE, fetch the
   live page first (never edit from memory of it) and diff against reality. If a concrete model
   helps, fetch one exemplar page listed in the archetype (they are live page ids). Any fetch
   requires the cookie/header setup from `references/api-mechanics.md`; do that setup now.
4. **Draft the outline first** (sections + one-line content plan per section) and show it to the
   user before writing the full body, unless the user asked for the full page directly.
5. **Write the body in storage-format XHTML** using `references/storage-format.md` recipes and
   `references/house-style.md` rules. Non-negotiables:
   - where the chosen archetype calls for them: status lozenges for lifecycle and inline
     badges, the metadata table, and an Open questions section (miniTDRs deliberately have
     none of these); jira macro next to every tracked item (never bare ticket keys); decisions
     as literal `Decision:` lines or "(selected option)" markers with rationale; append-only
     updates on existing pages.
   - draw.io macros cannot be created via REST: emit a `TODO(<owner>): insert diagram of <x>`
     placeholder paragraph instead.
   - no em dashes in prose (user rule); no Co-Authored-By-style attribution anywhere.
   - run the XML well-formedness smoke test from storage-format.md before any publish.
6. **Deliver**: default is BOTH the paste-ready draft and an offer to publish. Publishing goes
   through `references/api-mechanics.md` (browser-session cookie, ALL headers with exact values
   including user-agent, backup + version-drift guard, dry-run diff first, PUT/POST only after
   the user confirms or has pre-authorized publishing in this task). If no working cookie is in
   the session scratchpad, ask the user to paste
   a fresh "Copy as cURL" from DevTools; treat the cookie as ephemeral and delete scratch copies
   when done.
7. **Report**: page title, id, new version number, and the webui link (or the paste-ready
   storage XML if not publishing).

## Quality gate before delivering

- Archetype skeleton complete: every non-optional section present (full TDRs keep placeholders
  for unfilled sections; miniTDRs may drop irrelevant ones).
- Sounds native per house-style.md: bullet-first, quantified claims, named owners, dated
  amendments, arrows dialect.
- Zero anti-patterns from house-style.md (no boilerplate residue, no options without a recorded
  outcome, no undated decisions, no heading-level jumps).
- Update case: surgical unique-match edits on the live body, original reasoning preserved,
  version message set.

## References (read on demand, not all up front)

- `references/archetypes.md`: the 9 page skeletons + title conventions + live exemplar ids.
- `references/house-style.md`: voice, structure, status/decision/history rules, anti-patterns.
- `references/storage-format.md`: exact XHTML/macro recipes and write-side gotchas.
- `references/api-mechanics.md`: cookie/header discipline, read/PUT/POST endpoints, batch-skim
  pattern, publish safety rails.
