---
id: "0006"
slug: maplibre-web-interactions
stage: review
reviewed: 2026-06-10
commit: b91fa590
---

# Maplibre Web Interactions — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

> Scope of this pass: **phase gate for 0006-P2** through review-fix commit `b91fa590`.
> Prior P1 review findings remain addressed; P3–P6 and the remaining UI/style/release acceptance criteria are reviewed at later gates / before release.

### Strengths
- lib/map_tiles/geojson_exporter.rb:282-293 — the cascade seam is explicit and documented; `effective_card_attributes` resolves warnings, guidebook, and parking once at export time, matching the shared web/native contract and avoiding client-side divergence.
- lib/map_tiles/geojson_exporter.rb:231-279,318-363 — area/cluster/region properties now consistently merge bounds, aggregate `problemCount`/`gradeMin`/`gradeMax`, and scalar card fields, so the card contract is baked into both point and hull features.
- lib/map_tiles/geojson_exporter.rb:366-387 — cover-photo URLs use the CDN image route with `expires_in: nil` and follow the main-area/main-cluster chain for higher-level entities, which aligns with the spec's deterministic tile-data requirement.
- lib/map_tiles/geojson_exporter.rb:390-401 — region `mainCluster*` bounds are exported separately from full region bounds, giving P4/P5 the data needed for the Maltatal/main-cluster camera fix without overloading existing bounds fields.
- lib/map_tiles/layer_contract.rb:27-60 and lib/map_tiles/smoke_check.rb:28,225-227 — the layer contract and smoke checker were extended together, including a narrow URL-field allowlist (`coverPhotoUrl`, `guidebookUrl`, `parkingGoogleUrl`, plus existing `googleUrl`) instead of weakening the URL guard globally.
- test/lib/map_tiles/geojson_exporter_test.rb:71-203 — exporter tests exercise the cascade matrix, published-area-only aggregates, main-cluster bounds, deterministic/non-expiring cover URL output, and cluster/region main-child cover fallback through real model records and exported GeoJSON.
- test/lib/map_tiles/layer_contract_test.rb:40-47 — contract tests pin representative new properties across point and hull layers, reducing the chance that schema updates drift from exporter output.
- Commit history follows incant conventions (`incant 0006-P2: exporter cascade and card tile contract`, `incant 0006-P2: address exporter review findings`). Fresh review-fix gate run in this session passed: `bin/rails db:prepare && bin/rails test test/lib/map_tiles && bin/rubocop lib/map_tiles test/lib/map_tiles -f github` in Docker/PostGIS → 66 runs, 1947 assertions, 0 failures/errors; rubocop exit 0.

### Blocker
(none)

### Major
- .incant/work/0006-maplibre-web-interactions/plan.md:237-240 + .gitignore:29 + docs/map_tiles.md:3 — P2 is checked off as having updated `docs/map_tiles.md`, but `/docs/` is ignored and the P2 commit contains no docs change. status: wontfix — human confirmed `/docs/` is intentionally gitignored for this project; the local ignored contract note is accepted as the intended documentation location for this phase.

### Minor
- test/lib/map_tiles/geojson_exporter_test.rb:172-203 — the cover-photo test proves area cover URLs are deterministic, but it never exercises the required cluster/region main-child cover fallback implemented in `effective_cover_attachment`. The code path looks correct, but this is an exporter-contract edge that can regress silently and affects cards on higher-level pins. Add assertions for cluster main-area cover and region main-cluster→main-area cover fallback (including absent-cover behavior). status: addressed — test now sets `cluster.main_area_id` and `region.main_cluster_id`, asserts the cluster and region `coverPhotoUrl` equal the area cover URL across two exports, and asserts all three omit `coverPhotoUrl` after purging the cover; gate re-run green (66 runs/1947 assertions, rubocop clean).

### Nit
(none)

### Verdict
Ready to release? **Yes** for the P2 phase gate. No open blockers or majors remain (the docs finding is accepted `wontfix` by human decision, and the cover-fallback test gap is addressed); the review-fix gate is green. Proceed to `/incant:implement 0006` for `0006-P3`.
