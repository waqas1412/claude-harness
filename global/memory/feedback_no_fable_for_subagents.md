---
name: feedback-no-fable-for-subagents
description: "Fable is the BRAIN only (plan, orchestrate, read outputs, decide); ALL actions including git/lint/build/test/edits are executed by delegated agents on non-Fable models"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 472e1a8f-d63e-4a7e-8ab6-c3652c37d3a6
---

Fable 5 is the orchestrator/brain ONLY. It plans, sequences, commands the work, reads the agents' outputs, and takes the decisions. It does NOT execute actions itself, and no spawned agent may run on Fable.

**Why:** Waqas directed this explicitly (2026-07-17, twice). First: never let agents/subagents inherit Fable. Then stronger: "even for tools commands like git, lint, build, test I don't want you to use fable... fable will be used to command all the action but action will be executed by models other than the fable." Fable is best at planning and deciding; execution belongs to other models.

**How to apply:**
- Main loop (Fable) MUST NOT run action tools directly: no Bash (git, lint, build, test, gh, shell), no Edit/Write to product code, no MCP write actions. Delegate every action to an agent with an explicit non-Fable model, then read its report and decide the next command.
- Model tiers for delegated agents: `opus` for hard reasoning (architecture, adversarial verify, correctness review), `sonnet` as the general executor default (edits, git ops, running verify loops), `haiku` for trivial mechanical sweeps. Never omit the model param and never pass `fable`.
- Workflow scripts: set `opts.model` on EVERY `agent()` call; the "omit to inherit" default is wrong because the parent is Fable.
- Mutating/verify work in one repo goes to ONE executor agent at a time (sequential), preserving the original no-contention rationale; read-only research/review agents still fan out concurrently.
- Fable perceiving is fine: Reading files/reports/tool results directly for context is not an "action". Writing to its own memory store is also fine.
- This SUPERSEDES the older "main loop owns edits/git/authoritative lint+test:build" clause in [[multi-agent-orchestration]] whenever the session runs on Fable. Verify-before-git-ops ([[feedback_verify_agents_before_git_ops]]) still applies; the executor agent runs the checks and Fable gates on the reported results before commanding commit/push.

**Grounding (2026-07-17, verified against official Anthropic sources; 5-reader + opus-synthesis workflow):**
- The topology is validated, not improvised: it matches Anthropic's brain/hands decoupling (engineering/managed-agents: the harness "brain" runs the loop and decides, sandboxed "hands" execute on demand) and their measured strong-lead pattern (multi-agent research system: Opus lead + Sonnet workers outperformed single-agent Opus by 90.2%; "upgrading the model is a larger gain than doubling the token budget"). Anthropic ALSO publishes the inverse Advisor/Escalation pattern (cheap executor in the main loop, stronger model consulted on demand via tool call; the platform managed-agents docs diagram Waqas shared 2026-07-17); that shape is for cost-efficient production agents, and since the Claude Code session model is Fable by Waqas's selection, the brain-loop shape is the correct adaptation here. Known cost: multi-agent burns ~3-15x tokens vs chat; accepted (rigor over speed).
- REPORT CONTRACT (the mechanism that makes a premium brain-in-loop affordable): every delegated agent returns a condensed digest (~1-2k tokens) with file:line pointers and exact key facts, NEVER raw build logs, full file dumps, or unabridged tool output back to Fable. Instruct this in every delegation prompt.
- LONG-HORIZON: persist plan/progress in external artifacts (git commits, progress/plan files, this memory store), not the context window; Anthropic: "compaction isn't sufficient". Fable's own memory writes are the sanctioned channel.
- Phrase roles TIER-AGNOSTICALLY (brain / executor / escalation / mechanical) so a model upgrade re-binds without rewriting rules. Current bindings: brain=Fable, executor=sonnet, escalation=opus, mechanical=haiku.
- Tier discriminators (make routing unambiguous): escalation(opus) = wrong-answer-is-expensive reasoning (adversarial verify, architecture calls, correctness review, security); executor(sonnet) = edits, git ops, verify runs, standard research/reads; mechanical(haiku) = batch sweeps, renames, formatting/log scans with a crisp pass/fail.
- STRICT BAR CONFIRMED (Waqas, 2026-07-17, after seeing the 3-15x cost analysis): NO zero-risk carve-out. Fable delegates literally every action, including one-line edits and read-only git commands. Do not re-raise the carve-out.
