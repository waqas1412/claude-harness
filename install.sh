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
    | (if ($prefs == 1) then ($f._personalPrefs | del(._comment)) else {} end) as $p
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

  # Wire the three PreToolUse hooks with resolved absolute paths; idempotent (drop ours, re-add).
  local h="$CLAUDE_HOME/hooks"
  jq --arg co "sh \"$h/block-coauthor.sh\"" \
     --arg pr "sh \"$h/block-pr-reviewer.sh\"" \
     --arg md "sh \"$h/block-md-emdash.sh\"" '
    .hooks //= {} | .hooks.PreToolUse //= []
    # remove any existing harness hook entries (commands referencing /hooks/block-*)
    | .hooks.PreToolUse |= ( map(
        .hooks |= ( (. // []) | map(select((.command // "") | test("/hooks/block-") | not)) )
      ) | map(select((.hooks // []) | length > 0)) )
    | .hooks.PreToolUse += [
        { "matcher": "Bash", "hooks": [ {"type":"command","command":$co}, {"type":"command","command":$pr} ] },
        { "matcher": "Write|Edit", "hooks": [ {"type":"command","command":$md} ] }
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
    for f in "$SRC"/plugins/harness/hooks/block-*.sh; do
      [ -e "$f" ] || continue
      copy_file "$f" "$CLAUDE_HOME/hooks/$(basename "$f")"
      chmod +x "$CLAUDE_HOME/hooks/$(basename "$f")"
    done
    note "3 enforcement hooks (coauthor, pr-reviewer, md-emdash)"
  fi

  if [ "$WITH_MEMORY" = 1 ] && [ "$WITH_GLOBAL" = 1 ]; then
    head "Memory store"
    local mem="$CLAUDE_HOME/memory"; mkdir -p "$mem"
    [ -d "$CLAUDE_HOME/memory-seed" ] && { rm -rf "$CLAUDE_HOME/memory-seed"; note "removed legacy memory-seed/ (migrated to memory/)"; } || true
    for f in "$SRC"/global/memory/*.md; do
      [ -e "$f" ] || continue
      local base; base="$(basename "$f")"
      [ -f "$mem/$base" ] || copy_file "$f" "$mem/$base"
    done
    note "memory store at $mem (existing facts preserved; convention is in CLAUDE.md)"
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
    for s in block-coauthor block-pr-reviewer block-md-emdash; do
      if jq -e --arg s "$s" '.. | .command? // empty | select(test($s))' "$CLAUDE_HOME/settings.json" >/dev/null 2>&1; then
        [ -f "$CLAUDE_HOME/hooks/$s.sh" ] && note "hook wired + present: $s" || { note "WIRED BUT MISSING: hooks/$s.sh"; ok=0; }
      else
        note "NOT WIRED: $s"; ok=0
      fi
    done
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
      && [ "$(_ec block-coauthor.sh '{"tool_input":{"command":"git commit -m ok"}}')" = 0 ] \
      && note "behavior: block-coauthor denies+allows" || { note "BEHAVIOR FAIL: block-coauthor"; ok=0; }
  fi
  if [ -f "$h/block-pr-reviewer.sh" ]; then
    [ "$(_ec block-pr-reviewer.sh '{"tool_input":{"command":"gh pr create --reviewer x"}}')" = 2 ] \
      && [ "$(_ec block-pr-reviewer.sh '{"tool_input":{"command":"gh pr create --base main"}}')" = 0 ] \
      && note "behavior: block-pr-reviewer denies+allows" || { note "BEHAVIOR FAIL: block-pr-reviewer"; ok=0; }
  fi
  if [ -f "$h/block-md-emdash.sh" ]; then
    [ "$(_ec block-md-emdash.sh "$(printf '{"tool_input":{"file_path":"/x/a.md","content":"a %s b"}}' "$em")")" = 2 ] \
      && [ "$(_ec block-md-emdash.sh '{"tool_input":{"file_path":"/x/a.md","content":"a, b"}}')" = 0 ] \
      && note "behavior: block-md-emdash denies+allows" || { note "BEHAVIOR FAIL: block-md-emdash"; ok=0; }
  fi

  # memory store + bidirectional pointer integrity: every fact file is listed in MEMORY.md, and
  # every MEMORY.md link resolves to a real file. Any inconsistency fails --check.
  if [ -d "$CLAUDE_HOME/memory" ]; then
    note "memory store present"
    local idx="$CLAUDE_HOME/memory/MEMORY.md" orphan=0 mf ptr
    if [ -f "$idx" ]; then
      for mf in "$CLAUDE_HOME"/memory/*.md; do
        [ -e "$mf" ] || continue
        [ "$(basename "$mf")" = "MEMORY.md" ] && continue
        grep -qF "$(basename "$mf")" "$idx" || { note "memory: $(basename "$mf") has no MEMORY.md pointer"; orphan=1; }
      done
      for ptr in $(grep -oE '\]\([^)]+\.md\)' "$idx" | sed -E 's/^\]\(//; s/\)$//'); do
        [ -f "$CLAUDE_HOME/memory/$ptr" ] || { note "memory: MEMORY.md points to missing $ptr"; orphan=1; }
      done
      [ "$orphan" = 0 ] && note "memory: pointers consistent" || ok=0
    fi
  fi

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
