---
name: workspace-init
description: Scan a multi-repo workspace root (a directory whose children are independent git repos) and generate a workspace navigation harness: a catalog CLAUDE.md router, per-repo .claude/rules/<repo>.md deep indexes with auto-load wiring, .claude/meta/navigation.md, and a .claude/harness/seams/ cluster config ready for refresh-seams. Complements single-repo harness-init, never replaces it. Use to bootstrap or refresh a workspace of repos, or when asked to "harness this workspace", index a monorepo-of-repos, or set up a workspace router.
argument-hint: "[--refresh] [optional: scope, e.g. one category or a subset of repo names]"
allowed-tools: Read, Grep, Glob, Agent, Workflow
---

# /workspace-init: harness a multi-repo workspace

Bootstrap or refresh navigation for a workspace ROOT whose immediate children are independent git repositories. This skill is a recipe, not an engine: the main loop plans, delegates, and gates. Read-only scan agents fan out concurrently; exactly one sequential executor agent per repo writes files. Do not build a coordinator, daemon, message bus, or worktree fan-out.

This skill produces WORKSPACE-LEVEL artifacts. It complements the single-repo `harness-init` skill, which produces REPO-LEVEL artifacts inside one repo. Where a child repo already has its own `AGENTS.md`/`CLAUDE.md`, treat that as authoritative for the repo and only summarize it here; never overwrite a repo's internal files.

## Arguments
- No arg: full workspace scan and generation.
- `--refresh`: regenerate all workspace artifacts from a fresh scan; preserve any hand edits outside generated markers (see Phase 6).
- A trailing scope string (e.g. a category name or a space-separated subset of repo slugs): limit deep-index (re)generation to those repos only; the root CLAUDE.md catalog is always regenerated in full so the router stays complete.

## Artifacts written
- `CLAUDE.md` (workspace root) from this skill's `assets/workspace-CLAUDE.md.tmpl`.
- `.claude/rules/<repo>.md` per child repo (deep index, with auto-load frontmatter) from this skill's `assets/rule.md.tmpl`.
- `.claude/meta/navigation.md` from this skill's `assets/navigation.md.tmpl`.
- `.claude/harness/seams/clusters.json` (cluster + hunter config parameter file for refresh-seams).

## Template resolution
This skill ships its own template copies under its `assets/` directory (`workspace-CLAUDE.md.tmpl`, `rule.md.tmpl`, `navigation.md.tmpl`) so it is self-contained; resolve each by name relative to this skill's own directory. A workspace-local copy always wins: if `.claude/harness/templates/<name>.tmpl` already exists in the target workspace, read that instead of the bundled one (same copy-wins convention `refresh-seams` uses for its own assets).

## Phase 1: enumerate and pre-classify (main loop, fast)
Use Glob/Bash-free discovery: `Glob` for `*/` at the root, then for each child read only its top-level markers (`README*`, `package.json`, `go.mod`, `pyproject.toml`, `Cargo.toml`, `*.csproj`, `CMakeLists.txt`, `west.yml`, `.gitmodules`, `cdk.json`, an `AGENTS.md`/`CLAUDE.md` if present). Record for each repo: slug (dir name), primary stack, a coarse platform group, and vendored/placeholder/deprecated flags. Skip non-repo dirs (no VCS metadata, pure datasets, caches); list them for the "Not indexed" line. Keep this to a shallow read; the deep work is delegated.

## Phase 2: parallel deep scan (delegate, read-only)
Dispatch one read-only scan agent per repo, concurrently within this gate, using the Agent tool.
- Model: `sonnet` for each scan agent (one per repo). Use `haiku` only for a trivial repo (placeholder, near-empty, or a vendored fork you will black-box).
- Each agent is instructed: do not recurse vendored/huge trees; for a vendored fork return only a black-box summary (what it is, upstream, where fork-local deltas would live) plus the consumer-side integration points. Return a CONDENSED digest, not a file dump.
- Digest contract per repo: `{ slug, one_liner, category, stack, coreLogic[], stateData[], entrypoints[], riskZones[], strictPatterns[], verify{test,lint,build,e2e}, docs[], trackerPrefix?, flags[] }`. Every path an agent cites must be one it actually read.
- Record low-confidence inferences explicitly in an `ASSUMPTIONS` list on the digest rather than guessing silently.

Collect digests. Do not proceed until every in-scope repo has returned one.

## Phase 3: derive the cluster config (main loop, judgment)
From the digests, group repos into platform clusters by detected stack/platform (for example a services-and-web cluster versus a firmware-and-device cluster; name them for the platforms present, not for any product). Write `.claude/harness/seams/clusters.json`:
```
{
  "root": "<absolute workspace root>",
  "clusters": { "<clusterA>": ["repoSlug", ...], "<clusterB>": [ ... ] },
  "vendored": ["repoSlug", ...],
  "excludes": ["node_modules", ".git", "dist", "build", "target", ".venv", "__pycache__", "cdk.out"],
  "rulesFileConvention": ".claude/rules/<repo>.md",
  "trackerPrefixes": { "<PREFIX>": "<domain>" }
}
```
This file is the single parameter source refresh-seams reads later. If a run is judgment-heavy (ambiguous cluster boundaries, many bridge repos), consult one `opus` advisor agent for the cluster taxonomy only; otherwise the main loop decides. Membership is derived FROM the catalog, never hardcoded.

