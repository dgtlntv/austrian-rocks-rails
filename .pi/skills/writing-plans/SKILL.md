---
name: writing-plans
description: Turns a human-approved spec into a phased plan.md with per-phase quality gates and a Status block — maps files first, slices vertically, bans placeholders, re-validates a stale spec before planning, and stops for human approval before any code. Use after a spec is approved, before implementation begins.
---

# Writing plans

Turn an **approved** spec into an executable, phased `plan.md`. No planning before the spec is
approved — if it is not, go back to `writing-specs`.

## 1. Re-validate a stale spec first

Check `spec.md`'s `commit:` against current HEAD. If the spec is far behind and the item has
not reached `implement`, re-read the affected code and confirm the spec still holds. Fix the
spec (and re-approve) before planning. Staleness is surfaced, never auto-resolved.

## 2. Map the files to touch

List every file the work will create or change, with a one-line purpose each, in the plan's
**## Files touched** section. Prefer small, single-responsibility files. Decompose by
**vertical slices** (each phase delivers a working sliver) over horizontal layers.

## 3. Write the phases

Each phase is a **working slice** with:
- a goal,
- ordered checkbox steps with **real paths and complete content — no placeholders**
  ("TBD", "add error handling", "similar to Phase N", undefined symbols are all banned),
- **read-before-edit** steps where you touch existing files,
- an explicit automated **Quality gate**: the exact command to run + the expected result.
  Prefer `pnpm run check` for broad incant prompt, skill, or CLI changes. Use a narrower
  command only when the phase explains why that command covers the changed surface.

Phases are committed individually on the feature branch (`incant <id>-P<n>: <phase>`).

```markdown
## Phase 0007-P2 — callback handler
- [ ] step 1: read src/server/routes.ts before editing
- [ ] step 2: add src/auth/callback.ts — full handler, exchanges code for tokens
**Quality gate:** `pnpm vitest run src/auth` → all auth tests pass; this narrower gate covers the phase because only auth route behaviour changed.
```

## 4. Fill the Status block

At the top of `plan.md`, keep the `## Status` block current (phase, stage, branch, next step,
blockers, key decisions). This is the per-item state — there is no separate STATUS file.

## 5. Coverage self-review (validate → fix loop)

- [ ] **Every spec requirement maps to ≥1 step.** List them and check.
- [ ] **Symbol/signature consistency** across steps (same names, same arguments).
- [ ] **Verify at the goal level too** — "phase done ≠ goal met"; a final phase or gate proves
      the spec's acceptance criteria.
- [ ] **No placeholders anywhere.**

Fix any gap before the human approval checkpoint.

## 6. Human approval checkpoint

Commit the plan (`incant <id>: plan`) and ask the human to approve it. **Do not write code
until the plan is approved.**

Next (after approval): `/incant:implement <id>` (**implementing-plans**).
