---
id: "0008"
slug: pmtiles-e2e-docker-config
branch: incant/0008-pmtiles-e2e-docker-config
title: Make PMTiles E2E Publish-Ready With Dockerized Felt Tippecanoe And Rails Config
stage: spec
status: in-progress
created: 2026-06-08
commit: 492e9b80
updated: 2026-06-08
---

# Make PMTiles E2E Publish-Ready With Dockerized Felt Tippecanoe And Rails Config

## Goal
Make the PMTiles build/publish pipeline from item `0004` strict-E2E-testable in Docker against the local production dump, without dummy POIs, host PostgreSQL, or env-only non-secret map configuration.

## Context & codebase fit
Item `0004` added the PMTiles pipeline in `lib/map_tiles/`: `Configuration` currently reads map tile output, Bunny prefix, CDN host, and artifact version from `MAP_TILES_*` environment variables; `CLI` exposes `bin/build_pmtiles` commands; `SmokeCheck` requires every expected layer to have non-zero features in production mode; `BunnyPublisher` requires map tile publication env vars plus Bunny S3-compatible credentials.

The current local production dump at `tmp/db/production.dump` matches the current deployed data shape closely, but it predates item `0007`'s `walking_paths` table and contains no `pois` or `poi_routes`. That makes the existing strict smoke gate unsuitable for realistic E2E testing: walking paths should be added through the UI after migrations, while POIs should not need dummy data just to publish map tiles.

Docker is already the project's intended database boundary for map-data work: `docker-compose.yml` runs `austrian-rocks-db` from `postgis/postgis:16-3.5` and the dev web image from `Dockerfile.dev`. The production image in `Dockerfile` is used by Kamal. Neither image currently installs Tippecanoe, so real Docker E2E and production operation depend on a binary that is not present in the app container.

The maintained Tippecanoe source is Felt's repository at `https://github.com/felt/tippecanoe`; this work must not use the legacy Mapbox repository. Felt tags include `2.79.0`, which will be pinned for reproducible Docker builds.

A separate future inbox item covers operator-triggered or automated UI/background publishing. This item is only about making the existing CLI pipeline correctly configured, Docker-capable, and E2E-testable.

## Requirements
1. Add tracked Rails map tile configuration at `config/map_tiles.yml` for non-secret stable values: artifact basename `austrian-rocks`, output directory `tmp/map_tiles`, public CDN host `tiles.austrian.rocks`, development Bunny prefix `map_tiles/e2e`, production Bunny prefix `map_tiles`, and optional production layers containing only `pois`.
2. Remove env-only configuration for non-secret map tile values. `MAP_TILES_PUBLIC_CDN_HOST`, `MAP_TILES_BUNNY_PREFIX`, and `MAP_TILES_OUTPUT_DIR` must no longer be used as supported overrides by `MapTiles::Configuration`.
3. Keep Bunny S3-compatible credentials as secrets read from the existing `BUNNY_STORAGE_ENDPOINT`, `BUNNY_STORAGE_REGION`, `BUNNY_STORAGE_BUCKET`, `BUNNY_STORAGE_ACCESS_KEY_ID`, and `BUNNY_STORAGE_SECRET_ACCESS_KEY` environment variables supplied by Kamal/1Password or local shell secret loading.
4. Replace `MAP_TILES_VERSION` with an explicit per-run version argument. `bin/build_pmtiles build`, `bin/build_pmtiles smoke`, and `bin/build_pmtiles publish` must require `--version=<value>`; `bin/build_pmtiles export` must remain runnable without a version because it only writes GeoJSON.
5. Sanitize the explicit version argument with the same safe path-segment rule as before: only letters, numbers, dots, underscores, and dashes are allowed.
6. Replace `MAP_TILES_SKIP_SMOKE` with an explicit publish flag, `bin/build_pmtiles publish --version=<value> --skip-smoke`; publishing without `--skip-smoke` must run production smoke first.
7. Preserve Rails task access without reintroducing env-based versioning. Tasks that operate on an artifact must accept explicit task arguments equivalent to the CLI version and smoke options, for example a version argument for build/smoke/publish and a skip-smoke argument for publish.
8. Make `pois` optional in production smoke. A zero-feature `pois.geojson` must pass production mode, and PMTiles metadata may omit `pois` when the GeoJSON layer is empty.
9. Keep every other expected PMTiles source layer required in production smoke, especially `walking_paths`; zero features in `problems`, `boulders`, `areas`, `area_hulls`, `clusters`, `cluster_hulls`, `regions`, `region_hulls`, or `walking_paths` must still fail production mode.
10. Continue validating optional production layers when data exists. If `pois` has features, smoke checks must validate its geometry, required properties, scalar property values, forbidden circuit fields, and forbidden app-local URL fields.
11. Build Felt Tippecanoe from `https://github.com/felt/tippecanoe` at pinned ref `2.79.0` in both `Dockerfile.dev` and `Dockerfile`; do not use the Mapbox repository.
12. Install Tippecanoe binaries into both dev and production app images so `tippecanoe --version` works in the dev web container and in the final production image. Include `tippecanoe-decode` and `tile-join` if the Felt build produces them, because they are useful operational inspection tools.
13. Keep production image build dependencies out of the final runtime image as far as practical by using a build stage for Tippecanoe and copying only the installed binaries/runtime needs into the final stage.
14. Update missing-Tippecanoe error guidance and maintainer documentation to reference Felt Tippecanoe, Dockerized availability, explicit `--version`, Rails config, optional POIs, and the removal of map tile non-secret env knobs.
15. During implementation, a temporary ignored local E2E helper may be created under `tmp/` to restore `tmp/db/production.dump` into Docker PostGIS, run migrations, source `.kamal/secrets` for Bunny credentials, and run strict build/smoke/publish. This helper must not be committed.
16. Do not implement an admin UI button, data-change trigger, scheduler, deploy hook, CI publish job, or permanent E2E script in this item; those belong to the separate automation follow-up.
17. Keep production server disk usage bounded by pruning old local generated PMTiles artifacts and metadata after successful publish. Cleanup must be local-only, must keep the just-published artifact, must not delete GeoJSON needed by the current run before smoke/publish completes, and must not delete remote Bunny objects.