## Phase 4: write per-repo deep indexes (delegate, one executor per repo)
For each in-scope repo, dispatch ONE sequential executor agent (`model: sonnet`) that writes `.claude/rules/<repo>.md` from this skill's `assets/rule.md.tmpl` (or its workspace-local override, see Template resolution), filled from that repo's digest. The file MUST open with bare YAML frontmatter starting at byte 0, no HTML-comment wrapper (this is the only wiring; there is no central registry):
```
---
id: <repo>-deep-index
targets:
  - "<repo>/**/*"
---
```
Body follows the four-section template: Domain Component Mapping (Core Logic / State-Data Layer / Entrypoints and Triggers), Local Architecture Gotchas (Risk Zones / Strict Patterns), Local Verification Loop (Test/Lint/Build/E2E, empty string when N/A), Documentation Map (real docs plus an "ignore generated X" line). Vendored forks get a black-box rule block instead of a deep body. Do NOT add a `## Cross-repo seams` section here; refresh-seams owns that between its own markers.

Executors run one repo at a time (sequential) so file writes never collide; the scan fan-out in Phase 2 was the only concurrent step.

## Phase 5: write the workspace router and navigation (delegate, single executor)
Dispatch one executor agent (`model: sonnet`) to write:
- `CLAUDE.md` from this skill's `assets/workspace-CLAUDE.md.tmpl` (or its workspace-local override): Section 1 System Topology (core daily-drivers callout plus full catalog grouped by category header, one bold-name bullet and one sentence each, vendored tagged, trailing Not-indexed line); Section 2 Structural Routing Triggers (topic to path, daily-drivers only); Section 3 Search and Grep Optimization (file patterns, legacy dirs, deny rules, never-grep-recurse list, non-code zones); Section 4 Deep Index Pointers (the `.claude/rules/<repo>.md` convention, auto-load note, tracker-prefix table); Section 5 Deeper navigation (pointers only).
- `.claude/meta/navigation.md` from this skill's `assets/navigation.md.tmpl` (or its workspace-local override): Doc Map, Agent Instruction Hierarchy (global to workspace to repo to subscope to task-prompt, narrower wins), and a Key skills line that names `workspace-init` and `refresh-seams`.

Keep catalog one-liners to a single sentence each; favor density over prose.

## Phase 6: idempotent refresh
On `--refresh`, regenerate all artifacts but preserve human content: the root CLAUDE.md and navigation.md are fully regenerated (they are ours); per-repo rules files are regenerated body-and-frontmatter, but if refresh-seams has already written a `## Cross-repo seams` section between `<!-- seams:start -->` / `<!-- seams:end -->`, leave that block verbatim. Never touch a child repo's own `AGENTS.md`/`CLAUDE.md`.

## Phase 7: self-verify gate (haiku sweep + main-loop check)
Delegate a mechanical `haiku` agent to run the SAME deterministic core `harness-init` bundles, `plugins/harness/skills/harness-init/assets/verify-generated.sh` (reference it, never ship a second copy, a duplicate re-introduces the drift the shared script removes), over `CLAUDE.md`, `.claude/meta/navigation.md`, and each `.claude/rules/<repo>.md`: it test-e's every backtick path, sweeps for the em-dash U+2014, and checks harness-marker balance, printing a `RESULT` line. On top of the script's output, the agent still confirms in prose that every generated rules file has valid frontmatter and that its `targets` glob starts with its own slug (a judgment check the script does not make). The main loop fixes or drops anything flagged before reporting. Then remind the user that `refresh-seams` can now build the cross-repo integration map from the cluster config just written.

## Report
List repos cataloged (by category), deep indexes written, the derived clusters and their members, non-indexed dirs, any recorded ASSUMPTIONS, and any self-verify fixes.

## Scope discipline
Ask the user only when a decision is genuinely blocking (for example the workspace root is ambiguous or a "repo" is actually a submodule host). Otherwise infer and proceed, recording uncertainty. A tiny workspace (a handful of repos) needs only the scan-and-write path; do not spin up advisor panels or the opus taxonomy step unless cluster boundaries are genuinely unclear.

## Gotchas
- A Phase 2 scan agent recursing into a vendored/forked repo's full source instead of returning a black-box summary; it burns the scan budget and pastes upstream code into the digest.
- A per-repo deep index whose `targets` glob does not start with its own repo slug, so it silently matches nothing (or the wrong repo) on auto-load.
- Regenerating a per-repo rules file on `--refresh` and clobbering an existing `## Cross-repo seams` block instead of preserving it between its `<!-- seams:start -->`/`<!-- seams:end -->` markers.
- Spinning up the opus cluster-taxonomy step or a full advisor panel for a two- or three-repo workspace when the boundaries are already obvious from the Phase 1 catalog.
