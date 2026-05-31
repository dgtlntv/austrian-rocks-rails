---
name: using-incant
description: Orients an incant work session before acting — explains the capture→triage→spec→plan→implement→review→finalize→archive workflow, the hard gates that protect quality, and routes to the right stage skill. Use at the start of any incant session; read .incant/STATE.md first.
---

# Using incant

incant turns an intent into released code through a chain of small markdown artifacts,
leaving the spellbook behind for the next reader. Every artifact is a greppable markdown
file committed under `.incant/`.

## Always do this first

1. Read `.incant/STATE.md` — the tiny orientation note (current focus + active items).
2. Read `.incant/backlog.md` only if you need the full active list. **Never read a whole
   work item's files unless you are working on that item.**
3. Decide the stage from the request and route to the stage skill below.

If there is no `.incant/` directory yet, the project has not been initialised — run
`incant init`.

## The workflow

```
inbox ─triage─▶ backlog ─start─▶ spec ─▶ plan ─▶ implement ─▶ review ─▶ finalize ─▶ archive
  │              │                                              │
  └─ drop ─▶ graveyard ◀─ drop ─┘                       revise ◀┘ (blockers/majors)
```

| You want to… | Stage | Skill | Command |
|---|---|---|---|
| Jot an idea down | capture | (no skill) | `/incant:capture` · `incant capture "…"` |
| Sort inbox into prioritised work | triage | `triaging-work` | `/incant:triage` |
| Start a backlog item (spec it) | spec | `writing-specs` | `/incant:start <id>` |
| Turn an approved spec into a plan | plan | `writing-plans` | `/incant:plan <id>` |
| Build a planned item | implement | `implementing-plans` | `/incant:implement [id]` |
| Review a work item's diff | review | `reviewing-changes` | `/incant:review [id]` |
| Close out and archive | finalize | `finalizing-work` | `/incant:finalize [id]` |

## Hard gates (enforced by judgment, never by the CLI)

- **No plan before the human approves the spec** — regardless of how simple it looks.
- **No code before the human approves the plan.**
- **No finalize/archive while any blocker or major review finding is open.**
- **Never claim a phase complete without fresh verification evidence** — you ran the
  phase's quality-gate command this session and read its output.
- **Work happens on the feature branch `incant/<id>-<slug>`, never on main.** Continuing a
  feature switches to that branch first.

## Conventions you must keep

- **IDs** are zero-padded width-4 (`0007`), minted once at triage, permanent, gaps allowed.
- **Phase tokens** are `<id>-P<n>` (`0007-P2`), cited in commit subjects: `incant 0007-P2: …`.
- **Secrets never enter `.incant/`** — it is committed to the repo.
- Use forward-slash paths everywhere. Keep terminology consistent across artifacts.

## Allowed values (use only these)

These fields are fixed enums — never invent new values:

- backlog `prio`: `high` · `med` · `low`
- backlog `size`: `S` · `M` · `L` · `XL`
- backlog `status`: `ready` · `spec` · `plan` · `implement` · `review` · `blocked` · `done`
- artifact `stage` (frontmatter): `spec` · `plan` · `implement` · `review` · `finalize` · `archived`
- review finding severity: `blocker` · `major` · `minor` · `nit`
- review finding `status`: `open` · `addressed` · `wontfix`

## When `incant` is unavailable

The CLI is incant's quality floor — expect it to work. If an `incant` command errors or is not
found, **do not improvise the operation by hand.** Stop and tell the user incant is not set up
correctly, with the likely fix:

- not installed → install `@daemon-kit/incant` as a local devDependency (node/pnpm projects)
  or globally (`npm i -g @daemon-kit/incant`) for polyglot projects;
- not built → run `pnpm --filter @daemon-kit/incant build`.

Resume once the command works.

## Where things live

- `inbox.md` — raw capture, no IDs.
- `backlog.md` — one compact prioritised row per active item; IDs minted here.
- `.incant/STATE.md` — read-first orientation, hand/skill-maintained.
- `work/<id>-slug/` — `spec.md`, `plan.md`, then `review.md`, `summary.md`, `sessions.json`.
- `principles/` — project-local spec considerations (additions/overrides).
- `archive/graveyard.md` — dropped ideas with reasons.
- `archive/work/<id>-slug/` — completed items, moved verbatim (with raw `sessions/`).

Next: pick the stage skill from the table above.
