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
# the flag search is scoped to the git push SEGMENT: an unrelated -f elsewhere on the line is not a
# force push. Whole-line scanning blocked all four of these.
run "force-push: push then unrelated rm -f passes"  block-force-push.sh 0 '{"tool_input":{"command":"git push origin main; rm -f /tmp/x"}}'
run "force-push: rm -f then push passes"            block-force-push.sh 0 '{"tool_input":{"command":"rm -f /tmp/x && git push origin main"}}'
run "force-push: push piped to tail -f passes"      block-force-push.sh 0 '{"tool_input":{"command":"git push origin main 2>&1 | tail -f"}}'
run "force-push: push with -c flag passes"           block-force-push.sh 0 '{"tool_input":{"command":"git -c credential.helper= push origin main"}}'
# but a real force in its own segment still blocks, even beside an innocent segment
run "force-push: force in its own segment blocks"   block-force-push.sh 2 '{"tool_input":{"command":"echo ok && git push -f origin main"}}'
run "force-push: lease beside unrelated -f passes"  block-force-push.sh 0 '{"tool_input":{"command":"git push --force-with-lease origin main; rm -f /tmp/x"}}'
# a segment counts only if it BEGINS with a push invocation, so prose that merely mentions one is safe
run "force-push: commit prose naming push and -f passes" block-force-push.sh 0 '{"tool_input":{"command":"git commit -m \\"fix: git push -f scanning was too broad, hit on rm -f /tmp/x\\""}}'
run "force-push: env prefix before push blocks"      block-force-push.sh 2 '{"tool_input":{"command":"GIT_ASKPASS=/tmp/a git push -f origin main"}}'
run "force-push: echo mentioning push -f passes"     block-force-push.sh 0 '{"tool_input":{"command":"echo \\"never run git push -f\\""}}'

# block-md-emdash
run "emdash: em dash in .md blocks"   block-md-emdash.sh 2 "$(printf '{"tool_input":{"file_path":"/x/a.md","content":"alpha %s beta"}}' "$EM")"
run "emdash: clean .md passes"        block-md-emdash.sh 0 '{"tool_input":{"file_path":"/x/a.md","content":"alpha, beta"}}'
run "emdash: MEMORY.md exempt"        block-md-emdash.sh 0 "$(printf '{"tool_input":{"file_path":"/x/MEMORY.md","content":"a %s b"}}' "$EM")"
run "emdash: code file ignored"       block-md-emdash.sh 0 "$(printf '{"tool_input":{"file_path":"/x/a.ts","content":"const s = \\"a %s b\\";"}}' "$EM")"
run "emdash: .txt covered"            block-md-emdash.sh 2 "$(printf '{"tool_input":{"file_path":"/x/body.txt","content":"a %s b"}}' "$EM")"
run "emdash: .mdx covered"            block-md-emdash.sh 2 "$(printf '{"tool_input":{"file_path":"/x/a.mdx","content":"a %s b"}}' "$EM")"
run "emdash: Edit new_string blocks"  block-md-emdash.sh 2 "$(printf '{"tool_input":{"file_path":"/x/a.md","new_string":"a %s b"}}' "$EM")"
run "emdash: Bash git commit blocks"  block-md-emdash.sh 2 "$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m fix%sready"}}' "$EM")"
run "emdash: Bash gh pr create blocks" block-md-emdash.sh 2 "$(printf '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title t --body a%sb"}}' "$EM")"
run "emdash: Bash gh issue edit blocks" block-md-emdash.sh 2 "$(printf '{"tool_name":"Bash","tool_input":{"command":"gh issue edit 1 --body a%sb"}}' "$EM")"
run "emdash: Bash cat em-dash file passes" block-md-emdash.sh 0 "$(printf '{"tool_name":"Bash","tool_input":{"command":"cat notes%s.md"}}' "$EM")"
run "emdash: Bash non-authoring passes" block-md-emdash.sh 0 "$(printf '{"tool_name":"Bash","tool_input":{"command":"git status %s"}}' "$EM")"
run "emdash: Bash clean commit passes" block-md-emdash.sh 0 '{"tool_name":"Bash","tool_input":{"command":"git commit -m clean-message"}}'
# widened Bash coverage: review-thread replies, gh api bodies, and Confluence REST publishes
run "emdash: Bash gh pr comment blocks" block-md-emdash.sh 2 "$(printf '{"tool_name":"Bash","tool_input":{"command":"gh pr comment 1 --body a%sb"}}' "$EM")"
run "emdash: Bash gh pr review blocks"  block-md-emdash.sh 2 "$(printf '{"tool_name":"Bash","tool_input":{"command":"gh pr review 1 --comment -b a%sb"}}' "$EM")"
run "emdash: Bash gh api body blocks"   block-md-emdash.sh 2 "$(printf '{"tool_name":"Bash","tool_input":{"command":"gh api graphql -f body=a%sb"}}' "$EM")"
run "emdash: Bash confluence PUT blocks" block-md-emdash.sh 2 "$(printf '{"tool_name":"Bash","tool_input":{"command":"curl -X PUT https://x/wiki/rest/api/content/1 -d a%sb"}}' "$EM")"
run "emdash: Bash clean gh pr comment passes" block-md-emdash.sh 0 '{"tool_name":"Bash","tool_input":{"command":"gh pr comment 1 --body \"clean reply\""}}'

