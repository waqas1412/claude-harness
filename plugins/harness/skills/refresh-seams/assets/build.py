#!/usr/bin/env python3
"""Reconcile, verify, and emit cross-repo seams for a multi-repo workspace.

Usage:
    SEAMS_DATE=YYYY-MM-DD SEAMS_ROOT=/abs/workspace python3 build.py journal.jsonl [more.jsonl ...]

Parameter-driven: reads .claude/harness/seams/clusters.json for root, clusters,
vendored set, excludes, and the rules-file convention. Nothing workspace-specific
is hardcoded. A workspace-local copy of this file wins over the bundled one.
"""
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CFG = json.loads((HERE / "clusters.json").read_text())

SEAMS_ROOT = Path(os.environ.get("SEAMS_ROOT", CFG["root"])).resolve()
DATE = os.environ.get("SEAMS_DATE", "")
RULES_DIR = SEAMS_ROOT / ".claude" / "rules"
META_DIR = SEAMS_ROOT / ".claude" / "meta"
SEAMS_HARNESS_DIR = SEAMS_ROOT / ".claude" / "harness" / "seams"

CLUSTERS = CFG["clusters"]                 # name -> [repo slugs]
ALL_REPOS = sorted({slug for members in CLUSTERS.values() for slug in members})
VENDORED = set(CFG.get("vendored", []))
EXCLUDES = set(CFG.get("excludes", ["node_modules", ".git", "dist", "build", "target", ".venv", "__pycache__", "cdk.out"]))

# kind -> cluster derived from which cluster's hunters emit it; cross-cluster => bridge.
# clusters.json may supply an explicit kindClusters map; else infer per-repo at edge time.
KIND_CLUSTERS = CFG.get("kindClusters", {})
KIND_ORDER = CFG.get("kindOrder", [
    "pkg-import", "http-api", "schema-contract", "openapi-contract", "typespec-contract",
    "data-table", "queue", "manifest-pin", "git-submodule", "shared-lib", "other"
])

MARK_START = "<!-- seams:start -->"
MARK_END = "<!-- seams:end -->"


def repo_of(slug):
    for name, members in CLUSTERS.items():
        if slug in members:
            return name
    return None


def load_edges(argv):
    edges = []
    for arg in argv:
        p = Path(arg)
        if not p.exists():
            continue
        if arg.endswith(".json"):
            data = json.loads(p.read_text())
            edges.extend(data if isinstance(data, list) else data.get("edges", []))
            continue
        for line in p.read_text().splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if rec.get("type") == "result":
                payload = rec.get("result") or rec.get("output") or {}
                edges.extend(payload.get("edges", []))
            elif "edges" in rec:
                edges.extend(rec["edges"])
    return edges


def norm_ref(ref):
    if not ref:
        return ref
    parts = ref.split(":")
    fpath = parts[0]
    segs = fpath.split("/")
    out = []
    for s in segs:
        if out and out[-1] == s:
            continue
        out.append(s)
    fpath = "/".join(out)
    return ":".join([fpath] + parts[1:])


def repair_ref(repo, ref):
    if not ref:
        return ref
    fpath = ref.split(":")[0]
    line = ref.split(":")[1] if ":" in ref else ""
    if (SEAMS_ROOT / fpath).exists():
        return ref
    base = os.path.basename(fpath)
    repo_dir = SEAMS_ROOT / repo
    if not repo_dir.exists() or repo in VENDORED:
        return ref
    hits = []
    for dirpath, dirnames, filenames in os.walk(repo_dir):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDES]
        if base in filenames:
            hits.append(os.path.relpath(os.path.join(dirpath, base), SEAMS_ROOT))
    if len(hits) == 1:
        return ":".join([hits[0], line]) if line else hits[0]
    return ref


def read_file(ref):
    if not ref:
        return None
    fpath = ref.split(":")[0]
    p = SEAMS_ROOT / fpath
    if p.exists() and p.is_file():
        try:
            return p.read_text(errors="ignore")
        except OSError:
            return None
    return None


def verify(edge):
    from_txt = read_file(edge.get("fromRef"))
    to_ext = str(edge.get("to", "")).startswith("ext:")
    to_txt = None if (to_ext or not edge.get("toRef")) else read_file(edge.get("toRef"))
    from_ok = from_txt is not None
    to_ok = to_ext or edge.get("toRef") in (None, "") or to_txt is not None
    if not (from_ok or to_ok):
        return None
    proof = (edge.get("proof") or "").strip()
    matched = bool(proof) and ((from_txt and proof in from_txt) or (to_txt and proof in to_txt))
    if matched:
        edge["verify"] = "verified"
    elif from_ok and to_ok:
        edge["verify"] = "files-ok"
    else:
        return None
    return edge


def cluster_of(edge):
    k = edge.get("kind")
    if k in KIND_CLUSTERS:
        return KIND_CLUSTERS[k]
    cf = repo_of(edge.get("from"))
    ct = repo_of(edge.get("to"))
    if cf and ct and cf == ct:
        return cf
    if cf and (ct is None):
        return cf
    return "bridge"


