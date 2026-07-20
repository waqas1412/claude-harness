---
name: refresh-seams
description: Rebuild the cross-repo integration map for a multi-repo workspace. Runs evidence-based seam discovery (parallel hunter agents scoped by the workspace cluster config), reconciles and verifies every edge by file:line proof, then regenerates .claude/meta/seams.json, each connected repo's "## Cross-repo seams" section, and .claude/meta/integration-map.md with feature-flow playbooks. Cluster names, hunter set, and repo lists come from .claude/harness/seams/clusters.json (written by workspace-init), never hardcoded. Use after changes that add or remove cross-repo dependencies, or when the seam map is stale. Scope-limit with an argument.
argument-hint: "[optional scope, e.g. one cluster name or a subset of repo/edge kinds]"
allowed-tools: Read, Grep, Glob, Agent, Workflow
disable-model-invocation: true
---

# /refresh-seams: rebuild the workspace integration map

Discover, verify, and draw the cross-repo dependency graph. This skill never edits product code; it is grep-based evidence discovery plus mechanical verification plus map authoring. It is choreography: the main loop plans and delegates, hunter scan agents fan out concurrently, mechanical steps run as delegated helpers, and one strong agent redraws the map at the end. Do not build a coordinator or daemon.

## Prerequisites and parameters
Read `.claude/harness/seams/clusters.json` (produced by `workspace-init`). It supplies: workspace `root`, the `clusters` map (name to repo-slug list), the `vendored` black-box set, `excludes`, the `rulesFileConvention`, and `trackerPrefixes`. Everything workspace-specific comes from this file; nothing about clusters, repo names, or hunter counts is hardcoded in this skill.

On first run, scaffold the pipeline assets from this skill's bundled `assets/` into the workspace, but only if they are missing:
- `assets/discover.workflow.js` to `.claude/harness/seams/discover.workflow.js`
- `assets/build.py` to `.claude/harness/seams/build.py`
- `assets/cartographer-prompt.md` to `.claude/harness/seams/cartographer-prompt.md`
- `assets/verify-map.sh` to `.claude/harness/seams/verify-map.sh`
A workspace-local copy ALWAYS wins over the bundled one: if `.claude/harness/seams/discover.workflow.js` already exists, use it as-is. This lets a workspace tune hunters, kinds, or budgets without editing the shared plugin. (Directory-scoped skill precedence separately lets a workspace ship its own `refresh-seams` skill that shadows this one; see MANIFEST.)

## Scope argument
If given a scope (a cluster name, a subset of repo slugs, or a subset of hunter keys), pass it through as `args.scope` alongside `args.config` on the `Workflow` call in Phase 2 (`Workflow(scriptPath, { args: { config, scope } })`); `discover.workflow.js` reads both off the `args` global and filters both the hunter list and the flat cluster union down to the matching names before running discovery, then reconcile only those edges and merge into the existing `seams.json` rather than replacing untouched clusters. With no scope, pass only `args: { config }` and do a full rebuild (idempotent given the same code state).

## Phase 1: derive the hunter set (main loop)
The workflow defines hunters per CONNECTION MECHANISM, not per repo pair. Build the active `HUNTERS` list from the cluster config: each hunter is `{ key, effort, mechanism, guidance, kind }` where `kind` is the edge tag it emits. Seed the hunter set from the mechanisms present in the workspace's stacks (for example: package/library imports, HTTP or REST contracts, schema/IPC contracts, message queues, shared datastores, manifest or submodule pins, device or hardware flashing). Count and effort scale to workspace size and budget; a small workspace needs a handful of hunters, a large one more. Never emit more hunter definitions than mechanisms you can justify from the catalog.

