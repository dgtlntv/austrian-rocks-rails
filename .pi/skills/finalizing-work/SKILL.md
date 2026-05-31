---
name: finalizing-work
description: Closes out a finished work item — confirms done with the human, writes summary.md, spawns follow-ups into the inbox, and archives the work dir with its linked sessions. Use when wrapping up a completed item via /incant:finalize [id], once no blocker or major review findings remain.
---

# Finalizing work

Finalize a completed work item: write the record, capture follow-ups, then archive.

## 1. Confirm it is releasable (HARD GATE)

- Re-check `review.md`: **no open blocker or major findings.** If any remain, go back to
  `implementing-plans`. Do not finalize or archive over open blockers/majors.
- Confirm the spec's acceptance criteria are met.
- Ask the human to confirm the item is done.

## 2. Write summary.md

Fill the closing record (frontmatter `stage: archived`, `completed` date, final `commit`):
- **What was built** — the released outcome.
- **Deviations from spec** — what changed and why.
- **Key decisions.**
- **Links** — commits/PR for the feature.
- **Sessions** — list the linked session ids from `sessions.json`.
- **Follow-ups** — each also dropped into `inbox.md` (use `/incant:capture` or `incant capture`).

## 3. Archive

Run `incant archive <id>`. It moves `work/<id>-…/` → `archive/work/<id>-…/`, removes the
item's `backlog.md` row, and copies each linked session `.jsonl` **verbatim** into
`archive/work/<id>-…/sessions/` (use `--no-sessions` to skip transcripts). If the command is
unavailable, **do not do this by hand** — stop and tell the user incant isn't set up
correctly; `using-incant` has the likely fix.

## 4. Update .incant/STATE.md

Remove the item from **Active** and reset the current focus if it was the focus.

## Notes

- incant never auto-merges or pushes; leave the branch ready for the human to merge.

This is the end of the chain. New follow-ups re-enter at the inbox.
