# The findings contract

One shape for every lens verdict, so findings from different lenses are comparable, rankable, and
cheap to triage. Adapted from the review contract Claude Code's own `code-review` uses.

## 1. Pick precision or recall before you start

The same lens behaves differently depending on what the review is for. Decide, say which, and hold it.

- **Precision** (the default, and correct for a nit pass, a small diff, or anything you are about to
  send to a reviewer): every finding you surface must be one a maintainer would act on. Cap the report
  at `min(files_changed, 4)`. A finding you would not fix yourself does not belong in the report.
- **Recall** (correct for an audit, a pre-merge sweep of a large or risky change, or when asked to be
  thorough): catch every real bug a careful reviewer would catch in one sitting. Here, catching real
  bugs matters more than avoiding false positives. Err on the side of surfacing.

Getting this backwards is a real failure mode in both directions: recall behaviour on a precision job
produces a nitpick flood and an oversized diff to defend, and precision behaviour on an audit misses
things.

## 2. Every finding carries a concrete failure scenario

| Field | Rule |
|---|---|
| `category` | short kebab-case slug: `correctness`, `security`, `accessibility`, `compatibility`, `simplification`, `efficiency`, `altitude`, `reuse`, `test-coverage`, `spec-fidelity`, `design-parity`, `timing` |
| `file` + `line` | repo-relative path and the 1-indexed line the finding anchors to |
| `short_summary` | 60 characters or fewer: the claim alone, no rationale, no consequence clause |
| `summary` | one sentence stating the defect |
| `failure_scenario` | **concrete inputs or state, then the wrong output, crash, or exposure that results** |
| `verdict` | `CONFIRMED` or `PLAUSIBLE` (see below) |

`failure_scenario` is the load-bearing field and the cheapest false-positive filter there is: if you
cannot write down the specific state that produces the specific wrong result, you do not have a
finding, you have a suspicion. Delete it or downgrade it to a note. "This could be unsafe" is not a
failure scenario. "A user whose account has no records opens the dashboard, `items[0]` is
undefined, and the page throws before the empty state renders" is.

A `file:line` proves the code exists. It does not prove the code is wrong. Both are required.

## 3. Verify with a three-way verdict

For each candidate, argue against it and return exactly one of:

- **CONFIRMED**: the failure scenario holds and you can trace it in the code.
- **PLAUSIBLE**: the reasoning holds but something is unproven (a path you could not fully trace, a
  runtime value you cannot see). Keep it, and say what is unproven.
- **REFUTED**: something in the code prevents it (a guard upstream, a type that cannot be null, a
  default that makes the branch unreachable). Drop it, and name what refutes it.

Keep CONFIRMED and PLAUSIBLE. Drop REFUTED. Three outcomes matter: a binary keep-or-kill forces an
honest "probably real but unproven" into a coin flip, and those are often the findings worth having.

## 4. Cap the report, and rank it

Up to 6 candidates per angle before verification. After verification, most severe first, capped per
the precision or recall choice above. If nothing survives, say so plainly: an empty report is a
result, not a failure, and padding it to look thorough is the one thing that destroys trust in every
future review.

## 5. Report through the tool when it is available

When the `ReportFindings` tool is available, call it once with `{level, findings}` and do not also
print the findings as prose. It renders in the host UI. Without it, use the same field shape in a
markdown table.

## 6. Disclose what actually ran

State plainly which lenses ran, which you skipped and why, and, when the review was a single solo pass
rather than independent per-lens passes, say that too, so nobody reading it is misled about what
actually happened. A review that overstates its own coverage is worse than a smaller honest one.

## 7. Gap pass, at the top effort levels only

At xhigh or max, after the report is drafted, do one pass that hunts only for what is missing: a lens
that should have applied and did not run, a claim asserted but never verified, a file in the diff that
no finding or disposition touched. What that pass turns up is the next round of work.
