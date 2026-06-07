---
id: "0004"
slug: pmtiles-overlay-contract
branch: incant/0004-pmtiles-overlay-contract
title: Austrian Rocks PMTiles Overlay Contract And Bunny Delivery
stage: plan
status: in-progress
created: 2026-06-06
commit: 1bf0c5ca
updated: 2026-06-07
---

# Plan — Austrian Rocks PMTiles Overlay Contract And Bunny Delivery

## Status
- Phase: planning complete; awaiting human approval before implementation.
- Stage: plan.
- Branch: `incant/0004-pmtiles-overlay-contract`.
- Next step: after plan approval, ensure the branch includes completed `0007` changes, then run `/incant:implement 0004` and begin `0004-P1`.
- Blockers: none; `0007` is complete, but implementation should be on top of its final merged changes.
- Key decisions:
  - Build a new `MapTiles` subsystem in `lib/map_tiles/` instead of extending the Mapbox-era rake task.
  - Keep generated GeoJSON and PMTiles under `tmp/map_tiles/`; never rely on `public/maps/austrian-rocks.pmtiles`.
  - Use Tippecanoe for PMTiles generation with native max zoom `16` and use smoke checks over both the exported GeoJSON contract data and the built PMTiles metadata.
  - Reuse Bunny S3-compatible credentials while keeping map tile CDN host, object prefix, and version/latest naming in map-specific environment-backed config.

## Files touched
- `.incant/work/0004-pmtiles-overlay-contract/contract.md` — committed consumer/maintainer contract for source layers, properties, zoom, style-layer expectations, and Bunny URL/versioning rules while `/docs/` stays gitignored.
- `lib/map_tiles/configuration.rb` — map-specific configuration for build output, public CDN host, Bunny prefix, object names, version strings, and expected layers.
- `lib/map_tiles/layer_contract.rb` — canonical layer/property definitions shared by contract checks, exporter, and smoke checks.
- `lib/map_tiles/geojson_exporter.rb` — exports deterministic per-layer GeoJSON FeatureCollections from Rails/PostGIS data.
- `lib/map_tiles/tippecanoe_builder.rb` — checks Tippecanoe availability, builds one PMTiles archive, and emits clear install guidance when missing.
- `lib/map_tiles/smoke_check.rb` — verifies artifact existence, expected layers/properties, counts, bounds, and relaxed-vs-production count rules.
- `lib/map_tiles/bunny_publisher.rb` — uploads immutable versioned and stable latest PMTiles objects through Bunny S3-compatible storage and verifies HTTP `HEAD` reachability.
- `lib/map_tiles/cli.rb` — small command entrypoint used by binstub/rake tasks for export, build, smoke, and publish modes.
- `bin/build_pmtiles` — executable wrapper for full build/smoke/publish workflows.
- `lib/tasks/map_tiles.rake` — Rails tasks that call the same entrypoint for CI/operator use.
- `test/lib/map_tiles/layer_contract_test.rb` — verifies expected layer names, geometry types, native max zoom, camelCase properties, and circuit exclusion.
- `test/lib/map_tiles/geojson_exporter_test.rb` — fixture-backed exporter tests for required properties, localized names, POI route metadata JSON string, and no canonical URLs.
- `test/lib/map_tiles/tippecanoe_builder_test.rb` — tests missing-Tippecanoe failure messaging and command construction without invoking the binary.
- `test/lib/map_tiles/smoke_check_test.rb` — tests strict production counts, relaxed zero-feature mode, property checks, bounds checks, and artifact non-empty failures.
- `test/lib/map_tiles/bunny_publisher_test.rb` — tests object key construction, version/latest uploads, credential handling, and HTTP `HEAD` verification through fakes.
- `.incant/backlog.md` — keep item `0004` at `status:plan` after removing the stale `0007` blocker.
- `.incant/STATE.md` — update current focus to the unblocked plan stage.
- `.incant/work/0004-pmtiles-overlay-contract/plan.md` — this implementation plan.

## Phase 0004-P1 — contract and source alignment
Goal: land the committed PMTiles contract artifact outside `/docs/` and document source assumptions against the database and walking-path foundations delivered by completed item `0007`.

