#!/usr/bin/env bash
#
# Single source of truth for the version. VERSION is canonical; this writes it into both manifests
# so scripts/validate.sh version-consistency check passes. Usage:
#   ./scripts/bump-version.sh 0.2.0   # set a new version
#   ./scripts/bump-version.sh         # re-sync manifests to the current VERSION
# After running: commit, then `git tag v<version>` to cut a pinnable release.
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
new="${1:-}"
cur="$(tr -d ' \t\n\r' < "$ROOT/VERSION")"
if [ -n "$new" ]; then printf '%s\n' "$new" > "$ROOT/VERSION"; else new="$cur"; fi
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

write() { local file="$1" filter="$2" tmp; tmp="$(mktemp)"; jq --arg v "$new" "$filter" "$file" > "$tmp" && mv "$tmp" "$file"; }
write "$ROOT/plugins/harness/.claude-plugin/plugin.json" '.version=$v'
write "$ROOT/.claude-plugin/marketplace.json" '.plugins[0].version=$v'

echo "version set to $new in VERSION, plugin.json, marketplace.json"
echo "next: git add -A && git commit, then: git tag v$new"
