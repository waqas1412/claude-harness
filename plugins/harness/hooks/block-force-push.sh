#!/bin/sh
# PreToolUse / Bash: block a bare `git push --force` / `git push -f`.
# Rule: force-with-lease only; --force-with-lease and --force-if-includes stay allowed.
#
# Two scoping rules, both learned from real false positives:
#   1. Judge each shell segment on its own, not the whole command line. Scanning the whole line made
#      `git push origin main; rm -f /tmp/x` look like a force push because of the `rm -f`.
#   2. A segment counts only if it BEGINS with a git push invocation (after optional VAR=val
#      assignments and git's own -c/-C style options). Merely containing the words made
#      `git commit -m "... git push ... -f ..."` look like a force push because of the prose.
# A regex cannot fully parse shell, so a segment that genuinely starts with `git push -f` inside a
# quoted string is still blocked. That is the safe direction to be wrong in: reword and retry.
cmd=$(jq -r '.tool_input.command // ""')

PUSH_START='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git[[:space:]]+(-[cC][[:space:]]+[^[:space:]]+[[:space:]]+|--[a-z-]+(=[^[:space:]]*)?[[:space:]]+)*push([[:space:]]|$)'
FORCE_FLAG='(^|[[:space:]])--force([[:space:]]|=|$)|(^|[[:space:]])-[a-zA-Z0-9]*f[a-zA-Z0-9]*([[:space:]]|$)'

offending=$(printf '%s' "$cmd" | tr ';&|' '\n\n\n' \
  | LC_ALL=C grep -E "$PUSH_START" \
  | LC_ALL=C grep -vE -- '--force-with-lease|--force-if-includes' \
  | LC_ALL=C grep -E -- "$FORCE_FLAG")

if [ -n "$offending" ]; then
  echo "Blocked: no bare git push --force/-f. Use --force-with-lease (or --force-if-includes)." >&2
  printf '  offending segment: %s\n' "$(printf '%s' "$offending" | head -1 | cut -c1-160)" >&2
  exit 2
fi
exit 0
