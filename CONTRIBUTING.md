# Contributing

A small, single-maintainer, first-party harness. Keep additions lean; resist bloat (see the
"Deliberately not adopting" reasoning that shaped this repo).

## Before you push

Everything is gated by one script and one test file, the same ones CI runs:

```bash
./scripts/validate.sh        # frontmatter, read-only-tools invariant, Boundaries graph,
                             # version consistency, manifests parse, shell lint
./tests/run-hook-tests.sh    # behavioral hook tests (deny vs allow, exit codes)
CLAUDE_HOME="$(mktemp -d)" ./install.sh && CLAUDE_HOME="$(mktemp -d)" ./install.sh --check
```

Requires `jq` (and `shellcheck` for the full lint; the validator falls back to syntax-only without it).

## Conventions

- **Agents** are read-only advisors: `tools:` must stay within `Read, Grep, Glob, Bash, WebFetch,
  WebSearch`. Every sibling named in a `Boundaries` block must resolve to a real agent file. The
  validator enforces both.
- **Skills** keep `SKILL.md` as a lean decision layer; put verbose bodies in `references/` opened on
  demand. Frontmatter carries `name`, `description`, and where useful `argument-hint` /
  `allowed-tools`.
- **Versioning:** `VERSION` is the source of truth. Run `./scripts/bump-version.sh <x.y.z>` to sync
  the manifests, commit, then `git tag v<x.y.z>`. The validator fails if the three versions drift.
- **No em dashes** in authored markdown (a hook enforces this); `MEMORY.md` is the one exemption.
- **One commit per PR.** Fold review fixes in via amend plus force-with-lease.