# the block message must locate the offence, so the fix is one edit and not a hunt
emdash_reports_location() {
  local out json
  # \\n stays a literal backslash-n so the JSON string is valid (a raw newline would break jq)
  json="{\"tool_input\":{\"file_path\":\"/x/a.md\",\"content\":\"ok line\\nbad ${EM} here\\nok\"}}"
  out=$(printf '%s' "$json" | sh "$HOOKS/block-md-emdash.sh" 2>&1 >/dev/null)
  case "$out" in
    *"content line: 2:"*"<<EMDASH>>"*) PASS=$((PASS + 1)); printf 'PASS  %-46s\n' "emdash: block names line + marks the char" ;;
    *) FAIL=$((FAIL + 1)); printf 'FAIL  %-46s got: %s\n' "emdash: block names line + marks the char" "$out" ;;
  esac
}
emdash_reports_location

# filter-verbose-output (PostToolUse: exits 0 always; assert on stdout, not exit code)
if command -v python3 >/dev/null 2>&1; then
  FVO="$HOOKS/filter-verbose-output.py"
  runf() { # desc  mode(hasfail|empty)  event_json
    local desc="$1" mode="$2" json="$3" out pass=0
    out="$(printf '%s' "$json" | python3 "$FVO" 2>/dev/null)"
    case "$mode" in
      empty)   [ -z "$out" ] && pass=1 ;;
      hasfail) printf '%s' "$out" | grep -q '"updatedToolOutput"' \
                 && printf '%s' "$out" | grep -q 'FAILED' && pass=1 ;;
    esac
    if [ "$pass" = 1 ]; then PASS=$((PASS + 1)); printf 'PASS  %-46s\n' "$desc"
    else FAIL=$((FAIL + 1)); printf 'FAIL  %-46s (stdout mismatch)\n' "$desc"; fi
  }
  FVO_BIG="$(python3 -c 'import json;print(json.dumps({"tool_name":"Bash","tool_input":{"command":"yarn test:playwright"},"tool_response":{"stdout":"\n".join("ok %d passed"%i for i in range(700))+"\nx boom FAILED\nTests: 1 failed, 699 passed, 700 total","stderr":"","interrupted":False,"isImage":False,"noOutputExpected":False}}))')"
  FVO_CAT="$(python3 -c 'import json;print(json.dumps({"tool_name":"Bash","tool_input":{"command":"cat data.json"},"tool_response":{"stdout":"x"*20000,"stderr":"","interrupted":False,"isImage":False,"noOutputExpected":False}}))')"
  runf "filter: test output filtered + failure surfaced" hasfail "$FVO_BIG"
  runf "filter: non-test big output passes through"      empty   "$FVO_CAT"
  runf "filter: small test output passes through"        empty   '{"tool_name":"Bash","tool_input":{"command":"yarn test:playwright"},"tool_response":{"stdout":"3 passed\nok","stderr":"","interrupted":false,"isImage":false,"noOutputExpected":false}}'
  runf "filter: malformed input passes through"          empty   'not json{'

  # Regression: a real failure that appears AFTER more warning/summary lines than the digest cap must
  # still reach the digest. Line-ordered filling dropped it; severity-tiered filling keeps it.
  FVO_LATE="$(python3 -c 'import json
log  = ["Running 500 tests using 8 workers", ""]
log += ["  npm warn deprecated pkg-%d@1.0.0: superseded" % i for i in range(90)]
log += ["  ok %d - passing spec (11ms)" % i for i in range(400)]
log += ["  x LateSuite > boom FAILED (2.1s)"]
log += ["  ok %d - passing spec (9ms)" % i for i in range(400, 480)]
log += ["Tests: 1 failed, 499 passed, 500 total"]
print(json.dumps({"tool_name":"Bash","tool_input":{"command":"yarn test:playwright"},
  "tool_response":{"stdout":"\n".join(log),"stderr":"","interrupted":False,"isImage":False,"noOutputExpected":False}}))')"
  late_failure_survives() {
    local out digest
    out="$(printf '%s' "$FVO_LATE" | python3 "$FVO" 2>/dev/null)"
    # the digest is everything before the body separator
    digest="$(printf '%s' "$out" | python3 -c 'import sys,json
try: t=json.load(sys.stdin)["hookSpecificOutput"]["updatedToolOutput"]["stdout"]
except Exception: print(""); raise SystemExit
print(t.split("===== stdout, original order")[0])' 2>/dev/null)"
    if printf '%s' "$digest" | grep -q 'LateSuite > boom FAILED'; then
      PASS=$((PASS + 1)); printf 'PASS  %-46s\n' "filter: late failure survives the digest cap"
    else
      FAIL=$((FAIL + 1)); printf 'FAIL  %-46s (crowded out by warnings)\n' "filter: late failure survives the digest cap"
    fi
  }
  late_failure_survives
