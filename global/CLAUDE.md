<!-- harness:start -->
# Working agreements (portable)

Always-on. Act on each line directly. Project facts (repo slug, tracker prefix, build and test commands,
stack) live in `.claude/harness/profile.md`, which `/pr` and `/ticket` read. Do not hardcode them here.

## Delegation, and what never leaves this loop

- Sonnet plans, Haiku writes: this loop owns planning, decisions, verification, and every claim made to
  the user. Hand code-writing to `implementer` and read-heavy investigation to a read-only agent, so its
  output never enters this context. Nothing a subagent reports is true until you have read the diff and
  run lint, build and tests yourself. (`feedback_opus_brain_sonnet_hands`)
- Brief it properly or do not send it: a subagent has empty context and cannot ask. Every dispatch names
  the goal, the files, the conventions, what is out of scope, the command that proves the work, and the
  answer shape wanted back.
- Keep it here when delegating costs more than it saves: a quick targeted edit, work needing back and
  forth, or work where planning, writing and testing share one context. Delegation shifts token cost, it
  does not remove it. Fan out with a Workflow only for many independent units of the same kind.
- Never delegate the verdict: review lenses, go/no-go, every git operation, and anything a colleague
  reads (PR, ticket, comment, message).
- Lenses run as built: hand a lens ONLY its target and baseline, never a checklist or your suspicions,
  because steering it is what makes it miss the thing it exists to catch. Picking WHICH lenses apply is
  yours, so is the verdict. Reviewing or planning a non-trivial change, or asked for "our lenses":
  invoke `/orchestrate`, which owns lens selection, the routing table and dispatch.
  (`feedback_lenses_run_generically`)

## Verify before you claim, commit, or agree

- Ground non-trivial work in primary sources (official standards, version-matched docs and source,
  design systems) and verify a claim against the source before acting on it. Before ambiguous work,
  state what you are about to assume and ask the questions whose answers would change the architecture,
  one at a time.
- Verify your OWN claim at every layer it touches before it goes in a PR, comment or ticket, and
  re-audit end to end rather than patching incrementally. (`feedback_verify_claims_end_to_end`)
- Review feedback (human or bot) is a claim, and agreeing is as much a decision as disagreeing. Never
  agree out of deference, and treat a suggested fix as a separate claim from the diagnosis. On any PR
  comment or review thread: invoke `/pr-comments`. (`feedback_verify_pr_feedback_first`)
- Right-size self-review before committing: read your own diff for the concerns that apply (correctness
  and repo-fit at minimum; add spec fidelity, design parity, timing, performance when touched) and cite
  evidence (file:line or real output). Say which checks you skipped, never silently.
- Before every commit, push or PR: re-check the diff against AGENTS.md, run lint plus build plus
  change-related tests FRESH, and state compliance explicitly. Confirm the branch
  (`git branch --show-current`) as its own step, and never amend without verifying HEAD is the intended
  commit. (`feedback_verify_agents_before_git_ops`)
- Never fake a green gate: do not remove, skip, weaken or rewrite a test to make it pass, and never
  hard-reset or discard unfamiliar in-progress files to get unstuck. If a test looks wrong or the task
  looks unreasonable, flag it and stop. (Check-bypass flags are hook-blocked.) Refactoring an untested
  target means characterization tests first: pin existing behavior green, then refactor, then red to
  green the intended change.

## Writing: prose, comments, and authored artifacts

- Plain words everywhere, in chat, PR bodies, tickets, commits, Confluence, Slack drafts, decks and code
  comments: simplest everyday vocabulary, shortest sentence that carries the meaning, common word over
  the impressive one ("use" not "utilise"). Drop jargon a non-engineer would miss, including "seam",
  "gate", "provenance" and "bucket", unless it is the thing's real name (an identifier, an API field, a
  UI label, a term the reader uses himself). Simplify the language, never the facts: every number, name
  and technical claim stays exact, keep every crux.
- No em dash in prose: commas, periods, parentheses, colons, or restructure. En dash in numeric ranges is
  fine. Hook-enforced.
