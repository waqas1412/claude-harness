#!/bin/sh
#
# Deterministic Phase 5 self-verify for /refresh-seams, run AFTER Phase 4 draws the map.
# It (1) sweeps .claude/meta/*, .claude/repo-index/*.md and the root CLAUDE.md for U+2014, (2) test -e
# every backtick path in .claude/meta/integration-map.md after stripping mermaid-fenced blocks and
# any :line suffix, and (3) checks that seams:start and seams:end markers balance in every rules
# file. It prints one machine-readable RESULT line and exits non-zero on any failure.
#
# It intentionally does NOT reuse verify-generated.sh: that script counts harness: markers and has
# no mermaid exclusion, whereas the seam map uses seams: markers and embeds mermaid node/edge labels
# that would false-positive as missing paths.
#
# Usage: sh verify-map.sh   (run from the workspace root)
#
set -u
export LC_ALL=C
EM=$(printf '\342\200\224')

MAP=".claude/meta/integration-map.md"

verified=0
missing=0
emdash=0
unbalanced=0
missing_list=""

# (1) em-dash sweep over the generated meta files, the rules files, and the root index.
for f in .claude/meta/* .claude/repo-index/*.md CLAUDE.md; do
  [ -f "$f" ] || continue
  if grep -q "$EM" "$f"; then
    emdash=$((emdash + 1))
    echo "emdash: $f" >&2
  fi
done

# (3) seams marker balance in every rules file.
for f in .claude/repo-index/*.md; do
  [ -f "$f" ] || continue
  s=$(grep -c '<!-- seams:start -->' "$f")
  e=$(grep -c '<!-- seams:end -->' "$f")
  [ "$s" = "$e" ] || { unbalanced=$((unbalanced + 1)); echo "unbalanced: $f ($s/$e)" >&2; }
done

# (2) backtick-path existence in the map, excluding mermaid-fenced blocks (whose node/edge labels
# are not file paths). Strip any :line suffix, then apply the same token filter as verify-generated.
if [ -f "$MAP" ]; then
  stripped=$(awk '
    /^```mermaid/ { infence=1; next }
    /^```/ { if (infence) { infence=0; next } }
    !infence { print }
  ' "$MAP")
  for raw in $(printf '%s\n' "$stripped" | grep -oE '`[^`]+`' | tr -d '`'); do
    tok=${raw%%:*}
    case "$tok" in
      *'{'*|*'}'*|*'<'*|*'>'*|*'$'*|*'|'*|*'('*|*')'*|*'*'*|*'['*|*']'*) continue ;;
      */*) : ;;
      *) continue ;;
    esac
    if [ -e "$tok" ]; then
      verified=$((verified + 1))
    else
      missing=$((missing + 1))
      missing_list="$missing_list $tok"
    fi
  done
fi

fail=0
[ "$missing" -gt 0 ] && fail=1
[ "$emdash" -gt 0 ] && fail=1
[ "$unbalanced" -gt 0 ] && fail=1

[ -n "$missing_list" ] && echo "missing:$missing_list" >&2

result=pass
[ "$fail" -eq 0 ] || result=fail
echo "RESULT $result verified=$verified missing=$missing emdash=$emdash markers_unbalanced=$unbalanced"
exit "$fail"
