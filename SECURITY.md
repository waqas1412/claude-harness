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

### A genuine strength: mode-proof, not just pattern-proof

These are `PreToolUse` hooks, so they fire before any permission-mode check, in every permission
mode, including `bypassPermissions` and `--dangerously-skip-permissions`. A deny from one of these
guards cannot be evaded by switching permission mode. The one honest off-switch is at the settings
layer, not the agent layer: setting `disableAllHooks: true` in a settings file, or removing the
harness's `PreToolUse` entries from `settings.json`, disables all three wholesale. That is a
settings-level off-switch an operator can flip, not a bypass an agent can talk its way around.

### Known residual bypasses (by design, documented not hidden)

- **Co-Authored-By via config or message reuse:** the installed settings.json now sets
  `attribution.commit` and `attribution.pr` to empty strings, which declaratively suppresses
  Claude Code's own auto-injected attribution across Bash, MCP git/github tools, and any
  mis-wired Windows install (a settings key, not a Bash-text match, so it has none of the hook's
  blind spots). `block-coauthor.sh` remains as the belt-and-suspenders guard for a hand-typed
  trailer in a `git commit` command, including `--trailer` and `--amend` that pass the trailer
  inline. It still cannot see a trailer added through `git config trailer.*`, a commit template, or
  a `--amend` that reuses an existing message already containing the trailer (no trailer text
  appears in the command); those residual paths are no longer the only line of defense, but they
  are also not closed by the `attribution` setting, which only governs Claude's own injected byline.
- **Reviewers via other surfaces:** the hook catches `--reviewer` / `--add-reviewer` on `gh pr
  create` / `gh pr edit` and `requested_reviewers` mutations on `gh api` (a non-GET method or field
  flags; a read-only GET is allowed). It does not inspect a reviewer added through the web UI or a
  third-party client.
- **Em dash outside guarded authoring paths:** the hook checks `*.md` Write/Edit content (exempting
  `MEMORY.md`, its list delimiter) and scans the command text of `git commit` and `gh pr`/`gh issue`
  `create`/`edit` for the byte sequence, so inline `-m` / `--body` commit, PR, and ticket bodies are
  covered. It does not scan non-markdown files, a body fed from a file (`--body-file` / `-F` / a
  commit template routes the text through a path the Write/Edit guard sees only if it is `*.md`), or
  text pasted through other clients (web UI, other CLIs).
- **The MCP git/github tool families are not inspected:** all three guards are wired to matchers
  `Bash` and `Write|Edit` only. A commit, PR, or reviewer add made through `mcp__git__.*` or
  `mcp__github__.*` (for example `mcp__git__git_commit`, `mcp__github__create_pull_request`,
  `mcp__github__create_pull_request_review`) never reaches `block-coauthor.sh`,
  `block-pr-reviewer.sh`, or `block-md-emdash.sh`. The harness's prescribed path is `gh`/`git` over
  Bash, so this is documented rather than closed; extending coverage would mean adding
  `mcp__git__.*` / `mcp__github__.*` matchers and parsing each tool's own input shape (for example
  `.tool_input.message`, `.tool_input.reviewers`), which is only worth doing if MCP git/github
  becomes the prescribed path.

The matchers are deliberately narrow to avoid false-positive denials that would block legitimate
work. Treat the hooks as guardrails plus the working-agreement instructions in `CLAUDE.md`, not as a
guarantee.

## Settings-level floor: secret reads and raw curl

The installed settings.json also carries a `permissions.deny` block
(`Read(./.env)`, `Read(./.env.*)`, `Read(./secrets/**)`, `Read(./*.pem)`, `Read(./*.key)`,
`Bash(curl *)`) blocking the Read tool from touching common secret paths and blocking raw `curl`.
This is a partial floor, not full coverage: `CLAUDE.md` allows blanket `Bash`, so a mutating agent
can still run `cat .env` or `type .env` through Bash and read the file's contents; the deny rule only
stops the dedicated Read tool and the `curl` command name. Treat it as a mechanical guardrail against
the accidental path, the same honest framing as the hooks above, not a secret-exfiltration guarantee.

## Reporting

This is a personal tooling repo. Open an issue for anything that looks wrong; do not include secrets
in the report.
