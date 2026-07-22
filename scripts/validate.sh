#!/usr/bin/env bash
#
# Structural validator for claude-harness. Runs from anywhere; exits non-zero on any failure.
# Checks (low false-positive, additive): manifests parse, version consistency, agent frontmatter
# + read-only-tools invariant + valid model tier + Boundaries deferral graph resolves, skill
# frontmatter, hooks.json references resolve, and shell syntax/shellcheck of every script.
#
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/plugins/harness"; AGENTS="$PLUGIN/agents"; SKILLS="$PLUGIN/skills"; HOOKS="$PLUGIN/hooks"
FAILS=0
SYNTAX_ONLY=0
err()  { printf 'FAIL  %s\n' "$1" >&2; FAILS=$((FAILS + 1)); }
warn() { printf 'WARN  %s\n' "$1" >&2; }
ok()   { printf 'ok    %s\n' "$1"; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

fm()    { awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit} f{print}' "$1"; }
fmval() { fm "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1 | sed 's/^"//; s/"$//'; }
is_in() { local n="$1"; shift; for x in "$@"; do [ "$x" = "$n" ] && return 0; done; return 1; }

echo "== manifests parse =="
for f in "$ROOT/.claude-plugin/marketplace.json" "$PLUGIN/.claude-plugin/plugin.json" "$HOOKS/hooks.json"; do
  if jq -e . "$f" >/dev/null 2>&1; then ok "json ${f#"$ROOT"/}"; else err "invalid json ${f#"$ROOT"/}"; fi
done

echo "== version consistency =="
vf=$(tr -d ' \t\n\r' < "$ROOT/VERSION")
vp=$(jq -r '.version' "$PLUGIN/.claude-plugin/plugin.json")
vm=$(jq -r '.plugins[0].version' "$ROOT/.claude-plugin/marketplace.json")
if [ "$vf" = "$vp" ] && [ "$vf" = "$vm" ]; then ok "version $vf consistent (VERSION/plugin/marketplace)"
else err "version mismatch: VERSION=$vf plugin=$vp marketplace=$vm"; fi

echo "== agents =="
agent_slugs=$(for f in "$AGENTS"/*.md; do basename "$f" .md; done | sort)
RO_TOOLS="Read Grep Glob Bash WebFetch WebSearch"
MODELS="sonnet opus haiku fable"
for f in "$AGENTS"/*.md; do
  name=$(basename "$f" .md)
  [ -n "$(fmval "$f" name)" ] || err "$name: missing 'name'"
  [ -n "$(fmval "$f" description)" ] || err "$name: missing 'description'"
  [ "$(fmval "$f" name)" = "$name" ] || err "$name: frontmatter name != filename"
  tl=$(fmval "$f" tools)
  if [ -n "$tl" ]; then
    bad=""
    for t in $(echo "$tl" | tr ',' ' '); do is_in "$t" $RO_TOOLS || bad="$bad $t"; done
    [ -z "$bad" ] && ok "$name: tools read-only" || err "$name: non-read-only tools:$bad"
  fi
  ml=$(fmval "$f" model)
  if [ -n "$ml" ]; then is_in "$ml" $MODELS && ok "$name: model $ml" || err "$name: invalid model '$ml'"; fi
  # Only treat hyphenated tokens ending in a known advisor role-suffix as agent references, so
  # ordinary prose ("use multi-step", "use red-green") cannot false-fail CI.
  for ref in $(grep -oE 'use [a-z-]+-(architect|designer|reviewer|optimizer|engineer|advisor|researcher|author|auditor)' "$f" | sed 's/^use //' | sort -u); do
    is_in "$ref" $agent_slugs || err "$name: dangling agent reference '$ref'"
  done
done
ok "agents scanned: $(echo "$agent_slugs" | wc -w | tr -d ' ')"

echo "== skills =="
RO_SKILLS="pr ticket orchestrate workspace-init refresh-seams"
for d in "$SKILLS"/*/; do
  s=$(basename "$d"); f="$d/SKILL.md"
  [ -f "$f" ] || { err "skill $s: missing SKILL.md"; continue; }
  [ "$(fmval "$f" name)" = "$s" ] || err "skill $s: name != dirname"
  [ -n "$(fmval "$f" description)" ] || err "skill $s: missing description"
  at=$(fmval "$f" allowed-tools)
  [ -n "$at" ] || err "skill $s: missing allowed-tools"
  if is_in "$s" $RO_SKILLS; then
    for t in $(echo "$at" | tr ',' ' '); do
      { [ "$t" = "Write" ] || [ "$t" = "Edit" ]; } && warn "skill $s: read-only skill lists mutating tool '$t'"
    done
  fi
  ok "skill $s"
done

echo "== hooks.json references resolve =="
for s in $(jq -r '((.hooks.PreToolUse // []) + (.hooks.PostToolUse // [])) | .[].hooks[].command' "$HOOKS/hooks.json" | grep -oE '(block-[a-z-]+\.sh|filter-verbose-output\.py)' | sort -u); do
  [ -f "$HOOKS/$s" ] && ok "hook $s present" || err "hooks.json references missing $s"
done

echo "== hooks tested =="
for f in "$HOOKS"/block-*.sh "$HOOKS"/filter-verbose-output.py; do
  b=$(basename "$f")
  grep -q "$b" "$ROOT/tests/run-hook-tests.sh" && ok "hook $b has behavioral test" || err "hook $b has no behavioral test"
done

echo "== python lint =="
if command -v python3 >/dev/null 2>&1; then
  for p in plugins/harness/hooks/filter-verbose-output.py; do
    [ -f "$ROOT/$p" ] && { python3 -m py_compile "$ROOT/$p" 2>/dev/null && ok "py_compile $p" || err "python syntax error $p"; }
  done
else
  warn "python3 absent: skipped python hook syntax check"
fi

echo "== shell lint =="
BASH_FILES="install.sh uninstall.sh scripts/validate.sh scripts/bump-version.sh tests/run-hook-tests.sh"
SH_FILES="plugins/harness/hooks/block-coauthor.sh plugins/harness/hooks/block-pr-reviewer.sh plugins/harness/hooks/block-md-emdash.sh plugins/harness/skills/harness-init/assets/verify-generated.sh plugins/harness/skills/refresh-seams/assets/verify-map.sh"
for b in $BASH_FILES; do [ -f "$ROOT/$b" ] && { bash -n "$ROOT/$b" 2>/dev/null && ok "bash -n $b" || err "syntax error $b"; }; done
for s in $SH_FILES; do [ -f "$ROOT/$s" ] && { sh -n "$ROOT/$s" 2>/dev/null && ok "sh -n $s" || err "syntax error $s"; }; done
if command -v shellcheck >/dev/null 2>&1; then
  for f in $BASH_FILES $SH_FILES; do [ -f "$ROOT/$f" ] && { shellcheck -S error "$ROOT/$f" >/dev/null 2>&1 && ok "shellcheck $f" || err "shellcheck errors in $f"; }; done
else
  SYNTAX_ONLY=1
  warn "shellcheck absent: lint grade reduced to syntax-only; CI runs the full lint"
fi

echo
if [ "$FAILS" -eq 0 ]; then
  if [ "$SYNTAX_ONLY" -eq 1 ]; then echo "VALIDATION PASSED (syntax-only lint; shellcheck absent)"; else echo "VALIDATION PASSED"; fi
  exit 0
else echo "VALIDATION FAILED ($FAILS issue(s))"; exit 1; fi
