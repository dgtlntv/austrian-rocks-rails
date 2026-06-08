---
id: "0008"
slug: pmtiles-e2e-docker-config
branch: incant/0008-pmtiles-e2e-docker-config
title: Make PMTiles E2E Publish-Ready With Dockerized Felt Tippecanoe And Rails Config
stage: plan
status: in-progress
created: 2026-06-08
commit: 0fbd9115
updated: 2026-06-08
---

# Make PMTiles E2E Publish-Ready With Dockerized Felt Tippecanoe And Rails Config — plan

## Status
- Phase: planning complete; awaiting human approval before implementation
- Stage: plan
- Branch: incant/0008-pmtiles-e2e-docker-config
- Next: human approves this plan, then run `/incant:implement 0008`
- Blockers: none
- Key decisions:
  - Stable non-secret PMTiles settings move to `config/map_tiles.yml`; Bunny credentials remain environment secrets.
  - Artifact version is a per-command argument and is sanitized before artifact paths or Bunny object keys are built.
  - `pois` is the only optional production layer; `walking_paths` and all core map layers remain required.
  - Felt Tippecanoe is pinned at `2.79.0` and built inside both dev and production images.

## Spec freshness check
- `spec.md` records base commit `492e9b80`; current `HEAD` is `0fbd9115`.
- `git diff --name-only 492e9b80..HEAD` shows only `.incant/` planning/spec artifacts, so the PMTiles code, tests, Dockerfiles, and config files mapped below have not drifted since the spec was written.

## Files touched

### Tracked application files
- `config/map_tiles.yml` (new) — environment-specific stable PMTiles config for artifact basename, output dir, CDN host, Bunny prefix, and optional production layers.
- `lib/map_tiles/configuration.rb` (edit) — load Rails map tile config, accept explicit sanitized versions, expose optional production layers, and stop supporting non-secret `MAP_TILES_*` inputs.
- `lib/map_tiles/cli.rb` (edit) — parse required `--version` for build/smoke/publish and explicit `--skip-smoke` for publish.
- `lib/tasks/map_tiles.rake` (edit) — expose explicit Rails task arguments for version, smoke mode, allow-empty layers, and skip-smoke.
- `lib/map_tiles/bunny_publisher.rb` (edit) — use config-backed CDN host/prefix/version object keys while keeping only Bunny storage credentials in environment variables.
- `lib/map_tiles/smoke_check.rb` (edit) — permit configured optional production layers to be empty and absent from PMTiles metadata while keeping feature validation when data exists.
- `lib/map_tiles/tippecanoe_builder.rb` (edit) — update missing-binary guidance to Felt Tippecanoe and Dockerized availability.
- `Dockerfile.dev` (edit) — build and install Felt Tippecanoe `2.79.0` in the development web image.
- `Dockerfile` (edit) — build Felt Tippecanoe `2.79.0` in a throw-away stage and copy runtime binaries into the final production image.

### Tracked tests
- `test/lib/map_tiles/configuration_test.rb` (new) — cover Rails config loading, sanitized versions, optional layer config, and ignored legacy non-secret env overrides.
- `test/lib/map_tiles/cli_test.rb` (new) — cover command argument parsing, required versions, `export` without version, publish smoke default, and `--skip-smoke`.
- `test/lib/map_tiles/bunny_publisher_test.rb` (edit) — cover config-backed host/prefix and secret-only Bunny env requirements.
- `test/lib/map_tiles/smoke_check_test.rb` (edit) — cover zero-feature optional `pois`, required `walking_paths`, metadata omission, and dataful POI validation.
- `test/lib/map_tiles/tippecanoe_builder_test.rb` (edit) — cover updated Felt/Docker install guidance and explicit-version configuration.
- `test/lib/map_tiles/geojson_exporter_test.rb` (edit) — adjust PMTiles configuration construction after env-only output/version removal.

### Local ignored files
- `docs/map_tiles.md` (edit, ignored by `.gitignore`) — update the local operational runbook; verify it remains uncommitted.
- `tmp/map_tiles_e2e_publish.sh` (new if needed, ignored by `.gitignore`) — temporary local helper for production-dump Docker E2E; delete before review or leave ignored with no secrets and no tracked changes.

