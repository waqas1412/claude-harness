# Confluence REST mechanics (session-cookie auth)

All requests go to `https://framery.atlassian.net/wiki/rest/api/...` (adjust host if another
tenant is named). Auth is Waqas's live browser session, NOT an API token.

## Cookie + headers: non-negotiable rules

- Ask the user for a fresh browser `curl` (Chrome DevTools, Network tab: right-click any
  `framery.atlassian.net` request made while logged in, ideally an XHR to `/wiki/rest/...`, then
  "Copy as cURL") if no cookie file is already in the session scratchpad. The
  `tenant.session.token` JWT is short-lived.
- From the pasted curl, save the cookie value (the `-b '...'` argument, or the `cookie:` header
  value) VERBATIM into `<scratchpad>/confluence_cookie.txt`, and copy the exact `user-agent` and
  `sec-ch-ua*` values into the fetch helper below.
- Send ALL browser headers with EXACT values, including `user-agent`, `sec-ch-ua*`, `sec-fetch-*`,
  `accept-language`, `priority`, and a plausible same-origin `referer`. Atlassian bot-detection
  keys on header fingerprint; a bare curl gets challenged or the session flagged.
- The cookie is EPHEMERAL: keep it only in the session scratchpad (never the repo, never memory,
  never a skill file), and delete the scratch copy when the task is done.

## Fetch helper (write once per session into the scratchpad as `cfetch.sh`)

```bash
#!/bin/bash
# Ephemeral Confluence session fetch. Cookie is session-scoped, do not persist.
# Usage: cfetch.sh <URL> [extra curl args]. Override referer per-call: REFERER=... cfetch.sh ...
URL="$1"; shift
curl -s "$URL" "$@" \
  -H 'accept: */*' \
  -H 'accept-language: en-GB,en-US;q=0.9,en;q=0.8' \
  -H "content-type: ${CONTENT_TYPE:-application/json}" \
  -b "$(cat "$(dirname "$0")/confluence_cookie.txt")" \
  -H 'priority: u=1, i' \
  -H "referer: ${REFERER:-https://framery.atlassian.net/wiki/}" \
  -H 'sec-ch-ua: <EXACT value from the user curl>' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'sec-fetch-dest: empty' \
  -H 'sec-fetch-mode: cors' \
  -H 'sec-fetch-site: same-origin' \
  -H 'user-agent: <EXACT value from the user curl>'
```

Replace the placeholder header values with the exact ones from the user's pasted curl. Never
pass a second `-H referer`/`-H content-type` via the extra args (curl sends duplicate headers,
which itself looks bot-like); use the `REFERER`/`CONTENT_TYPE` env overrides. Before asking the
user for a fresh curl, check sibling session scratchpads for a still-working pair:
`ls -t /private/tmp/claude-*/*/*/scratchpad/*cookie*.txt` (helpers named `cfetch.sh` or
`jfetch.sh` beside them); a test GET returning JSON (not a login HTML page) means it still works.

## Read endpoints

| Need | Request |
|---|---|
| Page content + version | `GET /wiki/rest/api/content/<id>?expand=body.storage,version,space,ancestors` |
| Direct children | `GET /wiki/rest/api/content/<id>/child/page?limit=100` |
| Whole subtree | `GET /wiki/rest/api/content/search?cql=ancestor%3D<id>%20and%20type%3Dpage&limit=200&expand=ancestors,version` |
| Find page by title | `GET /wiki/rest/api/content?spaceKey=<KEY>&title=<urlencoded>&expand=version` |

`body.storage.value` is the storage-format XHTML; `version.number` is what you must bump on PUT.
CQL search paginates via `_links.next` past `limit`.

Parsing a Confluence URL the user pastes: page id is the numeric segment and space key the
`/spaces/` segment of `https://<host>/wiki/spaces/<SPACEKEY>/pages/<pageId>/<slug>`. Short links
(`/wiki/x/<code>`) redirect: fetch with `curl -sI` and read the `location` header.

## Update an existing page (PUT)

1. Fetch fresh: `?expand=body.storage,version`. Save the full JSON as `backup_<id>_v<n>.json` in
   the scratchpad BEFORE any write.
2. Guard version drift: if `version.number` differs from the version you analyzed, STOP and
   re-diff; someone edited the page meanwhile.
3. Make surgical edits on the storage XML with unique-match find/replace ops; abort any op whose
   needle matches zero or more than one time. Never regenerate a whole existing page from scratch
   unless the user asked for a rewrite.
4. PUT with version `n+1` and a one-line `version.message` describing the change:

```json
{
  "id": "<id>", "type": "page", "title": "<unchanged title>",
  "version": {"number": <n+1>, "message": "<what changed and why>"},
  "body": {"storage": {"value": "<full new XHTML>", "representation": "storage"}}
}
```

```
PUT /wiki/rest/api/content/<id>
   ... all browser headers as above ...
   -H 'X-Atlassian-Token: no-check'
   -H 'referer: https://framery.atlassian.net/wiki/pages/viewpage.action?pageId=<id>'
   --data @put_<id>.json
```

Success = response JSON echoes `version.number == n+1`. Anything else: print the response body,
do not retry blindly (a 409 means version drift, a login HTML page means the cookie died).

## Create a new page (POST)

```json
{
  "type": "page", "title": "<title>",
  "space": {"key": "<SPACEKEY>"},
  "ancestors": [{"id": "<parentPageId>"}],
  "body": {"storage": {"value": "<XHTML>", "representation": "storage"}}
}
```

`POST /wiki/rest/api/content` with the same headers + `X-Atlassian-Token: no-check`. When the
user only names a parent page, get `space.key` by fetching the parent with `?expand=space`. The
response `id` + `_links.webui` give the URL to report back (`webui` is tenant-relative; prefix
`https://<host>/wiki`). Duplicate titles in a space fail with 400.

## Attachments (needed before view-file / ac:image references render)

```
POST /wiki/rest/api/content/<pageId>/child/attachment
   ... browser headers, but multipart, NOT json ...
   -H 'X-Atlassian-Token: no-check'
   -F 'file=@/path/to/screenshot.png'
```

Use `CONTENT_TYPE=` tricks carefully here: drop the `content-type: application/json` header
entirely and let curl set the multipart boundary (call curl directly with the browser headers
rather than through the JSON-defaulted helper). Upload attachments before (or in the same flow
as) the body write that references them by `ri:filename`.

## Batch-skim a subtree cheaply (the pattern that worked)

1. CQL `ancestor=<rootId>` -> list of ids/titles/versions.
2. Loop-fetch each page's `body.storage` to `raw_<id>.json` (add `sleep 0.15` between calls).
3. Condense each to a digest (strip tags; keep heading outline, macro-name counts, table count,
   truncated text) before letting any LLM read it. 100+ pages compress to well under 1MB of text.

## Discipline

- Dry-run by default: build and print the would-be payload/diff first; PUT/POST only after the
  user has seen what will change (or has pre-authorized publishing in this task).
- One `sleep 1` between consecutive writes.
- Never delete pages via API. Never touch pages outside the ones the user named.
- After publishing, report: page title, id, new version, and the webui link.
