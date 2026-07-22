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
  * The filtered result LEADS with every failure/error line and the run summary,
    so they survive even a truncated preview of a huge log; the original-order
    (trimmed) body follows. Nothing is fabricated or reordered within the body.
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
MAX_DIGEST = 60               # cap the surfaced failure/summary digest

CMD_RE = re.compile(r"""(?ix)
    playwright | \bjest\b | vitest | \bmocha\b | pytest | \bnose2?\b |
    \bgo\s+test\b | \bcargo\s+test\b | \bng\s+test\b | \brspec\b | \bphpunit\b |
    (?:yarn|npm|pnpm|bun|make)\s+(?:run\s+)?(?:test|test:[\w:-]+|verify|e2e) |
    \btest:[\w:-]+
""")

FAIL_RE = re.compile(r"""(?ix)
    \bfail(?:ed|ing|ure)?\b | \berror\b | \bexception\b | \bassert | traceback |
    \btimed?\s*out\b | \bpanic\b | \bunhandled\b | \bexpected\b | \breceived\b |
    \bnot\s+ok\b | ✕|✗|×|✘|✖ | ^\s*at\s+ | \bFAIL\b | \bERR |
    \bwarn(?:ing)?s?\b | \bdeprecat | \bTS\d{3,}\b
""")

# Aggregate summary lines worth surfacing. Deliberately does NOT match a bare
# "<n> passed" (that appears in every per-test line); only run-level rollups:
# a "Tests:"/"Suites:" header, any failure count, mocha "N passing/failing",
# a total, or timing/coverage.
SUMMARY_RE = re.compile(r"""(?ix)
    \btests?:\s | \btest\s+suites?:\s | \bsuites?:\s |
    \b\d+\s+(?:failed|failing|errored|pending)\b |
    \b\d+\s+passing\b | \b\d+\s+total\b | \btotal\b |
    \btime:\s | \bduration\b | \bcoverage\b
""")


def _filter(text):
    """Return (surfaced_digest_lines, body_text, kept, total) or None."""
    lines = text.split("\n")
    n = len(lines)
    if n <= HEAD + TAIL + 20:
        return None

    fail_idx = [i for i, ln in enumerate(lines) if FAIL_RE.search(ln)]
    summ_idx = [i for i, ln in enumerate(lines) if SUMMARY_RE.search(ln)]

    keep = set(range(min(HEAD, n)))
    keep.update(range(max(0, n - TAIL), n))
    for i in fail_idx:
        keep.update(range(max(0, i - CTX), min(n, i + CTX + 1)))
    if len(keep) >= n * (1 - MIN_DROP_RATIO):
        return None  # too little passing noise to bother

    # in-order body with omission markers
    body, prev = [], -1
    for i in sorted(keep):
        if i > prev + 1:
            body.append("        ... [%d lines trimmed] ..." % (i - prev - 1))
        body.append(lines[i])
        prev = i

    # failures + summary surfaced first (deduped, in original order, capped)
    dig_idx = sorted(set(fail_idx) | set(summ_idx))
    truncated = len(dig_idx) > MAX_DIGEST
    digest = [lines[i] for i in dig_idx[:MAX_DIGEST]]
    if truncated:
        digest.append("        ... [%d more failure/summary lines; see full log] ..."
                      % (len(dig_idx) - MAX_DIGEST))
    return digest, "\n".join(body), len(keep), n


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
        "additionalContext": ("filter-verbose-output surfaced all failure/error "
                              "and summary lines first, then a trimmed in-order "
                              "log; passing/verbose lines were removed. " +
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
