#!/usr/bin/env python3
"""PostToolUse hook: shrink verbose test/Playwright output before it reaches the
model's context, without dropping decision-relevant signal.

Contract (verified against code.claude.com/docs/en/hooks and an empirical probe):
  stdin  = PostToolUse event JSON; Bash output is tool_response.{stdout,stderr}
           (tool_response is a dict: stdout, stderr, interrupted, isImage,
           noOutputExpected).
  stdout = {"hookSpecificOutput": {"hookEventName": "PostToolUse",
            "updatedToolOutput": <tool_response with filtered stdout/stderr>,
            "additionalContext": "<what was trimmed>"}}
  exit 0 always.

Design for a quality-first user:
  * Only recognized test/Playwright runners with large output are touched;
    everything else passes through untouched.
  * The surfaced digest is filled by SEVERITY TIER, not by line order, so a real
    failure late in a log can never be pushed out of the cap by warnings or
    assertion chatter earlier in the log. Tier 1 hard failures, then tier 2 run
    summaries, then tier 3 warnings, each tier in original order.
  * The original-order (trimmed) body follows the digest. Nothing is fabricated
    or reordered within the body. Assertion detail (expect/received/stack
    frames) is kept as body context around each hard failure.
  * The full raw log is still persisted by the harness; the note says so.
  * Fail-safe: any anomaly (unknown shape, parse error, small output, non-test
    command, or a filter that would not clearly help) prints nothing and exits 0,
    leaving the original result intact. Worst case is "no filtering", never
    "wrong output".
"""
import sys, json, re

TRIGGER_CHARS = 8000          # leave anything smaller alone
HEAD, TAIL, CTX = 12, 60, 3   # run header, trailing summary, failure context
MIN_DROP_RATIO = 0.20         # only rewrite if it removes at least this fraction
MAX_DIGEST = 60               # cap the surfaced digest, filled tier by tier

CMD_RE = re.compile(r"""(?ix)
    playwright | \bjest\b | vitest | \bmocha\b | pytest | \bnose2?\b |
    \bgo\s+test\b | \bcargo\s+test\b | \bng\s+test\b | \brspec\b | \bphpunit\b |
    (?:yarn|npm|pnpm|bun|make)\s+(?:run\s+)?(?:test|test:[\w:-]+|verify|e2e) |
    \btest:[\w:-]+
""")

# Tier 1: a real failure. These must never be crowded out of the digest.
HARD_RE = re.compile(r"""(?ix)
    \bfail(?:ed|ing|ure)?\b | \berror\b | \bexception\b | \bpanic\b |
    \bunhandled\b | \btimed?\s*out\b | \bnot\s+ok\b | \bFAIL\b | \bERR |
    ✕|✗|×|✘|✖|●
""")

# A HARD hit on a line that only reports a zero count is not a failure.
ZERO_RE = re.compile(r"""(?ix)
    \b(?:0|no)\s+(?:errors?|failures?|failed|failing|problems?|warnings?)\b
""")

# Tier 2: run-level rollups. Deliberately does NOT match a bare "<n> passed"
# (that appears in every per-test line); only aggregate lines.
SUMMARY_RE = re.compile(r"""(?ix)
    \btests?:\s | \btest\s+suites?:\s | \bsuites?:\s |
    \b\d+\s+(?:failed|failing|errored|pending)\b |
    \b\d+\s+passing\b | \b\d+\s+total\b | \btotal\b |
    \btime:\s | \bduration\b | \bcoverage\b
""")

# Tier 3: worth surfacing, but never at the cost of a hard failure.
WARN_RE = re.compile(r"""(?ix)
    \bwarn(?:ing)?s?\b | \bdeprecat | \bTS\d{3,}\b
""")

# Not surfaced in the digest, but kept in the body: the detail that explains a
# failure. Matching these only widens context, it never fills the digest.
DETAIL_RE = re.compile(r"""(?ix)
    \bassert | \bexpected\b | \breceived\b | traceback | ^\s*at\s+
""")


