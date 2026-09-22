# Confluence storage-format (XHTML) recipes

Real snippets mined from the corpus, genericized but structurally exact. Storage format is
strict XHTML: close every element, self-close empty ones (`<p />`, `<ri:page ... />`,
`<time ... />`), and escape raw `&` `<` `>` in text as entities, or the PUT fails with an XML
parse error. `ac:macro-id` / `ac:local-id` are server-assigned: omit them on NEW content
(standard Confluence behavior is to regenerate them; every read-back macro has one) and preserve
existing ones untouched when surgically editing a fetched body.

## Status lozenge (the house workflow vocabulary)

```xml
<ac:structured-macro ac:name="status" ac:schema-version="1"><ac:parameter ac:name="title">approved</ac:parameter><ac:parameter ac:name="colour">Green</ac:parameter></ac:structured-macro>
```

Params: `title` plus optional `colour`, conventionally title-first; `colour` capitalized:
Green | Yellow | Blue | Red | Purple (omit = grey).
House vocabulary: Blue "work in progress" / `ESTIMATE: N days`; Yellow "ready for review" /
"In progress" / `AFTER FIRST RELEASE` / "open question"; Green "approved" / `COMPLETED` /
"solved" / `FIRST RELEASE`; Red "blocked"; Purple "future dev". Reuse one exact casing per
lozenge text; the title renders uppercase.

## Jira issue (never write bare ticket keys)

```xml
<ac:structured-macro ac:name="jira" ac:schema-version="1"><ac:parameter ac:name="key">WEB-1234</ac:parameter><ac:parameter ac:name="serverId">f0da01d5-8c0a-3293-ae39-b445767839f0</ac:parameter><ac:parameter ac:name="server">System Jira</ac:parameter></ac:structured-macro>
```

`server` + `serverId` must match the tenant's Jira instance or the lozenge renders permanently
broken. Framery pair: `System Jira` / `f0da01d5-8c0a-3293-ae39-b445767839f0`. For another
tenant, copy the pair from any existing page that embeds Jira. Place the macro next to the exact
thing it tracks (heading, bullet, table cell, task item).

## Table of contents (top of every long doc)

```xml
<ac:structured-macro ac:name="toc" ac:schema-version="1" data-layout="default"><ac:parameter ac:name="style">none</ac:parameter></ac:structured-macro>
```

House default is `style=none` (flat). Scoped variant adds `minLevel`/`maxLevel` params.

## Code block

```xml
<ac:structured-macro ac:name="code" ac:schema-version="1"><ac:parameter ac:name="language">sql</ac:parameter><ac:plain-text-body><![CDATA[SELECT id FROM t WHERE v = 1]]></ac:plain-text-body></ac:structured-macro>
```

Body is ALWAYS `<ac:plain-text-body><![CDATA[...]]>`. If the code contains `]]>`, split the
CDATA as `]]]]><![CDATA[>`. Language values are short editor codes: sql, json, py (not python),
go, bash, html, text; omit the param for pseudo-API sketches (the house norm for endpoint
specs). Wide blocks (long SQL, ASCII diagrams) add
`<ac:parameter ac:name="breakoutMode">wide</ac:parameter><ac:parameter ac:name="breakoutWidth">1800</ac:parameter>`.

## Callout panels

```xml
<ac:structured-macro ac:name="info" ac:schema-version="1"><ac:rich-text-body><p>Reader guidance.</p></ac:rich-text-body></ac:structured-macro>
<ac:structured-macro ac:name="note" ac:schema-version="1"><ac:rich-text-body><p>NOTE! Deprecation / staleness banner.</p></ac:rich-text-body></ac:structured-macro>
```

Reserve panels for page-lifecycle metadata: role banners on hubs, "moved here from X"
provenance, dated supersede notices, must-read routing, AI-generated-content disclosure. Inline
cautions in body text are plain "NB:" / "Note!" prose. Don't use the `panel` macro (not house
standard).

## Expand (collapsible)

```xml
<ac:structured-macro ac:name="expand" ac:schema-version="1"><ac:parameter ac:name="title">GET /service/things response</ac:parameter><ac:rich-text-body><p>...usually one code macro...</p></ac:rich-text-body></ac:structured-macro>
```

House pattern in API designs: one expand per endpoint, titled by purpose, wrapping one code
macro. Wide variant: `data-layout="wide"` attribute + `breakoutWidth` param.

## Links

```xml
<!-- internal page (same space) -->
<ac:link ac:card-appearance="inline"><ri:page ri:content-title="Exact Page Title" /><ac:link-body>Exact Page Title</ac:link-body></ac:link>
<!-- cross-space: MUST add ri:space-key or the link dangles -->
<ac:link ac:card-appearance="inline"><ri:page ri:space-key="OTHER" ri:content-title="Exact Page Title" /><ac:link-body>Exact Page Title</ac:link-body></ac:link>
<!-- heading anchor -->
<ac:link ac:card-appearance="inline" ac:anchor="Open-questions"><ri:page ri:content-title="Exact Page Title" /><ac:link-body>text</ac:link-body></ac:link>
<!-- user @mention: needs the Atlassian account id -->
<ac:link><ri:user ri:account-id="712020:xxxx-..." /></ac:link>
<!-- external -->
<a href="https://example.com/path" data-card-appearance="inline">https://example.com/path</a>
```