else
  echo "SKIP  filter-verbose-output tests (python3 absent)"
fi

# verify-generated.sh (shared Phase 7 self-verify core: pass on a real path, fail on an invented one)
vg() { # desc want file
  local desc="$1" want="$2" file="$3" got
  ( cd "$ROOT" && sh "$ROOT/plugins/harness/skills/harness-init/assets/verify-generated.sh" "$file" ) >/dev/null 2>&1; got=$?
  if { [ "$want" = 0 ] && [ "$got" = 0 ]; } || { [ "$want" != 0 ] && [ "$got" != 0 ]; }; then
    PASS=$((PASS + 1)); printf 'PASS  %-46s exit %s\n' "$desc" "$got"
  else FAIL=$((FAIL + 1)); printf 'FAIL  %-46s exit %s (want %s)\n' "$desc" "$got" "$want"; fi
}
# block-workflow-rules: four deterministic workflow guards
run "workflow: pr create without --draft blocks"    block-workflow-rules.sh 2 '{"tool_input":{"command":"gh pr create --title t --body b"}}'
run "workflow: pr create with --draft passes"       block-workflow-rules.sh 0 '{"tool_input":{"command":"gh pr create --draft --title t --body b"}}'
run "workflow: --no-verify blocks"                  block-workflow-rules.sh 2 '{"tool_input":{"command":"git commit --no-verify -m x"}}'
# a flag named inside a quoted argument is prose, not an invocation, so it must pass
run "workflow: prose naming --no-verify passes"     block-workflow-rules.sh 0 '{"tool_input":{"command":"echo \"the --no-verify flag is blocked\""}}'
run "workflow: prod write-port blocks"              block-workflow-rules.sh 2 '{"tool_input":{"command":"psql -h localhost -p 15433 -c \"select 1\""}}'
run "workflow: write-port nested in ssh blocks"     block-workflow-rules.sh 2 '{"tool_input":{"command":"ssh prod \"psql -p 15433 -c 1\""}}'
# the number is only a port when used as one; grepping for it is fine
run "workflow: grep for the port number passes"     block-workflow-rules.sh 0 '{"tool_input":{"command":"grep -rn 15433 hooks/"}}'
run "workflow: write against prod reader blocks"    block-workflow-rules.sh 2 '{"tool_input":{"command":"psql -p 15432 -c \"UPDATE pods SET x=1\""}}'
run "workflow: read from prod reader passes"        block-workflow-rules.sh 0 '{"tool_input":{"command":"psql -p 15432 -c \"select count(*) from pods\""}}'
run "workflow: write against dev passes"            block-workflow-rules.sh 0 '{"tool_input":{"command":"psql -p 25432 -c \"INSERT INTO pods VALUES (1)\""}}'
run "workflow: sleep then gh pr checks blocks"      block-workflow-rules.sh 2 '{"tool_input":{"command":"sleep 60 && gh pr checks 1234"}}'
run "workflow: single gh pr checks passes"          block-workflow-rules.sh 0 '{"tool_input":{"command":"gh pr checks 1234"}}'

# block-local-only-refs: local paths must not reach anything a colleague reads
run "localrefs: /Users path in pr body blocks"      block-local-only-refs.sh 2 '{"tool_input":{"command":"gh pr create --draft --body \"see /Users/w/x.md\""}}'
run "localrefs: kb path in commit blocks"           block-local-only-refs.sh 2 '{"tool_input":{"command":"git commit -m \"per kb/tickets/web-1/spec.md\""}}'
run "localrefs: repo-relative path in commit passes" block-local-only-refs.sh 0 '{"tool_input":{"command":"git commit -m \"refactor src/utils/date.ts\""}}'
run "localrefs: tracker link in pr body passes"     block-local-only-refs.sh 0 '{"tool_input":{"command":"gh pr create --draft --body \"Closes [WEB-1](https://x.atlassian.net/browse/WEB-1)\""}}'
# a local path in a non-publishing command is fine, and naming a publish command is not publishing
run "localrefs: ls of a local path passes"          block-local-only-refs.sh 0 '{"tool_input":{"command":"ls /Users/w/projects/kb"}}'
run "localrefs: grep naming gh pr create passes"    block-local-only-refs.sh 0 '{"tool_input":{"command":"grep -q \"gh pr create\" /Users/w/.claude/CLAUDE.md"}}'

VGTMP="$(mktemp -d)"
trap 'rm -rf "$VGTMP"' EXIT
printf 'see `%s` for the wiring\n' "plugins/harness/hooks/hooks.json" > "$VGTMP/good.md"
printf 'points at `%s`\n' "plugins/harness/does-not-exist.md" > "$VGTMP/bad.md"
vg "verify-generated: real path passes"    0 "$VGTMP/good.md"
vg "verify-generated: invented path fails" 1 "$VGTMP/bad.md"

echo
echo "hook tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
