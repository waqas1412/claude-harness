#!/bin/sh
# One agent-panel row per subagent: the model and effort it actually runs on, which the main status
# line cannot show because it reports the session model only.
set -eu

jq -c '
  (.columns // 100) as $cols
  | .tasks[]?
  | (.model // "" | sub("^[a-z]+\\.anthropic\\.claude-"; "") | sub("^claude-"; "") | sub("\\[1m\\]$"; "")) as $m
  | (if .contextWindowSize and .contextWindowSize > 0
       then " \u001b[2m\((.tokenCount // 0) * 100 / .contextWindowSize | floor)%\u001b[0m" else "" end) as $pct
  | (if .status == "running" then "\u001b[32m"
     elif .status == "completed" then "\u001b[2m"
     else "\u001b[31m" end) as $sc
  | ([.name // .agentType, (if $m != "" then $m else empty end), (.effort // empty | tostring)] | join(" · ")) as $head
  | ($head | length) as $used
  | ((.label // .description // "") | .[0:([$cols - $used - 12, 0] | max)]) as $label
  | {id: .id, content: "\($sc)●\u001b[0m \($head)\($pct) \u001b[2m\($label)\u001b[0m"}
'