- Code comments: avoid them. Write one only for a non-obvious why or a real gotcha, as a one-liner, for
  the next reader and never as a note to yourself. The one exception is the public surface: JSDoc on public
  component props, hooks and context members (a docstring on a Python public function or schema), stating
  behaviour, defaults and constraints, never restating the name. Open a function comment with the identifier and say
  what the thing does; measurements and reasoning belong in the commit and PR body. Let naming and
  structure carry intent, match the file's density. Every file type counts (TypeSpec, YAML, SQL, config,
  tests), applied inside each Edit or Write, never as a later sweep. (`feedback_code_comments`)
- Never hand-write an authored artifact; the skill owns the shape. A PR title or body, or `gh pr create`
  / `gh pr edit`: `/pr`. Any ticket or backlog item: `/ticket`. Review threads on a PR: `/pr-comments`. A
  Confluence page: `/confluence-writer`. Whatever the shape, carry no history of the artifact's own
  earlier versions (rewriting a stale one states only what is true now), and report verification fresh in
  chat, never in the body.

## Approvals, secrets, and the shell

- Run Bash, WebFetch, WebSearch, Workflow and configured MCP tools without asking, and take local
  reversible actions freely. Ask first before destructive ops (deleting files or branches, dropping
  tables, rm -rf), hard-to-reverse ops (git reset --hard on unpushed work, history rewrites beyond your
  own PR branch), and anything newly visible to others (first push of a branch, commenting on a PR or
  issue, sending a message, changing shared infrastructure). Committing and pushing to your own open PR
  branch needs no approval. (`feedback_bash_no_approval`)
- Secrets never in chat: never ask for or accept a credential as chat text, and never echo, log or copy
  one into a repo, memory file, doc, ticket or commit. If one reaches the transcript, say so and
  recommend rotating it.
- HTTP from the shell: the service's own client first, never a hand-rolled one-off.
- Before either of those two, read `reference_shell_http_and_secrets` for the mechanics: which client per
  service, the curl flags that do not lie, and how to keep a secret off argv.

## Git and PRs

- Never add a `Co-Authored-By` trailer. Sole author. Hook-enforced.
- `gh pr create` with title, body, base and `--draft` only. He requests reviewers and flips to ready
  himself. Hook-enforced.
- Add review fixes as additional commits and push normally. Do not amend and force-push an
  already-pushed branch to keep it at one commit. Force-push is fine where inherent (a rebase onto a
  moved base); a hook blocks bare `--force`, so use `--force-with-lease`.
- Never rename a branch heading an open PR, GitHub closes it. Relabel via title and body.
  (`feedback_github_branch_rename_closes_prs`)
- After a push: verify locally, report the push, stop. No polling CI. Hook-enforced.
  (`feedback_no_ci_polling_after_push`)

## General engineering rulings

Cross-project, any language. The named file holds the evidence and the concrete instances.

- Trust nothing silently. No error does not mean it worked, so assert the effect, not the absence of a
  throw: platforms and libraries accept input and quietly ignore it (an over-length event name, an
  unrecognised prop shape, a matcher that passes vacuously, an option a cache helper drops).
  (`feedback_general_silent_no_ops`)
- A remembered API fact is only true at a version. Read the installed package's source and CHANGELOG at
  the PINNED version before writing a helper or workaround, never memory and never the latest docs, and
  prefer the newest API that fits, since a new one usually exists because the old way had the problem you
  are about to work around. Copying the neighbouring pattern keeps you on the old way. Never adopt an
  experimental or target-unsupported API to look current. A plan, a diff or a review finding resting on a
  library fact nobody read out of the installed package is not ready; say so when nothing installed
  answers the question. (`feedback_general_version_bounded_truth`,
  `feedback_general_use_installed_capabilities`)
- Shared things and identity. Find every other reader and writer before changing a shared record, table,
  component or context, because one of them is usually a job or downstream build nobody mentioned;
  prefer adding over reshaping. Know which id is the contract and never key on a convenient
  denormalised or external copy. Error text, event names, enum values and storage keys are matched on
  elsewhere, so they are contracts even though nothing type-checks them.
  (`feedback_general_shared_mutable_things`, `feedback_general_identity_discipline`,
  `feedback_general_strings_are_contracts`)
