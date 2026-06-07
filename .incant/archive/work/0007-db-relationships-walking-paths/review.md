---
id: "0007"
slug: db-relationships-walking-paths
stage: review
reviewed: 2026-06-07
commit: 405aa543abe144ea84ccb14b5d1d36f10e9d9d07
---

# Db Relationships Walking Paths — review

### Strengths
- db/schema.rb:208 and db/schema.rb:289 — `problems.boulder_id` is present, indexed, optional, and foreign-keyed to `boulders`, satisfying the core relationship foundation without forcing ambiguous legacy rows.
- app/services/problem_boulder_assignment.rb:47 — The problem-to-boulder classifier separates `area_mismatch`, `missing_location`, `no_containing_boulder`, `matched`, and `multiple_containing_boulders`; app/services/problem_boulder_assignment.rb:69 keeps assignment conservative by limiting candidates to boulders in the problem's own area.
- lib/tasks/problem_boulder_assignments.rake:14 — The report/backfill task prints every required category and row-id list before update counts, so dirty or ambiguous data is visible instead of silently changed.
- db/schema.rb:278 — All candidate existing relationships are now represented by database foreign keys, including area/cluster/region, line/problem/topo, POI route, contribution, parent problem, and topo/boulder constraints.
- db/schema.rb:243 and db/schema.rb:253 — Walking-path area and cluster groupings are many-to-many join tables with uniqueness and foreign keys, keeping editorial grouping optional rather than creating a single-owner path assumption.
- db/schema.rb:263 — `walking_paths` stores label, slug, description, published state, SRID 4326 geometry, spatial indexing, and a line-geometry check constraint for LineString/MultiLineString source data.
- app/models/walking_path.rb:8 — Published walking paths require slug uniqueness and valid SRID 4326 line geometry, while drafts can remain unpublished without geometry.
- app/services/walking_path_geojson_parser.rb:41 — The parser documents the one-submission-to-one-path boundary and rejects unsupported sibling geometries or multi-line FeatureCollections before persistence.
- app/controllers/admin/walking_paths_controller.rb:63 — Admin create/update wraps metadata, grouping IDs, and GeoJSON parsing in a transaction, preventing partial saves when invalid geometry is submitted.
- app/views/admin/walking_paths/_form.html.erb:48 — The edit form leaves the paste textarea blank and shows current geometry separately, so uploaded `.geojson` replacement no longer conflicts with existing geometry preview.
- test/controllers/admin/walking_paths_controller_test.rb:90 — Regression coverage proves uploaded `.geojson` update replaces stored geometry while the current-geometry preview remains read-only.
- Fresh review gate evidence: `docker compose run --rm -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/dump-prod web bin/rails db:migrate:status` → every migration through `20260607092652` is `up`.
- Fresh review gate evidence: `docker compose run --rm -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/dump-prod web bin/rails problem_boulder_assignments:report` → all five required categories printed with count `0` and `*_ids: none`.
- Fresh review gate evidence: `docker compose run --rm -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/dump-prod web bin/rails relationship_foreign_keys:report` → every candidate relationship reported `clean`, `count: 0`, `row_ids: none`.
- Fresh review gate evidence: `docker compose run --rm -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/dump-prod web bin/rails problem_boulder_assignments:backfill` → all categories count `0`, `updated: 0`, `updated_ids: none`.
- Fresh re-review gate evidence: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=https://example.invalid -e BUNNY_STORAGE_ACCESS_KEY_ID=test -e BUNNY_STORAGE_SECRET_ACCESS_KEY=test -e BUNNY_STORAGE_REGION=de -e BUNNY_STORAGE_BUCKET=test web bin/rails test test/models/problem_boulder_assignment_test.rb test/models/relationship_foreign_key_report_test.rb test/models/walking_path_test.rb test/models/topo_test.rb test/models/boulder_test.rb test/models/poi_test.rb test/controllers/admin/walking_paths_controller_test.rb` → 33 runs, 126 assertions, 0 failures, 0 errors, 0 skips.
- Fresh re-review gate evidence: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rubocop` → 248 files inspected, no offenses detected.
- Fresh re-review workflow evidence: `.incant/work/0007-db-relationships-walking-paths/summary.md` is absent from the working tree and `git diff --name-status e553738f..HEAD -- .incant/work/0007-db-relationships-walking-paths/summary.md` shows it deleted.

### Blocker
None.

### Major
- .incant/work/0007-db-relationships-walking-paths/summary.md:4 and .incant/work/0007-db-relationships-walking-paths/summary.md:11 — Previously, a finalize-stage artifact had been committed in the active work directory with `stage: archived`, stale `commit: 3cd48232`, and placeholder summary sections. The premature `summary.md` is now deleted from the implementation branch, so finalization owns summary creation again. status: addressed
- .incant/work/0007-db-relationships-walking-paths/spec.md:96 and .incant/work/0007-db-relationships-walking-paths/plan.md:167 — Previously, Phase 0007-P4 lacked complete release-readiness evidence and full `bin/rubocop` failed. P4 is now complete: migration status, assignment report/backfill, relationship report, relevant Rails tests, and full RuboCop all have fresh passing evidence in `plan.md` and were re-run during this review. status: addressed
- app/views/admin/walking_paths/_form.html.erb:48 and app/controllers/admin/walking_paths_controller.rb:100 — Previously, editing an existing path with geometry pre-filled the `geojson_text` textarea caused uploaded `.geojson` replacement through the normal edit UI to be rejected as “both pasted and uploaded” input. The form now keeps the textarea blank unless the user pasted new input and shows current geometry separately; `test/controllers/admin/walking_paths_controller_test.rb:90` covers uploaded replacement. status: addressed
- app/services/walking_path_geojson_parser.rb:24 — Previously, `extract_line_geometries` silently ignored unsupported geometries inside a `FeatureCollection` as long as exactly one line geometry was present. The parser now returns `GeoJSON must contain only LineString or MultiLineString geometries` when any sibling Point/Polygon is present, and regression tests cover both mixed cases. status: addressed

### Minor
None.

### Nit
None.

### Verdict
Ready to release? **Yes** — all blocker and major findings are addressed, the premature finalize-stage summary artifact is gone, and the fresh re-review gates pass. Proceed to `/incant:finalize 0007`.
