---
name: orchestrate
description: Apply the review lenses yourself, in the solo main loop, with no subagent dispatch. Pick only the lenses the change actually touches, run each as a checklist against real code and real command output, and gate go/no-go on cited evidence. Use when asked to run, use, or review with "our lenses", or to plan or verify a non-trivial change. No executor split, no parallel advisors, no model pinning.
argument-hint: "[short description of the change, or a PR number to review]"
allowed-tools: Read, Grep, Glob, Bash
---

# /orchestrate: run the lenses in one loop

The lenses are checklists, not agents. This skill names which ones apply to a given change, what each
one asks, and what evidence closes it. You apply them yourself in this loop: you plan, you read, you
edit, you run lint and build and tests, and you review your own diff before committing.

## How this works: one loop, no dispatch

The 16 files in `~/.claude/agents/*.md` are the lens CONTENT. When a checklist below is not enough
detail for the change in front of you, Read the matching file and use its rubric. They are reference
documents here, never dispatch targets. Do not spawn a subagent or author a workflow to run a lens
unless the user asks for that in the moment.

Every verdict follows one shape: read `references/findings-contract.md` before reporting anything. It
defines the precision-versus-recall dial, the required `failure_scenario`, the three-way verdict, the
report cap, and the disclosure rule. It is the same contract Claude Code's own `code-review` uses.

## Pick the lenses, then say which you skipped

Right-size to the change:

- One-file fix: correctness and repo-fit only.
- Feature or multi-file change: add the two or three lenses the change actually touches.
- Cross-cutting, shared-seam, or architecture change: the full panel.

Declare skips out loud ("no design parity: this diff has no UI"). A silent skip reads as a pass.

## Set the dial: precision or recall

Decide before you start, and say which. Getting it backwards fails in both directions.

- **Precision** (default; a small diff, a nit pass, anything about to go to a reviewer): only findings a
  maintainer would act on. Cap at `min(files_changed, 4)`. A repo-wide sweep prompted by a
  diff-scoped nit is this dial set wrong.
- **Recall** (an audit, a large or risky change, or when asked to be thorough): catch every real bug a
  careful reviewer would catch in one sitting. Real bugs matter more than false positives here, so err
  on the side of surfacing.

## Pin the baseline before judging

Name the thing the diff is answerable to: the ticket, the spec or KB path, the design node, or, when
there is no external spec, the plan agreed in this conversation. Judging a diff against nothing is how
gold plating and scope creep survive review.

## PLAN lenses (before writing code)

Run only the relevant ones. Lens file in parentheses.

- Placement and blast radius: where the code belongs, module boundaries, what else it touches, fit to
  existing repo patterns (`system-architect.md`).
- Exact shapes: function and query signatures, request and response shapes, the edge-case matrix,
  once placement is settled (`system-designer.md`).
- Reuse and right-sizing: what to factor out versus leave alone, and an explicit guard against
  premature abstraction (`principles-engineer.md`).
- Structural soundness: coupling, cohesion, SOLID and GRASP, on larger designs only
  (`design-principles-advisor.md`).
- Version-correct library usage: check the version actually installed in `node_modules` or `go.mod`,
  and the version-matched official docs, before using an API (`docs-researcher.md`).
- Spec baseline: pin it, lint the acceptance criteria, seed the traceability matrix
  (`spec-fidelity-auditor.md`).
- Design source: pin the file and node, build the token bridge, the state matrix, and the breakpoint
  table, when the change implements a design (`design-parity-auditor.md`).
- Settlement and one-shot effects: when the feature fires analytics, seeds, redirects, caches, or
  queue acks off eventually-consistent state (`data-flow-timing-auditor.md`).
- Threat surface: which new inputs cross a trust boundary, which authorization decision is made and
  where, and what the unsafe-by-default version of this design would be (`security-auditor.md`).
- Accessibility contract: the keyboard path, what takes focus on open and where it returns, how every
  control gets its name, which native element carries the semantics (`accessibility-auditor.md`).
- Compatibility budget: who consumes what this will change, whether it can be done additively, and the
  migration and deploy ordering (`compatibility-auditor.md`).

Close the gate with a plan that states placement, signatures, the test plan, the risks, and the
assumptions the request left implicit. A non-trivial plan naming zero assumptions is under-examined.
For an untested target, write characterization tests that pin current behavior and get them green
before changing anything.

## VERIFY lenses (after the diff exists, before commit)

- Correctness, adversarially: try to break your own diff. Boundaries, nil and empty, collection
  ordering, timezones, invariants, contracts (`developer-reviewer.md`).