`ri:content-title` is the EXACT page title. `ri:version-at-save` appears in read-back data;
omitting it on writes relies on standard Confluence server behavior (keep it if editing existing
markup). `ac:card-appearance` and `data-card-appearance` are cosmetic; the attribute-less forms
are equally valid and actually the corpus majority. Anchor values: spaces become hyphens,
periods are kept, and colons/slashes/quotes/emoji are percent-encoded
(`Special-rule%3A-...`, `Pairing-%2F-unpairing-spaces`).

## Tables

```xml
<table data-layout="default"><tbody>
<tr><th><p><strong>Column A</strong></p></th><th><p><strong>Column B</strong></p></th></tr>
<tr><td><p>value</p></td><td><p /></td></tr>
</tbody></table>
```

No `<thead>`: the header row is a `<tr>` of `<th>` at the top of `<tbody>`. Text content wraps
in `<p>`; block elements (`ul`/`ol`/headings/macros) sit directly in the cell without a `<p>`
wrapper. An empty cell is `<td><p /></td>`, never `<td></td>`. Optional sizing:
`data-table-width` on `<table>` (most corpus tables carry it), `<colgroup>` of self-closed
`<col style="width: Npx;" />`; `data-layout` values seen: align-start (most common), default.
Cell shading via `data-highlight-colour="#f4f5f7"` on td/th.

## Task list (action items, deployment checklists)

```xml
<ac:task-list>
<ac:task>
<ac:task-id>1</ac:task-id>
<ac:task-uuid>1</ac:task-uuid>
<ac:task-status>incomplete</ac:task-status>
<ac:task-body><span class="placeholder-inline-tasks">Name to do the thing</span></ac:task-body>
</ac:task>
</ac:task-list>
```

task-id/task-uuid unique per page; status is incomplete | complete.

## Dates, emojis, images

```xml
<h2>Meeting notes <time datetime="2026-07-02" /></h2>
<ac:emoticon ac:name="blue-star" ac:emoji-shortname=":construction:" ac:emoji-id="1f6a7" ac:emoji-fallback="🚧" />
<ac:image ac:align="center" ac:layout="center" ac:alt="screenshot.png"><ri:attachment ri:filename="screenshot.png" /><ac:caption><p>Optional caption</p></ac:caption></ac:image>
```

Every corpus image also carries `ac:original-width`/`ac:original-height`; the server backfills
dimensions on save, so the minimal form above is acceptable for writes, but include `ac:alt`.

## Attachments (view-file, images)

`view-file` and `ac:image` reference page attachments by `ri:filename`; upload via
`POST /wiki/rest/api/content/<id>/child/attachment` BEFORE the body references them, or they
render broken.

```xml
<ac:structured-macro ac:name="view-file" ac:schema-version="1"><ac:parameter ac:name="name"><ri:attachment ri:filename="report.pdf" /></ac:parameter></ac:structured-macro>
```

## draw.io diagrams: DO NOT emit

The `drawio` macro only references diagram data stored as separate custom content on the source
page (`custContentId` + `pageId` params). Writing the macro XML to a new page yields a broken
diagram. Instead: emit a placeholder paragraph (`<p><em>TODO(<name>): insert draw.io diagram of
<what it should show></em></p>`) or an `ac:image` snapshot, and let a human insert the real
diagram in the editor. To reuse a diagram another page owns, `inc-drawio` transclusion works,
but add a "Original diagram source is on <page>" note.

## Reusable excerpt (running-memo entry template)

```xml
<ac:structured-macro ac:name="excerpt" ac:schema-version="1"><ac:parameter ac:name="hidden">true</ac:parameter><ac:parameter ac:name="name">Memo template</ac:parameter><ac:rich-text-body><p>Copy this excerpt when having a new meeting</p><!-- blank entry skeleton --></ac:rich-text-body></ac:structured-macro>
```

## Placeholders in templates

`<ac:placeholder>@ mention someone</ac:placeholder>` renders grey and vanishes when edited; use
for fill-me-in cells in metadata tables.

## Layouts: default to none

Only 4 of 109 pages use `ac:layout`. If you do, the ENTIRE body must live inside
`ac:layout > ac:layout-section (ac:type = fixed-width | two_equal | three_equal |
two_right_sidebar) > ac:layout-cell`; mixed top-level content breaks the editor. Skip layouts
unless matching an existing page that has them.

## Other write-side gotchas

- Smart punctuation may be written as HTML entities (`&rsquo; &ldquo; &rarr;`) or raw UTF-8;
  both are accepted.
- Unknown macro names don't fail the PUT; they render an "unknown macro" error box. Typo-check
  macro names.
- `version.number` must be exactly current+1; stale gives 409.
- Quick local well-formedness smoke test before a PUT: strip entities, wrap in a namespace root,
  parse:

```python
import re, xml.etree.ElementTree as ET
body_test = re.sub(r'&[a-zA-Z#0-9]+;', 'X', body)
ET.fromstring('<root xmlns:ac="urn:a" xmlns:ri="urn:r">' + body_test + '</root>')
```
