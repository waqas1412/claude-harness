#!/usr/bin/env python3
"""Price the real token usage in local Claude Code transcripts.

Reads ~/.claude/projects/*/*.jsonl and the subagent transcripts under
~/.claude/projects/*/*/subagents/, which carry the full usage record per API call:
per-type token counts, the 5m/1h cache-write split and the model. One API response is
written as several lines (thinking, text, tool call) with the same usage, so each
response is counted once by message id. Nothing here touches AWS.

Dollars are Anthropic list price. Bedrock rates may differ; if they do, every figure
scales by the same factor and the ranking is unchanged. The token counts are exact.

  cost-baseline.py                 last 30 days
  cost-baseline.py --days 7        last 7 days
  cost-baseline.py --days 7 --caps 300000 200000
"""
import argparse, glob, json, os, time
from collections import defaultdict

# Per-MTok input price and cache-read multiplier. Output is 5x input; 5m write 1.25x; 1h write 2.0x.
# Most specific key first: Opus 5.5 reads at $0.20, which is 0.05x its $4 input.
RATE = {"opus-5-5": (4.0, 0.05), "opus": (5.0, 0.1), "sonnet": (2.0, 0.1), "haiku": (1.0, 0.1)}


def family(model):
    m = (model or "").lower()
    for k in RATE:
        if k in m:
            return k
    return None


def transcripts():
    base = os.path.expanduser("~/.claude/projects")
    yield from ((p, "main") for p in glob.glob(f"{base}/*/*.jsonl"))
    yield from ((p, "subagent") for p in glob.glob(f"{base}/*/*/subagents/*.jsonl"))


def records(days):
    cutoff = time.time() - days * 86400
    seen = set()
    for path, where in transcripts():
        try:
            if os.path.getmtime(path) < cutoff:
                continue
        except OSError:
            continue
        with open(path, errors="ignore") as fh:
            for line in fh:
                if '"usage"' not in line:
                    continue
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                msg = entry.get("message") or {}
                usage = msg.get("usage") or entry.get("usage")
                if not isinstance(usage, dict):
                    continue
                fam = family(msg.get("model") or entry.get("model"))
                if not fam:
                    continue
                rid = msg.get("id") or entry.get("requestId") or entry.get("uuid")
                if rid in seen:
                    continue
                seen.add(rid)
                stamp = entry.get("timestamp") or ""
                if stamp[:19] < time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(cutoff)):
                    continue
                writes = usage.get("cache_creation") or {}
                yield {
                    "fam": fam,
                    "where": where,
                    "path": path,
                    "ts": stamp,
                    "day": stamp[:10],
                    "uncached": usage.get("input_tokens") or 0,
                    "read": usage.get("cache_read_input_tokens") or 0,
                    "w5": writes.get("ephemeral_5m_input_tokens") or 0,
                    "w1": writes.get("ephemeral_1h_input_tokens") or 0,
                    "out": usage.get("output_tokens") or 0,
                    "think": (usage.get("output_tokens_details") or {}).get("thinking_tokens") or 0,
                }


def price(r):
    return sum(parts(r).values())


def parts(r):
    rate, read = RATE[r["fam"]]
    return {
        "cache reads": r["read"] * rate * read / 1e6,
        "5m cache writes": r["w5"] * rate * 1.25 / 1e6,
        "1h cache writes": r["w1"] * rate * 2.0 / 1e6,
        "output": r["out"] * rate * 5 / 1e6,
        "uncached input": r["uncached"] * rate / 1e6,
    }