## Phase 0008-P1 — Rails config, explicit version arguments, and Bunny publication config
- [ ] Read `config/application.rb`, `lib/map_tiles/configuration.rb`, `lib/map_tiles/cli.rb`, `lib/tasks/map_tiles.rake`, `lib/map_tiles/bunny_publisher.rb`, `lib/map_tiles/tippecanoe_builder.rb`, `test/lib/map_tiles/bunny_publisher_test.rb`, `test/lib/map_tiles/tippecanoe_builder_test.rb`, and `test/lib/map_tiles/geojson_exporter_test.rb` before editing.
- [ ] Add `config/map_tiles.yml` with `default` values `artifact_basename: austrian-rocks`, `output_dir: tmp/map_tiles`, `public_cdn_host: assets.austrian.rocks`, and `bunny_prefix: map_tiles`; set `development.bunny_prefix: map_tiles/e2e`; set `test.bunny_prefix: map_tiles/test`; set `production.bunny_prefix: map_tiles`; set `production.optional_production_layers: [pois]`.
- [ ] Edit `lib/map_tiles/configuration.rb` so `Configuration.new(version: nil, env: ENV, settings: nil)` loads `Rails.application.config_for(:map_tiles)`, returns `output_dir`, `geojson_dir`, `artifact_basename`, `public_cdn_host`, `bunny_prefix`, and `optional_production_layers` from config, and keeps `env` only for Bunny secret lookups.
- [ ] In `lib/map_tiles/configuration.rb`, keep one safe path-segment sanitizer that accepts only letters, numbers, dots, underscores, and dashes; apply it to configured artifact basename, configured Bunny prefix segments, configured optional layer names, and the explicit version.
- [ ] In `lib/map_tiles/configuration.rb`, make artifact-specific methods (`version`, `artifact_path`, `metadata_path`, `versioned_object_key`, `latest_object_key`) raise `ArgumentError, "--version is required for build, smoke, and publish"` when no version was supplied, while `output_dir` and `geojson_dir` continue to work without a version for `export`.
- [ ] In `lib/map_tiles/configuration.rb`, add `with_version(version)` returning a same-settings configuration with the supplied version, and remove all support for `MAP_TILES_PUBLIC_CDN_HOST`, `MAP_TILES_BUNNY_PREFIX`, `MAP_TILES_OUTPUT_DIR`, and `MAP_TILES_VERSION`.
- [ ] Edit `lib/map_tiles/cli.rb` so `build`, `smoke`, and `publish` require `--version=2026-06-07` or `--version 2026-06-07` style arguments; `export` remains runnable as `bin/build_pmtiles export` without a version; unknown options fail with a clear usage message.
- [ ] Edit `lib/map_tiles/cli.rb` so `publish --version=2026-06-07` runs `SmokeCheck` with `--mode=production` before upload, and `publish --version=2026-06-07 --skip-smoke` is the only bypass; delete the `MAP_TILES_SKIP_SMOKE` lookup.
- [ ] Edit `lib/tasks/map_tiles.rake` to expose exact task forms: `bin/rails map_tiles:export`, `bin/rails "map_tiles:build[2026-06-07]"`, `bin/rails "map_tiles:smoke[2026-06-07,production,]"`, and `bin/rails "map_tiles:publish[2026-06-07,false]"`; translate those task arguments into the same CLI flags without reading map tile env vars.
- [ ] Edit `lib/map_tiles/bunny_publisher.rb` so validation requires only `BUNNY_STORAGE_ENDPOINT`, `BUNNY_STORAGE_REGION`, `BUNNY_STORAGE_BUCKET`, `BUNNY_STORAGE_ACCESS_KEY_ID`, and `BUNNY_STORAGE_SECRET_ACCESS_KEY` from `configuration.env`; validate config-backed CDN host, Bunny prefix, artifact basename, and version through `Configuration` without naming removed `MAP_TILES_*` knobs as required env vars.
- [ ] Add `test/lib/map_tiles/configuration_test.rb` covering YAML config defaults, development/test/production prefix differences through injectable settings, sanitized version values, rejected unsafe versions, unknown optional layer names, and legacy non-secret `MAP_TILES_*` env vars being ignored.
- [ ] Add `test/lib/map_tiles/cli_test.rb` with fakes for exporter, builder, smoke, and publisher so tests prove `export` does not require a version, `build`/`smoke`/`publish` do require one, unsafe versions fail, publish runs smoke by default, and `--skip-smoke` suppresses only the publish smoke call.
- [ ] Update `test/lib/map_tiles/bunny_publisher_test.rb`, `test/lib/map_tiles/tippecanoe_builder_test.rb`, and `test/lib/map_tiles/geojson_exporter_test.rb` to construct `MapTiles::Configuration` with explicit `version:` and injected `settings:` instead of `MAP_TILES_*` env values.
- [ ] Commit this phase as `incant 0008-P1: config-backed PMTiles commands` after the quality gate passes.
**Quality gate:** `docker compose run --rm web bin/rails test test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/cli_test.rb test/lib/map_tiles/bunny_publisher_test.rb test/lib/map_tiles/tippecanoe_builder_test.rb test/lib/map_tiles/geojson_exporter_test.rb` → all selected map tile configuration, command, publisher, builder, and exporter tests pass against Docker-hosted PostgreSQL/PostGIS.

