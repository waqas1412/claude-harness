<!-- harness:start -->
# Working agreements (portable)

Always-on working agreements that apply in every project. Act on each line directly.
Project-specific facts (repo slug, tracker prefix, build/test/lint commands, stack) live in the
per-project profile that `/harness-init` generates at `.claude/harness/profile.md`. The `/pr` and
`/ticket` skills read that profile; do not hardcode project tokens here.

## How I work

- Single main loop: solve tasks yourself in one loop, using whatever model is selected for the
  session. Plan, read code, edit, and run shell/git/lint/build/test directly, then review your own
  work before committing. Do NOT delegate to subagents or spin up workflows, do NOT pin per-agent
  models, and do NOT split "brain" (planner) from "hands" (executor). Reach for a subagent or
  workflow ONLY when explicitly asked in the moment.
  - Right-size self-review to the change before committing: read your own diff for the concerns that
    actually apply (correctness and repo-fit at minimum; add spec fidelity, design parity, timing,
    and performance when the change touches them) and cite concrete evidence (file:line or real
    output). Say which checks you skipped and why, never silently.
  - Ground non-trivial work in authoritative primary sources (official standards, version-matched
    library docs and source, design systems, mature products), and verify a claim against the
    source before acting on it.
- Surface implicit assumptions before ambiguous or underspecified work. State the assumptions you
  are about to make, ask the questions whose answers would change the architecture (one at a time),
  and make the implicit explicit rather than filling gaps with plausible-but-wrong guesses. Applies
  before any ambiguous or underspecified task.
- Avoid em dash: do not lean on the em dash (the long dash character) in prose. Default to commas,
  periods, parentheses, or colons, or restructure. Applies to chat and authored docs (PRs, tickets,
  commits). En dash in numeric ranges is fine. This is also enforced mechanically by a hook.
- Code comments: avoid inline comments; write one only when necessary (a non-obvious why or a real
  gotcha) and keep it a one-liner. Write it as documentation for the next reader, never as a note to
  yourself: open a function comment with the identifier it documents, say what the thing does, and
  leave investigation measurements and reasoning-in-progress to the commit message and PR body. Let
  naming and structure carry intent; match the file's density.
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
- Secrets never in chat: never ask for, and never accept, a credential (private key, PAT, session
  cookie, password, connection string) as chat text. The moment one is needed, offer the file path
  first: have the user write it himself to a file outside every repo (`~/.config/<org>/<name>.txt`,
  `chmod 600`), then read it only as a shell variable (`-H "Authorization: Bearer $(cat ~/.config/...)"`,
  `-b "$(cat ...)"`) and never echo, log, or copy it into a repo, memory file, doc, ticket, or commit.
  If a secret does reach the transcript anyway, say so plainly and recommend rotating it rather than
  reusing it. Per-service file names are workspace facts and live in the memory store, not here.
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

- Keep durable, reusable facts in the memory store, one fact per file with frontmatter (`name`,
  `description`, `metadata.type` = user | feedback | project | reference). The store that is actually
  auto-loaded is the workspace-scoped one at `~/.claude/projects/<cwd-slug>/memory/`, where
  `<cwd-slug>` is the working directory path with separators replaced by dashes. Write there, not to
  `~/.claude/memory/`, which is a legacy store that no session loads.
- That store's `MEMORY.md` is the index: one line per fact (`- [Title](file.md) hook`). Add a pointer
  when you create a fact; this index is the part loaded each session, so a fact with no pointer line
  is dark and will never fire.
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
- Keep the session model stable within a task so the cached prefix survives (a fallbackModel swap on
  overload is a deliberate degradation exception, not a violation).
- Reset with `/clear` when switching to a distinct task so stale reads and command output do not
  carry forward.

## How this repo is mapped

- If this repo has a root `CLAUDE.md` index and `.claude/repo-index/*.md` deep indexes, read the index
  first, then Read only the matching `.claude/repo-index/*.md` for what you touch; do not blind-recurse
  the tree or bulk-read the index dir.
- If it has none, run `/harness-init` once to generate them from a scan of the repo.
<!-- harness:end -->
