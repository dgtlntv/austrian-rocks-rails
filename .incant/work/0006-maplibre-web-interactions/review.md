---
id: "0006"
slug: maplibre-web-interactions
stage: review
reviewed: 2026-06-10
commit: 46be4e78
---

# Maplibre Web Interactions — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

> Scope of this pass: **P5 re-review after the `?problem=` deep-link blocker fix** through commit `46be4e78`. Prior P1/P2/P3 findings remain addressed/wontfix/clean, the P4 re-review blocker remains addressed, and P6 documentation/release-smoke work is still pending.

### Strengths
- app/controllers/map_controller.rb:16-18 — the controller now resolves the problem deep-link id from `params[:pid]` or `params[:problem]`, preserving the existing path while satisfying the spec's `?problem=<id>` acceptance wording.
- test/controllers/map_controller_test.rb:58-76 — coverage now exercises both `?pid=` and `?problem=` server-rendered data paths, so the JS `centerMap()` path receives `data-map-problem-value` for either query spelling.
- app/javascript/controllers/map_controller.js:225-241,750-765 — problem and area entry points continue to call `selectFeatureWhenIdle` after camera movement, so search events and deep links route through the selected-card path instead of the removed popup path.
- app/javascript/controllers/map_controller.js:359-391 — the idle-time selector remains bounded and defensive: it queries the source layer by id, falls back to rendered layers, retries once, and lets stale links fail without breaking the map.
- app/javascript/controllers/map_controller.js:622-627 — the `flyToBounds` zoom-15 clamp remains removed, aligning drill-ins and region card CTAs with fitted bounds rather than forcing every target to boulder-level zoom.
- .incant/work/0006-maplibre-web-interactions/plan.md:20-31,113-115 — the revise loop records what changed and includes Docker/PostGIS gate evidence. I re-ran the phase gate in this review session: `bin/rails db:prepare && bin/rails test test/controllers/map_controller_test.rb && bin/rubocop -f github` → 9 runs, 182 assertions, 0 failures/errors; rubocop exited clean.

### Blocker
- app/controllers/map_controller.rb:16 and test/controllers/map_controller_test.rb:69-76 — the approved spec acceptance criterion names `?problem=` deep links (`spec.md:98-99`, `spec.md:223-224`), but the previous P5 pass only handled `pid`. The controller now accepts `params[:problem]` as an alias and the new test proves `/en/map?problem=<id>` emits `data-map-problem-value`, so the selected-card JS path can run for the spec-declared query. status: addressed

### Major
(none)

### Minor
(none)

### Nit
(none)

### Verdict
Ready to release? **With fixes** — the P5 blocker is addressed and there are no open blocker/major findings for this phase gate. Continue with `0006-P6`; final release still waits on the planned contract documentation, full release gate, and manual smoke evidence.
