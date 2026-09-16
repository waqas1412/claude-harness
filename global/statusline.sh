#!/bin/sh
# Surfaces the two things that actually drive Bedrock spend and are otherwise invisible:
# how much context is being re-billed every turn, and how long before the cache goes cold.
# A cold resume at a large context re-writes the whole prefix at the 1h write rate.
set -eu
J=$(cat)

g() { printf '%s' "$J" | jq -r "$1 // empty" 2>/dev/null || true; }
# jq's // treats false as empty, so booleans need a getter without it.
b() { printf '%s' "$J" | jq -r "$1 | tostring" 2>/dev/null || true; }

MODEL=$(g '.model.display_name')
EFFORT=$(g '.effort.level')
DIR=$(g '.workspace.current_dir' | sed "s|^$HOME|~|")
BRANCH=$(g '.workspace.git.branch')

PCT=$(g '.context_window.used_percentage')
TOK=$(g '.context_window.current_usage | (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens)')
WIN=$(g '.context_window.context_window_size')
COST=$(g '.cost.total_cost_usd')

WARM=$(b '.prompt_cache.warm')
TTL=$(g '.prompt_cache.ttl')
HIT=$(g '.prompt_cache.hit_ratio')
MISSES=$(g '.prompt_cache.misses')
EXP=$(g '.prompt_cache.expires_at')

DIM='\033[2m'; RED='\033[31m'; YEL='\033[33m'; GRN='\033[32m'; OFF='\033[0m'

# List-price write rate per MTok at the 1h TTL (2x base input). Directional, not your bill.
case "$MODEL" in
  *Opus*)   RATE=10 ;;
  *Sonnet*) RATE=4  ;;
  *Haiku*)  RATE=2  ;;
  *)        RATE=0  ;;
esac

line1="${MODEL:-?}"
[ -n "$EFFORT" ] && line1="$line1 ${DIM}/${OFF}$EFFORT"
[ -n "$DIR" ] && line1="$line1 ${DIM}|${OFF} $DIR"
[ -n "$BRANCH" ] && line1="$line1 ${DIM}@${OFF}$BRANCH"

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

if [ "$WARM" = "true" ]; then
  hp=$(printf '%.0f' "$(echo "${HIT:-0} * 100" | bc -l 2>/dev/null || echo 0)")
  left=''
  if [ -n "$EXP" ]; then
    now=$(date +%s); mins=$(( (EXP - now) / 60 ))
    [ "$mins" -lt 0 ] && mins=0
    if [ "$mins" -le 10 ]; then left=" ${RED}cold in ${mins}m${OFF}"; else left=" ${DIM}${mins}m left${OFF}"; fi
  fi
  line2="$line2 ${DIM}|${OFF} cache ${GRN}warm${OFF} ${TTL} ${hp}% hit${left}"
  [ -n "$MISSES" ] && [ "$MISSES" -gt 0 ] && line2="$line2 ${DIM}(${MISSES} miss)${OFF}"
elif [ "$WARM" = "false" ]; then
  miss=''
  if [ "$RATE" -gt 0 ] && [ -n "$TOK" ]; then
    miss=$(printf ' next turn ~$%.2f' "$(echo "${TOK} / 1000000 * $RATE" | bc -l)")
  fi
  line2="$line2 ${DIM}|${OFF} cache ${RED}COLD${OFF}${RED}${miss}${OFF}"
fi

printf '%b\n%b\n' "$line1" "$line2"
