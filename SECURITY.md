# Security and hook threat model

## What ships

This package ships no secrets. The originating machine's `settings.local.json` contained machine
paths and a leaked database password; none of that was carried over. If you reuse an old local
settings file, scrub credentials and rotate any exposed secret.

## Enforcement hooks: what they are and are not

The three `PreToolUse` hooks (`block-coauthor.sh`, `block-pr-reviewer.sh`, `block-md-emdash.sh`) are
**best-effort deterrents for the common accidental path**, not a tamper-proof security boundary. They
pattern-match the tool-call command or content and exit non-zero to block. They reliably stop the
obvious mistake; a determined caller can route around a shell pattern match. Their behavior is proven
by `tests/run-hook-tests.sh` and re-checked against the installed copies by `install.sh --check`.

### Known residual bypasses (by design, documented not hidden)

- **Co-Authored-By via config or message reuse:** the hook catches a `Co-Authored-By` trailer in a
  `git commit` command, including `--trailer` and `--amend` that pass the trailer inline. It cannot
  see a trailer added through `git config trailer.*`, a commit template, or a `--amend` that reuses an
  existing message already containing the trailer (no trailer text appears in the command).
- **Reviewers via other surfaces:** the hook catches `--reviewer` / `--add-reviewer` on `gh pr
  create` / `gh pr edit` and `requested_reviewers` mutations on `gh api` (a non-GET method or field
  flags; a read-only GET is allowed). It does not inspect a reviewer added through the web UI or a
  third-party client.
- **Em dash outside authored markdown:** the hook checks `*.md` Write/Edit content and exempts
  `MEMORY.md` (its list delimiter). It does not scan non-markdown files, PR bodies typed into `gh`, or
  text pasted through other tools.

The matchers are deliberately narrow to avoid false-positive denials that would block legitimate
work. Treat the hooks as guardrails plus the working-agreement instructions in `CLAUDE.md`, not as a
guarantee.

## Reporting

This is a personal tooling repo. Open an issue for anything that looks wrong; do not include secrets
in the report.
