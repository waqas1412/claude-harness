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
- Verify review feedback before agreeing with it: a comment on a PR (human or bot) is a claim, and
  agreeing is as much a decision as disagreeing. Check it against the installed library source at the
  pinned version, the version-matched official docs, real-world discussion of the same failure, and the
  repo's own gotchas, then state the verdict with that evidence. Treat a reviewer's suggested fix as a
  separate claim from their diagnosis, and where the mechanism is subtle, pin it with a failing test
  before writing the fix. Never agree out of deference.
- Surface implicit assumptions before ambiguous or underspecified work. State the assumptions you
  are about to make, ask the questions whose answers would change the architecture (one at a time),
  and make the implicit explicit rather than filling gaps with plausible-but-wrong guesses. Applies
  before any ambiguous or underspecified task.
- Avoid em dash: do not lean on the em dash (the long dash character) in prose. Default to commas,
  periods, parentheses, or colons, or restructure. Applies to chat and authored docs (PRs, tickets,
  commits). En dash in numeric ranges is fine. This is also enforced mechanically by a hook.
- Plain words: write every piece of text in simple, everyday vocabulary, in the shortest sentence that
  still carries the meaning. Applies to chat, PR bodies, tickets, commit messages, wiki pages, chat-app
  and reply drafts, slide decks, and code comments. Pick the common word over the impressive one ("use"
  not "utilise", "broken" not "malformed", "reads" not "resolves"), and drop jargon a non-engineer would
  not follow, including the review-lens vocabulary ("seam", "gate", "provenance"), unless the word is
  the real name of the thing: an identifier, an API field, a UI label, or a term the reader uses himself.
  Simplify the language, never the facts; keep every number, name, and technical claim exact.
- Code comments: avoid inline comments; write one only when necessary (a non-obvious why or a real
  gotcha) and keep it a one-liner. Write it as documentation for the next reader, never as a note to
  yourself: open a function comment with the identifier it documents, say what the thing does, and
  leave investigation measurements and reasoning-in-progress to the commit message and PR body. Let
  naming and structure carry intent; match the file's density. This holds in every file type, not
  just the app language: TypeSpec, YAML, SQL, config, and tests are all covered, and it is applied
  inside each Edit or Write call rather than as a later sweep.
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
  sending messages, changing shared infrastructure). Adding a commit and pushing it to your own open
  PR branch is the established flow and needs no extra approval.
- Secrets never in chat: never ask for, and never accept, a credential (private key, PAT, session
  cookie, password, connection string) as chat text. The moment one is needed, offer the file path
  first: have the user write it himself to a file outside every repo (`~/.config/<org>/<name>.txt`,
  `chmod 600`), then keep it off the command line: curl blanks only `-u` from process listings, so
  `-H "Authorization: Bearer $(cat ...)"` is readable via `ps` for the life of the request. Pass the
  whole header line from the file instead (`curl -H @~/.config/<org>/<name>.header`, or `-K` for a
  config file), and never echo, log, or copy it into a repo, memory file, doc, ticket, or commit.
  If a secret does reach the transcript anyway, say so plainly and recommend rotating it rather than
  reusing it. Per-service file names are workspace facts and live in the memory store, not here.
- HTTP from the shell: reach for the service's own client first, because it already handles auth,
  paging, and errors (`gh api` for GitHub, the vendor CLI for a cloud provider, the project's own
  authenticated fetch helper for a tracker or wiki). For anything else use `curl -sS --fail-with-body`:
  plain curl exits 0 on a 404, `--fail` alone throws away the error body, and only `--fail-with-body`
  gives both a non-zero exit and the body that explains why. Do not hand-roll a scripting-language HTTP
  call for a one-off request, and do not add an HTTP library to reach a machine that only has stdlib.
- Commit authorship: never add a `Co-Authored-By` trailer. Sole author. Enforced by a hook.
- PR reviewers: `gh pr create` with title, body, and base only. No `--reviewer`, no
  requested_reviewers mutations. Request reviews yourself. Enforced by a hook.
- PR description format: write PR bodies with the `/pr` skill (profile-driven). Title
  `<type>: <TICKET-KEY> ...`. The body is a linked tracker-close line (`Closes [KEY](browse-url).`)
  followed by 3 to 6 flat one-line bullets, each naming a change and its why, and nothing else (no
  headings, no Testing block, no Screenshots table, no breaking-changes assertion). Bullets are the
  shape, never a paragraph. With no ticket, open the body with the source thread as a link instead of
  the close line. When the work came from a report, close with `Reported by <name> in [#channel](url).`
  Reconcile the body whenever a commit lands or the scope moves, so it never describes an older
  head. Verification still runs fresh and is reported in chat, not in the body.
- Ticket format: write tickets with the `/ticket` skill (profile-driven). A ticket is a type/parent
  line, a terse `<Area>: <imperative>` title, and 2 to 4 bullets (3 is typical) of what should change
  and why, and nothing else (no headings, no persona formula, no acceptance criteria, no Out-of-scope
  block, no verification gate). Write it in product language a non-engineer can act on: no
  identifiers, file paths, formulas, or library names. Carry no history of the ticket's own earlier
  versions, and when rewriting a stale ticket, state only what is true now. When the work came from a
  report, close with `Reported by <name> in [#channel](url).` Verification still runs when the work is
  done, reported in chat.
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
  via PR title/body instead.
- PR commits: add review fixes and follow-ups as additional commits and push normally. Do not amend
  and force-push an already-pushed PR branch to keep it at one commit. Force-push stays fine where it
  is inherent to the operation, such as a rebase onto a moved base; a hook blocks a bare `--force`, so
  use `--force-with-lease`.

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
