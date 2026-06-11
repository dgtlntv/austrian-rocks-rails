---
id: "0012"
slug: remove-legacy-mapbox-references
branch: incant/0012-remove-legacy-mapbox-references
title: Remove Legacy Mapbox References
stage: plan
status: in-progress
created: 2026-06-11
commit: 246f28e9
updated: 2026-06-11
---

# Remove Legacy Mapbox References — plan

## Status
- Phase: 0012-P1 complete; awaiting review.
- Stage: review
- Branch: incant/0012-remove-legacy-mapbox-references
- Next: run `/incant:review 0012`.
- Blockers: none.
- Fresh verification: 2026-06-11 implementation gate passed. Static checks produced no forbidden output (`lib/tasks/mapbox.rake` absent; no case-insensitive `mapbox` matches under `app config lib bin README.md Dockerfile Dockerfile.dev`; no legacy deploy volume/path in `config/deploy.yml`). Docker-backed Rails task discovery found no `mapbox` tasks, and targeted tests passed: 23 runs, 1176 assertions, 0 failures, 0 errors, 0 skips.
- Gate note: the originally planned in-container `rg` task-discovery check failed because the web image does not include `rg`, and the first Docker test run exposed an empty `BUNNY_STORAGE_SECRET_ACCESS_KEY` test-env value. The passing rerun used equivalent `grep -i` task discovery inside Docker and a non-secret `BUNNY_STORAGE_SECRET_ACCESS_KEY=test-secret` test value.
- Key decisions:
  - Delete the obsolete Mapbox-named rake task instead of renaming it, because `map_tiles:*` and `bin/build_pmtiles` are the maintained PMTiles export/build/publish path.
  - Remove the legacy Kamal volume mount without replacement; durable PMTiles artifacts are published to Bunny/CDN and local generated files remain under `tmp/map_tiles`.
  - Preserve existing tests that intentionally mention Mapbox while using static search to ensure app/deploy/task/docs code no longer does.

## Spec freshness check
- `spec.md` records base commit `e98ebb9d`; current `HEAD` during planning is `246f28e9`.
- `git diff --name-status e98ebb9d..HEAD` shows only `.incant/` artifacts for item `0012`, so `config/deploy.yml`, `lib/tasks/mapbox.rake`, `lib/tasks/map_tiles.rake`, `app/controllers/admin/maps_controller.rb`, `config/routes.rb`, and the targeted tests have not drifted since the spec was written.

## Files touched

### Incant planning artifacts
- `.incant/work/0012-remove-legacy-mapbox-references/plan.md` (edit) — replace the scaffold with this approved-spec implementation plan.
- `.incant/work/0012-remove-legacy-mapbox-references/sessions.json` (edit) — record this linked planning session through `incant session link 0012`.
- `.incant/backlog.md` (edit) — move item `0012` from `status:spec` to `status:plan` after writing the plan.
- `.incant/STATE.md` (edit) — record that item `0012` is planned and awaiting approval.

### Implementation files
- `lib/tasks/mapbox.rake` (delete) — remove the obsolete `mapbox:*` GeoJSON export namespace and its legacy `../#{BRAND_CONFIG[:slug]}-maps/mapbox/*.geojson` output paths.
- `config/deploy.yml` (edit) — remove only the `austrian_rocks_mapbox:/austrian-rocks-maps/mapbox` volume mount while preserving `austrian_rocks_export:/rails/export`.
- `app/controllers/admin/maps_controller.rb` (edit) — replace stale Mapbox simple-style wording with neutral simple-style/geojson.io wording while keeping `marker-color` output unchanged.
- `config/routes.rb` (edit) — remove the incidental Mapbox wording from the redirects route comment without changing the route.

### Verification surfaces read but intentionally unchanged
- `lib/tasks/map_tiles.rake` (read) — confirm the maintained map tile rake namespace remains untouched.
- `bin/build_pmtiles` (read) — confirm the maintained PMTiles CLI entry point remains untouched.
- `test/controllers/map_controller_test.rb` (read) — keep readable Mapbox-negative runtime assertions.
- `test/controllers/admin/exports_controller_test.rb` (read) — keep legacy GeoJSON export absence coverage.
- `test/lib/map_tiles/style_materializer_test.rb` (read) — keep `mapbox://` style absence coverage.
- `test/lib/map_tiles/tippecanoe_builder_test.rb` (read) — keep historical Mapbox Tippecanoe repository absence coverage.

