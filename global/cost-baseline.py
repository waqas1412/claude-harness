#!/usr/bin/env python3
"""Price the real token usage in local Claude Code transcripts.

Reads ~/.claude/projects/*/*.jsonl, which carry the full usage record per API call:
per-type token counts, the 5m/1h cache-write split, the model, and whether the call
came from a subagent. Nothing here touches AWS, so it works without billing access.

Dollars are Anthropic list price. Bedrock rates may differ; if they do, every figure
scales by the same factor and the ranking is unchanged. The token counts are exact.

  cost-baseline.py                 last 30 days
  cost-baseline.py --days 7        last 7 days
  cost-baseline.py --days 7 --caps 300000 200000
"""
import argparse, glob, json, os, time
from collections import defaultdict

# Per-MTok input price. Output is 5x input; cache read 0.1x; 5m write 1.25x; 1h write 2.0x.
RATE = {"opus": 5.0, "sonnet": 2.0, "haiku": 1.0}


def family(model):
    m = (model or "").lower()
    for k in RATE:
        if k in m:
            return k
    return None


def records(days):
    cutoff = time.time() - days * 86400
    for path in glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl")):
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
                writes = usage.get("cache_creation") or {}
                yield {
                    "fam": fam,
                    "where": "subagent" if entry.get("isSidechain") else "main",
                    "day": (entry.get("timestamp") or "")[:10],
                    "uncached": usage.get("input_tokens") or 0,
                    "read": usage.get("cache_read_input_tokens") or 0,
                    "w5": writes.get("ephemeral_5m_input_tokens") or 0,
                    "w1": writes.get("ephemeral_1h_input_tokens") or 0,
                    "out": usage.get("output_tokens") or 0,
                    "think": (usage.get("output_tokens_details") or {}).get("thinking_tokens") or 0,
                }


def price(r):
    rate = RATE[r["fam"]]
    return (
        r["uncached"] * rate
        + r["w5"] * rate * 1.25
        + r["w1"] * rate * 2.0
        + r["read"] * rate * 0.1
        + r["out"] * rate * 5
    ) / 1e6


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
        if r["fam"] == "opus" and r["where"] == "main":
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
    # Composition, priced with the opus rate since it dominates.
    r = RATE["opus"]
    parts = {
        "cache reads": agg["read"] * r * 0.1,
        "5m cache writes": agg["w5"] * r * 1.25,
        "1h cache writes": agg["w1"] * r * 2.0,
        "output": agg["out"] * r * 5,
        "uncached input": agg["uncached"] * r,
    }
    print("\nwhere the money goes (opus rate):")
    for name, v in sorted(parts.items(), key=lambda kv: -kv[1]):
        print(f"  {name:18s} ${v / 1e6:>8,.0f}  {100 * v / max(sum(parts.values()), 1):>4.0f}%")

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
                f"  {100 * over / n:>4.0f}% of calls affected  ~${excess * 0.97 * 0.5 / 1e6:>6,.0f}/period"
            )
        print("  floor only: it counts tokens above the line, not the lower restart after each compaction.")

    print(f"\n{'day':12s}{'calls':>7s}{'cache read':>13s}{'5m write':>11s}{'1h write':>11s}{'$ list':>9s}")
    for day in sorted(by_day)[-args.days:]:
        b = by_day[day]
        print(
            f"{day:12s}{b['reqs']:>7.0f}{b['read'] / 1e6:>12.0f}M{b['w5'] / 1e6:>10.1f}M"
            f"{b['w1'] / 1e6:>10.2f}M{b['cost']:>9.0f}"
        )


if __name__ == "__main__":
    main()
