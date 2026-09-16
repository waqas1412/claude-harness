#!/usr/bin/env bash
#
# claude-harness installer (idempotent).
#
# Installs the portable parts that a plugin cannot own:
#   - global working-agreements CLAUDE.md  (marker-block merge into ~/.claude/CLAUDE.md)
#   - settings.json merge                  (model/effort/theme prefs + permission allow-rules + hook wiring)
#   - advisor agents, skills, hooks        (copied into ~/.claude with timestamped backups)
#
# Safe to re-run. Differing files are backed up to <name>.bak.<timestamp> before overwrite.
#
# Usage:
#   ./install.sh                 install everything (capabilities + global instructions + settings)
#   ./install.sh --no-prefs      skip personal prefs (model/effortLevel/theme/tui); still install the rest
#   ./install.sh --check         validate an existing install; write nothing
#   ./install.sh --with-marketplace   also register this repo as a local plugin marketplace (best effort)
#   ./install.sh --link          symlink agents/skills/hooks to this repo (two-way: edits flow both ways)
#   ./install.sh --unlink        replace those symlinks with plain copies (freeze the live setup)
#   ./install.sh --no-memory     skip seeding ~/.claude/memory (use if you manage memory elsewhere)
#   ./install.sh --no-global     skip the CLAUDE.md + settings merge (sync only agents/skills/hooks)
#   ./install.sh --uninstall     remove harness files (delegates to uninstall.sh)
#   ./install.sh -h | --help
#
# Env:
#   CLAUDE_HOME   target config dir (default: $HOME/.claude). Set this to dry-run into a sandbox.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
TS="$(date +%Y%m%d%H%M%S)"
WITH_PREFS=1
MODE="install"
WITH_MARKETPLACE=0
LINK=0
UNLINK=0
WITH_MEMORY=1
WITH_GLOBAL=1

while [ $# -gt 0 ]; do
  case "$1" in
    --no-prefs) WITH_PREFS=0 ;;
    --check) MODE="check" ;;
    --with-marketplace) WITH_MARKETPLACE=1 ;;
    --link) LINK=1 ;;
    --unlink) UNLINK=1 ;;
    --no-memory) WITH_MEMORY=0 ;;
    --no-global) WITH_GLOBAL=0 ;;
    --uninstall) MODE="uninstall" ;;
    -h|--help) awk 'NR>1 && /^#/{sub(/^# ?/,"");print} NR>2 && !/^#/{exit}' "$0"; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

note() { printf '  %s\n' "$1"; }
head() { printf '\n== %s ==\n' "$1"; }

require_jq() {
  command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required (brew install jq)." >&2; exit 1; }
}

# ---- copy helper: backup-if-differs, no-op if identical ----------------------
copy_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
    mv "$dst" "$dst.bak.$TS"; note "backed up $(basename "$dst") -> $(basename "$dst").bak.$TS"
  fi
  cp "$src" "$dst"
}

# ---- symlink helpers (two-way sync): point CLAUDE_HOME/<name> at the repo dir ----
link_dir() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then note "linked (already) $(basename "$dst")"; return; fi
    rm "$dst"
  elif [ -e "$dst" ]; then
    mv "$dst" "$dst.bak.$TS"; note "backed up $(basename "$dst")/ -> $(basename "$dst").bak.$TS"
  fi
  ln -sfn "$src" "$dst"; note "linked $(basename "$dst") -> repo"
}
unlink_dir() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then rm "$dst"; fi
  mkdir -p "$dst"; cp -R "$src"/. "$dst"/; note "unlinked $(basename "$dst") (now a real copy)"
}

# ---- CLAUDE.md marker-block merge -------------------------------------------
merge_claude_md() {
  local managed="$SRC/global/CLAUDE.md" target="$CLAUDE_HOME/CLAUDE.md" tmp
  tmp="$(mktemp)"
  if [ ! -f "$target" ]; then
    cp "$managed" "$target"; note "wrote new CLAUDE.md"; rm -f "$tmp"; return
  fi
  if grep -q '<!-- harness:start -->' "$target"; then
    awk -v mf="$managed" '
      $0 ~ /<!-- harness:start -->/ { while ((getline line < mf) > 0) print line; close(mf); skip=1; next }
      $0 ~ /<!-- harness:end -->/   { skip=0; next }
      skip != 1 { print }
    ' "$target" > "$tmp"
    if ! cmp -s "$tmp" "$target"; then
      mv "$target" "$target.bak.$TS"; mv "$tmp" "$target"; note "refreshed managed block in CLAUDE.md"
    else
      note "CLAUDE.md already current"; rm -f "$tmp"
    fi
  else
    mv "$target" "$target.bak.$TS"
    { cat "$managed"; printf '\n\n'; cat "$target.bak.$TS"; } > "$target"
    note "prepended managed block; preserved your prose below it"
  fi
}

