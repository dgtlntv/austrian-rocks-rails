---
id: "0006"
slug: maplibre-web-interactions
stage: review
reviewed: 2026-06-10
commit: 6aa1c923
---

# Maplibre Web Interactions — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

> Scope of this pass: **P5 review** through commit `6aa1c923`, with prior P1/P2/P3 findings remaining addressed/wontfix/clean and the P4 re-review blocker remaining addressed. P6 documentation/release-smoke work is still pending.

### Strengths
- app/javascript/controllers/map_controller.js:225-241,750-765 — problem and area entry points now call `selectFeatureWhenIdle` after camera movement, so search events and existing `pid`/area deep links route through the same selected-card path instead of the removed popup path.
- app/javascript/controllers/map_controller.js:359-391 — the idle-time selector is bounded and defensive: it queries the source layer by id, falls back to rendered layers, retries once, and lets stale links fail without breaking the map.
- app/javascript/controllers/map_controller.js:622-627 — the `flyToBounds` zoom-15 clamp is gone, aligning drill-ins and region card CTAs with fitted bounds rather than forcing every target to boulder-level zoom.
- app/javascript/controllers/map_controller.js:237-240,544-546,613-614 — legacy problem popup/deferred replay code is removed while contribution-request popups remain isolated to the mapping overlay, preserving that out-of-scope behavior.
- test/controllers/map_controller_test.rb:58-75 — the P5 regression checks keep existing problem deep-link data present for the controller and assert the controller no longer contains the old popup helpers or zoom clamp.
- .incant/work/0006-maplibre-web-interactions/plan.md:99,507 — P5 status and fresh Docker/PostGIS gate evidence are recorded. I re-ran the phase gate in this review session: `bin/rails db:prepare && bin/rails test test/controllers/map_controller_test.rb && bin/rubocop -f github` → 8 runs, 163 assertions, 0 failures/errors; rubocop exited clean.
- Commit history follows incant conventions for this phase: `incant 0006-P5: search and deep-link card selection`.

### Blocker
- app/controllers/map_controller.rb:16 and test/controllers/map_controller_test.rb:58-75 — the approved spec acceptance criterion names `?problem=` deep links (`spec.md:98-99`, `spec.md:223-224`), but the controller and tests only handle `pid`. A request such as `/en/map?problem=<id>` will not populate `data-map-problem-value`, so the new JS path at app/javascript/controllers/map_controller.js:237-240 never runs and the selected card does not open. Fix by either accepting `params[:problem]` as an alias for `params[:pid]` (and covering it) or formally reconciling the spec/plan mismatch before release. status: open

### Major
(none)

### Minor
(none)

### Nit
(none)

### Verdict
Ready to release? **No** — P5 is close and the gate is green, but one spec-level deep-link acceptance criterion remains unmet/open. Route back through `/incant:implement 0006` to address or explicitly reconcile the `?problem=` vs `?pid=` mismatch before continuing to P6/final release.