## Phase 0012-P1 — remove legacy Mapbox surfaces and verify MapLibre/PMTiles paths
- [x] Read `lib/tasks/mapbox.rake`, `lib/tasks/map_tiles.rake`, and `bin/build_pmtiles` before editing to confirm the obsolete namespace is isolated from the maintained PMTiles pipeline.
- [x] Delete `lib/tasks/mapbox.rake` entirely; do not add a replacement `mapbox:*` namespace, renamed legacy GeoJSON namespace, or new task file for the old `../#{BRAND_CONFIG[:slug]}-maps/mapbox/*.geojson` outputs.
- [x] Read `config/deploy.yml` before editing, then remove only the `austrian_rocks_mapbox:/austrian-rocks-maps/mapbox` entry from `volumes:` and leave `austrian_rocks_export:/rails/export` unchanged.
- [x] Read `app/controllers/admin/maps_controller.rb` before editing, then replace the Mapbox simple-style URL/comment with neutral wording that explains the standard `marker-color` simple-style property used by geojson.io; keep `hash[:"marker-color"] = "#ccc"`, GeoJSON rendering, download behaviour, and camelization behaviour unchanged.
- [x] Read `config/routes.rb` before editing, then replace the redirects route comment so it no longer says `mapbox`; keep `resources :redirects, only: :new` and all route names/paths unchanged.
- [x] Read `test/controllers/map_controller_test.rb`, `test/controllers/admin/exports_controller_test.rb`, `test/lib/map_tiles/style_materializer_test.rb`, and `test/lib/map_tiles/tippecanoe_builder_test.rb`; leave their intentional Mapbox-negative test names/helpers/literals readable and unchanged unless a test failure proves an actual behavioural regression.
- [x] Run static verification that `lib/tasks/mapbox.rake` is absent, Rails task discovery exposes no case-insensitive `mapbox` tasks, `config/deploy.yml` no longer contains the legacy volume/path, and `rg -n -i "mapbox" app config lib bin README.md Dockerfile Dockerfile.dev` produces no output.
- [x] Run the targeted Docker-backed Rails tests for public MapLibre rendering, admin export cleanup, style materialization, and Tippecanoe guidance.
- [x] Update this plan’s Status block with the fresh gate evidence, set `.incant/backlog.md` to `status:review phase:0012-P1`, update `.incant/STATE.md` to say item `0012` is awaiting review, and commit the phase as `incant 0012-P1: remove legacy Mapbox references`.
**Quality gate:** `bash -lc 'test ! -e lib/tasks/mapbox.rake && ! rg -n -i "mapbox" app config lib bin README.md Dockerfile Dockerfile.dev && ! rg -n "austrian_rocks_mapbox|/austrian-rocks-maps/mapbox" config/deploy.yml && docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test -e BUNNY_STORAGE_SECRET_ACCESS_KEY=test-secret web bash -lc "if bin/rails -T | grep -i \"mapbox\"; then exit 1; fi; bin/rails test test/controllers/map_controller_test.rb test/controllers/admin/exports_controller_test.rb test/lib/map_tiles/style_materializer_test.rb test/lib/map_tiles/tippecanoe_builder_test.rb"'` → static checks produced no forbidden output; Rails task discovery had no `mapbox` matches; targeted tests passed with 23 runs, 1176 assertions, 0 failures, 0 errors, 0 skips.

## Coverage self-review
- Requirement 1 → Phase 0012-P1 deletes `lib/tasks/mapbox.rake` and explicitly forbids a replacement legacy namespace/task.
- Requirement 2 → Phase 0012-P1 quality gate runs `bin/rails -T` and fails if any case-insensitive `mapbox` task is listed.
- Requirement 3 → Phase 0012-P1 removes `austrian_rocks_mapbox:/austrian-rocks-maps/mapbox` and keeps `/rails/export`; the quality gate searches for both legacy strings.
- Requirement 4 → Phase 0012-P1 updates only incidental comments in `app/controllers/admin/maps_controller.rb` and `config/routes.rb` while preserving endpoint and `marker-color` behaviour.
- Requirement 5 → Phase 0012-P1 reads and preserves the intentional Mapbox-negative tests.
- Requirement 6 → Phase 0012-P1 quality gate runs `rg -n -i "mapbox" app config lib bin README.md Dockerfile Dockerfile.dev` and expects no output outside `.incant/` and tests.
- Requirement 7 → Phase 0012-P1 leaves MapLibre runtime code, PMTiles tasks/CLI/config, admin SQLite export, and admin GeoJSON editing/debug endpoints untouched, then runs the targeted tests that cover those preservation points.
- Acceptance criteria → The Phase 0012-P1 static checks and Docker-backed test command cover every listed acceptance criterion.
- Symbol/signature consistency checked: no new Ruby constants, methods, routes, rake task names, environment variables, or deploy paths are introduced; existing `resources :redirects, only: :new` and `hash[:"marker-color"] = "#ccc"` remain unchanged.
- No placeholders remain in this plan.

## Phase handoff
- Phase 0012-P1 implementation is complete and ready for review.
- Next: `/incant:review 0012`.
