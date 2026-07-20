#!/usr/bin/env bash
#
# Behavioral tests for the enforcement hooks: pipe crafted tool-call JSON into each block-*.sh and
# assert the exit code (2 = blocked, 0 = allowed). Proves the deny logic, not just that the file is
# wired. install.sh --check reuses the same crafted payloads against the INSTALLED hooks.
#
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="${HARNESS_HOOKS_DIR:-$ROOT/plugins/harness/hooks}"
PASS=0; FAIL=0
EM="$(printf '\342\200\224')"

run() { # desc hook want json
  local desc="$1" hook="$2" want="$3" json="$4" got
  printf '%s' "$json" | sh "$HOOKS/$hook" >/dev/null 2>&1; got=$?
  if [ "$got" = "$want" ]; then PASS=$((PASS + 1)); printf 'PASS  %-46s exit %s\n' "$desc" "$got"
  else FAIL=$((FAIL + 1)); printf 'FAIL  %-46s exit %s (want %s)\n' "$desc" "$got" "$want"; fi
}

# block-coauthor
run "coauthor: trailer present blocks" block-coauthor.sh 2 '{"tool_input":{"command":"git commit -m \"x\n\nCo-Authored-By: A <a@b.c>\""}}'
run "coauthor: --trailer flag blocks"  block-coauthor.sh 2 '{"tool_input":{"command":"git commit --trailer \"Co-authored-by: A <a@b.c>\""}}'
run "coauthor: clean commit passes"    block-coauthor.sh 0 '{"tool_input":{"command":"git commit -m \"normal message\""}}'
run "coauthor: prose mention passes"   block-coauthor.sh 0 '{"tool_input":{"command":"git commit -m \"refactor the co-authored-by parser\""}}'
run "coauthor: non-commit passes"      block-coauthor.sh 0 '{"tool_input":{"command":"git status"}}'

# block-pr-reviewer
run "reviewer: --reviewer blocks"          block-pr-reviewer.sh 2 '{"tool_input":{"command":"gh pr create --title t --body b --reviewer alice"}}'
run "reviewer: --reviewer= equals-form blocks" block-pr-reviewer.sh 2 '{"tool_input":{"command":"gh pr create --reviewer=alice"}}'
run "reviewer: --add-reviewer blocks"      block-pr-reviewer.sh 2 '{"tool_input":{"command":"gh pr edit 1 --add-reviewer bob"}}'
run "reviewer: --add-reviewer= equals-form blocks" block-pr-reviewer.sh 2 '{"tool_input":{"command":"gh pr edit 1 --add-reviewer=bob"}}'
run "reviewer: requested_reviewers write blocks"  block-pr-reviewer.sh 2 '{"tool_input":{"command":"gh api repos/o/r/pulls/1/requested_reviewers -f reviewers[]=x"}}'
run "reviewer: requested_reviewers DELETE blocks" block-pr-reviewer.sh 2 '{"tool_input":{"command":"gh api -X DELETE repos/o/r/pulls/1/requested_reviewers"}}'
run "reviewer: requested_reviewers GET passes"    block-pr-reviewer.sh 0 '{"tool_input":{"command":"gh api repos/o/r/pulls/1/requested_reviewers"}}'
run "reviewer: clean create passes"        block-pr-reviewer.sh 0 '{"tool_input":{"command":"gh pr create --title t --body b --base main"}}'

# block-force-push
run "force-push: --force blocks"           block-force-push.sh 2 '{"tool_input":{"command":"git push --force"}}'
run "force-push: -f short flag blocks"     block-force-push.sh 2 '{"tool_input":{"command":"git push -f origin main"}}'
run "force-push: --force-with-lease passes" block-force-push.sh 0 '{"tool_input":{"command":"git push --force-with-lease origin main"}}'
run "force-push: --force-if-includes passes" block-force-push.sh 0 '{"tool_input":{"command":"git push --force-if-includes"}}'
run "force-push: plain push passes"        block-force-push.sh 0 '{"tool_input":{"command":"git push origin main"}}'
run "force-push: non-push -f ignored"      block-force-push.sh 0 '{"tool_input":{"command":"grep -f pattern file"}}'
run "force-push: commit mentioning force push passes" block-force-push.sh 0 '{"tool_input":{"command":"git commit -m \"force push\""}}'

# block-md-emdash
run "emdash: em dash in .md blocks"   block-md-emdash.sh 2 "$(printf '{"tool_input":{"file_path":"/x/a.md","content":"alpha %s beta"}}' "$EM")"
run "emdash: clean .md passes"        block-md-emdash.sh 0 '{"tool_input":{"file_path":"/x/a.md","content":"alpha, beta"}}'
run "emdash: MEMORY.md exempt"        block-md-emdash.sh 0 "$(printf '{"tool_input":{"file_path":"/x/MEMORY.md","content":"a %s b"}}' "$EM")"
run "emdash: non-md ignored"          block-md-emdash.sh 0 "$(printf '{"tool_input":{"file_path":"/x/a.txt","content":"a %s b"}}' "$EM")"
run "emdash: Edit new_string blocks"  block-md-emdash.sh 2 "$(printf '{"tool_input":{"file_path":"/x/a.md","new_string":"a %s b"}}' "$EM")"
run "emdash: Bash git commit blocks"  block-md-emdash.sh 2 "$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m fix%sready"}}' "$EM")"
run "emdash: Bash gh pr create blocks" block-md-emdash.sh 2 "$(printf '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title t --body a%sb"}}' "$EM")"
run "emdash: Bash gh issue edit blocks" block-md-emdash.sh 2 "$(printf '{"tool_name":"Bash","tool_input":{"command":"gh issue edit 1 --body a%sb"}}' "$EM")"
run "emdash: Bash cat em-dash file passes" block-md-emdash.sh 0 "$(printf '{"tool_name":"Bash","tool_input":{"command":"cat notes%s.md"}}' "$EM")"
run "emdash: Bash non-authoring passes" block-md-emdash.sh 0 "$(printf '{"tool_name":"Bash","tool_input":{"command":"git status %s"}}' "$EM")"
run "emdash: Bash clean commit passes" block-md-emdash.sh 0 '{"tool_name":"Bash","tool_input":{"command":"git commit -m clean-message"}}'

# verify-generated.sh (shared Phase 7 self-verify core: pass on a real path, fail on an invented one)
vg() { # desc want file
  local desc="$1" want="$2" file="$3" got
  ( cd "$ROOT" && sh "$ROOT/plugins/harness/skills/harness-init/assets/verify-generated.sh" "$file" ) >/dev/null 2>&1; got=$?
  if { [ "$want" = 0 ] && [ "$got" = 0 ]; } || { [ "$want" != 0 ] && [ "$got" != 0 ]; }; then
    PASS=$((PASS + 1)); printf 'PASS  %-46s exit %s\n' "$desc" "$got"
  else FAIL=$((FAIL + 1)); printf 'FAIL  %-46s exit %s (want %s)\n' "$desc" "$got" "$want"; fi
}
VGTMP="$(mktemp -d)"
trap 'rm -rf "$VGTMP"' EXIT
printf 'see `%s` for the wiring\n' "plugins/harness/hooks/hooks.json" > "$VGTMP/good.md"
printf 'points at `%s`\n' "plugins/harness/does-not-exist.md" > "$VGTMP/bad.md"
vg "verify-generated: real path passes"    0 "$VGTMP/good.md"
vg "verify-generated: invented path fails" 1 "$VGTMP/bad.md"

echo
echo "hook tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
