---
id: "0013"
slug: asset-host-localhost-photo-urls
branch: incant/0013-asset-host-localhost-photo-urls
title: Asset Host Localhost Photo Urls
stage: plan
status: in-progress
created: 2026-06-11
commit: 5aa362fe
updated: 2026-06-11
---

# Asset Host Localhost Photo Urls — plan

## Status
- Phase: 0013-P1 planned; awaiting human approval.
- Stage: plan
- Branch: incant/0013-asset-host-localhost-photo-urls
- Next: approve this plan, then run `/incant:implement 0013`.
- Blockers: none.
- Key decisions:
  - Keep Rails `config.asset_host` as the only host source for exported Active Storage photo URLs.
  - Fail export when a photo URL is actually needed and `asset_host` is blank; do not omit photo fields silently.
  - Use Docker-backed Rails test execution for the map-data exporter gate, per project state.

## Spec freshness check
- `spec.md` records base commit `5aa362fe`; current `HEAD` during planning is `85e91621`.
- `git diff --name-status 5aa362fe..HEAD` shows only `.incant/` artifacts for item `0013`, so `lib/map_tiles/geojson_exporter.rb`, `test/lib/map_tiles/geojson_exporter_test.rb`, `config/routes.rb`, and `config/environments/production.rb` have not drifted since the spec was written.

## Files touched

### Incant planning artifacts
- `.incant/work/0013-asset-host-localhost-photo-urls/plan.md` (edit) — replace the scaffold with this approved-spec implementation plan.
- `.incant/work/0013-asset-host-localhost-photo-urls/sessions.json` (edit) — record this linked planning session through `incant session link 0013`.
- `.incant/backlog.md` (edit) — move item `0013` from `status:spec` to `status:plan` after writing the plan.
- `.incant/STATE.md` (edit) — record that item `0013` is planned and awaiting approval.

### Implementation files
- `lib/map_tiles/geojson_exporter.rb` (edit) — remove the hardcoded localhost fallback from `cdn_variant_url` and add the required-asset-host error path used only when generating attached cover/topo photo URLs.
- `test/lib/map_tiles/geojson_exporter_test.rb` (edit) — set an explicit asset host for photo URL success tests, restore the previous Rails config after each test, and add blank-host failure/no-photo coverage.

### Verification surfaces read but intentionally unchanged
- `config/routes.rb` (read) — confirm the existing `cdn_image` direct route remains the Active Storage proxy URL generator and does not need schema/route changes.
- `config/environments/production.rb` (read) — confirm production already sets `config.asset_host` from brand asset-domain configuration.

