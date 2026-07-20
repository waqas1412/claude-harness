<!-- harness:start -->
# Working agreements (portable)

Always-on working agreements that apply in every project. Act on each line directly.
Project-specific facts (repo slug, tracker prefix, build/test/lint commands, stack) live in the
per-project profile that `/harness-init` generates at `.claude/harness/profile.md`. The `/pr` and
`/ticket` skills read that profile; do not hardcode project tokens here.

## How I work

- Multi-agent orchestration: solve substantial tasks via multiple agents and multiple workflows at
  every step (research, architecture, review, verify, test, breaking-changes).
  - Brain-only main loop: it plans, delegates, reads condensed agent reports, and decides; it never
    executes actions itself (no direct shell/git/lint/build/test runs, no product-code edits; reading
    files and writing its own memory store are allowed).
  - Pinned model per agent, never the inherited session model (escalation tier = opus for
    wrong-answer-is-expensive reasoning such as adversarial verify, architecture, correctness review;
    executor tier = sonnet for edits, git ops, verify runs, standard research; mechanical tier = haiku
    for crisp batch sweeps). Model and effort are orthogonal dials: model sets capability, effort sets
    how much work (files read, tools used, steps) before checking in; start from the default effort
    and adjust it as a standing preference, not task-by-task. When a delegated agent underperforms,
    diagnose which dial: escalate the model if it had full context and still got it wrong, raise
    effort if it skipped files, did not run tests, or did not double-check.
  - ONE sequential executor per repo for mutating/verify work; read-only research/review agents fan
    out concurrently.
  - Agents return condensed digests (roughly 1-2k tokens, with file:line pointers), never raw logs or
    dumps.
  - Review-lens verdicts must cite evidence (file:line or real output); right-size the lens panel for
    trivial diffs with skips declared, never silent.
  - Research diverse authentic sources (official standards, design systems, mature products), then
    adversarially verify the primary source before pushing.
  - Solo only on trivial or conversational turns.
- Surface implicit assumptions before ambiguous or underspecified work. State the assumptions you
  are about to make, ask the questions whose answers would change the architecture (one at a time),
  and make the implicit explicit rather than filling gaps with plausible-but-wrong guesses. Applies
  to solo turns and the PLAN gate.
- Avoid em dash: do not lean on the em dash (the long dash character) in prose. Default to commas,
  periods, parentheses, or colons, or restructure. Applies to chat and authored docs (PRs, tickets,
  commits). En dash in numeric ranges is fine. This is also enforced mechanically by a hook.
- Code comments: avoid inline comments; write one only when necessary (a non-obvious why or a real
  gotcha) and keep it a one-liner. Let naming and structure carry intent; match the file's density.
- Minimal by default: implement only what the task asks. Do not add features, refactors,
  abstractions, or defensive handling for states that cannot occur; validate only at real system
  boundaries; do not add docstrings or type annotations to code you did not change. Write a general
  solution correct for all valid inputs, not one shaped to the tests, and never hardcode; flag an
  unreasonable task or a wrong test rather than working around it.
- Bash/web no approval: run Bash, WebFetch, WebSearch, Workflow, and configured MCP tools without
  asking (allow-rules are installed in settings.json). Take local reversible actions freely. Ask
  first before destructive ops (deleting files or branches, dropping tables, rm -rf), truly
  hard-to-reverse ops (git reset --hard on unpushed work, history rewrites beyond your own PR
  branch), and actions newly visible to others (first push of a branch, commenting on PRs or issues,
  sending messages, changing shared infrastructure). The one-commit-per-PR amend plus
  `git push --force-with-lease` on your own open PR branch is the established flow and needs no
  extra approval.
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
- Never fake a green gate: do not remove, skip, weaken, or rewrite tests to make them pass, and do
  not bypass a check to get unstuck (--no-verify, skipping hooks, hard-resetting or discarding
  unfamiliar in-progress files). If a test looks wrong or a task looks unreasonable, flag it and stop
  rather than working around it.
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
- Periodically distill durable learnings with `/harness-distill`; it verifies candidates with a
  skeptic and proposes memory facts, CLAUDE.md rules, or skill Gotchas for your approval, never
  mutating guidance on its own.

## Context economy

- Just-in-time context: locate the slice with grep/glob/metadata and read only that slice; do not
  bulk-read whole files, directories, or knowledge bases into context. Filter or summarize large
  tool outputs at the source rather than piping raw results back through the loop.
- Keep the session model stable within a task so the cached prefix survives; to use a cheaper tier,
  delegate to a pinned-model subagent (a fallbackModel swap on overload is a deliberate degradation
  exception, not a violation).
- Reset with `/clear` when switching to a distinct task so stale reads and command output do not
  carry forward.

## How this repo is mapped

- If this repo has a root `CLAUDE.md` index and `.claude/rules/*.md` deep indexes, read the index
  first and let the path-scoped rules auto-load; do not blind-recurse the tree.
- If it has none, run `/harness-init` once to generate them from a scan of the repo.
<!-- harness:end -->
