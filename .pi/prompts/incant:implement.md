---
description: Implement the current planned phase or address review findings.
argument-hint: [id]
---

Resume work item `$1` (if no id is given, resolve the in-progress item from `.incant/backlog.md`
rows with `status:implement` or `status:review` when it is in a revise loop with open
blocker/major findings; if more than one is active, ask which id).

1. Invoke the **using-incant** skill unless it has already been invoked in this session.
2. Resolve `work/$1-<slug>/` from `.incant/work/` and read `spec.md` `branch:`.
3. Link this session: `incant session link $1`.
4. Switch to the feature branch from `spec.md` before editing. If the working tree is dirty and
   you are not already on that branch, stop and ask before switching.
5. Invoke the **implementing-plans** skill and resume from `plan.md`'s `## Status`.

Next after the phase commit: `/incant:review $1`.
