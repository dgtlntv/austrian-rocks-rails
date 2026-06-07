---
id: "0007"
slug: db-relationships-walking-paths
stage: review
reviewed: 2026-06-07
commit: dcdd0f868696b2a440eaf66ea81b7647b39b0bc0
---

# Db Relationships Walking Paths — review

### Strengths
- config/routes.rb:30 — Walking paths are wired into the localized admin namespace with member publish/unpublish routes, matching the planned admin surface without disturbing existing admin resources.
- app/controllers/admin/walking_paths_controller.rb:69 — Create/update wraps metadata, grouping IDs, and GeoJSON parsing in one database transaction, so invalid geometry rolls back partial metadata/grouping changes.
- app/controllers/admin/walking_paths_controller.rb:100 — The controller gives a clear validation error when admins submit both pasted and uploaded GeoJSON instead of guessing which untrusted input wins.
- app/controllers/admin/walking_paths_controller.rb:107 — Uploaded filenames are used only for extension validation, not as filesystem paths, keeping the upload handling inside the intended data-only trust boundary.
- app/views/admin/walking_paths/index.html.erb:40 — The list view exposes publish/unpublish and delete actions directly, satisfying the maintainer CRUD workflow promised for Phase 0007-P3.
- app/views/admin/walking_paths/_form.html.erb:35 — Area and cluster grouping controls remain optional editorial groupings, preserving the spec's no-single-owner walking-path rule.
- app/views/admin/walking_paths/_form.html.erb:50 — The form documents accepted GeoJSON shapes and rejected mixed/unsupported input in the admin UI, aligning the UI with the parser contract.
- test/controllers/admin/walking_paths_controller_test.rb:44 — Controller coverage exercises uploaded `.geojson` creation, so the upload path is tested through the real admin endpoint.
- test/controllers/admin/walking_paths_controller_test.rb:173 — Regression coverage proves invalid geometry updates do not partially persist metadata or grouping changes.
- app/services/walking_path_geojson_parser.rb:24 — The earlier P2 review fix remains in place: mixed FeatureCollections with unsupported sibling geometries are rejected before model persistence.
- Fresh gate evidence: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.test -e BUNNY_STORAGE_ACCESS_KEY_ID=test -e BUNNY_STORAGE_SECRET_ACCESS_KEY=test -e BUNNY_STORAGE_REGION=us-east-1 -e BUNNY_STORAGE_BUCKET=test web bin/rails test test/controllers/admin/walking_paths_controller_test.rb test/models/walking_path_test.rb` → 25 runs, 97 assertions, 0 failures, 0 errors, 0 skips.
- Fresh lint evidence: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.test -e BUNNY_STORAGE_ACCESS_KEY_ID=test -e BUNNY_STORAGE_SECRET_ACCESS_KEY=test -e BUNNY_STORAGE_REGION=us-east-1 -e BUNNY_STORAGE_BUCKET=test web bundle exec rubocop app/controllers/admin/walking_paths_controller.rb test/controllers/admin/walking_paths_controller_test.rb` → 2 files inspected, no offenses detected.

### Blocker
None.

### Major
- app/views/admin/walking_paths/_form.html.erb:48 and app/controllers/admin/walking_paths_controller.rb:100 — Editing an existing path with geometry pre-fills the `geojson_text` textarea, and the normal browser form will submit that value even when the admin chooses an uploaded `.geojson` replacement. `read_geojson_input` then rejects the request as “both pasted and uploaded” input, so uploaded geometry replacement is not supported through the default edit UI unless the maintainer manually clears the pasted field. This misses the planned edit/upload workflow. Fix: either do not submit existing geometry as editable paste input by default (show it as a separate preview), or explicitly treat an uploaded file as the replacement when the text field still equals the current geometry; add a controller test for updating an existing path from an uploaded `.geojson`. status: open
- app/services/walking_path_geojson_parser.rb:24 — Previously, `extract_line_geometries` silently ignored unsupported geometries inside a `FeatureCollection` as long as exactly one line geometry was present. The parser now returns `GeoJSON must contain only LineString or MultiLineString geometries` when any sibling Point/Polygon is present, and regression tests cover both mixed cases. status: addressed

### Minor
None.

### Nit
None.

### Verdict
Ready to release? **No** — Phase 0007-P3 has one open major finding in the admin upload edit path. Return to implementation for the fix; after that, the item still needs the planned 0007-P4 end-to-end verification before final release.
