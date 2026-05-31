---
name: triaging-work
description: Processes the incant inbox into prioritised backlog rows, or runs a cleanup sweep on explicit request. Clarifies and splits raw ideas, mints a stable ID per kept item, drops ideas to the graveyard with a reason, and flags stale specs and orphan work dirs. Use when triaging the inbox via /incant:triage or when the user asks for a backlog cleanup.
---

# Triaging work

Turn raw `inbox.md` bullets into prioritised `backlog.md` rows (or drop them), and keep the
backlog honest. This is the only place IDs are minted.

## Triage each inbox item

For every bullet in `.incant/inbox.md`:

1. **Clarify** — is the intent clear enough to act on? If genuinely ambiguous, ask the user
   one question (multiple choice where possible). Do not frontload questions.
2. **Decompose** — if it is really several subsystems, split it into separate items; each
   gets its own row and ID.
3. **Decide promote vs. drop:**
   - **Promote** → mint an ID and write a backlog row (below). Remove the inbox bullet.
   - **Drop** → move it to `archive/graveyard.md` with a one-line reason. Remove the bullet.
4. **Confirm priority and size with the human** before finalising rows.

### Minting the ID (mechanical — do not improvise)

Run `incant new` to allocate and print the next ID. It scans `backlog.md` + `work/*` +
`archive/work/*`, takes the max, and increments — the #1 collision risk if done by hand. If
the command is unavailable, **do not improvise by hand** — stop and tell the user incant
isn't set up correctly; `using-incant` has the likely fix.

### Backlog row format (keep terse, one line)

```
- [0007] prio:high size:M status:ready tags:auth — OAuth login
```

- Use only the allowed values (see `using-incant`): `prio` ∈ `high|med|low`,
  `size` ∈ `S|M|L|XL`, `status` = `ready` for a freshly triaged item.
- `phase:` and `→ work/<id>` are added later, once the item is promoted into the pipeline.
- Order rows top→bottom by priority.

## Cleanup sweep (only when the user explicitly asks)

Do **not** run this on your own initiative — only when the user explicitly requests a cleanup.

- Re-prioritise rows that have drifted.
- Drop stale inbox items to the graveyard (with reason).
- **Flag stale specs:** a `work/<id>` whose `spec.md` `commit:` is far behind HEAD and that
  has not reached `implement` — note it for re-validation before planning.
- **Catch orphan work dirs:** a `work/<id>` with no matching backlog row (and not archived).
- Archive finished work that was never closed out (route to `finalizing-work`).
- Update `.incant/STATE.md` if the current focus changed.

## Dropping an item

Run `incant archive --drop "<text>" --reason "<why>" [--id <id>]`. It appends a dated row to
`archive/graveyard.md` and removes the source line/row. If the command is unavailable, **do not
do this by hand** — stop and tell the user incant isn't set up correctly; `using-incant` has the fix.

## Before advancing

The human confirms priority and size. A promoted item is then ready for `writing-specs`
(via `/incant:start <id>`).

Next: **writing-specs** for items the human chooses to start.