- [ ] Confirm the implementation branch contains completed `0007` changes (`WalkingPath`, optional `problems.boulder_id`, corrected POI associations, and relationship foreign keys) before editing exporter code.
- [ ] Read `db/schema.rb`, `app/models/application_record.rb`, `app/models/problem.rb`, `app/models/boulder.rb`, `app/models/walking_path.rb`, `app/models/area.rb`, `app/models/cluster.rb`, `app/models/region.rb`, `app/models/poi.rb`, `app/models/poi_route.rb`, and `lib/tasks/mapbox.rake` before editing.
- [ ] Add `.incant/work/0004-pmtiles-overlay-contract/contract.md` documenting native max zoom `16`, the difference between PMTiles source layers and later MapLibre style layers, no circuit layers/properties, no app-local canonical URLs, Bunny public URL rules, immutable/latest object names, and all ten source layers: `problems`, `boulders`, `areas`, `area_hulls`, `clusters`, `cluster_hulls`, `regions`, `region_hulls`, `walking_paths`, and `pois`.
- [ ] In `.incant/work/0004-pmtiles-overlay-contract/contract.md`, document for every source layer its geometry type, required properties, optional properties, stable identifier property, localized `name`/optional `nameEn` rule, and consumer navigation guidance from IDs/slugs.
- [ ] In `.incant/work/0004-pmtiles-overlay-contract/contract.md`, document that `problems` may include `boulderId` from the `0007` relationship cleanup, and that `walking_paths` reads published line geometry from the `WalkingPath` model delivered by `0007`.
- [ ] In `.incant/work/0004-pmtiles-overlay-contract/contract.md`, document `pois.accessAreasJson` as a scalar JSON string derived from `poi_routes`, with entries containing `areaId`, `areaSlug`, `transport`, `distance`, and `minutes`, and explicitly state that it is metadata rather than route geometry.

**Quality gate:** `test -f .incant/work/0004-pmtiles-overlay-contract/contract.md && grep -q "walking_paths" .incant/work/0004-pmtiles-overlay-contract/contract.md && grep -q "native max zoom" .incant/work/0004-pmtiles-overlay-contract/contract.md` → the committed contract artifact exists and covers walking paths plus native zoom before exporter code starts.

## Phase 0004-P2 — deterministic GeoJSON export and Tippecanoe build
Goal: generate contract-aligned intermediate GeoJSON and build a single PMTiles artifact with Tippecanoe.

- [ ] Read `config/application.rb`, `Gemfile`, `lib/tasks/mapbox.rake`, `app/models/problem.rb`, `app/models/boulder.rb`, `app/models/area.rb`, `app/models/cluster.rb`, `app/models/region.rb`, `app/models/poi.rb`, `app/models/poi_route.rb`, and `app/models/walking_path.rb` before editing.
- [ ] Add `lib/map_tiles/layer_contract.rb` defining the ten expected layers, geometry type, required and optional camelCase properties, native max zoom `16`, and helper methods that reject layer/property names containing `circuit`.
- [ ] Add `lib/map_tiles/configuration.rb` reading `MAP_TILES_OUTPUT_DIR` with default `tmp/map_tiles`, `MAP_TILES_PUBLIC_CDN_HOST`, `MAP_TILES_BUNNY_PREFIX`, `MAP_TILES_VERSION`, and fixed artifact basename `austrian-rocks`; expose `versioned_object_key` and `latest_object_key` as `<prefix>/austrian-rocks-<version>.pmtiles` and `<prefix>/austrian-rocks-latest.pmtiles`.
- [ ] Add `lib/map_tiles/geojson_exporter.rb` that writes one deterministic GeoJSON FeatureCollection per source layer under `tmp/map_tiles/geojson`, orders features by stable IDs, transforms properties to camelCase, and exports only published/consumer-safe data.
- [ ] Implement `problems` point export from published areas with required `problemId`, `areaId`, `areaSlug`, `name`, `grade`, `steepness`, `featured`, and optional `boulderId`, `nameEn`, `popularity`, `landing`, `height`, `parentProblemId`.
- [ ] Implement `boulders` polygon export from boulders in published areas, excluding `ignore_for_area_hull` only from hull calculations rather than from boulder polygons, with required `boulderId`, `areaId`, `areaSlug` and optional `name`.
- [ ] Implement `areas` point and `area_hulls` polygon exports from published areas with stable IDs/slugs, localized labels, priority, bounds, and hull geometries derived from non-ignored boulders.
- [ ] Implement `clusters` point and `cluster_hulls` polygon exports from published clusters with labels, slugs, region relationship fields where present, bounds, and hull geometries derived from published child areas' non-ignored boulders.
- [ ] Implement `regions` point and `region_hulls` polygon exports from published regions with labels, slugs, bounds, and hull geometries derived from published descendant clusters/areas.
- [ ] Implement `walking_paths` LineString/MultiLineString export from `WalkingPath.published` with required `walkingPathId`, `slug`, `name`, optional `nameEn`, and optional `description`.
- [ ] Implement `pois` point export from POIs with locations, required `poiId`, `poiType`, `name`, `accessAreasJson`, optional `shortName`, `googleUrl`, and no app-local canonical URL properties.
- [ ] Add `lib/map_tiles/tippecanoe_builder.rb` that verifies `tippecanoe` is available, fails with Homebrew and project install guidance when missing, and runs Tippecanoe with `--force`, `--output-to-directory` disabled, `--maximum-zoom=16`, `--minimum-zoom=0`, `--no-tile-compression` only if required by tests, one `--named-layer=<layer>:<path>` per GeoJSON file, and output `tmp/map_tiles/austrian-rocks-<version>.pmtiles`.
- [ ] Add `bin/build_pmtiles` and `lib/tasks/map_tiles.rake` commands for `export`, `build`, `smoke`, and `publish`, all delegating to `MapTiles::CLI` with the same options and environment variables.
- [ ] Add `test/lib/map_tiles/layer_contract_test.rb`, `test/lib/map_tiles/geojson_exporter_test.rb`, and `test/lib/map_tiles/tippecanoe_builder_test.rb` covering layer names/properties, fixture exports, POI metadata JSON string shape, no circuit fields, no canonical URLs, output paths, and missing-Tippecanoe errors.

