#!/bin/sh
#
# Deterministic self-verify core shared by /harness-init and /workspace-init Phase 7.
# Given the generated file paths as arguments, it runs only the unambiguous mechanical checks:
# every backtick-quoted path exists, no U+2014 em dash, and harness markers balance per file. It
# prints one machine-readable RESULT line and exits non-zero on any failure. The judgment-bearing
# checks (frontmatter, targets-matches-a-real-file, slug prefix) stay in each skill's prose.
#
# Usage: sh verify-generated.sh <file> [<file> ...]
# Backtick paths are resolved against the current working directory (the target repo root).
#
set -u
export LC_ALL=C
EM=$(printf '\342\200\224')

# Return 0 if the token (a literal path or a glob) matches at least one existing entry. An
# unmatched glob stays literal under POSIX, so a nonexistent path also fails here.
glob_matches() {
  for _g in $1; do
    [ -e "$_g" ] && return 0
  done
  return 1
}

if [ "$#" -eq 0 ]; then
  echo "verify-generated: no files given" >&2
  echo "RESULT fail verified=0 missing=0 emdash=0 markers_unbalanced=0"
  exit 2
fi

verified=0
missing=0
emdash=0
unbalanced=0
missing_list=""

for f in "$@"; do
  if [ ! -f "$f" ]; then
    echo "verify-generated: not a file: $f" >&2
    missing=$((missing + 1))
    missing_list="$missing_list $f"
    continue
  fi

  grep -q "$EM" "$f" && emdash=$((emdash + 1))

  s=$(grep -c '<!-- harness:start -->' "$f")
  e=$(grep -c '<!-- harness:end -->' "$f")
  [ "$s" = "$e" ] || unbalanced=$((unbalanced + 1))

  for tok in $(grep -oE '`[^`]+`' "$f" | tr -d '`'); do
    case "$tok" in
      *'{'*|*'}'*|*'<'*|*'>'*|*'$'*|*'|'*|*'('*|*')'*) continue ;;
      */*) : ;;
      *) continue ;;
    esac
    if glob_matches "$tok"; then
      verified=$((verified + 1))
    else
      missing=$((missing + 1))
      missing_list="$missing_list $tok"
    fi
  done
done

fail=0
[ "$missing" -gt 0 ] && fail=1
[ "$emdash" -gt 0 ] && fail=1
[ "$unbalanced" -gt 0 ] && fail=1

[ -n "$missing_list" ] && echo "missing:$missing_list" >&2

result=pass
[ "$fail" -eq 0 ] || result=fail
echo "RESULT $result verified=$verified missing=$missing emdash=$emdash markers_unbalanced=$unbalanced"
exit "$fail"
