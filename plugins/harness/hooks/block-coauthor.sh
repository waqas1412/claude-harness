#!/bin/sh
# PreToolUse / Bash: block `git commit` whose message carries a Co-Authored-By trailer.
# Rule: sole author; never add a Co-Authored-By trailer.
cmd=$(jq -r '.tool_input.command // ""')
case "$cmd" in
  *"git commit"*)
    if printf '%s' "$cmd" | grep -qi 'Co-Authored-By'; then
      echo "Blocked: no Co-Authored-By trailer (sole author). See commit-authorship rule." >&2
      exit 2
    fi
    ;;
esac
exit 0
