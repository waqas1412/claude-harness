# Distill pipeline: rubric, skeptic prompt, dedup rule, proposal template

The verbose body of `/harness-distill`, opened on demand. Applied at run time as prose, not frozen
code, so it stays portable and expires gracefully as models self-reflect better. All proposed text
is em-dash-free; memory-fact proposals stay one fact per file.

## Extraction heuristics (Step 1)

From the bounded session slice and code-review corrections, a candidate learning looks like one of:
- An explicit correction: the user overrode or reversed something Claude did ("no, always X", "stop
  doing Y", a reverted edit, a rejected plan). Capture the correction and the wrong behavior it
  replaced.
- Recurring friction: the same class of mistake, retry, or clarification appears in two or more
  sessions (a command that keeps failing the same way, a convention repeatedly missed, a repeated
  question).
- A gotcha hit: a hard-won environment or repo trap discovered mid-task (a Windows PATH quirk, a
  flaky gate, a non-obvious build step).
- A successful ad hoc approach: a technique that worked well and would help again if it were written
  down.
Record for each candidate the raw signal plus its session evidence pointer (transcript path plus a
short quote, PR comment link, or file:line), so the skeptic can verify it later.

## Promote/reject rubric (Step 3)

Promote a candidate only if ALL hold:
- It recurs across two or more sessions, OR it is an explicit correction that would have prevented a
  real, concrete mistake.
- It is durable and reusable (true beyond this one task).
- It is not already captured in the memory store, CLAUDE.md, the repo, or git history.

Reject if ANY hold:
- It is a one-off with no recurrence and no tie to a concrete real mistake.
- It is transient task state (a TODO, a branch name, a passing test count).
- It restates a fact the repo, git history, or an existing rule already records.
- The skeptic cannot tie it to a specific real mistake or friction with cited evidence.

## Skeptic verifier prompt (Step 3, one per cluster, opus, adversarial)

> You are a skeptic. For this candidate learning, decide promote or reject. Ask: would this rule
> have prevented a real mistake in the cited sessions? Cite the specific session evidence
> (transcript path plus quote, PR comment, or file:line) for the mistake or the recurring friction.
> Reject if the candidate is a one-off, transient task state, or a fact the repo, git, CLAUDE.md, or
> an existing memory fact already records. Reject if you cannot tie it to a concrete real mistake.
> Prefer false negatives to false positives: when in doubt, reject. Return verdict plus a one-line
> rationale plus the evidence pointer.

## Dedup rule (Step 4)

Mirror the global CLAUDE.md Memory rule. Before proposing any new file:
- Grep the memory store (`~/.claude/memory/` and project `.claude/memory/`) and read `MEMORY.md`.
- If an existing fact covers the learning, propose an update-in-place to that file, never a
  duplicate.
- Only propose a new one-fact-per-file when nothing existing covers it, and include the matching
  one-line `MEMORY.md` index pointer in the proposal.

## Proposal template (Step 5, one per candidate)

```
### Proposal <n>: <short title>
- Destination: <exact installed file path, e.g. ~/.claude/memory/<slug>.md, ~/.claude/CLAUDE.md, or plugins/.../SKILL.md>
- Route: memory fact | CLAUDE.md rule line | skill Gotcha
- Scope: global | project
- Proposed text (verbatim, em-dash-free):
  <the exact line, fact body plus frontmatter, or Gotchas bullet to add>
- Evidence: <session transcript path plus quote / PR comment / file:line, one or more>
- Verdict: promote | reject, with the skeptic's one-line rationale
- Dedup note: <new file, or update-in-place of <existing path>, with the MEMORY.md pointer if a new fact>
```
