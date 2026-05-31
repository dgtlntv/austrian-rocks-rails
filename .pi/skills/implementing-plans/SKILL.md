---
name: implementing-plans
description: Executes an approved plan phase by phase, or addresses review findings — verifies the feature branch first, runs each phase's quality gate with fresh evidence before claiming it done, checks off steps, commits each phase, and keeps Status and .incant/STATE.md current. Use when continuing a planned item via /incant:implement [id] or working a revise loop after review.
---

# Implementing plans

Execute an approved `plan.md` one phase at a time, keeping gates green and history clean. Also
the revise loop after a review.

## 1. Orient and get on the branch

1. Link the session for provenance: `incant session link <id>` (records the newest pi
   `.jsonl` for this cwd into `work/<id>/sessions.json`, deduped). If the command is
   unavailable, **do not do this by hand** — stop and tell the user incant isn't set up
   correctly; `using-incant` has the likely fix.
2. Read `plan.md`'s `## Status` to find the current phase and next step.
3. **Verify the feature branch.** Compare the current branch to `spec.md`'s `branch:`. If they
   differ, switch to it first (`git switch incant/<id>-<slug>`). **If the working tree is
   dirty, stop and ask before switching branches.** If you are already on the expected feature
   branch, dirty work is allowed (common in revise loops); inspect it before editing and keep it
   on that branch. Skip gracefully outside a git repo.

## 2. Work the current phase

- Follow the phase's steps in order. **Read before you edit** any existing file.
- Write complete code — no placeholders, no "fix later" stubs.
- Check off each step in `plan.md` as you finish it.

## 3. Verify before claiming done (HARD GATE)

- Run the phase's **Quality gate** command **this session** and **read the output**.
- **Never mark a phase complete without fresh verification evidence.** "Should pass" is not
  evidence; a green run you just observed is.
- If the gate fails, fix the cause — do not weaken the gate or skip hooks.

## 4. Commit the phase

Once the gate is green, commit on the feature branch with the phase token:

```
incant <id>-P<n>: <phase name>
```

Then update `plan.md`'s `## Status` (advance the phase/next) and `.incant/STATE.md`'s current focus.
Use only the allowed enum values (see `using-incant`) for `stage` and the backlog `status`.

## 5. Stop after the phase — one phase per session

Implement **one phase per session.** After committing the phase, **stop and hand off to the
human to review that phase** (`/incant:review <id>`) — do not roll straight into the next phase. The next
phase is picked up later by a fresh session via `/incant:implement`, so each phase gets a clean context
window.

Only when the **final** phase is done and reviewed: confirm the **spec's acceptance criteria**
are met at the goal level, not just that each phase's gate passed, before releasing.

## Revise loop (after review)

When `reviewing-changes` leaves open **blocker/major** findings, address them here: fix, then
record the finding references, the work performed, and fresh verification evidence in
`plan.md`'s `## Status` area (for example under `Review fixes`). **Do not edit `review.md`
finding statuses or verdicts during implementation/revise work.** Only the `/incant:review`
workflow may update `review.md` statuses or verdicts after a fresh re-review. Re-run the
relevant gate. Blockers/majors must be resolved before release.

## Constraints

- Work only on the feature branch — never commit feature work to main.
- No auto-merge, force-push, or history rewriting.
- Keep secrets out of the repo and out of session transcripts.

Next: `/incant:review <id>` (**reviewing-changes**) at a phase gate or before release.
