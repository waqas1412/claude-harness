---
name: mcp-tool-search
description: On MCP-heavy installs, prefer on-demand tool discovery over loading every tool definition upfront.
metadata:
  type: reference
---

On installs aggregating many MCP servers or 10+ tools, loading every tool definition upfront can burn
tens of thousands of tokens before any work starts and degrades tool-selection accuracy past 30 to 50
tools. Prefer on-demand tool discovery (tool search / defer_loading) instead: keep only the 3 to 5
most-used tools always loaded, and namespace tools by service (`github_`, `slack_`) so one search
matches the whole group. This typically cuts tool-definition tokens by over 85 percent while keeping
selection accuracy high.
