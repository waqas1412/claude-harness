---
name: harness-distill
description: Distill durable learnings from recent sessions and code-review corrections into proposed memory facts, CLAUDE.md rule lines, or skill Gotchas. Use periodically, or after a run that surfaced recurring friction, corrections you keep repeating, or a gotcha worth capturing. It clusters candidates, adversarially verifies each with a skeptic, dedups against the memory store, and proposes edits for your approval. Not for one-off task notes or anything git, the repo, or CLAUDE.md already records; use the memory convention directly for a single known fact.
argument-hint: "[optional: session count or scope to widen the default slice]"
allowed-tools: Read, Grep, Glob, Bash, Agent, Workflow
---

# /harness-distill: mine sessions into verified learning proposals

A recipe, not an engine. It closes the harness's one-directional gap: learnings from real sessions
are otherwise captured only by hand. It carries no `Write`/`Edit` tool, so it is structurally
propose-only: the brain plans and delegates, read-only advisors fan out, and every survivor is
emitted as a proposal for your approval, never a silent mutation. On-demand only; there is no
scheduler. The verbose rubric, skeptic prompt, dedup rule, and proposal template live in
`references/distill-pipeline.md`, opened when a step needs them.

## Scope discipline

This is a prose choreography over native subagent dispatch, like `/orchestrate`. Do not build a
coordinator, daemon, message bus, or scheduler. Default to a tight bounded slice (the current
session plus a small recent window for this repo) because mining transcripts is token-heavy; the
user can widen via the argument. Pin models explicitly and do not over-tier: haiku for batch
extraction, sonnet for clustering, opus for the skeptic pass. No fable.

## Step 1: Scope and gather (read-only)

Default slice: the current session plus a small recent window of this repo's transcripts at
`~/.claude/projects/<slug>/*.jsonl`, plus code-review corrections (prior `/code-review` output and
`gh pr` review comments). If those transcripts are absent (a fresh install), say so and stop; there
is nothing to distill. Extract candidate signals with `Bash` plus `jq` over the slice; reserve a
mechanical-tier haiku agent per session only for a large batch. Candidate signals: explicit user
corrections, repeated friction, gotchas hit, and successful ad hoc approaches. See the extraction
heuristics in `references/distill-pipeline.md`.

## Step 2: Cluster (sonnet, parallel)

Fan out sonnet agents to group the raw candidates by theme in one pass. Recurrence across two or
more sessions is the signal; a one-off is noise and drops out here.

## Step 3: Adversarially verify (opus skeptic, one per cluster)

Dispatch one opus skeptic verifier per surviving cluster (those recurring across 2+ sessions). Each
asks "would this rule have prevented a real mistake?" and must cite session evidence. Promote only
durable, reusable learnings; reject task-specific noise, transient state, and anything git, the
repo, or CLAUDE.md already records. This is the false-positive filter. The skeptic prompt and the
promote/reject rubric are in `references/distill-pipeline.md`.

## Step 4: Dedup and route (per survivor)

Grep the memory store (`~/.claude/memory/` and any project `.claude/memory/`) plus `MEMORY.md`
first; if a fact already covers it, propose an update-in-place, never a duplicate file. Route each
survivor:
- a durable fact, correction, decision, gotcha, or stable preference to a memory fact (one per
  file, correct `metadata.type`);
- a rule Claude keeps missing that must be always-on to a CLAUDE.md rule line (portable rules to
  the user-global CLAUDE.md, project rules to the project CLAUDE.md or profile, never crossing
  scope);
- a skill-specific failure mode to a `## Gotchas` bullet in that `SKILL.md`.

Proposals target the user's INSTALLED `~/.claude` files and memory store (and project files), never
the distributable `global/` source, except when the user is explicitly improving the harness itself.

## Step 5: Propose, do not mutate

Emit one proposal per candidate using the template in `references/distill-pipeline.md`: destination
file, proposed exact text (em-dash-free, memory facts one-per-file), session evidence pointers,
promote/reject rationale, dedup note, and scope (global | project). On your approval, memory facts
are written by the brain and CLAUDE.md or skill-Gotchas edits go through the normal approved-edit
path. The skill itself writes nothing.

## Gotchas

- Mining many sessions is token-heavy: default to the bounded slice (current plus a small recent
  window) and only widen when the user asks.
- Never promote a project-specific learning into the portable global CLAUDE.md; keep portable and
  project scope separate, and target installed files, not the shipped `global/` source.
- Transcripts may be absent on a fresh install: report it and stop cleanly rather than fabricating
  candidates.
- Recurrence is the promote signal: a one-off, however sharp, is noise unless the skeptic ties it to
  a concrete real mistake.
- If a routed learning targets a skill lacking a `## Gotchas` section, propose adding the section
  rather than skipping the learning.
