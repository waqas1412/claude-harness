#!/bin/sh
# PreToolUse: block an em dash (U+2014) in authored content.
#   Write|Edit: authored markdown (*.md content/new_string); MEMORY.md exempt (its list delimiter).
#   Bash: the rule's other named targets authored through the shell, scoped to the commands that
#         publish prose: git commit, gh pr|issue create|edit|comment, gh pr review, gh api, and
#         Confluence REST publishes (wiki/rest/api/content, wiki/api/v2/pages, atlassian.net).
#         --body-file/-F/commit-template routes the text through a file the Write|Edit path already
#         guards; see SECURITY.md for that residual.
# Rule: no em dashes in authored prose/docs; en dash in numeric ranges is fine.
# Matches by UTF-8 byte sequence (E2 80 94) under LC_ALL=C so it is locale-proof.
# On a block, report WHERE: the first offending line numbers, with the em dash marked, so the fix is
# one edit and not a hunt.
input=$(cat)
emdash=$(printf '\342\200\224')
tool=$(printf '%s' "$input" | jq -r '.tool_name // ""')

# Print up to 3 offending lines of "$1", labelled by "$2", with the em dash marked.
report_hits() {
  printf '%s' "$1" | LC_ALL=C grep -n "$emdash" 2>/dev/null | head -3 | while IFS= read -r hit; do
    printf '  %s: %s\n' "$2" "$(printf '%s' "$hit" | sed "s/$emdash/<<EMDASH>>/g" | cut -c1-160)" >&2
  done
  n=$(printf '%s' "$1" | LC_ALL=C grep -c "$emdash" 2>/dev/null)
  [ "$n" -gt 3 ] && printf '  (%s offending lines total)\n' "$n" >&2
  return 0
}

case "$tool" in
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
    case "$cmd" in
      *"git commit"*|\
      *"gh pr create"*|*"gh pr edit"*|*"gh pr comment"*|*"gh pr review"*|\
      *"gh issue create"*|*"gh issue edit"*|*"gh issue comment"*|\
      *"gh api"*|\
      *"wiki/rest/api/content"*|*"wiki/api/v2/pages"*|*"atlassian.net"*)
        if printf '%s' "$cmd" | LC_ALL=C grep -q "$emdash"; then
          echo "Blocked: em dash in prose published via Bash (commit, PR/issue body or comment, or Confluence page). Restructure with commas, colons, or parentheses (en dash in numeric ranges is fine)." >&2
          report_hits "$cmd" "command line"
          exit 2
        fi
        ;;
    esac
    ;;
  *)
    fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
    [ "$(basename "$fp")" = "MEMORY.md" ] && exit 0
    case "$fp" in
      *.md|*.mdx|*.txt|*.markdown)
        field=content
        text=$(printf '%s' "$input" | jq -r '.tool_input.content // empty')
        if [ -z "$text" ]; then
          field=new_string
          text=$(printf '%s' "$input" | jq -r '.tool_input.new_string // ""')
        fi
        if printf '%s' "$text" | LC_ALL=C grep -q "$emdash"; then
          echo "Blocked: em dash in authored markdown; restructure with commas, colons, or parentheses (en dash in numeric ranges is fine)." >&2
          report_hits "$text" "$field line"
          exit 2
        fi
        ;;
    esac
    ;;
esac
exit 0
