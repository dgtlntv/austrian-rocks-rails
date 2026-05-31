---
name: reviewing-changes
description: Runs a thorough fresh-eyes review of a work item's diff against its spec, plan, acceptance criteria, active principles, commit history, and fresh gate evidence, writing strengths, severity-tiered findings (blocker/major/minor/nit), and a release verdict to review.md; blockers and majors must be fixed before release. Use when reviewing a work item's changes via /incant:review [id], at a phase gate, or before release.
---

# Reviewing changes

A single, thorough fresh-eyes pass over one work item's diff — judged against what was
promised and closed with a clear verdict, never a glance-and-"looks good".

## 1. Gather context

- Re-read `work/<id>/spec.md` and `work/<id>/plan.md`.
- Take the item's diff against its spec base:
  ```
  git diff <spec.commit>..HEAD -- <the item's touched paths>
  ```
  `<spec.commit>` is `spec.md`'s `commit:` field; paths come from the plan's **Files touched**.

## 2. What to check

Read **every changed line** and judge it against what was promised; cite `file:line` for each
observation. The first two areas are incant-specific grounding, the rest are general quality.

**Spec & plan alignment**
- Is every acceptance criterion (pass/fail) in the spec actually met?
- Were the planned phases done, and is all planned functionality present?
- Are deviations from the plan justified improvements or problematic departures? Flag each one
  specifically so the implementer can confirm it was intentional.
- If the fault is in the **spec or plan itself** rather than the code, say so.

**Active principles**
- Did it honour each enabled principle (config-vs-code, security, testability, plus
  project-local ones)?

**Code quality**
- Clean separation of concerns and clear names.
- Proper error handling; edge cases and failure paths handled.
- Type safety where the language supports it.
- DRY without premature abstraction.
- No dead code, placeholders, or leftover debug.

**Architecture**
- Sound design that integrates cleanly with the surrounding code.
- Reasonable scalability and performance for the spec's stated constraints.
- Security: trust boundaries, input validation, secrets, and the relevant vulnerability
  classes (injection, XSS, SSRF, path traversal, authz/authn).

**Testing and gates**
- Tests verify real behaviour, not mocks echoing themselves.
- Edge cases and failure paths covered; integration tests where they matter.
- The phase **quality gate** actually passes — confirm from fresh output, don't assume.
- `plan.md` records fresh quality-gate evidence for the phase or review-fix loop. Missing or
  stale release-critical evidence is a finding with severity calibrated to release risk.

**History and production readiness**
- Commit subjects follow incant conventions: `incant <id>: spec`, `incant <id>: plan`, and
  `incant <id>-P<n>: …` for phase commits. Missing or malformed release-critical history is a
  finding with severity calibrated to traceability and release risk.
- Migration/backfill strategy if a schema or data shape changed.
- Backward compatibility considered.
- Docs/comments updated where behaviour changed.
- No obvious bugs.

## 3. Calibrate severity

Grade each finding by its **actual impact** — not everything is a blocker, and a real blocker
must never be filed as a minor.

- **blocker** — bug, security hole, data-loss risk, broken/missing required functionality, or
  an unmet acceptance criterion.
- **major** — architecture problem, missing planned feature, poor error handling, real test gap.
- **minor** — style, optimisation opportunity, documentation polish.
- **nit** — trivial preference with no functional impact.

Note what was done well **before** the findings — accurate, specific praise makes the rest of
the review trusted.

## 4. Write review.md

Lead with **Strengths**, then findings grouped by severity, then a **Verdict**. Make each
finding concrete — *what* is wrong, *why* it matters, and *how* to fix it if not obvious:

```markdown
### Strengths
- src/auth/callback.ts — state param verified before token exchange; CSRF handled cleanly.

### Blocker
- src/auth/callback.ts:42 — token never verified against state param (CSRF); an attacker can
  forge the callback. Fix: compare the returned state to the stored nonce. status: open

### Major
- … status: open

### Minor
- … status: open

### Nit
- … status: open

### Verdict
Ready to release? **No** — one open blocker. <1–2 sentence technical assessment.>
```

- Severity order: **blocker → major → minor → nit.**
- `status: open | addressed | wontfix` (a note on `wontfix`).
- Stamp frontmatter `reviewed` (date) and `commit` (HEAD reviewed).
- Only review-stage agents update `review.md` finding statuses or verdicts. Implementers record
  review-fix work and verification in `plan.md` Status, then return here for fresh re-review.

## 5. Release decision

- **Verdict is one of `Yes` · `No` · `With fixes`.** Blockers and majors must be fixed before
  release — route back to `implementing-plans` (revise loop) while any are `open`.
- Minors/nits may be `wontfix` with a reason.
- Review runs at **phase gates and before release** — not after every tiny step.

Next: `/incant:implement <id>` (**implementing-plans**) if there are open blockers/majors,
otherwise `/incant:finalize <id>` (**finalizing-work**).