## In scope / Out of scope
**In scope:**
- Rails config for stable non-secret PMTiles settings.
- Explicit version/skip-smoke CLI and Rails task arguments.
- Optional production `pois` smoke semantics while keeping `walking_paths` and all core map layers required.
- Felt Tippecanoe `2.79.0` in development and production Docker images.
- Tests for configuration loading, CLI argument behavior, Bunny publication configuration, optional-layer smoke semantics, exporter contract compliance, and local artifact cleanup.
- Updating the ignored local contract `docs/map_tiles.md` during implementation; `/docs/` remains gitignored and the docs artifact remains uncommitted.
- A temporary ignored local E2E helper under `tmp/` for this testing effort only.

**Out of scope:**
- Admin UI or background-job triggering for PMTiles builds — reason: captured as a separate inbox item for a later product workflow.
- Adding dummy POIs or POI routes to production-like data — reason: production currently has none and the contract should reflect that reality.
- Changing `WalkingPath` schema/admin UI — reason: delivered by item `0007`; this item only requires the migrated schema to be usable in Docker E2E.
- Real production Bunny publication from this branch — reason: E2E should use development config prefix `map_tiles/e2e` until the human intentionally performs a production publish.
- Committing generated PMTiles, GeoJSON, downloaded PMTiles, or the temporary E2E helper — reason: these are build/test artifacts.

## Approach
Move stable PMTiles settings into `config/map_tiles.yml` and make `MapTiles::Configuration` load environment-specific Rails config rather than `MAP_TILES_*` env values. Treat artifact version as a runtime command argument, passed into `Configuration` from the CLI or Rails tasks, because it identifies a single generated artifact rather than describing application environment. Keep Bunny credentials in environment variables because they are secrets and already fit the Kamal/1Password deployment model.

Represent optional production layers in the layer contract/configuration and update `SmokeCheck` to derive expected PMTiles metadata layers from actual GeoJSON counts: required layers must be present and non-empty, while optional zero-feature layers may be absent from metadata. Feature-level validation continues to use the full layer contract whenever features are present.

Add a pinned Felt Tippecanoe build stage to Docker images. The dev image can keep build tools because it already includes development tooling; the production image should compile in a throw-away stage and copy the resulting binaries into the runtime stage.

After successful publish and public URL verification, prune old local generated PMTiles artifacts and metadata from `tmp/map_tiles/` with a conservative retention window so production disk usage does not grow without bound. Keep remote versioned Bunny artifacts as operator-managed rollback/debug history rather than deleting them automatically. Rejected alternatives: relying on host-installed Tippecanoe (not Docker E2E/prod-safe), using the legacy Mapbox repository (not the maintained upstream), keeping non-secret PMTiles settings as env vars (contrary to the desired config model), and immediately deleting the current local artifact before operators can inspect it after a publish.

## Considerations

### Config vs code
Non-secret stable map tile values live in `config/map_tiles.yml`, loaded by `MapTiles::Configuration`; they are not scattered as literals through exporter/publisher logic and are not overridden by `MAP_TILES_*` environment variables. The explicit artifact version and emergency `--skip-smoke` are command parameters, not configuration, because they are per-run operator choices. Bunny credentials remain environment-provided secrets, not config.

