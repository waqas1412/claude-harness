export const meta = {
  name: 'discover-cross-repo-seams',
  description: 'Evidence-based cross-repo seam discovery across a parameterized set of repo clusters; one hunter agent per connection mechanism, every edge proven by a grepped file:line.',
  phases: [{ title: 'Discover seams', detail: 'seam-hunter agents, grep-proven edges with file:line' }],
}

// Evidence-based cross-repo seam discovery. Runs one read-only hunter agent per
// CONNECTION MECHANISM (not per repo pair), all in parallel. This sandbox has no
// filesystem or Node.js API access, so every parameter (root, cluster/repo lists,
// vendored set, excludes, hunter definitions) arrives via the workflow `args`
// global: the caller reads .claude/harness/seams/clusters.json and passes the
// parsed object as args.config (plus an optional args.scope). Nothing here is
// workspace-specific.

const CFG = (typeof args !== "undefined" && args && args.config) ? args.config : null
if (!CFG) {
  throw new Error("pass the parsed clusters.json object as args.config")
}

const ROOT = CFG.root
const CLUSTERS = CFG.clusters || {}
const VENDORED = CFG.vendored || []
const EXCLUDES = CFG.excludes || ["node_modules", ".git", "dist", "build", "target", ".venv", "__pycache__", "cdk.out"]
const KIND_CLUSTERS = CFG.kindClusters || {}

// Optional scope, also read from args (e.g. Workflow(scriptPath, { args: { config, scope } })). A
// cluster name, a repo slug, or a hunter key, matched case-insensitively as a substring of the raw
// scope string (so a phrase like "services cluster only" or "just the gateway and web-client
// edges" both work). No scope, or a scope that matches nothing, falls back to a full run.
const RAW_SCOPE = (typeof args !== "undefined" && args && args.scope) ? String(args.scope).toLowerCase() : ""

function inScope(name) {
  return !RAW_SCOPE || RAW_SCOPE.includes(String(name).toLowerCase())
}

const ALL_CLUSTER_NAMES = Object.keys(CLUSTERS)
const CLUSTER_NAMES_IN_SCOPE = ALL_CLUSTER_NAMES.filter(inScope)
const ALL_REPOS = Object.values(CLUSTERS).flat()
const REPOS_NAMED_IN_SCOPE = ALL_REPOS.filter(inScope)

// Flat union of in-scope repo slugs, passed to every hunter prompt: repos named directly in the
// scope win; else the repos of any matched cluster; else (no scope, or scope matched nothing) all of them.
const CLUSTER = !RAW_SCOPE
  ? ALL_REPOS
  : (REPOS_NAMED_IN_SCOPE.length
      ? REPOS_NAMED_IN_SCOPE
      : (CLUSTER_NAMES_IN_SCOPE.length ? CLUSTER_NAMES_IN_SCOPE.flatMap((n) => CLUSTERS[n]) : ALL_REPOS))

// Structured output contract every hunter must return.
const EDGE_SCHEMA = {
  type: "object",
  properties: {
    hunter: { type: "string" },
    notes: { type: "string" },
    edges: {
      type: "array",
      items: {
        type: "object",
        required: ["from", "fromRef", "to", "kind", "direction", "detail", "proof", "confidence"],
        properties: {
          from: { type: "string" },
          fromRef: { type: "string" },       // root-relative file:line on the FROM side
          to: { type: "string" },            // repo slug, or ext:<name> for external systems
          toRef: { type: "string" },         // file:line on TO side; "" when external
          kind: { type: "string" },          // mechanism tag; see hunter.kind
          direction: { type: "string" },
          detail: { type: "string" },        // join key (table/topic/endpoint/etc.)
          proof: { type: "string" },         // exact grep-matched source line, trimmed
          confidence: { enum: ["high", "medium", "low"] }
        }
      }
    }
  },
  required: ["hunter", "edges"]
}

