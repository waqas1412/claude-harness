---
name: orchestrate
description: Run a substantial change through the standard multi-agent loop (PLAN gate, implement, VERIFY gate) using the read-only advisor agents in parallel, with a go/no-go before commit. Use for any non-trivial implementation, refactor, or review when you want the full advisor choreography instead of re-deciding it each turn. Not for trivial edits or pure Q&A.
argument-hint: "[short description of the change]"
allowed-tools: Read, Grep, Glob, Bash
---

# /orchestrate: the standard multi-agent loop

A recipe, not an engine. It names which read-only advisors fire at each gate and which run in
parallel. The main loop owns all edits, git, and the authoritative lint/build/test; the advisors
only advise. Dispatch agents with the native Task tool, concurrently within a gate. Scale the roster
to the task: a one-file fix needs two advisors, a cross-cutting change needs the full panel.

## Gate 1: PLAN (before writing code)

Dispatch in parallel the relevant subset, then synthesize their outputs into one plan:
- `system-architect` placement, boundaries, blast radius, fit to repo patterns.
- `system-designer` exact signatures, shapes, and the edge-case matrix (once placement is set).
- `principles-engineer` reuse vs new code, right-sizing, guard against over-engineering.
- `design-principles-advisor` structural soundness (SOLID/GRASP/coupling) for larger designs.
- `docs-researcher` version-correct library usage when the change touches an external dependency.
- `spec-fidelity-auditor` pins the spec baseline, lints the acceptance criteria, and seeds the
  traceability matrix, when the change has a ticket/spec/KB.
- `design-parity-auditor` pins the design source and produces the token bridge, state matrix, and
  breakpoint table, when the change implements a design file.
- `data-flow-timing-auditor` settlement contracts and gate design, when the feature has one-shot
  effects (analytics, seeds, redirects, caches, queue acks).

Output of this gate: a single agreed plan (placement, signatures, test plan, risks). If the advisors
disagree, resolve it in the plan before coding. For an untested target, write characterization tests
that pin current behavior and get them green first.

## Implement (main loop only)

Apply the edits yourself. Keep each PR single-purpose and one commit. Do not dispatch agents to edit.

## Gate 2: VERIFY (after the diff exists, before commit)

Run the authoritative lint/build/change-related tests yourself first, then dispatch in parallel:
- `developer-reviewer` correctness, invariants, boundary/nil/ordering, test coverage red to green,
  AGENTS.md compliance. Adversarial: it tries to break the diff.
- `spec-fidelity-auditor` bidirectional trace against the ticket/spec/KB: every criterion delivered
  at its promised evidence grade, every hunk traced or dispositioned (gold plating, scope creep).
- `design-parity-auditor` parity against the pinned design source: token identity, layout semantics,
  state matrix, breakpoints, WCAG floors (UI changes; state Figma = N/A explicitly otherwise).
- `data-flow-timing-auditor` provenance audit of the diff's inputs: settlement, proxy gates,
  one-shot consumers, when the change reads cross-file state or fires one-shot effects.
- `performance-optimizer` complexity and allocation regressions, when the change is hot-path.
- `senior-software-engineer` idiom and construction self-check in the repo's language.
- Re-run the relevant Gate 1 advisor to confirm the implementation matched the agreed structure.

Each VERIFY finding is triaged: fix it, or record why it is acceptable. Gate the commit on an
explicit go/no-go: do not commit with an unresolved correctness finding.

## Commit

Only after VERIFY is go: re-check the diff against the repo's AGENTS.md, run lint/build/tests fresh,
state compliance, then commit (single commit per PR) and open the PR with the `/pr` skill.

## Scope discipline

This is a prose choreography over native subagent dispatch. Do not build a coordinator, daemon,
message bus, or worktree fan-out. If a step would need machinery beyond dispatching agents and
reading their results, it does not belong here.
