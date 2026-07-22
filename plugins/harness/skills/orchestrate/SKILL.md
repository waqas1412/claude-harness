---
name: orchestrate
description: Run a substantial change through the standard multi-agent loop (PLAN gate, implement, VERIFY gate) using the read-only advisor agents in parallel, with a go/no-go before commit. Use for any non-trivial implementation, refactor, or review when you want the full advisor choreography instead of re-deciding it each turn. Not for trivial edits or pure Q&A.
argument-hint: "[short description of the change]"
allowed-tools: Read, Grep, Glob, Agent, Workflow
---

# /orchestrate: the standard multi-agent loop

A recipe, not an engine. It names which read-only advisors fire at each gate and which run in
parallel. The main loop is the brain: it plans, delegates, and gates. A single sequential executor
agent (model: sonnet, one per repo) applies edits and runs git and the authoritative lint/build/test,
returning condensed reports; the advisors only advise. Dispatch agents with the native Task tool,
concurrently within a gate. Scale the roster to the task: a one-file fix needs two advisors (one
PLAN, one VERIFY), a feature or multi-file change needs three to five relevant lenses per gate, a
cross-cutting or architecture change needs the full panel. Each parallel advisor is a full context
window, so only widen the roster when the added lens would plausibly change the go/no-go.

## Dispatch contract

Every agent dispatch carries five things: (1) Objective, the one question this lens answers for this
task; (2) Scope, the exact files or diff hunks in view plus the pinned baseline (plan, ticket, spec,
or design source); (3) Brief, the absolute path to the brief packet below; (4) Return format, the
condensed digest already defined in the working agreements (roughly 1-2k tokens, file:line pointers,
a verdict, never raw logs or full-file dumps); (5) Boundaries, what to ignore and which sibling owns
it. Underspecified dispatches produce duplicated or drifting findings.

## The brief packet (write once, before Gate 1)

Every agent starts cold and pays a full context entry cost, so any exploration it repeats is bought
twice. The main loop explores ONCE and writes the result to a brief in the scratchpad directory, e.g.
`<scratchpad>/BRIEF-<ticket>.md`. Every dispatch then names that absolute path, and the agents read
it instead of re-crawling the repo.

Facts only, never conclusions:

```markdown
# BRIEF: <ticket / change>
## Objective          one paragraph: what changes and why
## Baseline           ticket/spec/KB paths + the design node, pinned
## Files in play      path:line pointers, already located
## Diff               the actual diff (VERIFY gate only)
## Repo context       the ONE .claude/repo-index/<repo>.md that applies, plus AGENTS.md path
## Decisions settled  resolved choices, so nobody relitigates them
## Out of scope       explicitly excluded, with the owner
```

Withhold your own analysis. A reviewer handed your conclusions inherits your blind spots, and that
independence is the whole reason the lens exists. Handing over the diff and the file locations costs
nothing, because locating files was never where the review value came from. Refresh the brief with
the diff before Gate 2; do not write a second one.

## Gate 1: PLAN (before writing code)

Write the brief packet first, then dispatch in parallel the relevant subset, each dispatch naming the
brief path, then synthesize their outputs into one plan:
- `system-architect` placement, boundaries, blast radius, fit to repo patterns.
- `system-designer` exact signatures, shapes, and the edge-case matrix (once placement is set).
- `principles-engineer` reuse vs new code, right-sizing, guard against over-engineering.
- `design-principles-advisor` structural soundness (SOLID/GRASP/coupling) for larger designs.
- `docs-researcher` version-correct library usage when the change touches an external dependency.
- `spec-fidelity-auditor` pins the baseline (ticket/spec/KB, or the agreed plan when none exists),
  lints the acceptance criteria, and seeds the traceability matrix.
- `design-parity-auditor` pins the design source and produces the token bridge, state matrix, and
  breakpoint table, when the change implements a design file.
- `data-flow-timing-auditor` settlement contracts and gate design, when the feature has one-shot
  effects (analytics, seeds, redirects, caches, queue acks).

Output of this gate: a single agreed plan (placement, signatures, test plan, risks, surfaced
assumptions). Before locking the plan, list the assumptions the request leaves implicit (missing
flows, unspecified inputs, defaults being guessed) and resolve or flag each; a non-trivial plan that
names zero assumptions is under-examined. If the advisors disagree, resolve it in the plan before
coding. For an untested target, write characterization tests that pin current behavior and get them
green first.

## Implement (via the executor agent)

The main loop specifies the exact changes (files, edits, rationale), then dispatches ONE sequential
executor agent (model: sonnet) to apply them. The executor applies the edits and reports back the
diff; the main loop reviews the reported diff before proceeding. Keep each PR single-purpose and one
commit. Never run mutating agents in parallel in the same working dir; one executor at a time per repo.

## Gate 2: VERIFY (after the diff exists, before commit)

The executor runs the authoritative lint/build/change-related tests first for fast feedback and
reports the commands and results; `developer-reviewer` then re-runs those same commands itself in its
own context and pastes the raw output (exit codes, failing test names). Go/no-go gates on that
independent run, never on the executor's self-reported green. Refresh the brief with the diff, then
dispatch in parallel, each dispatch naming the brief path:
- `developer-reviewer` correctness, invariants, boundary/nil/ordering, test coverage red to green,
  AGENTS.md compliance. Adversarial: it tries to break the diff. Diff the test files: a deleted
  test, a newly added skip, or a loosened assertion used to reach green is a no-go finding, not a
  fix (tests are the referee; the diff may add tests but must not weaken or delete them). Skip
  explicitly when the diff touches no test files.
- `spec-fidelity-auditor` bidirectional trace against the ticket/spec/KB, or against the agreed
  Gate 1 plan when no external spec exists: every criterion delivered at its promised evidence
  grade, every hunk traced or dispositioned (gold plating, scope creep).
- `design-parity-auditor` parity against the pinned design source: token identity, layout semantics,
  state matrix, breakpoints, WCAG floors (UI changes; state Figma = N/A explicitly otherwise).
- `data-flow-timing-auditor` provenance audit of the diff's inputs: settlement, proxy gates,
  one-shot consumers, when the change reads cross-file state or fires one-shot effects.
- `performance-optimizer` complexity and allocation regressions, when the change is hot-path.
- `senior-software-engineer` idiom and construction self-check in the repo's language.
- Re-run the relevant Gate 1 advisor to confirm the implementation matched the agreed structure.

Each VERIFY finding is triaged: fix it, or record why it is acceptable. Lens verdicts must cite
concrete evidence (file:line or real output); right-size the panel for trivial diffs, with skips
declared explicitly, never silent. Gate the commit on an explicit go/no-go: do not commit with an
unresolved correctness finding. The fix-then-re-verify cycle is bounded: if VERIFY stays no-go after
two fix rounds on the same class of finding, stop, summarize the unresolved finding and what was
tried, and surface it to the user for a decision instead of iterating further.

## Commit

Only after VERIFY is go: dispatch the executor agent to re-check the diff against the repo's
AGENTS.md, run lint/build/tests fresh, state compliance, commit (single commit per PR), and open the
PR with the `/pr` skill. The main loop reviews the executor's report before treating the PR as done.

## Scope discipline

This is a prose choreography over native subagent dispatch. Do not build a coordinator, daemon,
message bus, or worktree fan-out. If a step would need machinery beyond dispatching agents and
reading their results, it does not belong here.
