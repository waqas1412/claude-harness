#!/bin/sh
# PreToolUse / Bash: block a bare `git push --force` / `git push -f`.
# Rule: force-with-lease only; --force-with-lease and --force-if-includes stay allowed.
cmd=$(jq -r '.tool_input.command // ""')

# Only guard real `git push` invocations (git and push inside one command segment).
if ! printf '%s' "$cmd" | LC_ALL=C grep -qE '\bgit\b[^;&|]*\bpush\b'; then
  exit 0
fi

# The lease-guarded pushes are the prescribed safe form; always allow.
if printf '%s' "$cmd" | LC_ALL=C grep -qE -- '--force-with-lease|--force-if-includes'; then
  exit 0
fi

# Block a bare long --force or a -f short flag used in the push context.
if printf '%s' "$cmd" | LC_ALL=C grep -qE -- '(^|[[:space:]])--force([[:space:]]|=|$)|(^|[[:space:]])-[a-zA-Z0-9]*f[a-zA-Z0-9]*([[:space:]]|$)'; then
  echo "Blocked: no bare git push --force/-f. Use --force-with-lease (or --force-if-includes)." >&2
  exit 2
fi
exit 0
