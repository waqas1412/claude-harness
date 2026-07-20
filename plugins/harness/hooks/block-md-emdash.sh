#!/bin/sh
# PreToolUse: block an em dash (U+2014) in authored content.
#   Write|Edit: authored markdown (*.md content/new_string); MEMORY.md exempt (its list delimiter).
#   Bash: the rule's other named targets authored through the shell (commit / PR / issue bodies),
#         scoped to git commit and gh pr|issue create|edit so a plain cat/grep of an em-dash file is
#         not blocked. --body-file/-F/commit-template routes the text through a file the Write|Edit
#         path already guards; see SECURITY.md for that residual.
# Rule: no em dashes in authored prose/docs; en dash in numeric ranges is fine.
# Matches by UTF-8 byte sequence (E2 80 94) under LC_ALL=C so it is locale-proof.
input=$(cat)
emdash=$(printf '\342\200\224')
tool=$(printf '%s' "$input" | jq -r '.tool_name // ""')
case "$tool" in
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
    case "$cmd" in
      *"git commit"*|*"gh pr create"*|*"gh pr edit"*|*"gh issue create"*|*"gh issue edit"*)
        if printf '%s' "$cmd" | LC_ALL=C grep -q "$emdash"; then
          echo "Blocked: em dash in a commit/PR/issue body authored via Bash; restructure with commas, colons, or parentheses (en dash in numeric ranges is fine)." >&2
          exit 2
        fi
        ;;
    esac
    ;;
  *)
    fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
    [ "$(basename "$fp")" = "MEMORY.md" ] && exit 0
    case "$fp" in
      *.md)
        text=$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // ""')
        if printf '%s' "$text" | LC_ALL=C grep -q "$emdash"; then
          echo "Blocked: em dash in authored markdown; restructure with commas, colons, or parentheses (en dash in numeric ranges is fine)." >&2
          exit 2
        fi
        ;;
    esac
    ;;
esac
exit 0