## Phase 2: discover (delegate, parallel, read-only)
The `discover.workflow.js` sandbox runs plain JS with no filesystem or Node.js API access, so it cannot read `clusters.json` itself. The main loop (or a delegated `haiku` helper) first Reads `.claude/harness/seams/clusters.json` and parses it into a plain object, then runs the workflow with that object as `args.config` (plus `args.scope` for a scoped run, see Scope argument): `Workflow('.claude/harness/seams/discover.workflow.js', { args: { config, scope } })`. The workflow runs every hunter in `parallel()`, each as a read-only `agent()` call, and RETURNS the array of hunter results directly, since the sandbox has no way to write a file itself:
- Model: each hunter agent's model is pinned by its own `effort`, not chosen ad hoc: a `low`-effort (purely mechanical, single-grep) hunter runs `haiku`; every other hunter runs `sonnet` (evidence grep plus judgment on proof lines). The mapping lives in `discover.workflow.js`.
- Each hunter prompt is built from a shared `base()` template: workspace root, the full flat cluster list, its own mechanism plus guidance, grep and exclude rules, and the vendored-repo rule (find the consumer-side reference only, never recurse a vendored base repo).
- Each hunter returns schema-validated edges `{ from, fromRef, to, toRef, kind, direction, detail, proof, confidence }`; `to` may be `ext:<name>` for an external system, with empty `toRef`.
As soon as `Workflow` returns, delegate a lightweight `haiku` executor agent (it has Write access; this skill's own tools stay read-only plus Agent/Workflow) to persist that array verbatim to `.claude/harness/seams/journal.jsonl`, one hunter-result object per line (each line already shaped `{ hunter, edges, notes }`). That shape satisfies `build.py`'s per-line `"edges" in rec` branch as-is, so `build.py` needs no change to consume it. For a scoped run you may write multiple journal files and pass them all to Phase 3.

## Phase 3: reconcile, verify, emit (delegate mechanical)
Invoke `SEAMS_DATE=<date> SEAMS_ROOT=<root> python3 .claude/harness/seams/build.py .claude/harness/seams/journal.jsonl [more journals...]`. It:
- loads all edges, normalizes and repairs refs (unique-basename search within the named repo, skipping vendored and standard build dirs),
- verifies each edge: an edge survives only if a cited file exists AND (the `proof` literal matches somewhere in either side's file text, OR both sides' files exist); tags `verify: verified` or `files-ok`; drops the rest,
- tags `cluster` via the kind-to-cluster map derived from clusters.json (a kind whose emitting hunter belongs to one cluster maps there; cross-cluster kinds map to `bridge`),
- dedupes on `(from,to,kind,detail-prefix)`, sorts by `KIND_ORDER` then from/to,
- writes `.claude/meta/seams.json` (schema below), `.claude/harness/seams/adjacency.txt` (per-repo OUT/IN listing), and rewrites each connected repo's `## Cross-repo seams` section between `<!-- seams:start -->` / `<!-- seams:end -->` markers (replace if present, append if not, so hand edits outside the markers survive).

`seams.json` fields: `generated`, `method`, `scope`, `stats{edges,verified,files_ok,repos,externals,by_cluster}`, `nodes{repos[],externals[],all_repos[]}` (`all_repos` is the full cluster roster from `clusters.json`, independent of whether a repo has any kept edge; the cartographer's zero-edge-repos coverage note is `all_repos` minus `repos`), `kinds{}`, `edges[]`. Per edge: `from, fromRef, to, toRef, kind, direction, detail, proof, confidence`, plus build-added `verify` and `cluster`.

Run build.py as a delegated `haiku` helper agent (or the main loop) since it is deterministic; it does no judgment.

## Phase 4: redraw the map (delegate, judgment gate)
Hand `.claude/harness/seams/cartographer-prompt.md` (with real counts substituted from seams.json) to ONE agent pinned to `opus`, high effort. That agent reads ONLY `seams.json` plus `adjacency.txt` (and may skim per-repo rules docs for narrative color, never raw source) and rewrites `.claude/meta/integration-map.md`:
- intro with evidence method and edge/repo counts,
- a mermaid backbone flowchart (backbone edges only, subgraphed by cluster, arrows labeled by mechanism),
- a node-roles table (repo, one-line role, out/in degree),
- a seam catalog by kind, split per cluster,
- feature-flow playbooks numbered `F<n>. <Feature>`: a hop-by-hop prose trace with inline `file:line` refs, each closed by a `Blast radius:` line and a `Contract(s):` line,
- a coverage-notes section listing zero-edge repos and thin-confidence edges.
Hard rules for the agent: no em-dash character, every cited path must come from seams.json, stay within the line budget stated in the prompt.

## Phase 5: verify gate (bundled script + main loop)
Run the deterministic self-verify AFTER Phase 4 has drawn the map (not folded into the Phase 3 `build.py` run, which executes before `integration-map.md` exists): `sh .claude/harness/seams/verify-map.sh` from the workspace root. It sweeps `.claude/meta/*`, `.claude/rules/*.md`, and root `CLAUDE.md` for U+2014, `test -e`s every backtick path in the new `integration-map.md` (mermaid-fenced blocks and any `:line` suffix stripped), and checks `seams:start`/`seams:end` marker balance in every rules file, then prints one `RESULT` line and exits non-zero on any failure. Run it as a delegated `haiku` helper or from the main loop; the main loop resolves any failure before reporting. The one judgment item left to the main loop is confirming the thin-confidence edges the cartographer flagged are genuinely low-confidence and worth surfacing, not silent drops.

## Report
Edge counts (verified vs files-ok), repo and external counts, per-cluster counts, coverage gaps (zero-edge repos), and the list of files touched.

## Scope discipline
Do not invent edges, paths, or proofs; every edge in the output traces to a grep-matched source line. Do not deep-recurse vendored or huge repos. Right-size the hunter panel to the workspace. Ask the user only if the cluster config is missing or malformed (point them at `workspace-init`); otherwise infer and proceed, recording any low-confidence edges as `confidence: low` rather than dropping them silently.

## Gotchas
- Auto-invocation is disabled by design; this skill overwrites committed navigation artifacts, so
  run it via the slash command on purpose.
- A hunter recursing into a vendored/base repo's full source instead of finding only the consumer-side reference, which floods the journal with noise edges.
- An edge whose `proof` string is stale or paraphrased so it no longer matches the cited file's text; build.py drops it rather than half-verifying it, so a hunter must quote the literal line.
- A `## Cross-repo seams` block missing its `<!-- seams:end -->` marker, which breaks Phase 3's replace-vs-append logic for that repo and Phase 5's marker-balance check.
- A missing or malformed `.claude/harness/seams/clusters.json` (or a stale workspace-local override) silently narrowing or misrouting the hunter set; treat that as blocking, not something to guess past.
