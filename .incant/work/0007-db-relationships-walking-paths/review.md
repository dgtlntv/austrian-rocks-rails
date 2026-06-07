---
id: "0007"
slug: db-relationships-walking-paths
stage: review
reviewed: 2026-06-07
commit: 790e4456dc7dd668f342e87d37173e50d38c9bf9
---

# Db Relationships Walking Paths — review

### Strengths
- app/services/problem_boulder_assignment.rb:46 — The assignment classifier explicitly separates matched, missing-location, no-containing-boulder, multiple-containing-boulders, and area-mismatch outcomes, matching the phase promise instead of silently guessing legacy data.
- app/services/relationship_foreign_key_report.rb:2 — The candidate relationship list covers the spec-required foreign keys plus `topos.boulder_id`, and the report returns clean/deferred status with dirty row IDs for follow-up.
- db/migrate/20260607092647_create_walking_paths.rb:3 — The walking-path table gives maintainers an independent editorial source with optional metadata, draft default, SRID 4326 geometry, spatial index, and a database line-geometry check constraint.
- app/models/walking_path.rb:2 — `WalkingPath` uses optional many-to-many area and cluster groupings through join models, avoiding the rejected single-owner path assumption.
- app/models/walking_path.rb:7 — Label, slug, and description normalization keeps admin-entered whitespace from becoming persisted state.
- app/models/walking_path.rb:22 — Published/draft validation is implemented at the model boundary: published paths need a slug and valid line geometry, while drafts can remain geometry-less.
- app/services/walking_path_geojson_parser.rb:24 — The P2 review fix now carries unsupported-geometry state through FeatureCollection traversal and rejects mixed line-plus-Point/Polygon input before returning a geometry.
- app/services/walking_path_geojson_parser.rb:41 — The parser documents the one-submission/one-persisted-path boundary and why unsupported sibling shapes are rejected before model persistence.
- test/models/walking_path_test.rb:62 — Regression coverage now proves mixed line+Point and line+Polygon FeatureCollections fail with clear validation errors.
- Fresh gate evidence: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.test -e BUNNY_STORAGE_ACCESS_KEY_ID=test -e BUNNY_STORAGE_SECRET_ACCESS_KEY=test -e BUNNY_STORAGE_REGION=us-east-1 -e BUNNY_STORAGE_BUCKET=test web bin/rails test test/models/walking_path_test.rb` → 12 runs, 33 assertions, 0 failures, 0 errors, 0 skips.
- Fresh regression evidence: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.test -e BUNNY_STORAGE_ACCESS_KEY_ID=test -e BUNNY_STORAGE_SECRET_ACCESS_KEY=test -e BUNNY_STORAGE_REGION=us-east-1 -e BUNNY_STORAGE_BUCKET=test web bin/rails test test/models/problem_boulder_assignment_test.rb test/models/relationship_foreign_key_report_test.rb test/models/topo_test.rb test/models/boulder_test.rb test/models/poi_test.rb test/models/walking_path_test.rb` → 19 runs, 52 assertions, 0 failures, 0 errors, 0 skips.
- Fresh lint evidence: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.test -e BUNNY_STORAGE_ACCESS_KEY_ID=test -e BUNNY_STORAGE_SECRET_ACCESS_KEY=test -e BUNNY_STORAGE_REGION=us-east-1 -e BUNNY_STORAGE_BUCKET=test web bundle exec rubocop app/services/walking_path_geojson_parser.rb test/models/walking_path_test.rb` → 2 files inspected, no offenses detected.

### Blocker
None.

### Major
- app/services/walking_path_geojson_parser.rb:24 — Previously, `extract_line_geometries` silently ignored unsupported geometries inside a `FeatureCollection` as long as exactly one line geometry was present. The parser now returns `GeoJSON must contain only LineString or MultiLineString geometries` when any sibling Point/Polygon is present, and regression tests cover both mixed cases. status: addressed

### Minor
None.

### Nit
None.

### Verdict
Ready to release? **With fixes** — the open P2 major finding is addressed and Phase 0007-P2 is ready to proceed. The full item is not release-ready yet because planned Phases 0007-P3 and 0007-P4 remain to be implemented and reviewed.
