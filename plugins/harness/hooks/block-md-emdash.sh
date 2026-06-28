#!/bin/sh
# PreToolUse / Write|Edit: block an em dash (U+2014) in authored markdown.
# Rule: no em dashes in authored prose/docs; en dash in numeric ranges is fine.
# Matches by UTF-8 byte sequence (E2 80 94) under LC_ALL=C so it is locale-proof.
input=$(cat)
fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')
# Exempt the auto-memory index: it uses the em dash as its list delimiter (rule-exempt).
[ "$(basename "$fp")" = "MEMORY.md" ] && exit 0
case "$fp" in
  *.md)
    text=$(printf '%s' "$input" | jq -r '.tool_input.content // .tool_input.new_string // ""')
    emdash=$(printf '\342\200\224')
    if printf '%s' "$text" | LC_ALL=C grep -q "$emdash"; then
      echo "Blocked: em dash in authored markdown; restructure with commas, colons, or parentheses (en dash in numeric ranges is fine)." >&2
      exit 2
    fi
    ;;
esac
exit 0
