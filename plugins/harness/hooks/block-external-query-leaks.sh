#!/bin/sh
# PreToolUse (Bash, WebFetch): keep proprietary identifiers out of anything sent to a third party
# for lookup. Sibling of block-local-only-refs.sh, which guards the PUBLISH path (commit messages,
# PR bodies, wiki pages). This one guards the LOOKUP path, a different egress with a different shape:
# a self-hosted metasearch still forwards the query to Google and Brave, and WebFetch runs the prompt
# through a model. Both leave the machine.
#
# Bash: the whole command is scanned, but only when it is really a search call.
# WebFetch: only the PROMPT is scanned, never the url. Fetching a company URL is legitimate; putting
# repo context in the prompt is what leaks.
#
# Two tiers of marker, on purpose. The generic ones below are portable and ship with this repo. The
# identifying ones (company and product names, internal hosts, tracker prefixes) belong to one site,
# so they live OUTSIDE this repo in an untracked file, one extended-regex per line, # for comments:
#   $CLAUDE_EGRESS_MARKERS, else ~/.claude/hooks/egress-markers.txt
# A missing file degrades to the generic tier rather than bricking every search. The message names
# the file rather than echoing the matched term, so the hook never prints the secret it is guarding.
#
# Markers stay narrow deliberately. A false positive here blocks real work, so generic repo words
# (connect, backend, pods) must NOT be markers: they collide with searches like "gin backend middleware".
input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // ""')

case "$tool" in
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
    [ -z "$cmd" ] && exit 0
    # Only a real search CALL counts, not a script that merely mentions a search URL: a heredoc, a
    # grep, or an edit to this very file would otherwise trip it. The sibling publish hook strips
    # quoted bodies to make this decision, which inverts here (a real curl keeps its URL in quotes),
    # so instead require that some command position actually invokes a fetch verb on a search URL.
    is_search=0
    segs=$(printf '%s' "$cmd" | tr '\n' ';' | sed 's/&&/;/g; s/||/;/g; s/|/;/g')
    OLDIFS=$IFS; IFS=';'
    # shellcheck disable=SC2086 # word splitting on ';' is the point here
    for seg in $segs; do
      # awk, not sed: BSD and GNU sed disagree on labels/branches joined by semicolons, so a sed
      # loop here silently stops stripping env prefixes on one of the two platforms.
      verb=$(printf '%s' "$seg" | awk '{
        i = 1
        while (i <= NF && $i ~ /^[A-Za-z_][A-Za-z0-9_]*=/) i++
        if (i <= NF) { n = split($i, p, "/"); print p[n] }
      }')
      case "$verb" in curl|wget|http|https|xh|httpie) ;; *) continue ;; esac
      if printf '%s' "$seg" | grep -Eqi \
        'localhost:8080/search|127\.0\.0\.1:8080/search|/search\?[^ ]*format=json|google\.[a-z.]+/search|bing\.com/search|duckduckgo\.com|searx'; then
        is_search=1; break
      fi
    done
    IFS=$OLDIFS
    [ "$is_search" = 1 ] || exit 0
    scan=$cmd
    what="a search query"
    ;;
  WebFetch)
    scan=$(printf '%s' "$input" | jq -r '.tool_input.prompt // ""')
    [ -z "$scan" ] && exit 0
    what="a WebFetch prompt"
    ;;
  *) exit 0 ;;
esac

generic_re='/Users/|(^|[^a-zA-Z0-9_/.-])kb/|\.claude/(repo-index|meta|harness)/'
hit=""
printf '%s' "$scan" | grep -q '/Users/' && hit="an absolute /Users/ path"
printf '%s' "$scan" | grep -Eq '(^|[^a-zA-Z0-9_/.-])kb/' && hit="${hit:+$hit, }a kb/ knowledge-base path"
printf '%s' "$scan" | grep -Eq '\.claude/(repo-index|meta|harness)/' && hit="${hit:+$hit, }a local harness path"

markers=${CLAUDE_EGRESS_MARKERS:-$HOME/.claude/hooks/egress-markers.txt}
site=0
if [ -f "$markers" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    if printf '%s' "$scan" | grep -Eqi -- "$line"; then site=1; break; fi
  done < "$markers"
fi
[ "$site" = 1 ] && hit="${hit:+$hit, }a site-specific identifier"

if [ -n "$hit" ]; then
  echo "Blocked: $hit in $what, which is sent to a third party." >&2
  echo "A self-hosted search still forwards the query to Google and Brave, and WebFetch runs the prompt through a model." >&2
  echo "Re-ask it generically: the library, framework, error text or standard, with no internal name, path or ticket in it." >&2
  [ "$site" = 1 ] && echo "  matched a pattern in $markers" >&2
  printf '%s' "$scan" | grep -noE "(${generic_re})[^ \"']*" | head -3 | cut -c1-120 | sed 's/^/  /' >&2
  exit 2
fi
exit 0
