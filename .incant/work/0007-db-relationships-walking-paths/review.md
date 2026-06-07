---
id: "0007"
slug: db-relationships-walking-paths
stage: review
reviewed: 2026-06-07
commit: cfc3b73770b56e84f229ba52c8f1ee7c72070214
---

# Db Relationships Walking Paths — review

### Strengths
- app/views/admin/walking_paths/_form.html.erb:48 — The edit form no longer submits the existing geometry through the paste textarea by default, so choosing an uploaded `.geojson` replacement no longer trips the controller's both-inputs validation.
- app/views/admin/walking_paths/_form.html.erb:55 — Existing geometry is still visible as a separate read-only preview, preserving admin context without turning current state into accidental form input.
- test/controllers/admin/walking_paths_controller_test.rb:89 — Regression coverage now proves the edit textarea is blank while current geometry is shown, and that an uploaded `.geojson` update replaces stored geometry successfully.
- config/routes.rb:30 — Walking paths are wired into the localized admin namespace with member publish/unpublish routes, matching the planned admin surface without disturbing existing admin resources.
- app/controllers/admin/walking_paths_controller.rb:69 — Create/update wraps metadata, grouping IDs, and GeoJSON parsing in one database transaction, so invalid geometry rolls back partial metadata/grouping changes.
- app/controllers/admin/walking_paths_controller.rb:100 — The controller gives a clear validation error when admins submit both pasted and uploaded GeoJSON instead of guessing which untrusted input wins.
- app/controllers/admin/walking_paths_controller.rb:107 — Uploaded filenames are used only for extension validation, not as filesystem paths, keeping the upload handling inside the intended data-only trust boundary.
- app/views/admin/walking_paths/index.html.erb:40 — The list view exposes publish/unpublish and delete actions directly, satisfying the maintainer CRUD workflow promised for Phase 0007-P3.
- app/views/admin/walking_paths/_form.html.erb:35 — Area and cluster grouping controls remain optional editorial groupings, preserving the spec's no-single-owner walking-path rule.
- app/views/admin/walking_paths/_form.html.erb:50 — The form documents accepted GeoJSON shapes and rejected mixed/unsupported input in the admin UI, aligning the UI with the parser contract.
- app/services/walking_path_geojson_parser.rb:24 — The earlier P2 review fix remains in place: mixed FeatureCollections with unsupported sibling geometries are rejected before model persistence.
- Fresh gate evidence: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.test -e BUNNY_STORAGE_ACCESS_KEY_ID=test -e BUNNY_STORAGE_SECRET_ACCESS_KEY=test -e BUNNY_STORAGE_REGION=us-east-1 -e BUNNY_STORAGE_BUCKET=test web bin/rails test test/controllers/admin/walking_paths_controller_test.rb test/models/walking_path_test.rb` → 26 runs, 107 assertions, 0 failures, 0 errors, 0 skips.
- Fresh full relevant test evidence: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.test -e BUNNY_STORAGE_ACCESS_KEY_ID=test -e BUNNY_STORAGE_SECRET_ACCESS_KEY=test -e BUNNY_STORAGE_REGION=us-east-1 -e BUNNY_STORAGE_BUCKET=test web bin/rails test test/models/problem_boulder_assignment_test.rb test/models/relationship_foreign_key_report_test.rb test/models/walking_path_test.rb test/models/topo_test.rb test/models/boulder_test.rb test/models/poi_test.rb test/controllers/admin/walking_paths_controller_test.rb` → 33 runs, 126 assertions, 0 failures, 0 errors, 0 skips.
- Fresh targeted lint evidence: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test ... web bundle exec rubocop test/controllers/admin/walking_paths_controller_test.rb app/controllers/admin/walking_paths_controller.rb app/services/walking_path_geojson_parser.rb test/models/walking_path_test.rb` → 4 files inspected, no offenses detected.

### Blocker
None.

### Major
- .incant/work/0007-db-relationships-walking-paths/spec.md:96 and .incant/work/0007-db-relationships-walking-paths/plan.md:151 — The release-readiness phase is still unchecked: migration status, problem-boulder report/backfill evidence, relationship report evidence, full lint, and final consistency review have not been completed in the implementation notes. The full relevant Rails test set passes, but `bin/rubocop` does not: the fresh full run reported 38 offenses, including item-introduced offenses in `test/models/problem_boulder_assignment_test.rb:10`/`:11`/`:12`/`:13`/`:14`/`:39`. This leaves acceptance criterion 15 / spec line 96 unmet. Fix: complete Phase 0007-P4, fix or explicitly separate introduced lint offenses from pre-existing repo offenses, and record fresh passing release-gate evidence. status: open
- app/views/admin/walking_paths/_form.html.erb:48 and app/controllers/admin/walking_paths_controller.rb:100 — Previously, editing an existing path with geometry pre-filled the `geojson_text` textarea, causing uploaded `.geojson` replacement through the normal edit UI to be rejected as “both pasted and uploaded” input. The form now keeps the textarea blank unless the user pasted new input and shows current geometry separately; `test/controllers/admin/walking_paths_controller_test.rb:89` covers uploaded replacement. status: addressed
- app/services/walking_path_geojson_parser.rb:24 — Previously, `extract_line_geometries` silently ignored unsupported geometries inside a `FeatureCollection` as long as exactly one line geometry was present. The parser now returns `GeoJSON must contain only LineString or MultiLineString geometries` when any sibling Point/Polygon is present, and regression tests cover both mixed cases. status: addressed

### Minor
None.

### Nit
None.

### Verdict
Ready to release? **No** — the P3 upload-edit finding is addressed, but the item still has one open major release-readiness finding: Phase 0007-P4 is incomplete and full `bin/rubocop` currently fails with item-introduced offenses. Return to `/incant:implement 0007` to finish P4 and fix the lint gate before finalization.