### Security
Bunny credentials stay in existing secret environment variables supplied by Kamal/1Password or local shell secret loading and must never be written into `config/map_tiles.yml`, `.incant/`, ignored docs, generated metadata, or logs. The version argument and configured Bunny prefix are sanitized before they are used in file paths or object keys to prevent path traversal. Local artifact cleanup must only target generated files under the configured output directory and must not use unsanitized operator input for deletion paths. `--skip-smoke` is an explicit operator flag so bypassing the safety gate is visible in the command invocation. The temporary E2E helper, if created, must avoid echoing secrets and must remain ignored under `tmp/`.

### Testability
Automated tests should cover Rails config loading, absence of non-secret env overrides, required version argument behavior, version sanitization, explicit `--skip-smoke`, optional `pois` production smoke semantics, required `walking_paths` production smoke failure, exporter compliance with the layer contract, local artifact cleanup retention behaviour, and Bunny publisher behavior with config-backed host/prefix plus secret env credentials. Relevant commands include targeted map tile tests, `bin/rubocop`, and a Docker build check that proves `tippecanoe --version` is available in the dev image; production Docker build should also be verified if practical in the phase gate.

### Code documentation
`MapTiles::Configuration`, CLI option parsing, optional production layer handling, and Docker Tippecanoe installation should have concise boundary documentation or comments where the intent is not obvious: why stable values are Rails config, why version is a command argument, why `pois` is optional but `walking_paths` is required, and why Felt Tippecanoe is pinned. Avoid noisy comments that restate straightforward Ruby or Dockerfile commands.

## Acceptance criteria
- [ ] `config/map_tiles.yml` is committed and defines development/production PMTiles config with `tiles.austrian.rocks`, development prefix `map_tiles/e2e`, production prefix `map_tiles`, output dir `tmp/map_tiles`, artifact basename `austrian-rocks`, and optional production layer `pois`.
- [ ] `MapTiles::Configuration` consumes `config/map_tiles.yml` and no longer supports `MAP_TILES_PUBLIC_CDN_HOST`, `MAP_TILES_BUNNY_PREFIX`, `MAP_TILES_OUTPUT_DIR`, or `MAP_TILES_VERSION` as map tile configuration inputs.
- [ ] `bin/build_pmtiles build`, `smoke`, and `publish` require `--version=<safe-segment>`; `export` does not require a version.
- [ ] `bin/build_pmtiles publish --version=<safe-segment>` runs production smoke by default, and `--skip-smoke` is the only supported bypass.
- [ ] Rails map tile tasks expose equivalent explicit arguments for version, smoke mode/allow-empty, and skip-smoke without relying on map tile env vars.
- [ ] Production smoke passes when `pois` has zero features and may be absent from PMTiles metadata, while still failing when `walking_paths` or any other required source layer has zero features.
- [ ] If `pois` contains features, smoke validates its contract fields and forbidden-field rules like any other layer.
- [ ] `Dockerfile.dev` and `Dockerfile` build Felt Tippecanoe from `https://github.com/felt/tippecanoe` pinned to `2.79.0`; `tippecanoe --version` works in the resulting dev and production images.
- [ ] Missing-Tippecanoe guidance references Felt Tippecanoe and remains clear for non-Docker local runs.
- [ ] Ignored `docs/map_tiles.md` is updated locally to document Rails config, explicit version argument, optional POIs, Dockerized Felt Tippecanoe, storage-backed `tiles.austrian.rocks` delivery, local cleanup, and strict E2E flow; it remains ignored/uncommitted.
- [ ] Automated tests for map tile configuration, CLI/version parsing, exporter contract compliance, smoke checks, local artifact cleanup, and Bunny publication pass.
- [ ] Relevant quality gates pass before review: targeted map tile tests, `bin/rubocop`, Docker dev image Tippecanoe availability check, and production image Tippecanoe availability check if practical.
- [ ] Successful publish prunes old local generated PMTiles artifacts and metadata under `tmp/map_tiles/` with a conservative retention window, keeps the current artifact, and never deletes remote Bunny objects.
- [ ] No generated PMTiles, GeoJSON, downloaded artifacts, secrets, or temporary E2E helper scripts are committed.

## Risks & open questions
- Building Felt Tippecanoe from source may require additional Debian packages beyond `gcc`, `g++`, `make`, `libsqlite3-dev`, and `zlib1g-dev`; the implementation should keep the dependency set minimal and documented.
- Tippecanoe may omit any empty layer from metadata, so optional-layer metadata validation must be based on exported GeoJSON counts rather than a hardcoded expected metadata list.
- Rails task argument ergonomics may be less pleasant than the CLI; the CLI is the primary operator interface, but tasks should remain usable.
- E2E publish requires local access to Kamal/1Password-provided Bunny credentials; this item can make the path clear but cannot verify credentials that are unavailable in an implementation session.
- The storage-backed `tiles.austrian.rocks` pull zone must allow `/map_tiles/*` while blocking non-map-tile storage paths; this is an operational Bunny/DNS prerequisite rather than app code.