**Quality gate:** `bin/rails test test/lib/map_tiles/layer_contract_test.rb test/lib/map_tiles/geojson_exporter_test.rb test/lib/map_tiles/tippecanoe_builder_test.rb` → all contract/export/build tests pass without requiring Tippecanoe to be installed except in explicitly skipped integration assertions.

## Phase 0004-P3 — smoke checks for local relaxed mode and production strict mode
Goal: prove generated artifacts match the contract and fail clearly when the artifact or data is unsuitable.

- [ ] Read `lib/map_tiles/layer_contract.rb`, `lib/map_tiles/configuration.rb`, `lib/map_tiles/geojson_exporter.rb`, `lib/map_tiles/tippecanoe_builder.rb`, and `bin/build_pmtiles` before editing.
- [ ] Add `lib/map_tiles/smoke_check.rb` that verifies the PMTiles file exists, is non-empty, and has metadata exposing exactly the expected source layers and field names from `LayerContract`.
- [ ] In `SmokeCheck`, inspect the exported GeoJSON layer files used to build the archive and verify required properties on sampled features, scalar-only vector-tile-safe property values, no circuit fields, and no app-local canonical URL fields.
- [ ] In `SmokeCheck`, calculate combined feature bounds and fail outside sane Austria-area bounds of longitude `9.0..17.5` and latitude `46.0..49.5`, while allowing empty fixture layers only in relaxed mode.
- [ ] In `SmokeCheck`, implement strict production/export mode that fails when any expected layer has zero features, and relaxed mode that accepts a caller-specified comma-separated list of zero-feature layers while still requiring all layer files and properties to exist when features are present.
- [ ] Wire `bin/build_pmtiles smoke --mode=relaxed --allow-empty=...` and `bin/build_pmtiles smoke --mode=production` to the same smoke-check implementation and print layer counts, bounds, missing fields, and actionable failures.
- [ ] Add `test/lib/map_tiles/smoke_check_test.rb` covering non-empty artifact requirement, expected layer metadata, required property sampling, Austria bounds failures, strict zero-feature failures, relaxed allowed empty layers, and rejection of unexpected circuit fields.

**Quality gate:** `bin/rails test test/lib/map_tiles/smoke_check_test.rb` → all smoke-check tests pass using fixture GeoJSON/PMTiles metadata fixtures and no network access.

## Phase 0004-P4 — Bunny publication, end-to-end contract notes, and release gates
Goal: publish both immutable and latest artifacts to Bunny/CDN, verify reachability, and prove all acceptance criteria are covered.

