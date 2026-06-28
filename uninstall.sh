#!/usr/bin/env bash
#
# claude-harness uninstaller. Removes only what install.sh added; backs up before deleting.
# Leaves your personal prefs and permission allow-rules in settings.json (edit those by hand).
#
# Usage: ./uninstall.sh         (CLAUDE_HOME overridable, default ~/.claude)

set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
TS="$(date +%Y%m%d%H%M%S)"
note() { printf '  %s\n' "$1"; }

echo "Uninstalling claude-harness from $CLAUDE_HOME"

# Agents: remove only files this package shipped (match by basename).
for f in "$SRC"/plugins/harness/agents/*.md; do
  [ -e "$f" ] || continue
  t="$CLAUDE_HOME/agents/$(basename "$f")"
  [ -f "$t" ] && { mv "$t" "$t.bak.$TS"; note "removed agent $(basename "$f") (backup kept)"; }
done

# Skills shipped by this package.
for name in harness-init pr ticket; do
  d="$CLAUDE_HOME/skills/$name"
  [ -d "$d" ] && { mv "$d" "$d.bak.$TS"; note "removed skill $name (backup kept)"; }
done

# Hooks.
for s in block-coauthor block-pr-reviewer block-md-emdash; do
  t="$CLAUDE_HOME/hooks/$s.sh"
  [ -f "$t" ] && { mv "$t" "$t.bak.$TS"; note "removed hook $s.sh (backup kept)"; }
done

# CLAUDE.md: strip the managed marker block, keep the rest.
target="$CLAUDE_HOME/CLAUDE.md"
if [ -f "$target" ] && grep -q '<!-- harness:start -->' "$target"; then
  tmp="$(mktemp)"
  awk '
    $0 ~ /<!-- harness:start -->/ { skip=1; next }
    $0 ~ /<!-- harness:end -->/   { skip=0; next }
    skip != 1 { print }
  ' "$target" > "$tmp"
  cp "$target" "$target.bak.$TS"; mv "$tmp" "$target"; note "removed managed block from CLAUDE.md (backup kept)"
fi

# settings.json: unwire the harness hooks (their scripts are gone); leave prefs/permissions.
settings="$CLAUDE_HOME/settings.json"
if [ -f "$settings" ] && command -v jq >/dev/null 2>&1; then
  tmp="$(mktemp)"
  jq '
    if .hooks.PreToolUse then
      .hooks.PreToolUse |= ( map(
        .hooks |= ((. // []) | map(select((.command // "") | test("/hooks/block-") | not)))
      ) | map(select((.hooks // []) | length > 0)) )
    else . end
  ' "$settings" > "$tmp" && { cp "$settings" "$settings.bak.$TS"; mv "$tmp" "$settings"; note "unwired harness hooks from settings.json (backup kept)"; }
fi

echo
echo "Done. Personal prefs and permission allow-rules were left in place; edit settings.json to remove them if you want."
