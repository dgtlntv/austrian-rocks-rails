---
id: "0006"
slug: maplibre-web-interactions
stage: review
reviewed: 2026-06-10
commit: d0c11809
---

# Maplibre Web Interactions — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

> Scope of this pass: **phase gate for 0006-P1** (commit d0c11809, the only phase committed).
> P2–P6 and the remaining acceptance criteria are reviewed at later gates / before release.

### Strengths
- db/migrate/20260610090000–20260610090002 — migrations mirror existing conventions exactly:
  `text` warning columns matching `areas.warning_de/_en`, `add_reference` with real FKs and
  indexes (`parking_poi_id → pois` via `to_table`), schema regenerated cleanly to 2026_06_10_090002.
- app/models/guidebook.rb:1-4 — the class comment documents the cascade intent (area → cluster →
  region inheritance at tile export), exactly the "Ruby docs at module boundaries" the spec's
  code-documentation consideration asked for; `audited` + `MapTiles::PublishStaleMarker` are both
  present so guidebook edits schedule a tile republish.
- app/models/guidebook.rb:17 — guidebook URL validated as http(s) at the model layer per the
  spec's security consideration; test/models/guidebook_test.rb:17-20 proves `javascript:` and
  bare-word URLs are rejected.
- app/models/area.rb:79, cluster.rb:35, region.rb:32 — `parking_poi_must_be_parking` reuses the
  existing `Poi#parking?` predicate instead of the plan's literal `poi_type == "parking"` string
  comparison; a small, justified improvement.
- Region/Cluster/Area already include `MapTiles::PublishStaleMarker`, so every new cascade-relevant
  field (warnings, guidebook_id, parking_poi_id) marks tiles stale with no extra wiring.
- Tests verify real behaviour: association round-trips with reload, the train-station rejection
  case on all three entities, blank-warning normalization, admin invalid-URL re-render with 422
  (test/controllers/admin/guidebooks_controller_test.rb:34-43), and persistence of every new
  permitted param through the real admin update actions.
- app/views/admin/guidebooks/index.html.erb:32 — outbound guidebook links get
  `target="_blank" rel="noopener noreferrer"`, honouring the spec's outbound-link rule already in
  the admin UI.
- Commit subject `incant 0006-P1: warnings, guidebooks, parking links (DB + admin)` follows the
  phase-token convention; quality gate re-run fresh this session: 111 runs, 409 assertions,
  0 failures/errors, rubocop clean (Docker PostGIS, exit 0) — matches the plan's recorded evidence.

**Deviations from plan (judged intentional/justified — implementer to confirm):**
- app/views/layouts/admin.html.erb:53 — a "Guidebooks" nav link was added; not in the plan's
  Files-touched list but necessary for the CRUD to be reachable. Improvement.
- Plan step 12 said "extend existing admin region/cluster/area controller tests", but no such
  files existed; new focused test files were created instead. Correct response to a plan
  assumption that didn't hold.

### Blocker
(none)

### Major
(none)

### Minor
- app/controllers/admin/guidebooks_controller.rb:39-44 — `destroy` on a guidebook referenced by
  any region/cluster/area raises `ActiveRecord::InvalidForeignKey` → admin 500 with no feedback.
  Sibling controllers (regions/clusters) share this naked-destroy pattern today, but guidebooks
  are *designed* to be shared across many entities, so an in-use delete is the likely case, and
  the index/edit views offer a Delete button that will 500. Fix: rescue
  `ActiveRecord::InvalidForeignKey` (or check `regions/clusters/areas.exists?` first) and
  re-render with a flash error naming the entities still referencing it. status: open

### Nit
- app/controllers/admin/guidebooks_controller.rb:17 + 34 — `flash[:error]` (not `flash.now`) set
  before a `render` leaks the message into the *next* request as well. Copied from the sibling
  `Admin::PoisController#update`, so consistent house style; noting it so the pattern doesn't
  spread further in P4/P5 views. status: open
- db/migrate/20260610090002_add_guidebook_and_parking_to_climbing_entities.rb:4-5 — `null: true`
  on `add_reference` is the default and redundant. No functional impact. status: open

### Verdict
Ready to release? **With fixes** — for the P1 phase gate: **pass**. No blockers or majors; the
phase delivers everything P1 promised (warnings on clusters/regions, Guidebook model + admin CRUD,
parking-POI links, admin forms/strong-params, tests) with a fresh green gate. The one minor
(in-use guidebook delete → 500) should be picked up in a later phase or the revise loop before the
item closes; the nits are take-or-leave. Proceed to `0006-P2`.
