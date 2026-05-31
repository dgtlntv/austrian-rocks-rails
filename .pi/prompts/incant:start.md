---
description: Start a triaged backlog item — scaffold its work dir, branch, link the session, and write its spec.
argument-hint: <backlog-id>
---

Start work on backlog item `$1`.

1. Invoke the **using-incant** skill unless it has already been invoked in this session.
2. Invoke the **writing-specs** skill for `$1` — it scaffolds `work/$1-<slug>/`, creates the
   feature branch `incant/$1-<slug>`, links this session with `incant session link $1`
   immediately after the work directory exists, writes `spec.md`, and stops for human approval.

The item must already be a minted backlog row. If `$1` is missing, ask which backlog id to
start.

Next after spec approval: `/incant:plan $1`.