## Phase 0008-P2 — optional production POI smoke semantics
- [ ] Read `lib/map_tiles/smoke_check.rb`, `lib/map_tiles/layer_contract.rb`, `test/lib/map_tiles/smoke_check_test.rb`, and the updated `config/map_tiles.yml` before editing.
- [ ] Edit `lib/map_tiles/smoke_check.rb` so GeoJSON layer inspection runs before metadata layer comparison, giving the metadata check the actual per-layer feature counts.
- [ ] Edit `lib/map_tiles/smoke_check.rb` so production mode treats `configuration.optional_production_layers` as allowed zero-feature layers; in this item the configured production optional layer set is exactly `pois`.
- [ ] Edit `lib/map_tiles/smoke_check.rb` so required layers with zero features still fail in production mode, including `problems`, `boulders`, `areas`, `area_hulls`, `clusters`, `cluster_hulls`, `regions`, `region_hulls`, and `walking_paths`.
- [ ] Edit `lib/map_tiles/smoke_check.rb` so PMTiles metadata layer comparison requires all required layers, allows an optional zero-feature `pois` layer to be absent or present, and requires a dataful optional `pois` layer to be present.
- [ ] Keep the existing metadata field validation and GeoJSON feature validation for every layer that exists or has features, so a dataful `pois.geojson` still validates geometry, required properties, scalar values, forbidden circuit fields, and forbidden app-local URL fields.
- [ ] Update `test/lib/map_tiles/smoke_check_test.rb` to prove production smoke passes with zero `pois` features and no `pois` PMTiles metadata layer, fails when `walking_paths` has zero features, fails when dataful `pois` has a contract violation, and still fails on required metadata/field mismatches for non-optional layers.
- [ ] Commit this phase as `incant 0008-P2: allow empty production POIs` after the quality gate passes.
**Quality gate:** `docker compose run --rm web bin/rails test test/lib/map_tiles/smoke_check_test.rb` → all smoke-check contract tests pass, including optional POI and required walking-path cases.

