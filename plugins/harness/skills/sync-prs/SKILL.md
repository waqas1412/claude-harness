---
name: sync-prs
description: Sync the user's open PRs with their base branches. Read each PR's real base from gh (never assume the default branch), rebase in stack order so a parent rewrite ripples into its children, preserve every commit, push --force-with-lease on the same branch ref, and report per-PR base-ahead / head-ahead / commit-count / conflict state. Hands any conflict back with files and hunks instead of resolving it. Use for "sync my open PRs with their base", "update PR N with development", "is branch X in sync with its base", or a plain branch sync with no PR.
argument-hint: "[PR number or branch, or blank for all open PRs]"
allowed-tools: Read, Grep, Glob, Bash
---

# /sync-prs: bring open PRs up to date

Load `.claude/harness/profile.md` for `REPO`, `DEFAULT_BRANCH`, `LINT_CMD`, `BUILD_CMD`,
`UNIT_TEST_CMD`, `E2E_TEST_CMD`.

## Not for

Opening, retargeting, or merging PRs. Review comments (use `/pr-comments`). PR bodies (use `/pr`).

## Invariants, restated as gates

These come from the always-on rules and the memory store. Do not redefine them here, just do not break
them.

- Preserve the branch's existing commits. A rebase replays them; do not squash them into one, and do
  not amend to reduce the count.
- `git push --force-with-lease` on the SAME branch ref, because a rebase rewrites the commits it
  replays and there is no non-force way to publish that. This is the one sanctioned force-push: it is
  inherent to rebasing, not a commit-count preference. A force-push does not close a PR and approvals
  survive it here. A branch RENAME does close it, so never rename a branch that heads an open PR.
- Confirm `git branch --show-current` as its own step before any rebase.
- Never `--no-verify`, never weaken a test to get green.

## Step 1: enumerate and build the graph

```sh
gh pr list --author @me --state open \
  --json number,headRefName,baseRefName,isDraft,mergeStateStatus,mergeable --limit 50
```

The base is `baseRefName` per PR. Read it; do not assume the default branch. Some PRs sit on an epic
branch, and "sync with development" for those means sync the epic first, then rebase the PR onto the
epic.

A PR is a stack child when its `baseRefName` equals another open PR's `headRefName`:

```sh
gh pr list --author @me --state open --json number,headRefName,baseRefName --jq '
  . as $p
  | map(. as $c | {n:$c.number, head:$c.headRefName, base:$c.baseRefName,
                   parentPR: ([$p[] | select(.headRefName == $c.baseRefName) | .number] | first)})
  | map("PR \(.n)  head=\(.head)  base=\(.base)  parent=\(.parentPR // "none")") | .[]'
```

## Step 2: dry-run report, before touching anything

`git fetch origin` first, then per PR:

```sh
B=origin/<baseRefName>; H=origin/<headRefName>
git rev-list --count $H..$B     # base-ahead: commits the base has that the head lacks
git rev-list --count $B..$H     # head-ahead: the branch's own commits
git merge-tree --write-tree --name-only $B $H >/dev/null 2>&1; echo $?   # 1 means conflicts
```

Print the table and the planned order. `base-ahead = 0` means already in sync: skip it, do not rebase
for nothing. Get a go-ahead before rewriting anything that is not a trivial case.

## Step 3: rebase in stack order

Topological order, roots first. After a parent is rewritten its head SHA changed, so every child must
be rebased onto the parent's NEW head, not onto the SHA you read in step 1. A mid-stack rebase always
ripples: recompute children even when step 2 said they were in sync.

## Step 4: confirm the replay kept every commit

The rebase replays the branch's commits onto the new base; it does not collapse them, and neither do
you. Verify with `git log --oneline <base>..HEAD` that the same number of commits came out as went in,
and report that count. A commit that vanished means the rebase dropped work: stop and surface it.

## Step 5: conflicts are handed back, not resolved

On any conflict: `git rebase --abort`, leave the branch exactly as it was, and report the PR number,
the conflicting files, and the hunks, with a question. Do not push a partially resolved tree, and do
not guess at a resolution because it looks mechanical.

For a stack, a blocked parent blocks its children: skip them and say so, because they cannot be
rebased onto a head that was never rewritten.

## Step 6: push and verify

`git push --force-with-lease` per branch. When the rebase moved real code rather than replaying
cleanly, run `LINT_CMD`, `BUILD_CMD`, and the change-related tests fresh and paste the real output.
State which gates ran and which you skipped.

## Step 7: final table

One row per PR: number, head, base, before SHA, after SHA, commit count, and pushed or skipped or
handed back. Then the branch the user is left on.

## Gotchas

- `mergeStateStatus: BLOCKED` with `mergeable: MERGEABLE` is branch protection (review required or a
  pending check), NOT a merge conflict. Do not rebase in response to it.
- A long-lived checkout often carries persistent uncommitted or gitignored work, and a rebase sweep is
  exactly when that bites. Sync on the real branches only when `git status --short` is empty; otherwise
  `git worktree add`, never `git stash`. Tear the worktree down in the same turn and state the handback.
- `git merge-tree --write-tree` needs git 2.38 or newer. Verified working on 2.50.1.
- Run this solo in the main loop. Do not spawn subagents for the rebases unless the user asks in the
  moment.
- Derive every base and SHA at run time. Do not write a concrete PR number or branch name into this
  file: those rot within days.
