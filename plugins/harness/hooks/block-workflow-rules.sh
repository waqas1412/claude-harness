#!/bin/sh
# PreToolUse (Bash): enforce four standing workflow rules mechanically, so they do not have to be
# re-read from CLAUDE.md on every prompt. Each section blocks with exit 2 and says what to do instead.
#   1. Every PR opens as a draft.
#   2. Never bypass a check to get unstuck.
#   3. Protected database ports: a read-only replica takes reads only, a second port is off limits.
#   4. Never sleep-and-poll CI after a push.
# Deliberately NOT handled here: anything needing judgement. These are the deterministic cases only.
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[ -z "$cmd" ] && exit 0

# Decide from the command with quoted STRING BODIES removed, so a command that merely mentions a flag or a
# subcommand inside an argument (a grep, a test, an echo, a commit message) is not mistaken for running it.
# The database checks deliberately use the FULL command instead, because there it is right to fail closed.
outer=$(printf '%s' "$cmd" | sed "s/'[^']*'//g; s/\"[^\"]*\"//g" | tr '\n' ' ')
full=$(printf '%s' "$cmd" | tr '\n' ' ')

# 1. PR must be a draft. The owner flips it to ready himself.
case "$outer" in
  *"gh pr create"*)
    case "$outer" in
      *--draft*) ;;
      *)
        echo "Blocked: open every PR as a draft. Add --draft to gh pr create; you flip it to ready yourself." >&2
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

# 3. Protected database ports. The numbers and the host name describe one site's infrastructure, so they
# live OUTSIDE this repo in an untracked file, one key=value per line, # for comments:
#   $CLAUDE_DB_PORTS, else ~/.claude/hooks/db-ports.txt
#     reader_port=5432       # read-only replica: reads pass, writes are blocked
#     forbidden_port=5433    # never connect to this one at all
#     dev_port=5434          # named in the message as where writes belong
#     reader_note=over the read-only bastion
# A missing file makes this rule a no-op rather than blocking every database command, the same degrade the
# sibling egress hook uses. `install.sh --check` reports the file as absent so the gap is visible, not silent.
# Matched on the FULL command (so a port nested inside a quoted ssh or psql payload still counts) but only
# where the number is used AS a port, so grepping for or documenting the number is not blocked. The
# host:port alternative names a real host on purpose: a bare colon would match any path or label that
# happens to end in the number.
dbcfg=${CLAUDE_DB_PORTS:-$HOME/.claude/hooks/db-ports.txt}
if [ -f "$dbcfg" ]; then
  _v() { grep -E "^[[:space:]]*$1[[:space:]]*=" "$dbcfg" 2>/dev/null | head -1 | sed 's/#.*//; s/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//'; }
  reader_port=$(_v reader_port | tr -cd '0-9')
  forbidden_port=$(_v forbidden_port | tr -cd '0-9')
  dev_port=$(_v dev_port | tr -cd '0-9')
  reader_note=$(_v reader_note)
  pos='((-p|--port|--dbport|port=|port)[[:space:]]*|(localhost|127\.0\.0\.1|0\.0\.0\.0):)'
  [ -n "$dev_port" ] && dev_hint=" Writes belong on port $dev_port." || dev_hint=""
  [ -n "$reader_note" ] && note_hint=" ($reader_note)" || note_hint=""

  if [ -n "$forbidden_port" ] && printf '%s' "$full" | grep -Eq "$pos$forbidden_port"; then
    echo "Blocked: port $forbidden_port is off limits. Use the read-only reader instead.$dev_hint" >&2
    exit 2
  fi
  if [ -n "$reader_port" ] && printf '%s' "$full" | grep -Eq "$pos$reader_port"; then
    if printf '%s' "$full" | grep -Eqi '\b(insert|update|delete|drop|alter|truncate|create|grant|revoke)\b'; then
      echo "Blocked: that looks like a WRITE against the read-only reader on port $reader_port$note_hint. Hand the SQL to the owner instead.$dev_hint" >&2
      exit 2
    fi
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