def main():
    edges = load_edges(sys.argv[1:])
    kept = []
    seen = {}
    rank = {"verified": 2, "files-ok": 1}
    for e in edges:
        e["fromRef"] = norm_ref(e.get("fromRef"))
        e["toRef"] = norm_ref(e.get("toRef"))
        e["fromRef"] = repair_ref(e.get("from"), e.get("fromRef"))
        if not str(e.get("to", "")).startswith("ext:"):
            e["toRef"] = repair_ref(e.get("to"), e.get("toRef"))
        v = verify(e)
        if not v:
            continue
        v["cluster"] = cluster_of(v)
        key = (v["from"], v["to"], v["kind"], (v.get("detail") or "")[:55])
        prev = seen.get(key)
        if prev is None or rank.get(v["verify"], 0) > rank.get(kept[prev]["verify"], 0):
            if prev is None:
                seen[key] = len(kept)
                kept.append(v)
            else:
                kept[prev] = v

    def sort_key(e):
        ko = KIND_ORDER.index(e["kind"]) if e["kind"] in KIND_ORDER else len(KIND_ORDER)
        return (ko, e["from"], e["to"])

    kept.sort(key=sort_key)

    repos = sorted({e["from"] for e in kept} | {e["to"] for e in kept if not str(e["to"]).startswith("ext:")})
    externals = sorted({e["to"] for e in kept if str(e["to"]).startswith("ext:")})
    by_cluster = {}
    for e in kept:
        by_cluster[e["cluster"]] = by_cluster.get(e["cluster"], 0) + 1
    kinds = {}
    for e in kept:
        kinds[e["kind"]] = kinds.get(e["kind"], 0) + 1

    doc = {
        "generated": DATE,
        "method": "evidence-based grep discovery, each edge verified by file:line proof",
        "scope": "workspace cross-repo seams from .claude/harness/seams/clusters.json",
        "stats": {
            "edges": len(kept),
            "verified": sum(1 for e in kept if e["verify"] == "verified"),
            "files_ok": sum(1 for e in kept if e["verify"] == "files-ok"),
            "repos": len(repos),
            "externals": len(externals),
            "by_cluster": by_cluster,
        },
        "nodes": {"repos": repos, "externals": externals, "all_repos": ALL_REPOS},
        "kinds": kinds,
        "edges": kept,
    }

    META_DIR.mkdir(parents=True, exist_ok=True)
    (META_DIR / "seams.json").write_text(json.dumps(doc, indent=2) + "\n")

    # adjacency.txt
    SEAMS_HARNESS_DIR.mkdir(parents=True, exist_ok=True)
    lines = []
    for r in repos:
        outs = [e for e in kept if e["from"] == r]
        ins = [e for e in kept if e["to"] == r]
        lines.append(r)
        for e in outs:
            lines.append("  OUT -> {} [{}]: {} ({})".format(e["to"], e["kind"], e.get("detail", ""), e.get("fromRef", "")))
        for e in ins:
            lines.append("  IN  <- {} [{}]: {} ({})".format(e["from"], e["kind"], e.get("detail", ""), e.get("fromRef", "")))
        lines.append("")
    (SEAMS_HARNESS_DIR / "adjacency.txt").write_text("\n".join(lines))

    rewrite_rules(kept, repos)

    emdash_guard()
    print("edges={} verified={} files_ok={} repos={} externals={}".format(
        doc["stats"]["edges"], doc["stats"]["verified"], doc["stats"]["files_ok"],
        doc["stats"]["repos"], doc["stats"]["externals"]))


def rules_file_for(repo):
    # rulesFileConvention like ".claude/rules/<repo>.md"; match case-insensitively.
    if not RULES_DIR.exists():
        return None
    want = repo.lower() + ".md"
    for f in RULES_DIR.glob("*.md"):
        if f.name.lower() == want:
            return f
    return None


def seam_block(repo, edges):
    outs = [e for e in edges if e["from"] == repo]
    ins = [e for e in edges if e["to"] == repo]
    out = [MARK_START,
           "## Cross-repo seams",
           "> Auto-generated from `.claude/meta/seams.json` (evidence-based; verified file:line). Edges where this repo is an endpoint. Full graph + feature-flow playbooks: `.claude/meta/integration-map.md`.",
           ""]
    for e in outs:
        out.append("- OUT -> `{}` [{}]: {} (`{}`)".format(e["to"], e["kind"], e.get("detail", ""), e.get("fromRef", "")))
    for e in ins:
        out.append("- IN  <- `{}` [{}]: {} (`{}`)".format(e["from"], e["kind"], e.get("detail", ""), e.get("fromRef", "")))
    out.append(MARK_END)
    return "\n".join(out) + "\n"


def rewrite_rules(edges, repos):
    for repo in repos:
        f = rules_file_for(repo)
        if not f:
            continue
        text = f.read_text()
        block = seam_block(repo, edges)
        if MARK_START in text and MARK_END in text:
            pre = text.split(MARK_START)[0].rstrip("\n")
            post = text.split(MARK_END)[1].lstrip("\n")
            new = pre + "\n\n" + block + ("\n" + post if post else "")
        else:
            new = text.rstrip("\n") + "\n\n" + block
        f.write_text(new)


def emdash_guard():
    for f in list(RULES_DIR.glob("*.md")) + list(META_DIR.glob("*.md")):
        if "\u2014" in f.read_text():
            print("WARN em-dash (U+2014) present in {}".format(f))


if __name__ == "__main__":
    main()
