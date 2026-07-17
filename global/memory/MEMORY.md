# Memory Index

Legend: **Rules** = always-on working agreements (these now live in `~/.claude/CLAUDE.md`; keep this
index for project and reference notes). **Projects/Reference** = pointers; open the file for detail.

One file per fact, with frontmatter (`name`, `description`, `metadata.type` = user | feedback |
project | reference). Add a one-line pointer here when you create a memory file.

## User
- [User background](user_background.md) — JS developer learning Go; anchor Go explanations in JS analogies first.

## Feedback
- [No Fable for subagents](feedback_no_fable_for_subagents.md) — main loop is the brain only, it never
  executes actions itself; every delegated agent gets an explicitly pinned non-session model (opus for
  hard reasoning, sonnet as the executor default, haiku for mechanical sweeps); agents report back a
  condensed digest (roughly 1-2k tokens with file:line pointers), never raw logs or dumps.

## Projects
(none yet)

## Reference
(none yet)