## Phase 0008-P3 — Dockerized Felt Tippecanoe, guidance, and E2E hygiene
- [ ] Read `Dockerfile.dev`, `Dockerfile`, `lib/map_tiles/tippecanoe_builder.rb`, `docs/map_tiles.md`, `.gitignore`, and `.dockerignore` before editing.
- [ ] Edit `Dockerfile.dev` to define `ARG TIPPECANOE_VERSION=2.79.0`, install the minimal Felt Tippecanoe build dependencies (`build-essential`, `git`, `ca-certificates`, `libsqlite3-dev`, `zlib1g-dev` in addition to existing dev packages), clone `https://github.com/felt/tippecanoe` with `--depth 1 --branch "$TIPPECANOE_VERSION"`, run `make -j"$(nproc)"`, run `make install`, and remove `/tmp/tippecanoe` plus apt caches.
- [ ] Edit `Dockerfile` to add a throw-away `tippecanoe` build stage with `ARG TIPPECANOE_VERSION=2.79.0`, Felt clone/build/install commands, and minimal build dependencies; copy `/usr/local/bin/tippecanoe`, `/usr/local/bin/tippecanoe-decode`, and `/usr/local/bin/tile-join` from that stage into the final runtime image.
- [ ] Keep production Tippecanoe compiler/build dependencies out of the final image by installing them only in the `tippecanoe` stage; rely on final-image runtime libraries already present in the Ruby slim base and app package set.
- [ ] Edit `lib/map_tiles/tippecanoe_builder.rb` so missing-binary guidance names Felt Tippecanoe, links `https://github.com/felt/tippecanoe`, says project Docker images include Tippecanoe, keeps `brew install tippecanoe` as non-Docker macOS guidance, and no longer links the legacy Mapbox repository.
- [ ] Edit ignored `docs/map_tiles.md` to document `config/map_tiles.yml`, explicit `--version`, `publish --skip-smoke`, optional production `pois`, required `walking_paths`, Dockerized Felt Tippecanoe `2.79.0`, Bunny credentials from `.kamal/secrets`/shell env, and the strict local Docker production-dump E2E sequence.
- [ ] If credentials and `tmp/db/production.dump` are available during implementation, create ignored `tmp/map_tiles_e2e_publish.sh` that restores the dump into the Docker Compose PostGIS database, runs migrations in the web container, sources `.kamal/secrets` without echoing secret values, and runs `bin/build_pmtiles build --version=e2e-0008`, `bin/build_pmtiles smoke --version=e2e-0008 --mode=production`, and `bin/build_pmtiles publish --version=e2e-0008` using the development Bunny prefix `map_tiles/e2e`; do not commit this helper.
- [ ] Verify no generated PMTiles, GeoJSON, downloaded artifacts, secrets, or temporary helper scripts are tracked with `git status --short --ignored tmp docs`; only ignored `docs/map_tiles.md` may remain locally changed outside the commit.
- [ ] Commit tracked Dockerfile and guidance changes as `incant 0008-P3: dockerize Felt Tippecanoe` after the quality gate passes; leave `docs/map_tiles.md` and any `tmp/` helper uncommitted because they are ignored local operational artifacts.
**Quality gate:** `docker compose run --rm web bin/rails test test/lib/map_tiles && docker compose run --rm web bin/rubocop && docker compose build web && docker compose run --rm web sh -lc 'tippecanoe --version && command -v tippecanoe-decode && command -v tile-join' && docker build -t austrian-rocks:0008-tippecanoe . && docker run --rm --entrypoint sh austrian-rocks:0008-tippecanoe -lc 'tippecanoe --version && command -v tippecanoe-decode && command -v tile-join'` → all map tile tests and RuboCop pass in Docker, the dev image reports Felt Tippecanoe, and the production image reports Felt Tippecanoe with inspection binaries available.

## Coverage self-review
- Requirement 1 → Phase 0008-P1 (`config/map_tiles.yml`).
- Requirement 2 → Phase 0008-P1 (`Configuration` removes non-secret env overrides).
- Requirement 3 → Phase 0008-P1 (`BunnyPublisher` keeps only Bunny credential env vars).
- Requirement 4 → Phase 0008-P1 (`--version` required for build/smoke/publish; export remains versionless).
- Requirement 5 → Phase 0008-P1 (safe path-segment sanitizer for explicit version).
- Requirement 6 → Phase 0008-P1 (`publish --skip-smoke` replaces `MAP_TILES_SKIP_SMOKE`).
- Requirement 7 → Phase 0008-P1 (Rails task arguments mirror CLI version and smoke options).
- Requirement 8 → Phase 0008-P2 (zero-feature production `pois` passes and may be absent from metadata).
- Requirement 9 → Phase 0008-P2 (all other production layers, especially `walking_paths`, remain required).
- Requirement 10 → Phase 0008-P2 (dataful `pois` still uses full feature and metadata validation).
- Requirement 11 → Phase 0008-P3 (Felt Tippecanoe `2.79.0` source in both Dockerfiles).
- Requirement 12 → Phase 0008-P3 (`tippecanoe`, `tippecanoe-decode`, and `tile-join` availability checks).
- Requirement 13 → Phase 0008-P3 (production throw-away Tippecanoe build stage).
- Requirement 14 → Phase 0008-P3 (missing-binary guidance and local docs updates).
- Requirement 15 → Phase 0008-P3 (temporary ignored E2E helper path and no-secret hygiene).
- Requirement 16 → Phase 0008-P3 (plan excludes UI button, triggers, scheduler, deploy hook, CI publish job, and permanent E2E script).
- Symbol and signature consistency checked: `Configuration.new(version:, env:, settings:)`, `Configuration#with_version`, CLI `--version`, CLI `--skip-smoke`, task args `[version, mode, allow_empty]`, task args `[version, skip_smoke]`, and `configuration.optional_production_layers` are used consistently across phases.
- Goal-level verification checked: final Phase 0008-P3 gate reruns all map tile tests, RuboCop, and both Docker image Tippecanoe availability checks.
- No generated PMTiles, GeoJSON, downloaded artifacts, secrets, or temporary helpers are planned for commit.