// Hunters come from config; if absent, fall back to a neutral default set covering
// the most common cross-repo mechanisms. Each: { key, effort, mechanism, guidance, kind }.
const DEFAULT_HUNTERS = [
  { key: "pkg-import",     effort: "medium", kind: "pkg-import",     mechanism: "one repo imports a package/library published or vendored by another repo", guidance: "look for dependency manifests and import statements naming a sibling repo's package" },
  { key: "http-api",       effort: "medium", kind: "http-api",       mechanism: "one repo calls another's HTTP/REST endpoint", guidance: "grep client base URLs and route strings; match to server route definitions" },
  { key: "schema-contract",effort: "medium", kind: "schema-contract",mechanism: "a shared schema/IDL/spec contract (OpenAPI, protobuf, typespec) generated or consumed across repos", guidance: "find spec files and their generated clients in sibling repos" },
  { key: "data-table",     effort: "medium", kind: "data-table",     mechanism: "shared database tables/views written by one repo and read by another", guidance: "match table/view names across schema DDL and query sources" },
  { key: "queue",          effort: "low",    kind: "queue",          mechanism: "message-queue producer/consumer pairs", guidance: "match queue/topic names between publish and subscribe sites" },
  { key: "manifest-pin",   effort: "low",    kind: "manifest-pin",   mechanism: "a manifest or submodule that pins another repo at a revision", guidance: "read manifest/submodule files; each pinned entry is one edge" }
]
const HUNTERS_ALL = (CFG.hunters && CFG.hunters.length) ? CFG.hunters : DEFAULT_HUNTERS

// A hunter stays in scope if: no scope was given; its own key is named in the scope string; its
// mechanism's kind maps (via clusters.json kindClusters) to an in-scope cluster; or its kind has no
// cluster mapping at all (an unmapped mechanism cannot be safely excluded by a cluster-only scope).
function hunterInScope(h) {
  if (!RAW_SCOPE) return true
  if (inScope(h.key)) return true
  const cluster = KIND_CLUSTERS[h.kind]
  return cluster ? CLUSTER_NAMES_IN_SCOPE.includes(cluster) : true
}

const HUNTERS = HUNTERS_ALL.filter(hunterInScope)

function base(h) {
  return [
    "You are a read-only cross-repo seam hunter. Do NOT edit any file.",
    "Workspace root: " + ROOT,
    "In-scope repos (flat list): " + CLUSTER.join(", "),
    "Your mechanism: " + h.mechanism,
    "Guidance: " + h.guidance,
    "Emit edges with kind = " + h.kind + ".",
    "Grep the FROM side for the concrete reference, then confirm the TO side file exists.",
    "Exclude these dirs from all greps: " + EXCLUDES.join(", ") + ".",
    "Vendored/black-box repos (find only the CONSUMER-side reference to them, never recurse their base tree): " + VENDORED.join(", ") + ".",
    "For an external system with no in-workspace repo, set to = 'ext:<name>' and toRef = ''.",
    "Every edge needs a 'proof' that is an exact source line you grepped, trimmed.",
    "Return { hunter, notes, edges[] } matching the schema. Be condensed; no prose dumps."
  ].join("\n")
}

// Model is pinned per hunter, not chosen ad hoc: a low-effort (single-grep, mechanical) hunter runs
// haiku; every other hunter runs sonnet (evidence grep plus judgment on proof lines).
function modelFor(h) {
  return h.effort === "low" ? "haiku" : "sonnet"
}

phase('Discover seams')
log(`Hunting ${HUNTERS.length} seam mechanisms across ${CLUSTER.length} repos.`)

const results = await parallel(
  HUNTERS.map((h) => () =>
    agent(base(h), {
      label: `seam:${h.key}`,
      phase: 'Discover seams',
      model: modelFor(h),
      effort: h.effort ?? 'medium',
      schema: EDGE_SCHEMA,
    }).then((r) => ({ hunter: h.key, ...(r || { edges: [], notes: 'null result' }) }))
  )
)

const all = results.filter(Boolean)
const total = all.reduce((n, r) => n + (r.edges ? r.edges.length : 0), 0)
log(`Discovery done: ${total} raw edges across ${all.length} mechanisms.`)
return all
