---
id: "0007"
slug: db-relationships-walking-paths
stage: review
reviewed: 2026-06-07
commit: 88cd001ad6234c7953cae0269849ba4e69ff7db3
---

# Db Relationships Walking Paths — review

### Strengths
- app/services/problem_boulder_assignment.rb:46 — The assignment classifier explicitly separates matched, missing-location, no-containing-boulder, multiple-containing-boulders, and area-mismatch outcomes, matching the phase promise instead of silently guessing legacy data.
- app/services/relationship_foreign_key_report.rb:2 — The candidate relationship list covers the spec-required foreign keys plus `topos.boulder_id`, and the report returns clean/deferred status with dirty row IDs for follow-up.
- db/migrate/20260607092647_create_walking_paths.rb:3 — The walking-path table gives maintainers an independent editorial source with optional metadata, draft default, SRID 4326 geometry, spatial index, and a database line-geometry check constraint.
- app/models/walking_path.rb:2 — `WalkingPath` uses optional many-to-many area and cluster groupings through join models, avoiding the rejected single-owner path assumption.
- app/models/walking_path.rb:7 — Label, slug, and description normalization keeps admin-entered whitespace from becoming persisted state.
- app/models/walking_path.rb:22 — Published/draft validation is implemented at the model boundary: published paths need a slug and valid line geometry, while drafts can remain geometry-less.
- app/services/walking_path_geojson_parser.rb:16 — The parser gives clear errors for blank, malformed, unsupported, empty, and multi-line GeoJSON input and returns an SRID 4326 RGeo geometry for valid line input.
- test/models/walking_path_test.rb:4 — The P2 tests cover draft saves, published requirements, LineString/MultiLineString acceptance, unsupported raw Point/Polygon rejection, malformed JSON, multi-line FeatureCollection rejection, optional groupings, and GeoJSON display.
- Fresh gate evidence: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.test -e BUNNY_STORAGE_ACCESS_KEY_ID=test -e BUNNY_STORAGE_SECRET_ACCESS_KEY=test -e BUNNY_STORAGE_REGION=us-east-1 -e BUNNY_STORAGE_BUCKET=test web bin/rails test test/models/walking_path_test.rb` → 11 runs, 29 assertions, 0 failures, 0 errors, 0 skips.
- Fresh regression evidence: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.test -e BUNNY_STORAGE_ACCESS_KEY_ID=test -e BUNNY_STORAGE_SECRET_ACCESS_KEY=test -e BUNNY_STORAGE_REGION=us-east-1 -e BUNNY_STORAGE_BUCKET=test web bin/rails test test/models/problem_boulder_assignment_test.rb test/models/relationship_foreign_key_report_test.rb test/models/topo_test.rb test/models/boulder_test.rb test/models/poi_test.rb test/models/walking_path_test.rb` → 18 runs, 48 assertions, 0 failures, 0 errors, 0 skips.

### Blocker
None.

### Major
- app/services/walking_path_geojson_parser.rb:39 — `extract_line_geometries` silently ignores unsupported geometries inside a `FeatureCollection` as long as exactly one line geometry is present. For example, a collection containing one `LineString` plus one `Point` parses successfully, even though the spec requires unsupported Point/Polygon input to produce clear validation errors and invalid geometry input not to be partially accepted. Fix: have the traversal report unsupported sibling geometries (or require the collection to contain exactly one geometry feature) and add tests for mixed line+Point/Polygon FeatureCollections. status: open

### Minor
None.

### Nit
None.

### Verdict
Ready to release? **No** — one open major finding in the strict GeoJSON parser. P1 remains sound and the P2 happy-path gate passes, but the parser should reject mixed unsupported FeatureCollection input before this phase is considered complete.
