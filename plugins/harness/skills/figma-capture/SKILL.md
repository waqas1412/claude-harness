---
name: figma-capture
description: "Capture a Figma design pack over the Desktop Bridge into the KB, then reconcile it against the codebase design system and report hardcodes that should be tokens. Use when Figma is the needed ground truth."
argument-hint: "[node URL or node id, plus a short slug for the capture]"
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# /figma-capture: pin a design pack, then reconcile it

The recurring ask, stated many ways: go through the layers and nodes, get the raw CSS, JSON,
breakpoints, geometry and assets, save it locally, then make the code match. The value is not the dump.
It is step 5, telling apart a value the design BINDS to a token from a value it happens to have.

## Preconditions

- The working route is our OWN bridge scripts at `connect/scripts/figma-tokens/`, not an MCP server.
  They need no PAT and no figma-console-mcp: in Figma Desktop open the file and run
  Plugins > Development > Figma Desktop Bridge, then `node scripts/figma-tokens/bridge-daemon.mjs` to
  hold the connection and `node scripts/figma-tokens/figma-node-walk.mjs --node <id> --depth <n> --out
  <dir> --png` to capture a subtree (it writes `walk.json` plus a `tokens.md` splitting bound tokens
  from raw literals, which is Step 5's input). The dir is git-ignored, so it is local-only; read its
  `README.md` for the protocol traps. The official Figma MCP View seat is exhausted, and
  `mcp__figma-console__*` is only a fallback for when those tools are actually present in the session.
- Confirm which file is open. The bridge is usually pointed at the user's COPY of a canonical DS file.
  Node ids inside a copy match the original; the file key and filename do NOT. Only a node id verified
  against the original via the REST PAT (`~/.config/framery/figma_pat.txt`) is quotable.

## Step 1: check the KB before fetching anything

`kb/sources/figma/_index.json` maps `<fileKey>` to `<slug>` entries with a `files` count and a
`referenced_by` list. Read it first and capture only what is missing. Re-capturing what is already
there is the most common waste in this task.

## Step 2: scope the subtree, do not walk the file

Pin the specific node or page the task needs and enumerate its descendants. Do not attempt a whole-file
walk: a single DS section can exceed twenty thousand descendants and the bridge call will time out.
When the ask is "all the nodes", it means all the nodes of THAT screen or section. Confirm the scope in
one line before a large capture.

## Step 3: capture

Per node in scope: name, type, id, absolute and relative geometry, auto-layout semantics (Fixed, Hug,
Fill, min and max), padding and gap, fills, strokes, effects, text style, and the variable BINDINGS
where present. Then the per-breakpoint variants for each frame size the file defines, and the PNG or
SVG exports the task actually needs.

## Step 4: write it into the KB, following the existing layout

```
kb/sources/figma/<fileKey>/<slug>/
```

Add the `_index.json` entry (`files`, `referenced_by`, and a `note` when the capture is partial).
Ticket-specific specs live in `kb/tickets/<KEY>/` and REFERENCE this capture by path; never copy the
dump into them.

## Step 5: reconcile bound tokens against raw literals

This is the point of the whole exercise. For each captured value, classify it:

- **MATCH**, the design binds a variable and the code uses the same DS token. Nothing to do.
- **DIFFER**, the design binds a variable and the code uses a raw literal or a different token. The
  DS token wins. This is the finding that matters.
- **MISSING**, the design binds a variable that has no counterpart in `src/theme`. Propose adding it
  to the DS, not a module-local constant.
- **UNBOUND**, the design uses a raw literal too. It is a designer question, not a code fix. Do not
  invent a token for it.

Prefer the DS-correct value even for a small visual shift: the DS is heavily Figma-synced and is
authoritative. See the prefer-DS-correct memory fact.

## Step 6: report, then change code separately

Report the reconcile table first and let the user decide the blast radius. Capture and code change are
two steps, not one.

## Gotchas

- `connect/scripts/figma-tokens/` (dump, resolve, reconcile, catalog, plus its tests) is the built
  pipeline for the TOKEN half of this job. It is gitignored via `~/.gitignore_global` line 10, so it is
  deliberately local-only tooling: use it, but never reference its path from production code, a PR
  body, a ticket, or a Confluence page. The token VALUES it produced did ship (commit `f8e6330f` on
  development); the scripts did not.
- Never let a capture's provenance leak into shared artifacts: no `kb/` paths, no `/Users/` paths, no
  COPY file keys, no dump line numbers. The portable pointer is the `figmaName` token name. See the
  code-comments memory fact.
- `figma-console` returned inconsistent resolved values in July 2026 for aliased variables. Trust the
  BINDING plus your own alias resolution over a single reported value, and cross-check with the REST
  PAT when the value drives a code change.
- Screenshots are for the user, not for measuring. Take geometry from node data, never from a pixel
  reading of an image.
- The user's DS Figma file is owned by the web lead. The job is to add or correct values FROM Figma,
  not to redesign the token system or rename existing decisions.