def ttl_replay(rows):
    """Re-price main-loop input under each TTL from the real start-to-start gaps.

    A response after a gap longer than the TTL rewrites its whole prefix; otherwise it
    reads the prefix and writes only the new tail. Observed rebuilds after a >5m gap get
    the median small write as their tail, since the real tail is hidden inside the rebuild.
    """
    main = sorted((r for r in rows if r["where"] == "main"), key=lambda r: (r["path"], r["ts"]))
    small = sorted(r["w5"] + r["w1"] for r in main if r["w5"] + r["w1"] < 20_000) or [0]
    tail = small[len(small) // 2]
    out = {}
    for ttl, mult in ((300, 1.25), (3600, 2.0)):
        cost, prev = 0.0, {}
        for r in main:
            rate, read = RATE[r["fam"]]
            w = r["w5"] + r["w1"]
            prefix = r["read"] + w
            t = time.mktime(time.strptime(r["ts"][:19], "%Y-%m-%dT%H:%M:%S"))
            gap = t - prev.get(r["path"], t)
            prev[r["path"]] = t
            new = w if gap <= 300 or w < 20_000 else tail
            cost += prefix * rate * mult if gap > ttl else (prefix - new) * rate * read + new * rate * mult
        out[ttl] = cost / 1e6
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--caps", type=int, nargs="*", default=[400_000, 300_000, 200_000])
    args = ap.parse_args()

    rows = list(records(args.days))
    if not rows:
        print(f"no usage records in the last {args.days} days")
        return

    by_model = defaultdict(lambda: defaultdict(float))
    by_day = defaultdict(lambda: defaultdict(float))
    sizes = []
    total = 0.0
    for r in rows:
        cost = price(r)
        total += cost
        for bucket, key in ((by_model, (r["fam"], r["where"])), (by_day, r["day"])):
            b = bucket[key]
            b["reqs"] += 1
            b["cost"] += cost
            for f in ("uncached", "read", "w5", "w1", "out", "think"):
                b[f] += r[f]
        if r["fam"].startswith("opus") and r["where"] == "main":
            sizes.append(r["uncached"] + r["read"] + r["w5"] + r["w1"])

    print(f"last {args.days} days: {len(rows)} API calls, ${total:,.0f} at list price\n")

    head = f"{'model/where':22s}{'calls':>7s}{'cache read':>13s}{'5m write':>11s}{'1h write':>11s}{'output':>10s}{'$ list':>10s}{'share':>7s}"
    print(head)
    print("-" * len(head))
    for key, b in sorted(by_model.items(), key=lambda kv: -kv[1]["cost"]):
        print(
            f"{key[0] + '/' + key[1]:22s}{b['reqs']:>7.0f}{b['read'] / 1e6:>12.0f}M"
            f"{b['w5'] / 1e6:>10.1f}M{b['w1'] / 1e6:>10.2f}M{b['out'] / 1e6:>9.1f}M"
            f"{b['cost']:>10.0f}{100 * b['cost'] / total:>6.0f}%"
        )

    agg = defaultdict(float)
    for b in by_model.values():
        for f in ("uncached", "read", "w5", "w1", "out", "think"):
            agg[f] += b[f]
    comp = defaultdict(float)
    for r in rows:
        for name, v in parts(r).items():
            comp[name] += v
    print("\nwhere the money goes:")
    for name, v in sorted(comp.items(), key=lambda kv: -kv[1]):
        print(f"  {name:18s} ${v:>8,.0f}  {100 * v / max(total, 1e-9):>4.0f}%")

    denom = agg["read"] + agg["w5"] + agg["w1"] + agg["uncached"]
    print(f"\ncache read share of all input: {100 * agg['read'] / max(denom, 1):.1f}%")
    print(f"thinking share of output:      {100 * agg['think'] / max(agg['out'], 1):.0f}%")
    writes = agg["w1"] + agg["w5"]
    print(f"1h share of cache writes:      {100 * agg['w1'] / max(writes, 1):.1f}%  (0% means the 1h TTL is not in effect)")

    if sizes:
        sizes.sort()
        n = len(sizes)
        q = lambda p: sizes[min(int(n * p), n - 1)] / 1000
        print(f"\nopus main-loop input per call (k tokens), n={n}:")
        print(f"  median {q(0.5):.0f}k   p75 {q(0.75):.0f}k   p90 {q(0.90):.0f}k   p99 {q(0.99):.0f}k   max {sizes[-1] / 1000:.0f}k")
        grand = sum(sizes)
        print("\ntokens sitting above a compaction cap (floor estimate, cache-read rate):")
        for cap in sorted(args.caps, reverse=True):
            excess = sum(s - cap for s in sizes if s > cap)
            over = sum(1 for s in sizes if s > cap)
            print(
                f"  {cap // 1000:>4}k  {excess / 1e9:>5.2f}B  {100 * excess / max(grand, 1):>3.0f}% of input"
                f"  {100 * over / n:>4.0f}% of calls affected  ~${excess * RATE['opus-5-5'][0] * RATE['opus-5-5'][1] / 1e6:>6,.0f}/period"
            )
        print("  floor only: it counts tokens above the line, not the lower restart after each compaction.")

    replay = ttl_replay(rows)
    print(f"\nmain-loop TTL replay on real gaps (input + writes): 5m ${replay[300]:,.0f}   1h ${replay[3600]:,.0f}")

    print(f"\n{'day':12s}{'calls':>7s}{'cache read':>13s}{'5m write':>11s}{'1h write':>11s}{'$ list':>9s}")
    for day in sorted(by_day)[-args.days:]:
        b = by_day[day]
        print(
            f"{day:12s}{b['reqs']:>7.0f}{b['read'] / 1e6:>12.0f}M{b['w5'] / 1e6:>10.1f}M"
            f"{b['w1'] / 1e6:>10.2f}M{b['cost']:>9.0f}"
        )


if __name__ == "__main__":
    main()