def _classify(lines):
    """Return (hard_idx, summ_idx, warn_idx, detail_idx) line-index lists."""
    hard, summ, warn, detail = [], [], [], []
    for i, ln in enumerate(lines):
        if HARD_RE.search(ln) and not ZERO_RE.search(ln):
            hard.append(i)
        if SUMMARY_RE.search(ln):
            summ.append(i)
        if WARN_RE.search(ln):
            warn.append(i)
        if DETAIL_RE.search(ln):
            detail.append(i)
    return hard, summ, warn, detail


def _build_digest(lines, hard, summ, warn):
    """Fill the cap by severity tier, each tier in original line order."""
    out, seen, dropped = [], set(), 0
    for tier in (hard, summ, warn):
        fresh = [i for i in tier if i not in seen]
        room = MAX_DIGEST - len(out)
        if room <= 0:
            dropped += len(fresh)
            continue
        take = fresh[:room]
        dropped += len(fresh) - len(take)
        for i in take:
            seen.add(i)
        out.extend(take)
    digest = [lines[i] for i in sorted(out)]
    if dropped:
        digest.append("        ... [%d more failure/summary/warning lines; see "
                      "full log] ..." % dropped)
    return digest


def _filter(text):
    """Return (digest_lines, body_text, kept, total) or None."""
    lines = text.split("\n")
    n = len(lines)
    if n <= HEAD + TAIL + 20:
        return None

    hard, summ, warn, detail = _classify(lines)

    keep = set(range(min(HEAD, n)))
    keep.update(range(max(0, n - TAIL), n))
    for i in hard + detail:                      # failures keep their context
        keep.update(range(max(0, i - CTX), min(n, i + CTX + 1)))
    keep.update(summ)                            # rollups keep the line only
    keep.update(warn)
    if len(keep) >= n * (1 - MIN_DROP_RATIO):
        return None  # too little passing noise to bother

    body, prev = [], -1
    for i in sorted(keep):
        if i > prev + 1:
            body.append("        ... [%d lines trimmed] ..." % (i - prev - 1))
        body.append(lines[i])
        prev = i

    return _build_digest(lines, hard, summ, warn), "\n".join(body), len(keep), n


def _rebuild(field, digest, body):
    lead = ("===== filter-verbose-output: FAILURES + SUMMARY (full raw log "
            "persisted by the harness; re-run the exact command for everything) =====")
    parts = [lead]
    if digest:
        parts.append("\n".join(digest))
    parts.append("===== %s, original order, passing/verbose lines trimmed =====" % field)
    parts.append(body)
    return "\n".join(parts)


def main():
    try:
        ev = json.load(sys.stdin)
    except Exception:
        return
    if ev.get("tool_name") != "Bash":
        return
    tr = ev.get("tool_response")
    if not isinstance(tr, dict) or tr.get("isImage") or tr.get("noOutputExpected"):
        return
    cmd = (ev.get("tool_input") or {}).get("command", "")
    if not CMD_RE.search(cmd):
        return
    out, err = tr.get("stdout") or "", tr.get("stderr") or ""
    if len(out) + len(err) < TRIGGER_CHARS:
        return

    new_tr = dict(tr)
    notes, changed = [], False
    for field, blob in (("stdout", out), ("stderr", err)):
        if len(blob) < TRIGGER_CHARS:
            continue
        res = _filter(blob)
        if res:
            digest, body, kept, total = res
            new_tr[field] = _rebuild(field, digest, body)
            notes.append("%s: kept %d of %d lines (%d trimmed)"
                         % (field, kept, total, total - kept))
            changed = True
    if not changed:
        return

    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "updatedToolOutput": new_tr,
        "additionalContext": ("filter-verbose-output surfaced failure lines "
                              "first (by severity, so a late failure is never "
                              "crowded out), then run summaries, then warnings, "
                              "then a trimmed in-order log. " +
                              "; ".join(notes) +
                              ". The full raw log is persisted; re-run the exact "
                              "command if you need it."),
    }}))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # never break a tool result
    sys.exit(0)