- [ ] Read `config/storage.yml`, `lib/map_tiles/configuration.rb`, `lib/map_tiles/tippecanoe_builder.rb`, and `lib/map_tiles/smoke_check.rb` before editing.
- [ ] Add `lib/map_tiles/bunny_publisher.rb` that reuses `BUNNY_STORAGE_ENDPOINT`, `BUNNY_STORAGE_REGION`, `BUNNY_STORAGE_BUCKET`, `BUNNY_STORAGE_ACCESS_KEY_ID`, and `BUNNY_STORAGE_SECRET_ACCESS_KEY` for S3-compatible upload, while requiring map-specific `MAP_TILES_PUBLIC_CDN_HOST`, `MAP_TILES_BUNNY_PREFIX`, and `MAP_TILES_VERSION` for publication.
- [ ] In `BunnyPublisher`, construct object keys only from sanitized config values and fixed artifact naming, upload `austrian-rocks-<version>.pmtiles` and `austrian-rocks-latest.pmtiles`, set an appropriate PMTiles content type such as `application/octet-stream`, and never log credentials.
- [ ] In `BunnyPublisher`, verify both versioned and latest public URLs with HTTP `HEAD`, requiring a 2xx status and reporting the exact URL/status for failures.
- [ ] Wire `bin/build_pmtiles publish` and `rails map_tiles:publish` so they run production smoke checks before upload unless `MAP_TILES_SKIP_SMOKE` is explicitly false-by-default and documented as only for emergency operator use.
- [ ] Update `.incant/work/0004-pmtiles-overlay-contract/contract.md` with maintainer commands for local relaxed export/build/smoke, production export/build/smoke/publish, required environment variables, Tippecanoe install guidance, Bunny external setup notes, generated artifact ignore policy, and a note that `/docs/` remains gitignored for now.
- [ ] Add `test/lib/map_tiles/bunny_publisher_test.rb` covering required configuration failures, object key construction, dual upload calls, latest overwrite behavior, successful HEAD checks, failed HEAD checks, and no credential leakage in errors.
- [ ] Run a coverage self-review against this plan and update `.incant/work/0004-pmtiles-overlay-contract/contract.md` or tests if any spec requirement lacks an implementation or gate.
- [ ] Run the final verification commands and paste the fresh outputs into the implementation status before review: targeted map tile tests, `bin/rails test`, `bin/rubocop`, and `bin/brakeman --no-pager`.

**Quality gate:** `bin/rails test test/lib/map_tiles/bunny_publisher_test.rb && bin/rails test && bin/rubocop && bin/brakeman --no-pager` → all tests, lint, and security checks pass locally with Bunny network calls faked in tests.

## Coverage self-review
- [x] Requirement 1 maps to P1 committed contract steps and P2 `LayerContract` tests.
- [x] Requirement 2 maps to P1 contract and P2 exporter/build steps for all ten layers.
- [x] Requirement 3 maps to P1 source-alignment documentation and P2 exporter consumption of `0007`-delivered models/relationships.
- [x] Requirement 4 maps to P1 contract, P2 `LayerContract`, and exporter camelCase transformation tests.
- [x] Requirement 5 maps to P1 contract and P2 exporter tests for stable IDs/slugs and no canonical URLs.
- [x] Requirement 6 maps to P1 contract and P2 localized `name`/`nameEn` exporter tests.
- [x] Requirement 7 maps to P1 POI metadata documentation and P2 `pois.accessAreasJson` exporter tests.
- [x] Requirement 8 maps to P1 source-layer/style-layer distinction contract notes.
- [x] Requirement 9 maps to P1 contract plus P2/P3 circuit exclusion tests.
- [x] Requirement 10 maps to P1 contract, P2 `LayerContract`, and Tippecanoe command tests.
- [x] Requirement 11 maps to P2 Tippecanoe builder and missing-binary tests.
- [x] Requirement 12 maps to P2 output paths, existing ignored build locations, and P4 contract notes.
- [x] Requirement 13 maps to P4 `BunnyPublisher` upload/key tests.
- [x] Requirement 14 maps to P2/P4 configuration steps and tests.
- [x] Requirement 15 maps to P3 smoke-check implementation and tests.
- [x] Requirement 16 maps to P3 relaxed/production mode steps and tests.
- [x] Requirement 17 maps to P4 dual upload and HTTP `HEAD` verification tests.
- [x] Acceptance criteria map to phases P1–P4 and the final quality gate.
- [x] Symbol/signature consistency checked: `LayerContract`, `Configuration`, `GeojsonExporter`, `TippecanoeBuilder`, `SmokeCheck`, `BunnyPublisher`, and `MapTiles::CLI` are used consistently.
- [x] No incomplete or template-only entries remain in this plan.

## Human approval checkpoint
This plan is ready for human review. No implementation code should be changed until the human approves this plan and starts `/incant:implement 0004`.
