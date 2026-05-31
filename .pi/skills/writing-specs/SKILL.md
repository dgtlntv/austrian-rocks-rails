---
name: writing-specs
description: Scouts the codebase and writes a backlog item's spec.md — interviews the user relentlessly one question at a time until every spec dimension is resolved, addresses every active principle, self-reviews, then stops for human approval; also creates the feature branch and scaffolds the work dir. Use when starting a triaged backlog item via /incant:start <id>.
---

# Writing specs

Discovery + spec for one backlog item. The spec is the heart of the framework — get it right
before any planning. You are doing WHAT, not HOW.

## 1. Scaffold and branch

Run `incant scaffold <id> --slug <slug>`. It creates `work/<id>-<slug>/` from templates and
stamps `id`, `slug`, `branch` (`incant/<id>-<slug>`), `created`, `commit` (base HEAD), and
`updated` into `spec.md`. It does **not** run git. If the command is unavailable, **do not do this by
hand** — stop and tell the user incant isn't set up correctly; `using-incant` has the fix.

Then create the feature branch (a skill git op, not the CLI's):

```
git switch -c incant/<id>-<slug>
```

Skip the branch step gracefully if the project is not a git repo.

After the work directory exists, link the current pi session immediately:

```
incant session link <id>
```

Do this before discovery/spec writing so the `/incant:start` session is recorded before the human
approval checkpoint. If the command is unavailable, **do not do this by hand** — stop and tell
the user incant isn't set up correctly; `using-incant` has the fix.

## 2. Discovery — scout, then interview relentlessly

The spec is only as good as this conversation. **Interview the user relentlessly until you
both share a complete understanding** of what to build — never settle for a vague or partial
picture, and never paper over a gap with an assumption.

- **Scout the real codebase first.** Read the files and patterns the item touches. Ground
  every question in what you found — no abstract questionnaires.
- **Prefer exploring over asking.** If a question can be answered by reading the code, read it
  instead of spending the user's attention on it.
- **Interview one question at a time.** Walk every branch of the decision tree, resolving
  dependent decisions in order — each answer usually opens the next question. Ask via the
  question UI, multiple choice where it fits, and **propose your recommended answer** with each
  question so the human can confirm or correct in one step. Never frontload a wall of questions.
- **Keep going until nothing material is unresolved** — goal, edge cases, error handling,
  scope edges, naming, data shapes, dependencies, rollout. Stop when the next question would be
  immaterial to the build, not when you hit some count.
- Clear the **four spec dimensions** as a yes/no checklist before writing — every box a
  confident yes grounded in answers, not assumptions:
  - [ ] **Goal** — one measurable outcome?
  - [ ] **Boundaries** — what is explicitly in vs. out of scope?
  - [ ] **Constraints** — performance, security, compatibility, dependencies?
  - [ ] **Acceptance** — how will we know it is done (pass/fail)?
- If the request is really several subsystems, **decompose first** — send extras back to the
  inbox; this item stays single-responsibility.

## 3. Write spec.md (fixed sections)

Fill the template's fixed sections — all always present:

1. **Goal** — one measurable sentence (ban "improve X").
2. **Context & codebase fit** — grounded in real files/patterns from scouting.
3. **Requirements** — numbered, each falsifiable ("<200ms p95 at 100 rps", not "be fast").
4. **In scope / Out of scope** — explicit lists; each out-of-scope item has a one-line reason.
5. **Approach** — chosen design + a short note on rejected alternatives (not a full log).
6. **Considerations** — one subsection per active principle (see below).
7. **Acceptance criteria** — pass/fail checkboxes only (ban "looks reasonable").
8. **Risks & open questions.**

### Principles → the Considerations section

Active principles are the **union by `name`** of:
- defaults bundled with this skill at `principles/` (`config-vs-code`, `security`,
  `testability`, `code-documentation`), resolved relative to this SKILL.md, and
- project-local `.incant/principles/` (additions + overrides; on a name collision the project
  file wins, and may set `enabled: false` to switch a default off).

For each **enabled** principle whose `applies:` includes `spec`, add a Considerations
subsection titled by its `heading` and actually address it for the project being built.

## 4. Self-review (validate → fix loop)

Before showing the user, check and fix:
- [ ] **No placeholders** — no TBD/TODO, no undefined references.
- [ ] **Internal consistency** — requirements, scope, and acceptance agree.
- [ ] **Ambiguity** — "could this be read two ways? pick one."
- [ ] **Scope** — fits a single work item.
- [ ] **Principle coverage** — every enabled principle has a Considerations subsection that
      genuinely addresses it. If any is unaddressed, fix before the gate.

## 5. Human approval checkpoint

Commit the scaffolded spec to the feature branch once you have written it
(`incant <id>: spec`), then say literally:

> Spec written to `work/<id>-<slug>/spec.md`. Review it and tell me what to change before we plan.

**Do not plan or write code until the human approves.** No exceptions for "simple" items.

Next (after approval): `/incant:plan <id>` (**writing-plans**).
