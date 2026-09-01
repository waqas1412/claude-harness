---
name: pr-comments
description: Triage unresolved review threads on an open PR and close them out. Per thread, either agree (fix scoped to THIS PR's diff, verify, commit and push, reply, resolve) or disagree (justify with a quoted citation from the version-matched official doc, reply, resolve). Every reply is drafted for approval before it posts. Use when asked about comments on a PR, or told "reply and resolve", "if agree fix, if not justify", or "what did we do about his comments".
argument-hint: "[PR number, or blank to infer from the current branch]"
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# /pr-comments: triage and close out review threads

Load `.claude/harness/profile.md` for `REPO`, `LINT_CMD`, `UNIT_TEST_CMD`, `E2E_TEST_CMD`,
`BUILD_CMD`. Infer from the repo if there is no profile.

## The policy this encodes

Stated repeatedly and unchanged: if you agree, fix it and resolve; if you do not agree, justify it and
resolve. Nothing is left open and nothing is resolved silently.

## Step 1: read the threads, do not guess them

```sh
gh api graphql -f owner=<OWNER> -f repo=<REPO> -F pr=<N> -f query='
query($owner:String!,$repo:String!,$pr:Int!){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      reviewThreads(first:100){
        nodes{
          id isResolved isOutdated path line
          comments(first:20){nodes{author{login} body createdAt}}
        }
      }
    }
  }
}'
```

`nodes[].id` is the `PRRT_...` thread id both mutations need. Filter to `isResolved == false`. Read
every comment in a thread, not just the first: a reviewer often narrows or answers their own point
further down. Separate human reviewers from the CI reviewbot (`github-actions`); bot threads are still
triaged, but a human reviewer's thread is the one with a person's time attached to it.

Also check top-level PR comments, which are not review threads:
`gh pr view <N> --json comments --jq '.comments[] | {a:.author.login, b:.body}'`

## Step 2: classify each thread before touching code

Per thread, decide and write down one of:

- **Agree.** The reviewer is right. Fix it.
- **Disagree.** Needs a cited justification, not an opinion.
- **Out of scope.** Real, but not this ticket. Say so, offer to file it, resolve.

## Step 3: scope the fix to THIS diff

A review comment on a line of your diff is a comment about your diff. Fix that occurrence and the
places your own diff touched. Do NOT sweep the repo for every other instance of the same pattern
unless the reviewer says so or the user asks.

This is the mistake that costs the most. Turning a diff-scoped nit into an app-wide sweep buys a second
reviewer round and a much larger diff to defend. When genuinely unsure which the reviewer meant, ask in
one line rather than picking the larger blast radius.

## Step 4: to disagree, bring the source

A disagreement reply must quote the version-matched official doc or the installed source, with a link
or a `file:line` in `node_modules` or the module path. Check the version actually installed, not the
latest. "Deprecated in v6" and "removed in v6" are different claims and the reviewer will check.
If the source does not actually support the disagreement, you agreed and did not realize it: fix it.

## Step 5: verify, then push the fix as its own commit

Run `LINT_CMD`, `BUILD_CMD`, and the change-related tests fresh, and paste the real output. Then
confirm `git branch --show-current` as its own step, commit the fix on top, and push normally. Do not
amend and force-push to keep the branch at one commit, and never rename the branch.
Anything about the PR's base branch belongs to `/sync-prs`, not here.

## Step 6: draft every reply, get approval, then post

Show the user all drafted replies together before anything is posted. Replies are outward-facing
messages: short, casual, human, no AI fluff, no local-tooling or KB provenance. Follow the
outward-message-voice memory fact.

```sh
# reply in the thread
gh api graphql -f tid=<PRRT_id> -f body='<text>' -f query='
mutation($tid:ID!,$body:String!){
  addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$tid, body:$body}){
    comment{ id url }
  }
}'

# then resolve it
gh api graphql -f tid=<PRRT_id> -f query='
mutation($tid:ID!){ resolveReviewThread(input:{threadId:$tid}){ thread{ id isResolved } } }'
```

Reply first, resolve second, and only after the fix is pushed. Resolving a thread whose fix is not yet
on the branch tells the reviewer something untrue.

## Step 7: report

One row per thread: reviewer, path and line, agree or disagree or out of scope, what changed
(`file:line`) or what was cited, pushed SHA, replied, resolved. Then state which gates ran.

## Gotchas

- `gh pr comment` posts a NEW top-level comment; it cannot reply inside a review thread. Only
  `addPullRequestReviewThreadReply` does that, and it needs the `PRRT_...` id from step 1.
- An `isOutdated` thread still needs a reply and a resolve. Outdated means the line moved, not that
  the point was answered.
- Do not claim a fix you have not run. A reply written ahead of the verification is how a wrong claim
  reaches a reviewer.
- When the PR belongs to someone else, the mode is different: flag defects for the author to decide,
  post as non-blocking, and never push to their branch.
- The em dash guard covers `gh api` and `gh pr comment` bodies, so a reply with an em dash is blocked
  before it posts. Restructure, do not retry.