# ---- settings.json merge ----------------------------------------------------
merge_settings() {
  local target="$CLAUDE_HOME/settings.json" frag="$SRC/global/settings.fragment.json"
  local overlay tmp existing
  overlay="$(mktemp)"; tmp="$(mktemp)"
  [ -f "$target" ] || echo '{}' > "$target"
  existing="$target"

  # Build overlay: fragment minus _personalPrefs, plus prefs (minus _comment) when enabled.
  jq --argjson prefs "$WITH_PREFS" '
    . as $f
    | ($f | del(._personalPrefs)) as $base
    | (if ($prefs == 1) then ($f._personalPrefs | with_entries(select(.key | startswith("_") | not))) else {} end) as $p
    | $base * $p
  ' "$frag" > "$overlay"

  # Deep-merge overlay into existing: objects recurse, arrays concat+dedupe, scalars take overlay.
  # Bind $a/$b first so they are fixed values, not filters re-evaluated against the reduce accumulator.
  jq -s '
    def deepmerge(a; b):
      a as $a | b as $b
      | if ($a | type) == "object" and ($b | type) == "object"
          then reduce (($a + $b) | keys_unsorted[]) as $k ({}; .[$k] = deepmerge($a[$k]; $b[$k]))
        elif ($a | type) == "array" and ($b | type) == "array"
          then (($a + $b) | unique)
        elif $b == null then $a
        else $b end;
    deepmerge(.[0]; .[1])
  ' "$existing" "$overlay" > "$tmp"

  # Wire the PreToolUse guards with resolved absolute paths; idempotent (drop ours, re-add).
  local h="$CLAUDE_HOME/hooks"
  jq --arg co "sh \"$h/block-coauthor.sh\"" \
     --arg pr "sh \"$h/block-pr-reviewer.sh\"" \
     --arg fp "sh \"$h/block-force-push.sh\"" \
     --arg md "sh \"$h/block-md-emdash.sh\"" \
     --arg wf "sh \"$h/block-workflow-rules.sh\"" \
     --arg lr "sh \"$h/block-local-only-refs.sh\"" \
     --arg ql "sh \"$h/block-external-query-leaks.sh\"" '
    .hooks //= {} | .hooks.PreToolUse //= []
    # remove any existing harness hook entries (commands referencing /hooks/block-*)
    | .hooks.PreToolUse |= ( map(
        .hooks |= ( (. // []) | map(select((.command // "") | test("/hooks/block-") | not)) )
      ) | map(select((.hooks // []) | length > 0)) )
    | .hooks.PreToolUse += [
        { "matcher": "Bash", "hooks": [ {"type":"command","command":$co}, {"type":"command","command":$pr}, {"type":"command","command":$fp}, {"type":"command","command":$md}, {"type":"command","command":$wf}, {"type":"command","command":$lr}, {"type":"command","command":$ql} ] },
        { "matcher": "WebFetch", "hooks": [ {"type":"command","command":$ql} ] },
        { "matcher": "Write|Edit", "hooks": [ {"type":"command","command":$md} ] }
      ]
  ' "$tmp" > "$tmp.h" && mv "$tmp.h" "$tmp"

  # Wire the PostToolUse output filter with a resolved absolute path; idempotent (drop ours, re-add).
  jq --arg fv "python3 \"$h/filter-verbose-output.py\"" '
    .hooks //= {} | .hooks.PostToolUse //= []
    | .hooks.PostToolUse |= ( map(
        .hooks |= ( (. // []) | map(select((.command // "") | test("/hooks/filter-verbose-output") | not)) )
      ) | map(select((.hooks // []) | length > 0)) )
    | .hooks.PostToolUse += [
        { "matcher": "Bash", "hooks": [ {"type":"command","command":$fv} ] }
      ]
  ' "$tmp" > "$tmp.h" && mv "$tmp.h" "$tmp"

  jq -e . "$tmp" >/dev/null || { echo "ERROR: merged settings.json is invalid; left original untouched." >&2; rm -f "$overlay" "$tmp"; exit 1; }
  if ! cmp -s "$tmp" "$target"; then
    cp "$target" "$target.bak.$TS"; mv "$tmp" "$target"; note "merged settings.json (backup saved)"
  else
    note "settings.json already current"; rm -f "$tmp"
  fi
  rm -f "$overlay"
}

# ---- copy agents / skills / hooks ------------------------------------------
install_capabilities() {
  if [ "$LINK" = 1 ]; then
    head "Agents / skills / hooks (symlinked to repo, two-way)"
    link_dir "$SRC/plugins/harness/agents" "$CLAUDE_HOME/agents"
    link_dir "$SRC/plugins/harness/skills" "$CLAUDE_HOME/skills"
    link_dir "$SRC/plugins/harness/hooks"  "$CLAUDE_HOME/hooks"
  elif [ "$UNLINK" = 1 ]; then
    head "Agents / skills / hooks (converting symlinks to copies)"
    unlink_dir "$SRC/plugins/harness/agents" "$CLAUDE_HOME/agents"
    unlink_dir "$SRC/plugins/harness/skills" "$CLAUDE_HOME/skills"
    unlink_dir "$SRC/plugins/harness/hooks"  "$CLAUDE_HOME/hooks"
  else
    head "Agents"
    for f in "$SRC"/plugins/harness/agents/*.md; do
      [ -e "$f" ] || continue
      copy_file "$f" "$CLAUDE_HOME/agents/$(basename "$f")"
    done
    note "$(ls -1 "$SRC"/plugins/harness/agents/*.md 2>/dev/null | wc -l | tr -d ' ') agents"

    head "Skills"
    for d in "$SRC"/plugins/harness/skills/*/; do
      [ -d "$d" ] || continue
      local name rel; name="$(basename "$d")"
      while IFS= read -r f; do
        rel="${f#"$d"}"
        copy_file "$f" "$CLAUDE_HOME/skills/$name/$rel"
      done < <(find "$d" -type f)
      note "skill: $name"
    done

    head "Hooks"
    for f in "$SRC"/plugins/harness/hooks/block-*.sh "$SRC"/plugins/harness/hooks/filter-verbose-output.py; do
      [ -e "$f" ] || continue
      copy_file "$f" "$CLAUDE_HOME/hooks/$(basename "$f")"
      chmod +x "$CLAUDE_HOME/hooks/$(basename "$f")"
    done
    note "8 hooks: 7 PreToolUse guards (coauthor, pr-reviewer, force-push, md-emdash, workflow-rules, local-only-refs, external-query-leaks) + 1 PostToolUse output filter"
  fi

  if [ "$WITH_MEMORY" = 1 ] && [ "$WITH_GLOBAL" = 1 ]; then
    head "Memory store"
    [ -d "$CLAUDE_HOME/memory-seed" ] && { rm -rf "$CLAUDE_HOME/memory-seed"; note "removed legacy memory-seed/"; } || true
    note "the auto-loaded store is $CLAUDE_HOME/projects/<cwd-slug>/memory, created by Claude on first write"
    note "no starter facts ship with the harness; the memory convention is in CLAUDE.md"
  else
    note "memory seeding skipped"
  fi
}

# ---- check mode -------------------------------------------------------------
do_check() {
  require_jq
  local ok=1
  head "Validating install at $CLAUDE_HOME"
  [ -f "$CLAUDE_HOME/CLAUDE.md" ] && grep -q '<!-- harness:start -->' "$CLAUDE_HOME/CLAUDE.md" \
    && note "CLAUDE.md managed block present" || { note "MISSING: CLAUDE.md managed block"; ok=0; }
  if [ -f "$CLAUDE_HOME/settings.json" ]; then
    jq -e . "$CLAUDE_HOME/settings.json" >/dev/null && note "settings.json is valid JSON" || { note "INVALID settings.json"; ok=0; }
    for s in block-coauthor block-pr-reviewer block-force-push block-md-emdash; do
      if jq -e --arg s "$s" '.. | .command? // empty | select(test($s))' "$CLAUDE_HOME/settings.json" >/dev/null 2>&1; then
        [ -f "$CLAUDE_HOME/hooks/$s.sh" ] && note "hook wired + present: $s" || { note "WIRED BUT MISSING: hooks/$s.sh"; ok=0; }
      else
        note "NOT WIRED: $s"; ok=0
      fi
    done
    if jq -e '.. | .command? // empty | select(test("filter-verbose-output"))' "$CLAUDE_HOME/settings.json" >/dev/null 2>&1; then
      [ -f "$CLAUDE_HOME/hooks/filter-verbose-output.py" ] && note "hook wired + present: filter-verbose-output" || { note "WIRED BUT MISSING: hooks/filter-verbose-output.py"; ok=0; }
    else
      note "NOT WIRED: filter-verbose-output"; ok=0
    fi
  else
    note "MISSING settings.json"; ok=0
  fi
  local na ns
  na="$(ls -1 "$CLAUDE_HOME"/agents/*.md 2>/dev/null | wc -l | tr -d ' ')"
  ns="$(ls -1d "$CLAUDE_HOME"/skills/*/ 2>/dev/null | wc -l | tr -d ' ')"
  note "agents present: $na ; skills present: $ns"
  for d in agents skills hooks; do
    [ -L "$CLAUDE_HOME/$d" ] && note "$d: symlinked -> $(readlink "$CLAUDE_HOME/$d")" || true
  done

  # behavioral: each installed hook must DENY a known-bad payload and ALLOW a known-good one
  local h="$CLAUDE_HOME/hooks" em; em="$(printf '\342\200\224')"
  _ec() { printf '%s' "$2" | sh "$h/$1" >/dev/null 2>&1; echo $?; }
  if [ -f "$h/block-coauthor.sh" ]; then
    [ "$(_ec block-coauthor.sh '{"tool_input":{"command":"git commit -m \"x\n\nCo-Authored-By: A <a@b.c>\""}}')" = 2 ] \
      && [ "$(_ec block-coauthor.sh '{"tool_input":{"command":"git commit --trailer \"Co-authored-by: A <a@b.c>\""}}')" = 2 ] \
      && [ "$(_ec block-coauthor.sh '{"tool_input":{"command":"git commit -m ok"}}')" = 0 ] \
      && [ "$(_ec block-coauthor.sh '{"tool_input":{"command":"git commit -m \"refactor the co-authored-by parser\""}}')" = 0 ] \
      && note "behavior: block-coauthor denies+allows" || { note "BEHAVIOR FAIL: block-coauthor"; ok=0; }
  fi
  if [ -f "$h/block-pr-reviewer.sh" ]; then
    [ "$(_ec block-pr-reviewer.sh '{"tool_input":{"command":"gh pr create --reviewer x"}}')" = 2 ] \
      && [ "$(_ec block-pr-reviewer.sh '{"tool_input":{"command":"gh pr create --reviewer=alice"}}')" = 2 ] \
      && [ "$(_ec block-pr-reviewer.sh '{"tool_input":{"command":"gh pr edit 1 --add-reviewer=bob"}}')" = 2 ] \
      && [ "$(_ec block-pr-reviewer.sh '{"tool_input":{"command":"gh pr create --base main"}}')" = 0 ] \
      && note "behavior: block-pr-reviewer denies+allows" || { note "BEHAVIOR FAIL: block-pr-reviewer"; ok=0; }
  fi
  if [ -f "$h/block-force-push.sh" ]; then
    [ "$(_ec block-force-push.sh '{"tool_input":{"command":"git push --force"}}')" = 2 ] \
      && [ "$(_ec block-force-push.sh '{"tool_input":{"command":"git push --force-with-lease"}}')" = 0 ] \
      && note "behavior: block-force-push denies+allows" || { note "BEHAVIOR FAIL: block-force-push"; ok=0; }
  fi
  if [ -f "$h/block-md-emdash.sh" ]; then
    [ "$(_ec block-md-emdash.sh "$(printf '{"tool_input":{"file_path":"/x/a.md","content":"a %s b"}}' "$em")")" = 2 ] \
      && [ "$(_ec block-md-emdash.sh '{"tool_input":{"file_path":"/x/a.md","content":"a, b"}}')" = 0 ] \
      && [ "$(_ec block-md-emdash.sh "$(printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m fix%sready"}}' "$em")")" = 2 ] \
      && [ "$(_ec block-md-emdash.sh "$(printf '{"tool_name":"Bash","tool_input":{"command":"cat notes%s.md"}}' "$em")")" = 0 ] \
      && note "behavior: block-md-emdash denies+allows" || { note "BEHAVIOR FAIL: block-md-emdash"; ok=0; }
  fi
  if [ -f "$h/block-workflow-rules.sh" ]; then
    [ "$(_ec block-workflow-rules.sh '{"tool_input":{"command":"gh pr create --title t --body b"}}')" = 2 ] \
      && [ "$(_ec block-workflow-rules.sh '{"tool_input":{"command":"gh pr create --draft --title t --body b"}}')" = 0 ] \
      && [ "$(_ec block-workflow-rules.sh '{"tool_input":{"command":"git commit --no-verify -m x"}}')" = 2 ] \
      && [ "$(_ec block-workflow-rules.sh '{"tool_input":{"command":"psql -p 15433 -c 1"}}')" = 2 ] \
      && [ "$(_ec block-workflow-rules.sh '{"tool_input":{"command":"psql -p 15432 -c \"select 1\""}}')" = 0 ] \
      && note "behavior: block-workflow-rules denies+allows" || { note "BEHAVIOR FAIL: block-workflow-rules"; ok=0; }
  fi
  if [ -f "$h/block-local-only-refs.sh" ]; then
    [ "$(_ec block-local-only-refs.sh '{"tool_input":{"command":"gh pr create --draft --body \"see /Users/w/x.md\""}}')" = 2 ] \
      && [ "$(_ec block-local-only-refs.sh '{"tool_input":{"command":"git commit -m \"refactor src/x.ts\""}}')" = 0 ] \
      && [ "$(_ec block-local-only-refs.sh '{"tool_input":{"command":"ls /Users/w/projects/kb"}}')" = 0 ] \
      && note "behavior: block-local-only-refs denies+allows" || { note "BEHAVIOR FAIL: block-local-only-refs"; ok=0; }
  fi
  if [ -f "$h/block-external-query-leaks.sh" ]; then
    [ "$(_ec block-external-query-leaks.sh '{"tool_name":"Bash","tool_input":{"command":"curl \"http://localhost:8080/search?q=/Users/w/x&format=json\""}}')" = 2 ] \
      && [ "$(_ec block-external-query-leaks.sh '{"tool_name":"Bash","tool_input":{"command":"curl \"http://localhost:8080/search?q=nextjs+router&format=json\""}}')" = 0 ] \
      && [ "$(_ec block-external-query-leaks.sh '{"tool_name":"Bash","tool_input":{"command":"grep -r x /Users/w/projects/app"}}')" = 0 ] \
      && [ "$(_ec block-external-query-leaks.sh '{"tool_name":"WebFetch","tool_input":{"url":"https://d.io","prompt":"check kb/tickets/x.md"}}')" = 2 ] \
      && [ "$(_ec block-external-query-leaks.sh '{"tool_name":"WebFetch","tool_input":{"url":"https://d.io","prompt":"quote the caching section"}}')" = 0 ] \
      && note "behavior: block-external-query-leaks denies+allows" || { note "BEHAVIOR FAIL: block-external-query-leaks"; ok=0; }
  fi

  # jq preflight: every hook parses the tool-call JSON with jq, so a hook runtime that cannot resolve
  # jq silently allows everything (the documented Windows no-op). Surface it loudly here; the hooks
  # themselves stay fail-open so a jq-less shell is not bricked for every Bash and Write/Edit call.
  if command -v jq >/dev/null 2>&1; then
    note "jq reachable for hook runtime: $(command -v jq)"
  else
    note "JQ UNREACHABLE: hooks will silently no-op. Prepend /usr/bin and jq to PATH (windows-hook-wiring)."; ok=0
  fi

  # memory store + bidirectional pointer integrity. Two routes make a fact reachable, and a fact needs
  # exactly one of them:
  #   - a feedback_* ruling file is cited inline by its own rule in the global CLAUDE.md, which loads
  #     every session. It is deliberately NOT listed in MEMORY.md, so listing it would pay for the same
  #     pointer twice on every prompt. Here we assert the citation exists instead.
  #   - everything else needs a MEMORY.md pointer, or it is dark and will never fire.
  # Either way a MEMORY.md link must resolve to a real file. Any inconsistency fails --check.
  local store idx slug orphan=0 found=0 mf ptr base ws cited hay
  # Where a ruling citation may live: the global rules file, and (for a repo-scoped ruling) the
  # workspace root index or one of its per-repo deep indexes.
  for store in "$CLAUDE_HOME"/projects/*/memory; do
    [ -d "$store" ] || continue
    found=1; slug="$(basename "$(dirname "$store")")"; idx="$store/MEMORY.md"
    if [ ! -f "$idx" ]; then
      if [ -n "$(ls -1 "$store"/*.md 2>/dev/null)" ]; then
        note "memory[$slug]: facts present but no MEMORY.md index"; orphan=1
      else
        note "memory[$slug]: empty"
      fi
      continue
    fi
    for mf in "$store"/*.md; do
      [ -e "$mf" ] || continue
      base="$(basename "$mf")"
      [ "$base" = "MEMORY.md" ] && continue
      case "$base" in
        feedback_*)
          # cited by its rule instead of indexed; the citation is what makes it fire. A general ruling
          # is cited in the global rules file; a repo-scoped one is cited in that repo's deep index.
          ws="/$(printf '%s' "$slug" | sed 's/^-//; s/-/\//g')"
          cited=0
          for hay in "$CLAUDE_HOME/CLAUDE.md" "$ws/CLAUDE.md" "$ws"/.claude/repo-index/*.md; do
            [ -f "$hay" ] || continue
            if grep -qF "${base%.md}" "$hay"; then cited=1; break; fi
          done
          [ "$cited" = 1 ] || { note "memory[$slug]: $base is a ruling file cited nowhere (not in CLAUDE.md, the workspace index, or a repo index), so it never fires"; orphan=1; }
          ;;
        *)
          grep -qF "$base" "$idx" || { note "memory[$slug]: $base has no MEMORY.md pointer"; orphan=1; }
          ;;
      esac
    done
    for ptr in $(grep -oE '\]\([^)]+\.md\)' "$idx" | sed -E 's/^\]\(//; s/\)$//'); do
      [ -f "$store/$ptr" ] || { note "memory[$slug]: MEMORY.md points to missing $ptr"; orphan=1; }
    done
    note "memory[$slug]: $(ls -1 "$store"/*.md 2>/dev/null | wc -l | tr -d ' ') files"
  done
  if [ "$found" = 1 ]; then
    [ "$orphan" = 0 ] && note "memory: every fact reachable (rulings cited by a rule, rest indexed)" || ok=0
  else
    note "memory: no workspace store yet at $CLAUDE_HOME/projects/<cwd-slug>/memory"
  fi
  [ -d "$CLAUDE_HOME/memory" ] && note "note: $CLAUDE_HOME/memory is a legacy path that no session loads" || true

  [ "$ok" = 1 ] && { echo; echo "OK: install looks healthy."; } || { echo; echo "PROBLEMS found (see above)."; exit 1; }
}

case "$MODE" in
  uninstall) exec "$SRC/uninstall.sh" ;;
  check) do_check; exit 0 ;;
esac

require_jq
echo "Installing claude-harness into $CLAUDE_HOME"
mkdir -p "$CLAUDE_HOME"
install_capabilities
if [ "$WITH_GLOBAL" = 1 ]; then
  head "Global instructions"
  merge_claude_md
  head "Settings"
  merge_settings
else
  head "Global instructions + settings"
  note "skipped (--no-global): CLAUDE.md, settings, and memory left untouched"
fi

if [ "$WITH_MARKETPLACE" = 1 ]; then
  head "Marketplace (best effort)"
  if command -v claude >/dev/null 2>&1; then
    claude plugin marketplace add "$SRC" >/dev/null 2>&1 && note "registered marketplace from $SRC" \
      || note "could not auto-register; run: /plugin marketplace add $SRC"
  else
    note "claude CLI not found; in Claude Code run: /plugin marketplace add $SRC"
  fi
fi

cat <<EOF

Done. Installed into $CLAUDE_HOME
Next:
  - Restart Claude Code (or /reload) so agents, skills, hooks, and CLAUDE.md load.
  - In any repo, run /harness-init once to generate its tailored index.
  - Validate any time with:  CLAUDE_HOME=$CLAUDE_HOME $SRC/install.sh --check
EOF