## Phase 0013-P1 — require configured asset host for exported photo URLs
- [ ] Read `lib/map_tiles/geojson_exporter.rb` and `test/lib/map_tiles/geojson_exporter_test.rb` before editing; keep the existing `cdn_image_url(..., expires_in: nil, host: ...)` call shape and the exporter layer/property schema intact.
- [ ] In `lib/map_tiles/geojson_exporter.rb`, define `MissingAssetHostError = Class.new(StandardError)` inside `MapTiles::GeojsonExporter` and define `ASSET_HOST_REQUIRED_MESSAGE = "Rails.application.config.asset_host must be configured to export map tile photo URLs"` as the raised message.
- [ ] Replace the `Rails.application.config.asset_host.presence || "http://localhost:3000"` expression in `cdn_variant_url` with `required_asset_host`, leaving `expires_in: nil` unchanged and continuing to pass the resulting host into `Rails.application.routes.url_helpers.cdn_image_url`.
- [ ] Add a private `required_asset_host` method in `lib/map_tiles/geojson_exporter.rb` that returns `Rails.application.config.asset_host.presence` or raises `MissingAssetHostError, ASSET_HOST_REQUIRED_MESSAGE`; do not call this method from `export`, `write_layer`, or any no-photo path, so records without attached cover/topo photos do not require `asset_host`.
- [ ] In `test/lib/map_tiles/geojson_exporter_test.rb`, save the previous `Rails.application.config.asset_host` in `setup`, set `Rails.application.config.asset_host = "https://assets.example.test"` for normal exporter tests, and restore the saved value in `teardown` after removing `@output_dir`.
- [ ] Update the deterministic cover photo URL test to assert every exported `coverPhotoUrl` is stable, uses `https://assets.example.test`, includes `/rails/active_storage/representations/proxy/`, and does not include `localhost`; keep the main-area-to-cluster-to-region fallback assertions and the post-purge no-photo assertions.
- [ ] Update the topo preview URL test to assert `topoPhotoUrl` uses `https://assets.example.test`, includes `/rails/active_storage/representations/proxy/`, and does not include `localhost`; keep the line coordinate JSON assertions and the no-line/no-photo assertions.
- [ ] Add a test that sets `Rails.application.config.asset_host = nil` with the default fixture records that have no attached cover/topo photos, runs `MapTiles::GeojsonExporter.new(configuration: @configuration).export`, and asserts representative area/problem properties omit `coverPhotoUrl` and `topoPhotoUrl`.
- [ ] Add a blank-host cover-photo failure test that attaches `@area.cover`, sets `Rails.application.config.asset_host = ""`, calls `MapTiles::GeojsonExporter.new(configuration: @configuration).export`, and asserts `MapTiles::GeojsonExporter::MissingAssetHostError` is raised with `ASSET_HOST_REQUIRED_MESSAGE`.
- [ ] Add a blank-host topo-photo failure test that creates a published `Topo` with an attached photo, creates a `Line` for `@problem`, sets `Rails.application.config.asset_host = nil`, calls `MapTiles::GeojsonExporter.new(configuration: @configuration).export`, and asserts `MapTiles::GeojsonExporter::MissingAssetHostError` is raised with `ASSET_HOST_REQUIRED_MESSAGE`.
- [ ] Run a static check that `lib/map_tiles/geojson_exporter.rb` no longer contains `localhost` or `http://localhost:3000`, then run the Docker-backed targeted exporter tests.
- [ ] Update this plan’s Status block with fresh gate evidence, set `.incant/backlog.md` to `status:review phase:0013-P1`, update `.incant/STATE.md` to say item `0013` is awaiting review, and commit the implementation phase as `incant 0013-P1: require asset host for photo URLs`.
**Quality gate:** `bash -lc '! rg -n "localhost|http://localhost:3000" lib/map_tiles/geojson_exporter.rb && docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test -e BUNNY_STORAGE_SECRET_ACCESS_KEY=test-secret web bin/rails test test/lib/map_tiles/geojson_exporter_test.rb'` → static check finds no localhost fallback in the exporter; the targeted GeoJSON exporter test suite passes with 0 failures and 0 errors.

## Coverage self-review
- Requirement 1 → Phase 0013-P1 removes the hardcoded localhost fallback from `cdn_variant_url` and the quality gate searches the exporter for `localhost` and `http://localhost:3000`.
- Requirement 2 → Phase 0013-P1 adds `MissingAssetHostError`, `ASSET_HOST_REQUIRED_MESSAGE`, `required_asset_host`, and separate blank-host cover/topo failure tests.
- Requirement 3 → Phase 0013-P1 keeps `cdn_image_url`, keeps `expires_in: nil`, sets `https://assets.example.test` in tests, and asserts cover/topo URLs use that host rather than localhost.
- Requirement 4 → Phase 0013-P1 adds explicit blank-host/no-attachment export coverage and keeps post-purge no-photo assertions.
- Requirement 5 → Phase 0013-P1 raises from the exporter itself, so existing CLI/publish paths that invoke export fail through their existing exception handling rather than publishing a bad artifact.
- Requirement 6 → Phase 0013-P1 extends `test/lib/map_tiles/geojson_exporter_test.rb` with both blank-host failure tests and configured-host success assertions.
- Acceptance criteria → The phase steps and quality gate cover every listed acceptance criterion, including the targeted exporter test command inside Docker.
- Symbol/signature consistency checked: the plan uses `MapTiles::GeojsonExporter::MissingAssetHostError`, `ASSET_HOST_REQUIRED_MESSAGE`, `required_asset_host`, `coverPhotoUrl`, `topoPhotoUrl`, `cdn_variant_url`, and `expires_in: nil` consistently.
- No placeholders remain in this plan.

## Phase handoff
- Phase 0013-P1 is ready for human approval.
- Next after approval: `/incant:implement 0013`.