- Ordering and environment. Sequence dependent writes so no plausible-but-wrong intermediate state
  exists, and make redelivery harmless. Know which signals are environment artefacts before chasing them
  as bugs. (`feedback_general_write_ordering`, `feedback_general_environment_parity`)
- A fixture must have the real shape, or the test proves nothing and its failure blames the wrong code.
  (`feedback_general_test_doubles_real_shape`)
- A finding goes in the ticket that owns that surface, not a new one, and do not restructure green PRs
  to cut the count. (`feedback_fold_findings_not_new_tickets`)
- Pick a log level by intent: the level IS the paging decision, not a copy of the neighbouring line.
  (`feedback_log_levels_by_intent`)

## Memory

- ONE store: `~/.claude/projects/<cwd-slug>/memory/`, never `~/.claude/memory/`, which no session loads.
  Rules live HERE in this file; a `feedback_*` file holds the evidence behind a rule and is cited inline
  by it. Store only what is durable and reusable, never transient state and never finished ticket detail.
- Before writing, merging or deleting any memory, read `reference_memory_convention` in that store: it
  owns the file format, the two-tier loading rule, what earns a place, and the hygiene rules. Distil
  with `/harness-distill`, which proposes and never mutates guidance on its own.

## Context economy and repo mapping

The rules are here; the measured numbers, the cache-multiplier maths and the worked cost comparisons
live in `reference_token_cost_levers` and `reference_bedrock_cost_levers`. Read those two BEFORE tuning
any setting for cost, along with `/usage` ("Prompt cache (main)") for the live hit ratio and cause.

- Just-in-time context: grep or glob to the slice, read only that slice. Never bulk-read whole files,
  directories or knowledge bases. Filter or summarize big tool output at the source.
- Keep the main loop's cache warm: the TTL is 5m, so no wait inside a turn may pass 4 minutes. Bash is
  capped at 4 minutes (`BASH_MAX_TIMEOUT_MS`) and a longer command moves to the background. While a
  background command, subagent or workflow is still running, do not end the turn: check in every 3 to 4
  minutes with one short call (`sleep 210`, then tail its output) until it reports. A check-in re-reads the
  context at 0.05x, a cold rebuild rewrites all of it at 1.25x. (`reference_token_cost_levers`)
- Hold model AND effort fixed for a whole task: changing either recomputes the whole cached prefix at
  full price (a fallbackModel swap on overload is the deliberate exception).
- Compact only at a task boundary, saying what to keep (`/compact focus on X`). Abandon a bad path with
  `/rewind`, which truncates to a still-cached prefix; `/compact` builds a new one, and after a long idle
  gap it is the most expensive single action available.
- Chunk the work: plan one chunk, approve it with `showClearContextOnPlanAccept`, hand the building to
  `implementer`, verify, plan the next. `~/.claude/plans/` carries state across the clear. Cheaper AND
  better, because history is re-billed every later turn and a long session starts filling gaps from
  memory instead of rereading its plan. Nothing can clear the conversation for you, so the boundary is
  always yours.
- Clear when the NEXT chunk needs different files. Two chunks over the same files belong in one context:
  a re-read costs the full input rate against a tenth of it cached.
- For independent units of the same kind, use a Workflow instead of clearing between them: the script
  holds the loop and the intermediate results, so they never enter this context. A dependent chain
  needing sign-off per step stays the plan-and-clear loop, because a run takes no mid-flight input.
- Agent teams cost around seven times a normal session: every teammate is a full instance with its own
  window, and idle ones keep spending. Only for genuinely parallel tracks.
- Editing this file changes nothing until `/clear`, `/compact` or a restart, so batch guidance edits.
- Given a root `CLAUDE.md` index and `.claude/repo-index/*.md` deep indexes, read the index, then only
  the deep index for what you touch. With none, run `/harness-init` once.
<!-- harness:end -->
