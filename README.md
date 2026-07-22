# claude-harness

A portable, self-adapting Claude Code setup: it carries the reusable parts of a personal `~/.claude` (working agreements, read-only advisor agents, profile-driven PR/ticket skills, enforcement hooks) and a `/harness-init` command that tailors any repository it lands in.

[![CI](https://github.com/waqas1412/claude-harness/actions/workflows/ci.yml/badge.svg)](https://github.com/waqas1412/claude-harness/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/waqas1412/claude-harness)](https://github.com/waqas1412/claude-harness/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-8A2BE2.svg)](https://docs.anthropic.com/en/docs/claude-code)

## Why claude-harness

Your best Claude Code habits (how you orchestrate agents, how you write PRs and tickets, the guardrails you never want to skip) live scattered across one machine's `~/.claude`. They do not travel, and they do not know anything about the repo you happen to be in.

claude-harness splits that problem in two. The **portable layer** (agents, skills, hooks, working agreements) is stack-neutral and installs the same everywhere. The **project layer** is generated on demand: run `/harness-init` in any repository and it scans the code, then writes a navigation index and a project profile that the generic agents and skills read. The portable pieces stay generic; the project knowledge is injected where you are.

## Contents

- [Prerequisites](#prerequisites)
- [Quickstart](#quickstart)
- [What you get](#what-you-get)
- [The self-adapting part](#the-self-adapting-part)
- [Install](#install)
- [Configuration](#configuration)
- [Keeping it in sync](#keeping-it-in-sync)
- [Layout](#layout)
- [Security](#security)
- [Uninstall](#uninstall)
- [Contributing](#contributing)
- [License](#license)

## Prerequisites

- **[jq](https://jqlang.github.io/jq/)** (required): `install.sh` and `scripts/validate.sh` exit early without it.
- **A POSIX shell** (bash): the installer runs under `#!/usr/bin/env bash`. On Windows, use Git Bash.
- **git**: for the clone-based install (Path A) and the two-way sync flow.
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)**: the host CLI these agents, skills, and hooks run inside.
- **shellcheck** (optional): used by CI and by `scripts/validate.sh` when present; the validator falls back to a syntax-only check without it.

## Quickstart

Install the portable layer, then let it adapt to a repo:

```bash
git clone https://github.com/waqas1412/claude-harness ~/claude-harness
cd ~/claude-harness
./install.sh
```

Open any project in Claude Code and run the bootstrap:

```text
/harness-init
```

It scans the repo and writes a navigation harness tuned to that codebase, for example:

```text
your-repo/
  CLAUDE.md                     root router (topology, routing triggers, grep deny rules)
  .claude/repo-index/<area>.md       one deep index per area (read on demand, not auto-loaded)
  .claude/meta/navigation.md    on-demand reference layer (doc map, instruction hierarchy)
  .claude/harness/profile.md    project profile (repo slug, tracker prefix, lint/test/build)
  .claude/memory/               project memory scaffold (one starter fact + index)
```

From then on, `/pr`, `/ticket`, and the advisor agents read that generated profile and index, so they behave as if hand-tuned for the repo. Re-run `install.sh` any time to update the portable layer; it is idempotent.

## What you get

- **Working agreements** (`global/CLAUDE.md`): always-on rules (multi-agent orchestration, no em dash, no Co-Authored-By, no PR reviewers, one commit per PR, characterization-tests-first, verify before git ops, and more). Installed as your global `~/.claude/CLAUDE.md`.
- **Advisor agents** (`plugins/harness/agents/`): 13 read-only PLAN/VERIFY advisors (system-architect, system-designer, developer-reviewer, data-flow-timing-auditor, spec-fidelity-auditor, design-parity-auditor, performance-optimizer, principles-engineer, design-principles-advisor, docs-researcher, senior-software-engineer, plus pr-author and jira-ticket-author). They defer to the repo's own generated index for stack and conventions, so they work in any codebase.
- **Skills** (`plugins/harness/skills/`), 7 in total:
  - `/harness-init` scans the current repo and generates its navigation harness (see [The self-adapting part](#the-self-adapting-part)).
  - `/workspace-init` scans a multi-repo workspace root and generates the workspace router (catalog CLAUDE.md, per-repo `.claude/repo-index/<repo>.md` deep indexes, navigation, and a `.claude/harness/seams/` cluster config). Complements `/harness-init`, does not replace it.
  - `/refresh-seams` rebuilds the cross-repo integration map: evidence-based seam discovery by parallel hunter agents, every edge verified by `file:line` proof, emitting `.claude/meta/seams.json`, per-repo seam sections, and `.claude/meta/integration-map.md`.
  - `/orchestrate` runs a change through the multi-agent PLAN and VERIFY loop in one command.
  - `/harness-distill` distills durable learnings from recent sessions and code-review corrections into proposed memory facts, CLAUDE.md rules, or skill Gotchas, verified by a skeptic and gated on your approval.
  - `/pr` and `/ticket` write to house templates, reading project tokens from a per-repo profile.
- **Hooks** (`plugins/harness/hooks/`): 4 PreToolUse guards that mechanically block a Co-Authored-By trailer (`block-coauthor.sh`), a reviewer flag on `gh pr` and `requested_reviewers` via `gh api` (`block-pr-reviewer.sh`), a bare `git push --force` / `-f` (`block-force-push.sh`), and an em dash in authored markdown (`block-md-emdash.sh`); plus 1 PostToolUse output filter (`filter-verbose-output.py`, needs `python3`) that trims passing/verbose test and Playwright output while surfacing failures, errors, warnings, and the run summary first, so failures survive even a truncated preview and the full raw log stays on disk. It only touches recognized test runners over a size threshold and is fail-safe: any unrecognized command, small output, or anomaly passes through untouched. See [`SECURITY.md`](./SECURITY.md) for the threat model and known residual bypasses.
- **Memory:** the installed `CLAUDE.md` carries a memory convention (one fact per file plus a `MEMORY.md` index), and the installer seeds a `~/.claude/memory/` store.
- **Quality gates:** `scripts/validate.sh` and `tests/run-hook-tests.sh` run in CI on every push and PR, and `install.sh --check` re-verifies hook behavior and memory integrity on a live install.

## The self-adapting part

Run `/harness-init` in any repository. It scans the repo and writes, following a documented pattern:

- `CLAUDE.md` a root router index (System Topology, Routing Triggers, Search/Grep deny rules, Deep Index Pointers).
- `.claude/repo-index/<area>.md` one deep index per area, read on demand (not auto-loaded); `targets` globs document each area's scope and feed tooling, they do not drive loading.
- `.claude/meta/navigation.md` an on-demand reference layer (doc map, instruction hierarchy, agent guide).
- `.claude/harness/profile.md` the project profile (repo slug, tracker prefix, default branch, and the resolved lint/test/build commands) that `/pr` and `/ticket` read.
- `.claude/memory/` a project memory scaffold (one starter fact plus an index).

Run it with `--emit codex` to also write a root `AGENTS.md` from the same model, for Codex and Cursor.

The portable agents and skills stay generic; `/harness-init` supplies the per-repo knowledge they read.

## Install

Two independent paths. Pick one. Do not run both (they would double-load the agents and skills).

### Path A: install.sh (recommended, complete, immediate)

```bash
git clone https://github.com/waqas1412/claude-harness ~/claude-harness
cd ~/claude-harness
./install.sh
```

This installs everything into `~/.claude`: copies agents, skills, and hooks (backing up any differing file), merges `settings.json` (permission allow-rules, hook wiring, and personal prefs), and merges the working-agreements block into `~/.claude/CLAUDE.md`. It is idempotent: re-run any time.

Sandbox dry-run (writes into a throwaway dir, touches nothing real):

```bash
CLAUDE_HOME=/tmp/harness-sandbox ./install.sh && CLAUDE_HOME=/tmp/harness-sandbox ./install.sh --check
```

See [Configuration](#configuration) for the full flag list.

### Path B: native plugin + marketplace (shareable)

In Claude Code:

```console
/plugin marketplace add waqas1412/claude-harness
/plugin install harness@waqas-harness
```

This gives you the agents, skills, and hooks via the plugin system. Plugins cannot set global instructions or permissions, so the working-agreements `CLAUDE.md` and the permission allow-rules are not applied this way. To add them, copy `global/CLAUDE.md` into your `~/.claude/CLAUDE.md` and add the `permissions.allow` entries from `global/settings.fragment.json` yourself, or just use Path A.

### What each path delivers

| Capability | Path A (`install.sh`) | Path B (plugin) |
| --- | --- | --- |
| Advisor agents | yes | yes |
| Skills (all 7) | yes | yes |
| Hooks | yes (wired into settings.json) | yes (plugin hooks) |
| Working-agreements CLAUDE.md | yes | no (copy it yourself) |
| Permission allow-rules and prefs | yes (merged) | no (add yourself) |
| Memory store seed | yes | no |
| Self-updating | git pull, re-run install.sh | `/plugin update` |

## Configuration

`install.sh` accepts the following flags:

| Flag | Effect |
| --- | --- |
| `--no-prefs` | Skip personal prefs (`model`, `effortLevel`, `theme`, `tui`); install the rest. |
| `--no-global` | Leave `~/.claude/CLAUDE.md`, `settings.json`, and the memory store as-is; install only the component dirs. |
| `--no-memory` | Skip seeding the `~/.claude/memory/` store. |
| `--check` | Validate an existing install and write nothing. |
| `--link` | Symlink agents/skills/hooks instead of copying (see [Keeping it in sync](#keeping-it-in-sync)). |
| `--unlink` | Convert the symlinks back to plain copies (freeze). |
| `--with-marketplace` | Also register this repo as a local plugin marketplace (best effort). |
| `--uninstall` | Remove harness files (delegates to `uninstall.sh`). |
| `-h`, `--help` | Print usage. |

The one hard requirement is `jq` (see [Prerequisites](#prerequisites)).

## Keeping it in sync

The portable layer (agents, skills, hooks) can be **symlinked** into `~/.claude` so edits flow both ways with no sync step:

```bash
./install.sh --link              # symlink agents/skills/hooks + merge CLAUDE.md/settings
./install.sh --link --no-global  # symlink ONLY the component dirs; leave CLAUDE.md/settings/memory as-is
./install.sh --unlink            # convert the symlinks back to plain copies (freeze)
```

Once linked, editing an agent, skill, or hook while you work IS editing the repo file: just `git commit` it, and a `git pull` updates your live setup instantly. `./install.sh --check` reports whether each dir is linked or copied and exercises the hooks.

What stays **local and is never synced here**: your memory store, your personal `settings.json` (model, theme, plugins), and any project index a repo generates with `/harness-init`. Project-specific knowledge belongs in that project's own `CLAUDE.md` + `.claude/repo-index` (which the generic agents read); this repo holds only the portable, stack-neutral layer.

## Layout

```text
claude-harness/
  install.sh / uninstall.sh        idempotent installer + remover
  scripts/validate.sh              structural validator (frontmatter, tools, version, lint)
  scripts/bump-version.sh          set the version (VERSION is the source of truth)
  tests/run-hook-tests.sh          behavioral hook tests (deny vs allow)
  .github/workflows/ci.yml         runs validate + hook tests + sandbox install on push/PR
  .claude-plugin/marketplace.json  native marketplace manifest (Path B)
  CONTRIBUTING.md / SECURITY.md    contribution gate + hook threat model
  global/
    CLAUDE.md                      portable working agreements + memory convention
    settings.fragment.json         prefs + permission allow-rules merged into settings.json
    memory/                        seed for the installed ~/.claude/memory store
  plugins/harness/
    .claude-plugin/plugin.json     plugin manifest
    agents/                        13 advisor agents
    skills/                        7 skills: harness-init, workspace-init, refresh-seams,
                                   orchestrate, harness-distill, pr, ticket (SKILL.md + references/)
    hooks/{hooks.json, block-*.sh} 4 enforcement hooks
  templates/                       human-readable copies of the index/rule/navigation patterns
```

## Security

This package ships no secrets. The originating machine's `settings.local.json` contained machine paths and a leaked database password; none of that was carried over. If you reuse an old local settings file, scrub credentials and rotate any exposed secret. For the hook threat model and the known residual bypasses, see [`SECURITY.md`](./SECURITY.md).

## Uninstall

```bash
cd ~/claude-harness && ./uninstall.sh
```

Removes only what the installer added (agents, skills, hooks, the managed `CLAUDE.md` block, and the hook wiring), backing each item up first. Personal prefs and permission allow-rules are left in place.

## Contributing

Contributions are welcome. See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for the conventions and the pre-push gate. Questions and bug reports: open a GitHub issue. Before you push, run the same checks CI runs:

```bash
./scripts/validate.sh
./tests/run-hook-tests.sh
CLAUDE_HOME="$(mktemp -d)" ./install.sh && CLAUDE_HOME="$(mktemp -d)" ./install.sh --check
```

## License

Released under the [MIT License](./LICENSE). Copyright (c) 2026 Waqas Hameed.
