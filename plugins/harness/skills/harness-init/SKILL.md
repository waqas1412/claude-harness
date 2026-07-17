---
name: harness-init
description: Scan the current repository and generate a tailored navigation harness (root CLAUDE.md index, path-scoped .claude/rules/*.md deep indexes, .claude/meta/navigation.md, and a .claude/harness/profile.md consumed by /pr and /ticket). Runs autonomously: infers stack, areas, verify commands, and conventions, then writes the files. Use to bootstrap or refresh a repo's harness, or when asked to "harness this project", set up CLAUDE.md, or index a codebase.
argument-hint: "[--refresh] [--emit codex] [optional: area/path to focus]"
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
---

# /harness-init: self-adapting project bootstrap

Generate this repository's navigation harness by scanning it and emitting four artifacts that follow
a documented pattern. Run **autonomously**: infer everything you can, write the files, and record any
assumption you had to make in the profile so the user can correct it. Ask the user only if a decision
is genuinely blocking and cannot be inferred (rare).

For a large or multi-package repo, fan out: use `Explore` or parallel agents to map areas in
parallel, then synthesize. The main loop owns the file writes.

## What you produce

1. `CLAUDE.md` (repo root) plus the root router index.
2. `.claude/rules/<area>.md` one path-scoped deep index per area.
3. `.claude/meta/navigation.md` the on-demand reference layer (includes an orchestration map).
4. `.claude/harness/profile.md` the project profile (repo slug, tracker, verify commands, stack flags).
5. `.claude/memory/` a project memory scaffold (one starter fact plus a `MEMORY.md` index).

Optional with `--emit codex`: a root `AGENTS.md` mirroring the same model for Codex and Cursor.

Wrap generated content between `<!-- harness:start -->` and `<!-- harness:end -->` markers so a later
`--refresh` replaces only the managed block and leaves any hand-written prose intact. If a target
file already exists without markers, back it up to `<name>.bak.<timestamp>` before writing.

## Phase 1: Detect (do not write yet)

Run a fast, read-only scan. Prefer Bash one-liners and Glob over reading whole files.

- **Repo identity:** `git remote get-url origin` (derive `owner/repo`), `git rev-parse --show-toplevel`.
- **Default branch:** `git symbolic-ref --quiet refs/remotes/origin/HEAD` (strip `origin/`); fall back
  to `main` then `master` if unresolved.
- **Monorepo vs single:** look for multiple sub-projects each with their own manifest
  (`package.json`, `go.mod`, `pyproject.toml`, `Cargo.toml`, `pom.xml`, `build.gradle`, `*.csproj`,
  `Gemfile`). One area per manifest dir; otherwise treat the root as a single area.
- **Stack per area:** infer from the manifest plus lockfile:
  - Node: `package.json` (+ `yarn.lock` -> yarn, `pnpm-lock.yaml` -> pnpm, `package-lock.json` -> npm,
    `bun.lockb` -> bun). Read the `scripts` block for lint/test/build.
  - Go: `go.mod` (+ a `Makefile`: read targets for `lint`, `test`, `build`, `sqlc`).
  - Python: `pyproject.toml` (+ `uv.lock` -> uv, `poetry.lock` -> poetry); detect ruff/pytest/mypy.
  - Rust `Cargo.toml`; Ruby `Gemfile`; Java/Kotlin `pom.xml`/`build.gradle`; .NET `*.csproj`.
- **Verify commands** (the most important output): resolve concrete `LINT_CMD`, `UNIT_TEST_CMD`,
  `BUILD_CMD`, and `E2E_TEST_CMD` per area from the scripts/targets above. Quote them exactly as a
  user would type them (e.g. `yarn lint`, `make test`, `uv run pytest`, `go build ./...`).
- **Docs and rules:** find `AGENTS.md`, `CLAUDE.md`, `README*`, `CONTRIBUTING*`, `docs/**`, and any
  spec/KB dirs. Note per-area `AGENTS.md` as authoritative.
- **Deny zones:** standard ignores plus anything large/generated you actually see
  (`node_modules`, `.next`, `dist`, `build`, `out`, `target`, `cdk.out`, `.git`, `.venv`,
  `__pycache__`, `*.egg-info`, `vendor`, generated `sqlc`/codegen dirs, test-report/snapshot dirs).
- **Tracker prefix:** infer from branch and commit history
  (`git log --oneline -50`, `git branch -a`): a recurring `[A-Z]{2,}-\d+` token is the prefix
  (e.g. `PROJ-`, `JIRA-`, `OPS-`). If none is found, leave `TICKET_PREFIX` empty and note that
  `/pr` and `/ticket` should fall back to GitHub issue refs.
- **Routing triggers:** for each area, identify the dirs that own the common intents (entrypoints,
  HTTP handlers/routes, data layer, shared libs, UI components, config, tests). These become Section 2.

## Phase 2: Write the profile

Write `.claude/harness/profile.md`. This is the single source of truth the `/pr` and `/ticket` skills
read. Keep it terse and machine-readable.

```markdown
<!-- harness:start -->
# Project profile (consumed by /pr and /ticket)

- REPO: {{owner/repo}}
- DEFAULT_BRANCH: {{main}}
- TRACKER: {{Jira|GitHub Issues|Linear|none}}
- TICKET_PREFIX: {{PROJ-|empty}}
- TRACKER_BROWSE_URL: {{https://org.atlassian.net/browse/ | empty}}
- TRACKER_CLOSE_KEYWORD: {{Closes | Fixes #}}
- PR_TOOL: gh
- COMMIT_TYPES: feat | fix | refactor | chore | perf | docs | test
- STACK: {{e.g. node-next, go, python}} (one per area)
- LINT_CMD: {{per area}}
- UNIT_TEST_CMD: {{per area}}
- E2E_TEST_CMD: {{per area or none}}
- BUILD_CMD: {{per area}}
- WEB_UI: {{true|false}} (enables design-system/analytics sections in /ticket)
- ASSUMPTIONS: {{anything inferred with low confidence, for the user to correct}}
<!-- harness:end -->
```

## Phase 3: Write the root CLAUDE.md index

Follow this structure (fill from Phase 1, drop empty sections). Keep it scannable and under ~200 lines.

```markdown
# {{Project}} Index

> Directional triggers for navigation. Read this first; do not blind-recurse the repo. Deep,
> path-scoped detail lives in .claude/rules/*.md and auto-loads when you touch the matching paths.

## 1. System Topology
- **{{Area}} `{{path}}/`:** {{stack}} ({{one-line purpose}}).

## 2. Structural Routing Triggers
- {{intent}}: `{{path}}`.
- Per-area agent rules: read `{{area}}/AGENTS.md` before editing that area.

## 3. Search & Grep Optimization
- **File patterns:** {{key globs}}.
- **Deny rules:** {{deny dirs}}.
- **Non-code zones:** {{doc/spec zones}}.

## 4. Deep Index Pointers
- Editing `{{path}}/**`: load `.claude/rules/{{area-slug}}.md` ({{one-line hint}}).

## 5. Deeper navigation (on-demand)
- `.claude/meta/navigation.md` for the doc map, instruction hierarchy, and agent/skill guide.
- `.claude/harness/profile.md` for /pr and /ticket project tokens.
```

If a root `CLAUDE.md` already exists, merge: keep the user's prose, replace only the managed marker
block. If it has no markers, back it up first.

## Phase 4: Write one deep index per area

For each area, write `.claude/rules/<area-slug>.md` with path-scoped frontmatter so it auto-loads only
when that area is touched:

```markdown
---
id: {{area-slug}}-deep-index
targets:
  - "{{area-path}}/**/*"
---

# Deep Index: {{Area}} ({{stack}})

> {{one-line summary}}. {{key tooling}}.

## 1. Domain Component Mapping
- **Core Logic:** `{{path}}` {{what}}.
- **State / Data Layer:** `{{path}}` {{what}}.
- **Entrypoints & Triggers:** `{{path}}` {{what}}.

## 2. Local Architecture Gotchas
- **Risk Zones:** {{what silently breaks and why}}.
- **Strict Patterns:** {{the convention to repeat verbatim}}.

## 3. Local Verification Loop
- **Test:** `{{UNIT_TEST_CMD}}`. **Lint:** `{{LINT_CMD}}`. **Build:** `{{BUILD_CMD}}`. **E2E:** `{{E2E_TEST_CMD}}`.

## 4. Documentation Map
- `{{doc}}` {{desc}}. Ignore `{{generated}}`.
```

Note on `targets`: this repo's convention is the `targets:` glob list (matches the workspace's
existing rule files). If your Claude Code build expects `paths:` instead, emit `paths:` with the same
globs; the rest of the file is identical.

## Phase 5: Write navigation.md

Write `.claude/meta/navigation.md` (on-demand reference): a Documentation Map, an Agent Instruction
Hierarchy (global -> workspace root -> per-area hubs -> sub-scopes, cumulative, narrowest wins), the
Agents/Workflows/Skills guide (the read-only advisor roster and key skills), and an ORCHESTRATION MAP
(which advisors fire at the PLAN gate vs the VERIFY gate and which run in parallel, mirroring the
`/orchestrate` skill). Keep it tailored to the areas and docs you found.

## Phase 6: Project memory scaffold

Write `.claude/memory/` with a `MEMORY.md` index and exactly one starter fact capturing project
context the scan already learned (stack, areas, the rationale behind the verify commands) as
`project-context.md` with frontmatter (`name`, `description`, `metadata.type: project`). Wrap the
managed parts in `<!-- harness:start -->` and `<!-- harness:end -->` so `--refresh` is idempotent and
a user's later facts survive. Use the same one-fact-per-file convention as the global memory store; do
not scatter state files into the repo root. Record a commit-vs-gitignore decision in ASSUMPTIONS.

## Phase 7: Self-verify

Prove the no-invented-paths contract mechanically before reporting:
- Extract every backtick-quoted path from the generated `CLAUDE.md` and each `.claude/rules/*.md`.
- For each, run `test -e` (or a `git ls-files` match); remove or correct any path that does not exist.
- For each rules file, confirm its `targets:` glob matches at least one real file; widen or drop it if not.
- Carry verified-vs-dropped counts into the Phase 8 report.

## Phase 8: Report

Summarize: the areas detected, the verify commands resolved per area, the files written (with paths),
the tracker/prefix inference, the self-verify verified-vs-dropped path counts, and every low-confidence
ASSUMPTION the user should confirm. Suggest, but do not auto-apply, project-scoped permission allow-rules
for the verify commands (those belong in the project's `.claude/settings.json`, not user-global).

## Optional: --emit codex (AGENTS.md)

When invoked with `--emit codex` (default stays Claude-only), also write a root `AGENTS.md` from the
SAME detected model (topology, routing, verify commands) so Codex and Cursor get the same guidance.
Emit `AGENTS.md` only: no per-harness packaging, MCP inventories, or transpile pipelines.

## Autonomy contract

- Infer and proceed; do not stall on questions you can answer by reading the repo.
- Never invent file paths: every path you cite must exist (verify with Glob/Bash before writing it).
- Record uncertainty in `ASSUMPTIONS`, do not hide it.
- Re-running with `--refresh` must be idempotent: same repo state yields the same files, and existing
  hand-written prose outside the markers is preserved.
