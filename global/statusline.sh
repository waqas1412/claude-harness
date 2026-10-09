#!/bin/sh
# Surfaces the two things that actually drive Bedrock spend and are otherwise invisible:
# how much context is being re-billed every turn, and how long before the cache goes cold.
# A cold resume at a large context re-writes the whole prefix at the cache write rate.
set -eu
J=$(cat)

g() { printf '%s' "$J" | jq -r "$1 // empty" 2>/dev/null || true; }
# jq's // treats false as empty, so booleans need a getter without it.
b() { printf '%s' "$J" | jq -r "$1 | tostring" 2>/dev/null || true; }

MODEL=$(g '.model.display_name')
EFFORT=$(g '.effort.level')
DIR=$(g '.workspace.current_dir' | sed "s|^$HOME|~|")
BRANCH=$(g '.workspace.git.branch')
WTREE=$(g '.workspace.git_worktree')
SNAME=$(g '.session_name')
FAST=$(b '.fast_mode')

PR_NUM=$(g '.pr.number')
PR_URL=$(g '.pr.url')
PR_STATE=$(g '.pr.review_state')
PR_KIND=$(g '.pr.kind')

PCT=$(g '.context_window.used_percentage')
TOK=$(g '.context_window.current_usage | (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens)')
WIN=$(g '.context_window.context_window_size')
COST=$(g '.cost.total_cost_usd')
ADDED=$(g '.cost.total_lines_added')
REMOVED=$(g '.cost.total_lines_removed')
DUR_MS=$(g '.cost.total_duration_ms')

WARM=$(b '.prompt_cache.warm')
TTL=$(g '.prompt_cache.ttl')
HIT=$(g '.prompt_cache.hit_ratio')
MISSES=$(g '.prompt_cache.misses')
EXP=$(g '.prompt_cache.expires_at')
MISS_CAUSE=$(g '.prompt_cache.last_miss_cause.causes | join(",")')
RECACHE=$(g '.prompt_cache.recache_tokens_if_cold')

DIM='\033[2m'; RED='\033[31m'; YEL='\033[33m'; GRN='\033[32m'; OFF='\033[0m'

# List-price base input per MTok. Directional, not your bill.
case "$MODEL" in
  *Opus*)   RATE=4    ;;
  *Sonnet*) RATE=2    ;;
  *Haiku*)  RATE=0.10 ;;
  *)        RATE=0    ;;
esac
# Cache writes bill at 1.25x base input for the 5m TTL, 2x for 1h.
if [ "$TTL" = "1h" ]; then WMULT=2; else WMULT=1.25; fi

line1="${MODEL:-?}"
[ -n "$EFFORT" ] && line1="$line1 ${DIM}/${OFF}$EFFORT"
[ "$FAST" = "true" ] && line1="$line1 ${YEL}fast${OFF}"
[ -n "$DIR" ] && line1="$line1 ${DIM}|${OFF} $DIR"
[ -n "$BRANCH" ] && line1="$line1 ${DIM}@${OFF}$BRANCH"
[ -n "$WTREE" ] && line1="$line1 ${YEL}wt:${WTREE}${OFF}"

if [ -n "$PR_NUM" ]; then
  if [ "$PR_KIND" = "mr" ]; then tag="!$PR_NUM"; else tag="#$PR_NUM"; fi
  case "$PR_STATE" in
    approved)          sc=$GRN ;;
    changes_requested) sc=$RED ;;
    pending)           sc=$YEL ;;
    *)                 sc=$DIM ;;
  esac
  pr="$tag"
  [ -n "$PR_URL" ] && pr="\033]8;;${PR_URL}\a${tag}\033]8;;\a"
  line1="$line1 ${DIM}|${OFF} PR $pr"
  [ -n "$PR_STATE" ] && line1="$line1 ${sc}${PR_STATE}${OFF}"
fi

[ -n "$SNAME" ] && line1="$line1 ${DIM}| ${SNAME}${OFF}"

if [ -n "$PCT" ]; then
  p=${PCT%.*}; p=${p:-0}
  filled=$(( p / 10 )); [ "$filled" -gt 10 ] && filled=10
  bar=''; i=0
  while [ $i -lt 10 ]; do
    if [ $i -lt $filled ]; then bar="$bar#"; else bar="$bar."; fi
    i=$((i+1))
  done
  if [ "$p" -ge 70 ]; then c=$RED; elif [ "$p" -ge 40 ]; then c=$YEL; else c=$GRN; fi
  ktok=$(( ${TOK:-0} / 1000 ))
  kwin=$(( ${WIN:-0} / 1000 ))
  line2="${c}[$bar]${OFF} ${p}% ${DIM}${ktok}k/${kwin}k${OFF}"
else
  line2="${DIM}[..........] no API call yet${OFF}"
fi

if [ -n "$COST" ]; then
  line2="$line2 ${DIM}|${OFF} \$$(printf '%.2f' "$COST")${DIM} list${OFF}"
fi

if [ -n "$DUR_MS" ]; then
  m=$(( DUR_MS / 60000 ))
  if [ "$m" -ge 60 ]; then d="$(( m / 60 ))h$(( m % 60 ))m"; else d="${m}m"; fi
  line2="$line2 ${DIM}${d}${OFF}"
fi

if [ "${ADDED:-0}" -gt 0 ] || [ "${REMOVED:-0}" -gt 0 ]; then
  line2="$line2 ${GRN}+${ADDED:-0}${OFF}${DIM}/${OFF}${RED}-${REMOVED:-0}${OFF}"
fi

if [ "$WARM" = "true" ]; then
  hp=$(printf '%.0f' "$(echo "${HIT:-0} * 100" | bc -l 2>/dev/null || echo 0)")
  left=''
  if [ -n "$EXP" ]; then
    now=$(date +%s); mins=$(( (EXP - now) / 60 ))
    [ "$mins" -lt 0 ] && mins=0
    if [ "$mins" -le 10 ]; then left=" ${RED}cold in ${mins}m${OFF}"; else left=" ${DIM}${mins}m left${OFF}"; fi
  fi
  line2="$line2 ${DIM}|${OFF} cache ${GRN}warm${OFF} ${TTL} ${hp}% hit${left}"
  if [ -n "$MISSES" ] && [ "$MISSES" -gt 0 ]; then
    if [ -n "$MISS_CAUSE" ]; then
      line2="$line2 ${DIM}(${MISSES} miss, last: ${OFF}${YEL}${MISS_CAUSE}${OFF}${DIM})${OFF}"
    else
      line2="$line2 ${DIM}(${MISSES} miss)${OFF}"
    fi
  fi
elif [ "$WARM" = "false" ]; then
  miss=''
  re=${RECACHE:-$TOK}
  # Haiku 5.5 bills prompts over 100K at 5x its base input.
  case "$MODEL" in *Haiku*) [ "${re:-0}" -gt 100000 ] && RATE=0.50 ;; esac
  if [ -n "$re" ] && [ "$RATE" != "0" ]; then
    miss=$(printf ' next turn re-caches %dk ~$%.2f' "$(( re / 1000 ))" "$(echo "$re / 1000000 * $RATE * $WMULT" | bc -l)")
  fi
  line2="$line2 ${DIM}|${OFF} cache ${RED}COLD${OFF}${RED}${miss}${OFF}"
fi

printf '%b\n%b\n' "$line1" "$line2"
