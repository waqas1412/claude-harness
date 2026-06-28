#!/bin/sh
# PreToolUse / Bash: block `gh pr create` / `gh pr edit` that pass a reviewer flag.
# Rule: open PRs with title/body/base only; request reviews yourself.
cmd=$(jq -r '.tool_input.command // ""')
case "$cmd" in
  *"gh pr create"*|*"gh pr edit"*)
    if printf '%s' "$cmd" | grep -qE -- '--reviewer|--add-reviewer'; then
      echo "Blocked: no --reviewer on gh pr create/edit. Request reviews yourself." >&2
      exit 2
    fi
    ;;
esac
case "$cmd" in
  *"gh api"*requested_reviewers*)
    # Block only writes (a non-GET method or field flags); allow read-only GET.
    if printf '%s' "$cmd" | grep -qiE -- '(--method[ =]|-X[ =]?)(post|put|patch|delete)|(^|[[:space:]])(-f|-F|--field|--raw-field|--input)([[:space:]]|=)'; then
      echo "Blocked: no requested_reviewers mutation via gh api. Request reviews yourself." >&2
      exit 2
    fi
    ;;
esac
exit 0
