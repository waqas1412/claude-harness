# claude-harness

A portable, self-adapting Claude Code setup. It carries the parts of a personal `~/.claude` that are
worth reusing everywhere (working agreements, read-only advisor agents, profile-driven PR/ticket
skills, enforcement hooks) and a `/harness-init` command that tailors any repository it lands in.

## What you get

- **Working agreements** (`global/CLAUDE.md`): always-on rules (multi-agent orchestration, no em dash,
  no Co-Authored-By, no PR reviewers, one commit per PR, characterization-tests-first, verify before
  git ops, and more). Installed as your global `~/.claude/CLAUDE.md`.
- **Advisor agents** (`plugins/harness/agents/`): read-only PLAN/VERIFY advisors (system-architect,
  system-designer, developer-reviewer, performance-optimizer, principles-engineer,
  design-principles-advisor, docs-researcher, senior-software-engineer, plus pr-author and
  jira-ticket-author). They defer to the repo's own generated index for stack and conventions, so they
  work in any codebase.
- **Skills** (`plugins/harness/skills/`):
  - `/harness-init` scans the current repo and generates its navigation harness (see below).
  - `/pr` and `/ticket` write to house templates, reading project tokens from a per-repo profile.
- **Enforcement hooks** (`plugins/harness/hooks/`): PreToolUse guards that mechanically block a
  Co-Authored-By trailer, a `--reviewer` flag on `gh pr`, and an em dash in authored markdown.

## The self-adapting part

Run `/harness-init` in any repository. It scans the repo and writes, following a documented pattern:

- `CLAUDE.md` a root router index (System Topology, Routing Triggers, Search/Grep deny rules, Deep
  Index Pointers).
- `.claude/rules/<area>.md` one path-scoped deep index per area, with `targets` globs so each loads
  only when you touch that area.
- `.claude/meta/navigation.md` an on-demand reference layer (doc map, instruction hierarchy, agent
  guide).
- `.claude/harness/profile.md` the project profile (repo slug, tracker prefix, default branch, and the
  resolved lint/test/build commands) that `/pr` and `/ticket` read.

This is what "harness itself based on where it is installed" means: the portable agents and skills stay
generic, and `/harness-init` injects the project knowledge.

## Install

Two independent paths. Pick one. Do not run both (they would double-load the agents and skills).

### Path A: install.sh (recommended, complete, immediate)

```bash
git clone https://github.com/waqas1412/claude-harness ~/claude-harness
cd ~/claude-harness
./install.sh
```

This installs everything into `~/.claude`: copies agents, skills, and hooks (backing up any differing
file), merges `settings.json` (permission allow-rules, hook wiring, and personal prefs), and merges the
working-agreements block into `~/.claude/CLAUDE.md`. It is idempotent: re-run any time.

Flags:
- `--no-prefs` skip personal prefs (`model`, `effortLevel`, `theme`, `tui`); install the rest.
- `--check` validate an existing install and write nothing.
- `--with-marketplace` also register this repo as a local plugin marketplace (best effort).
- `--uninstall` remove harness files (delegates to `uninstall.sh`).

Sandbox dry-run (writes into a throwaway dir, touches nothing real):
```bash
CLAUDE_HOME=/tmp/harness-sandbox ./install.sh && CLAUDE_HOME=/tmp/harness-sandbox ./install.sh --check
```

Requires `jq`.

### Path B: native plugin + marketplace (shareable)

In Claude Code:
```
/plugin marketplace add waqas1412/claude-harness
/plugin install harness@waqas-harness
```

This gives you the agents, skills, and hooks via the plugin system. Plugins cannot set global
instructions or permissions, so the working-agreements `CLAUDE.md` and the permission allow-rules are
not applied this way. To add them, copy `global/CLAUDE.md` into your `~/.claude/CLAUDE.md` and add the
`permissions.allow` entries from `global/settings.fragment.json` yourself, or just use Path A.

## Layout

```
claude-harness/
  install.sh / uninstall.sh        idempotent installer + remover
  .claude-plugin/marketplace.json  native marketplace manifest (Path B)
  global/
    CLAUDE.md                      portable working agreements (-> ~/.claude/CLAUDE.md)
    settings.fragment.json         prefs + permission allow-rules merged into settings.json
    memory/                        memory seed (reference; project memory is path-scoped)
  plugins/harness/
    .claude-plugin/plugin.json     plugin manifest
    agents/                        advisor agents
    skills/{harness-init,pr,ticket}/SKILL.md
    hooks/{hooks.json, block-*.sh} enforcement hooks
  templates/                       human-readable copies of the index/rule/navigation patterns
```

## Security

This package ships no secrets. The originating machine's `settings.local.json` contained machine paths
and a leaked database password; none of that was carried over. If you reuse an old local settings file,
scrub credentials and rotate any exposed secret.

## Uninstall

```bash
cd ~/claude-harness && ./uninstall.sh
```

Removes only what the installer added (agents, skills, hooks, the managed `CLAUDE.md` block, and the
hook wiring), backing each item up first. Personal prefs and permission allow-rules are left in place.
