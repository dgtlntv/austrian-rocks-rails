---
description: Close out and archive a finished work item.
argument-hint: [id]
---

Finalize work item `$1` (if no id is given, use the current in-progress item).

1. Invoke the **using-incant** skill unless it has already been invoked in this session.
2. Resolve `work/$1-<slug>/` from `.incant/work/` and read `review.md`.
3. Link this session: `incant session link $1`.
4. Invoke the **finalizing-work** skill for `$1`. It confirms no open blocker/major findings
   remain, writes `work/$1-<slug>/summary.md`, spawns follow-ups into the inbox, and archives the
   work dir with its linked sessions (`incant archive $1`).

Next: the item is archived; use `/incant:start <backlog-id>` or `/incant:triage` for more work.
