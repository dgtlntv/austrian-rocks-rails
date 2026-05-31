---
description: Turn an approved spec into a phased implementation plan.
argument-hint: <backlog-id>
---

Plan approved-spec work item `$1`.

1. Invoke the **using-incant** skill unless it has already been invoked in this session.
2. Resolve `work/$1-<slug>/` from `.incant/work/` and read `spec.md`.
3. Link this session: `incant session link $1`.
4. Invoke the **writing-plans** skill for `$1`; it writes `plan.md`, commits the plan, and stops
   for human approval before any code is changed.

The spec must already be approved by the human. If `$1` is missing, resolve the in-progress
spec item from `.incant/backlog.md`; if more than one is active, ask which id.

Next after plan approval: `/incant:implement $1`.
