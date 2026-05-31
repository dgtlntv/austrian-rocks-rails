---
description: Process the incant inbox into prioritised backlog rows.
---

Invoke the **using-incant** skill unless it has already been invoked in this session, then invoke
the **triaging-work** skill to process `.incant/inbox.md` into `.incant/backlog.md` (minting IDs
with `incant new`) or into `.incant/archive/graveyard.md`.

No work-item session link is required for `/incant:triage` because it is not tied to one minted
work item.

Next: `/incant:start <backlog-id>` for a backlog row that is ready to spec.
