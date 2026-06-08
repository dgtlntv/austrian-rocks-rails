---
id: "0008"
slug: pmtiles-e2e-docker-config
stage: review
reviewed: 2026-06-08
commit: 3e9680d8
---

# Pmtiles E2e Docker Config — review

### Strengths
- config/map_tiles.yml:1-20 — The committed Rails config covers the required stable non-secret values, including the development `map_tiles/e2e`, test `map_tiles/test`, production `map_tiles`, and production `pois` setting.
- lib/map_tiles/configuration.rb:12-49 and lib/map_tiles/configuration.rb:62-75 — `Configuration` now loads injected/Rails settings, carries the explicit per-run version through `with_version`, sanitizes artifact basename/Bunny prefix/version values, and requires a version only for artifact-specific paths/object keys.
- lib/map_tiles/cli.rb:73-100 — Build/smoke/publish are routed through a versioned configuration, and publish runs production smoke by default with only `--skip-smoke` bypassing that gate.
- lib/map_tiles/smoke_check.rb:48-56 and lib/map_tiles/smoke_check.rb:179-194 — Smoke checks now inspect GeoJSON layer counts before metadata layer comparison, so optional layer metadata is derived from actual exported data rather than a hardcoded full-layer list.
- lib/map_tiles/smoke_check.rb:310-327 — Production-mode count validation keeps required layers strict while allowing configured optional production layers to be empty.
- test/lib/map_tiles/smoke_check_test.rb:125-170 — The P2 tests cover zero-feature optional `pois`, required `walking_paths`, relaxed-mode `--allow-empty`, and dataful optional POI contract violations.
- Fresh verification passed during review: `docker compose run --rm web bin/rails test test/lib/map_tiles/smoke_check_test.rb` → 12 runs, 63 assertions, 0 failures, 0 errors, 0 skips; `docker compose run --rm web bin/rubocop lib/map_tiles/smoke_check.rb test/lib/map_tiles/smoke_check_test.rb` → 2 files inspected, no offenses detected.

### Blocker
- None.

### Major
- config/map_tiles.yml:6-10 and lib/map_tiles/smoke_check.rb:314-327 — The intended local Docker E2E path uses `RAILS_ENV=development` for the `map_tiles/e2e` Bunny prefix, but development inherits `optional_production_layers: []`. Because production-mode smoke reads `configuration.optional_production_layers`, zero-feature `pois` still fails in the actual dev-container E2E configuration even though the production Rails environment would allow it. Fresh check: `docker compose run --rm web bin/rails runner 'puts Rails.env; p MapTiles::Configuration.new.optional_production_layers'` printed `development` and `[]`. This misses the core requirement to make strict local production-dump E2E work without dummy POIs. Fix by making the production-smoke optional layer contract (`pois`) available in the development/E2E configuration as well (or otherwise decouple optional production smoke layers from Rails env), and add a regression test against the committed development config. status: open

### Minor
- lib/map_tiles/cli.rb:117-121 — The space-form parser accepts a following option token as the version value, so `bin/build_pmtiles build --version --bogus` treats `--bogus` as a safe version instead of reporting a missing version/unknown option. This is confusing operator feedback rather than a release-blocking correctness issue; reject `--version` values that begin with `--` unless supplied in `--version=<value>` form, and add a CLI regression test. status: open

### Nit
- None.

### Verdict
Ready to release? **No** — one open major prevents the promised Dockerized local E2E path from handling zero-POI production-like data, and phase 0008-P3 is still outstanding. Return to implementation for the major finding and remaining Docker/Tippecanoe phase work.