- Test-diff integrity: diff the test files. A deleted test, a new skip, or a loosened assertion used
  to reach green is a no-go finding, not a fix. Tests are the referee.
- Spec trace, both ways: every criterion delivered at its promised evidence grade, and every diff hunk
  traced to a spec clause or dispositioned as gold plating or scope creep
  (`spec-fidelity-auditor.md`).
- Design parity: token identity before resolved values, layout as auto-layout semantics, the state
  matrix, exact breakpoint boundaries, WCAG floors. State "Figma N/A" explicitly when there is no
  design (`design-parity-auditor.md`).
- Data flow and timing: provenance of every input the diff reads, when it crosses files or fires
  one-shot effects (`data-flow-timing-auditor.md`).
- Performance: only when the change is on a hot path (`performance-optimizer.md`).
- Idiom and repo compliance: the repo's own conventions and its AGENTS.md
  (`senior-software-engineer.md`).
- Security: authorization and tenant scoping, token and secret handling, sensitive data reaching logs
  or analytics, injection at real boundaries, fail-open defaults (`security-auditor.md`).
- Accessibility: keyboard path, focus management and visibility, accessible names, semantics, dialog
  behaviour, async announcement, reflow (`accessibility-auditor.md`). Read the component library's
  installed source before ruling: most of this is already handled for you.
- Compatibility: sweep outward to every consumer of what changed, then rule on whether the PR's
  breaking-change assertion is true (`compatibility-auditor.md`). A wrong "None" is a blocker.
- Re-check the implementation against the structure agreed at PLAN.

### Cleanup angles

The angles above hunt for defects. These four hunt for cleanup, in the changed code only, and are
pooled separately so they never crowd out a real bug:

- **Reuse**: something already exists that this reimplements (`principles-engineer.md`).
- **Simplification**: the same behaviour with less code or fewer branches.
- **Efficiency**: obviously wasteful work on a path that matters (`performance-optimizer.md`).
- **Altitude**: is this code at the right level of abstraction for where it sits? A detail leaking into a
  layer that should not know it, or a wrapper that adds a name and nothing else.

Cleanup findings are always precision-dialled, whatever the main dial is set to. Nobody thanks you for
four nits attached to a bug report.

## Evidence rules

Every verdict cites `file:line` or real pasted command output (exit codes, failing test names), AND a
concrete `failure_scenario`: the specific state that produces the specific wrong result. A `file:line`
proves the code exists, not that it is wrong. If you cannot write the failure scenario, you have a
suspicion, not a finding: drop it or downgrade it to a note.

Verify each candidate against itself and return one of **CONFIRMED**, **PLAUSIBLE**, or **REFUTED**.
Keep the first two, naming what is unproven on a PLAUSIBLE. Drop REFUTED, naming what refutes it.

Run lint, build, and the change-related tests yourself, fresh, and gate on that output. Never accept or
report a self-described green.

When the `ReportFindings` tool is available, call it once with `{level, findings}` and do not also print
the findings as prose. Otherwise use the same field shape in a table.

## Disclose what actually ran

Close every review by stating which lenses ran, which you skipped and why, which dial you used, and that
this was a single solo pass rather than independent per-lens passes. Say it even when the findings are
good, so nobody reading the report is misled about its coverage. An empty report is a valid result:
never pad one to look thorough.

At xhigh or max effort, add one gap pass after the report is drafted, hunting only for what is missing:
a lens that should have applied and did not, a claim asserted but never verified, a file in the diff
that no finding or disposition touched.

## Go and no-go, bounded

Triage each finding: fix it, or record why it is acceptable. Do not commit with an unresolved
correctness finding. The fix-then-re-verify cycle is bounded: if the same class of finding is still
no-go after two rounds, stop, summarize what was tried, and surface it for a decision instead of
iterating.

Confirm `git branch --show-current` as its own step before any commit or amend. Then commit (one
commit per PR) and, only when asked, open the PR with `/pr` as a draft.

## Gotchas

- No dispatch, no choreography, no coordinator, no worktree fan-out, no per-agent model pinning. The
  reversal is deliberate: a brain-and-hands split caused real mistakes (2026-07-24). See the
  single-main-loop memory fact.
- The `model:` fields were removed from the agent files on 2026-07-26. If you ever do dispatch a lens
  because the user asked, it inherits the session model.
- A lens with nothing to say is a skip you declare, not a section you pad.
- Reading the lens file is cheap and reading the wrong lens is waste: pick from the change, not from
  the list length.
