---
id: "0008"
slug: pmtiles-e2e-docker-config
stage: review
reviewed: 2026-06-08
commit: 4f41dc0c
---

# Pmtiles E2e Docker Config — review (re-review after P3 + post-review fixes)

### Strengths
- config/map_tiles.yml:1-22 — Tracked Rails config separates stable non-secret PMTiles settings (artifact basename, output dir, CDN host `tiles.austrian.rocks`, env-specific Bunny prefixes, optional production `pois`) from secrets; three environments clearly delimited.
- lib/map_tiles/configuration.rb:12-75,105-110 — `Configuration` consumes Rails/injected settings, gates artifact paths behind a sanitized explicit version, keeps Bunny secrets in `env`, and now rejects path-traversal segments `.` and `..` (a security hardening beyond the spec).
- lib/map_tiles/cli.rb:54-104,117-148 — Build/smoke/publish require explicit `--version`; `publish` runs production smoke by default with `--skip-smoke` as the only bypass; duplicate `--version` is caught; space-form `--version --bogus` rejects following option tokens; unknown options fail with usage.
- lib/map_tiles/smoke_check.rb:185-327 — Optional production metadata semantics are derived from actual GeoJSON counts: required layers (including `walking_paths`) remain strict; empty configured `pois` may be absent from PMTiles metadata while dataful `pois` gets full contract validation.
- lib/map_tiles/geojson_exporter.rb:109-115 — `area_hulls` no longer leaks out-of-contract `shortName`; `shortName` is scoped only to the `areas` point layer where the contract allows it.
- Dockerfile:9-27,76-80 — Felt Tippecanoe `2.79.0` is built in a throw-away stage (`tippecanoe`) with minimal build deps (`build-essential`, `ca-certificates`, `git`, `libsqlite3-dev`, `zlib1g-dev`); only the three binaries (`tippecanoe`, `tippecanoe-decode`, `tile-join`) are copied into the final runtime image. Compiler toolchain stays out of production.
- Dockerfile.dev:7,22-26 — Felt Tippecanoe `2.79.0` is built and installed directly in the dev image alongside existing dev tooling.
- lib/map_tiles/local_artifact_cleaner.rb:1-51 — Clean, bounded local cleanup: 14-day retention, pattern-scoped to `{basename}-*.pmtiles` and `{basename}-*.metadata.json`, current artifact preserved, GeoJSON untouched, remote Bunny objects never deleted.
- test/lib/map_tiles/configuration_test.rb, cli_test.rb, smoke_check_test.rb, local_artifact_cleaner_test.rb — Comprehensive test coverage across all new and changed behavior: config loading, env-specific prefixes, legacy env override ignorance, version requirements, CLI argument parsing, skip-smoke, optional POI smoke semantics, dataful POI contract violations, and local artifact cleanup retention logic.
- Fresh verification (2026-06-08): `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/lib/map_tiles` → **48 runs, 903 assertions, 0 failures, 0 errors, 0 skips**; `docker compose run --rm web bin/rubocop lib/map_tiles test/lib/map_tiles` → **16 files inspected, no offenses**; `docker compose run --rm web sh -lc 'tippecanoe --version && command -v tippecanoe-decode && command -v tile-join'` → `tippecanoe v2.79.0`, `/usr/local/bin/tippecanoe-decode`, `/usr/local/bin/tile-join`.
- Commit history is traceable: `incant 0008: spec`, `incant 0008: plan`, `incant 0008-P1: config-backed PMTiles commands`, `incant 0008-P2: allow empty production POIs`, `incant 0008-P2: address POI E2E review`, `incant 0008-P3: dockerize Felt Tippecanoe`, `incant 0008-P3: address PMTiles E2E publish findings`.

### Blocker
- None — the prior P3 blocker is resolved: both dev and production Docker images now build and install Felt Tippecanoe `2.79.0`, missing-binary guidance references Felt, and production image Tippecanoe availability was verified in the plan's P3 gate. status: addressed

### Major
- None.

### Minor
- None.

### Nit
- test/lib/map_tiles/smoke_check_test.rb:198 — The private `map_tile_settings` helper injects `"public_cdn_host" => "assets.austrian.rocks"` (the old Rails-origin CDN host) rather than the new `tiles.austrian.rocks` value from the committed config. `SmokeCheck` never reads `public_cdn_host`, so this has zero functional impact, but it's mildly inconsistent with the other test fixtures and the committed production config. status: open

### Verdict
Ready to release? **Yes** — all three phases are complete, every acceptance criterion is met, all quality gates pass with fresh verification (48 tests / 903 assertions / 0 failures, RuboCop clean, Tippecanoe v2.79.0 confirmed in dev image), the prior P3 blocker and all earlier review findings are addressed, and no new blockers or majors remain. One cosmetic nit about a test fixture value can be cleaned up opportunistically.
