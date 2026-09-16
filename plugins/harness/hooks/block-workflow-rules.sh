#!/bin/sh
# PreToolUse (Bash): enforce four standing workflow rules mechanically, so they do not have to be
# re-read from CLAUDE.md on every prompt. Each section blocks with exit 2 and says what to do instead.
#   1. Every PR opens as a draft.
#   2. Never bypass a check to get unstuck.
#   3. Prod DB is the read-only reader on 15432 only, never 15433, never a write.
#   4. Never sleep-and-poll CI after a push.
# Deliberately NOT handled here: anything needing judgement. These are the deterministic cases only.
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[ -z "$cmd" ] && exit 0

# Decide from the command with quoted STRING BODIES removed, so a command that merely mentions a flag or a
# subcommand inside an argument (a grep, a test, an echo, a commit message) is not mistaken for running it.
# The prod DB checks deliberately use the FULL command instead, because there it is right to fail closed.
outer=$(printf '%s' "$cmd" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g" | tr '\n' ' ')
full=$(printf '%s' "$cmd" | tr '\n' ' ')

# 1. PR must be a draft. He flips it to ready himself.
case "$outer" in
  *"gh pr create"*)
    case "$outer" in
      *--draft*) ;;
      *)
        echo "Blocked: open every PR as a draft. Add --draft to gh pr create; Waqas flips it to ready himself." >&2
        exit 2
        ;;
    esac
    ;;
esac

# 2. No bypassing a check. If a gate is wrong, flag it and stop instead.
case "$outer" in
  *--no-verify*|*"HUSKY=0"*|*"SKIP_HOOKS"*|*"--no-gpg-sign"*)
    echo "Blocked: never bypass a check to get unstuck (--no-verify, skipping hooks). Fix the cause, or flag the gate as wrong and stop." >&2
    exit 2
    ;;
esac

# 3. Prod DB: 15432 read-only reader ONLY. 15433 and any write are off limits.
# Matched on the FULL command (so a port nested inside a quoted ssh or psql payload still counts) but only
# where the number is used AS a port, so that grepping for or documenting the number is not blocked.
# The host:port alternative names a real host on purpose: a bare colon would match any path or label that
# happens to end in the number (a file path, a test case, a grep pattern).
port_re='((-p|--port|--dbport|port=|port)[[:space:]]*|(localhost|127\.0\.0\.1|0\.0\.0\.0):)15433'
if printf '%s' "$full" | grep -Eq "$port_re"; then
  echo "Blocked: 15433 is not the prod reader. Prod DB is localhost:15432 ONLY, read-only over ssh prod-bastion. Dev writes go to 25432." >&2
  exit 2
fi
if printf '%s' "$full" | grep -Eq '((-p|--port|--dbport|port=|port)[[:space:]]*|(localhost|127\.0\.0\.1|0\.0\.0\.0):)15432'; then
  if printf '%s' "$full" | grep -Eqi '\b(insert|update|delete|drop|alter|truncate|create|grant|revoke)\b'; then
    echo "Blocked: that looks like a WRITE against prod on 15432, which is a read-only reader. Hand the SQL to Waqas instead. Dev writes go to 25432." >&2
    exit 2
  fi
fi

# 4. No sleep-and-poll of CI after a push. Verify locally, report the push, stop.
case "$outer" in
  *"gh pr checks"*|*"gh run watch"*|*"gh run list"*)
    if printf '%s' "$outer" | grep -Eq '(^|[^a-z])sleep +[0-9]|watch |--watch|while +true|for +i +in'; then
      echo "Blocked: do not sleep-and-poll CI after a push. Verify locally, report the push, and stop." >&2
      exit 2
    fi
    ;;
esac

exit 0
