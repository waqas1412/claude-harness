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
exit 0
