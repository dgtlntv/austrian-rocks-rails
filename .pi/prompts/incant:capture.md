---
description: Capture a raw idea or todo into the incant inbox with zero ceremony.
argument-hint: <idea>
---

Invoke the **using-incant** skill unless it has already been invoked in this session, then run
`incant capture "$ARGUMENTS"` to append a timestamped bullet to `.incant/inbox.md`, and stop.
Do not triage, plan, or expand the idea — capture is frictionless.

No work-item session link is required for `/incant:capture` because it is not tied to a minted
work item. If `incant` is unavailable, tell the user incant is not set up correctly (see
`using-incant` → "When `incant` is unavailable").

Next: `/incant:triage` when the inbox should be processed.
