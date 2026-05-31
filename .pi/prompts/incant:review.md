---
description: Run a fresh-eyes review of a work item's diff and write tiered findings.
argument-hint: [id]
---

Review work item `$1` (if no id is given, use the current in-progress item).

1. Invoke the **using-incant** skill unless it has already been invoked in this session.
2. Resolve `work/$1-<slug>/` from `.incant/work/` and read `spec.md` and `plan.md`.
3. Link this session: `incant session link $1`.
4. Invoke the **reviewing-changes** skill for `$1`. It re-reads the spec and plan, diffs the item
   against its spec base, checks acceptance criteria and active principles, updates only the
   review-stage-owned `review.md` statuses/verdicts, and writes tiered findings.

Next: `/incant:implement $1` if there are open blocker/major findings; otherwise
`/incant:finalize $1` when the item is ready to close.
