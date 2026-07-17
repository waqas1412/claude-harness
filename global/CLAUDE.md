<!-- harness:start -->
# Working agreements (portable)

Always-on working agreements that apply in every project. Act on each line directly.
Project-specific facts (repo slug, tracker prefix, build/test/lint commands, stack) live in the
per-project profile that `/harness-init` generates at `.claude/harness/profile.md`. The `/pr` and
`/ticket` skills read that profile; do not hardcode project tokens here.

## How I work

- Multi-agent orchestration: solve substantial tasks via multiple agents and multiple workflows at
  every step (research, architecture, review, verify, test, breaking-changes). The main loop is the
  BRAIN only: it plans, delegates, reads condensed agent reports, and decides; it never executes
  actions itself (no direct shell/git/lint/build/test runs, no product-code edits; reading files and
  writing its own memory store are allowed). Every delegated agent gets an explicitly pinned model,
  never the inherited session model (escalation tier = opus for wrong-answer-is-expensive reasoning
  such as adversarial verify, architecture, correctness review; executor tier = sonnet for edits,
  git ops, verify runs, standard research; mechanical tier = haiku for crisp batch sweeps). ONE
  sequential executor per repo for mutating/verify work; read-only research/review agents fan out
  concurrently. Agents return condensed digests (roughly 1-2k tokens, with file:line pointers),
  never raw logs or dumps. Review-lens verdicts must cite evidence (file:line or real output);
  right-size the lens panel for trivial diffs with skips declared, never silent. Solo only on
  trivial or conversational turns. Research diverse authentic sources (official standards, design
  systems, mature products), then adversarially verify the primary source before pushing.
- Avoid em dash: do not lean on the em dash (the long dash character) in prose. Default to commas,
  periods, parentheses, or colons, or restructure. Applies to chat and authored docs (PRs, tickets,
  commits). En dash in numeric ranges is fine. This is also enforced mechanically by a hook.
- Code comments: avoid inline comments; write one only when necessary (a non-obvious why or a real
  gotcha) and keep it a one-liner. Let naming and structure carry intent; match the file's density.
- Bash/web no approval: run Bash, WebFetch, WebSearch, Workflow, and configured MCP tools without
  asking (allow-rules are installed in settings.json). Still flag destructive or irreversible
  operations before running them.
- Commit authorship: never add a `Co-Authored-By` trailer. Sole author. Enforced by a hook.
- PR reviewers: `gh pr create` with title, body, and base only. No `--reviewer`, no
  requested_reviewers mutations. Request reviews yourself. Enforced by a hook.
- PR description format: write PR bodies with the `/pr` skill (house template, profile-driven).
  Title `<type>: <TICKET-KEY> ...`; Summary plus a tracker-close line, What changed, Why,
  Breaking-changes-asserted, Testing (lint / build / scoped tests with red to green proof),
  Screenshots (Before | After), Notes. Lean and skippable; list deliberate SKIPs.
- Ticket format: write tickets with the `/ticket` skill (profile-driven templates: Story / Bug /
  Refactor-Spike). INVEST plus persona plus 3 to 5 testable acceptance criteria, terse `<Area>:`
  title, REQUIRED Out-of-scope section, characterization-first plan for refactors, migrate-then-delete
  grep gate, lint/build/scoped-test gate. Lean and skippable.
- Verify repo conventions before git ops: before every commit, push, or PR, re-check the diff
  against the repo's agent instructions (e.g. AGENTS.md), run lint plus build plus change-related
  tests fresh, and state compliance explicitly. Confirm the current branch
  (`git branch --show-current`) before any commit or amend; never amend without verifying HEAD is the
  intended commit.
- Characterization tests first: when refactoring an untested target, pin existing behavior green
  first, then refactor, then red to green the intended change.
- Branch rename closes PRs: never rename a branch that heads an open PR (GitHub closes it). Relabel
  via PR title/body and commit amend instead.
- One commit per PR: single commit per PR. Fold review fixes and follow-ups in via amend plus
  `git push --force-with-lease` (same branch ref is safe; only a rename closes the PR). Never add a
  second commit.

## Memory

- Keep durable, reusable facts in the memory store at `~/.claude/memory/`, one fact per file with
  frontmatter (`name`, `description`, `metadata.type` = user | feedback | project | reference).
- `~/.claude/memory/MEMORY.md` is the index: one line per fact (`- [Title](file.md) hook`). Add a
  pointer when you create a fact; this index is the part loaded each session.
- Write only what is durable and reusable: corrections, decisions, hard-won gotchas, stable user
  preferences. Never store transient task state or anything the repo or git history already records.
- Before saving, check for an existing file that covers it and update that instead of duplicating.
  Delete a fact that turns out to be wrong. The em dash is allowed in `MEMORY.md` as its delimiter.

## How this repo is mapped

- If this repo has a root `CLAUDE.md` index and `.claude/rules/*.md` deep indexes, read the index
  first and let the path-scoped rules auto-load; do not blind-recurse the tree.
- If it has none, run `/harness-init` once to generate them from a scan of the repo.
<!-- harness:end -->
