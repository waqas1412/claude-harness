#!/bin/sh
# PreToolUse (Bash): keep local-only references out of anything a colleague reads.
# Scoped to the commands that PUBLISH prose, mirroring block-md-emdash.sh: git commit, gh pr/issue
# create|edit|comment|review, gh api, and Confluence REST publishes. A local path is fine in chat and
# fine in a local file; it is not fine in a commit message, a PR body, a ticket, or a wiki page.
# Tracker keys, live Jira and Confluence URLs, and repo-relative paths are all allowed.
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[ -z "$cmd" ] && exit 0

# Decide "is this really a publish invocation" from the command with quoted STRING BODIES removed, so a
# command that merely mentions `gh pr create` inside an argument (a grep, a test, an echo) is not treated
# as publishing. The prose scan below still runs against the full command, since the prose lives in quotes.
outer=$(printf '%s' "$cmd" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g")
case "$outer" in
  *"git commit"*|\
  *"gh pr create"*|*"gh pr edit"*|*"gh pr comment"*|*"gh pr review"*|\
  *"gh issue create"*|*"gh issue edit"*|*"gh issue comment"*|\
  *"gh api"*|\
  *"wiki/rest/api/content"*|*"wiki/api/v2/pages"*|*"atlassian.net"*) ;;
  *) exit 0 ;;
esac

hit=""
printf '%s' "$cmd" | grep -q '/Users/' && hit="an absolute /Users/ path"
printf '%s' "$cmd" | grep -Eq '(^|[^a-zA-Z0-9_/.-])kb/' && hit="${hit:+$hit, }a kb/ knowledge-base path"
printf '%s' "$cmd" | grep -qi 'fetched locally' && hit="${hit:+$hit, }\"fetched locally\" narration"
printf '%s' "$cmd" | grep -Eq '\.claude/(repo-index|meta|harness)/' && hit="${hit:+$hit, }a local harness path"

if [ -n "$hit" ]; then
  echo "Blocked: $hit in prose being published where a colleague reads it." >&2
  echo "Drop the local-only reference. Tracker keys, live Jira and Confluence URLs, and repo-relative paths (src/..., packages/app/src/...) are fine." >&2
  printf '%s' "$cmd" | grep -nE '/Users/|(^|[^a-zA-Z0-9_/.-])kb/|[Ff]etched locally|\.claude/(repo-index|meta|harness)/' | head -3 | cut -c1-160 | sed 's/^/  /' >&2
  exit 2
fi
exit 0
