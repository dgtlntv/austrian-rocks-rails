---
id: "0008"
slug: pmtiles-e2e-docker-config
stage: review
reviewed: 2026-06-08
commit: 57d0746a
---

# Pmtiles E2e Docker Config — review

### Strengths
- config/map_tiles.yml:1-22 — Stable non-secret map tile settings are now tracked in Rails config, with the required CDN host, artifact basename/output directory, E2E Bunny prefix, production Bunny prefix, and `pois` optional in both production and the development/E2E path.
- lib/map_tiles/configuration.rb:12-75 and lib/map_tiles/configuration.rb:95-110 — `Configuration` consumes Rails/injected settings, keeps Bunny secrets in `env`, preserves `export` without a version, and gates artifact paths/object keys behind a sanitized explicit version.
- lib/map_tiles/cli.rb:73-100 and lib/map_tiles/cli.rb:113-130 — Build/smoke/publish require explicit versions, publish runs production smoke by default, `--skip-smoke` is the only bypass, and the previous space-form `--version --bogus` parser edge case is now rejected.
- lib/map_tiles/smoke_check.rb:188-193 and lib/map_tiles/smoke_check.rb:310-327 — Optional production metadata semantics are based on actual GeoJSON counts, so empty configured `pois` may be absent while required layers, including `walking_paths`, remain strict.
- test/lib/map_tiles/configuration_test.rb:41-47, test/lib/map_tiles/cli_test.rb:93-100, and test/lib/map_tiles/smoke_check_test.rb:125-172 — Regression coverage now proves the development/E2E config exposes optional `pois`, the CLI parser rejects an option-token version value, zero-feature optional POIs pass without metadata, required walking paths fail empty, and dataful POIs still get contract validation.
- Fresh verification passed during this review: `docker compose run --rm web bin/rails test test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/cli_test.rb test/lib/map_tiles/smoke_check_test.rb` → 28 runs, 135 assertions, 0 failures, 0 errors, 0 skips; `docker compose run --rm web bin/rubocop lib/map_tiles/cli.rb test/lib/map_tiles/cli_test.rb test/lib/map_tiles/configuration_test.rb lib/map_tiles/smoke_check.rb test/lib/map_tiles/smoke_check_test.rb` → 5 files inspected, no offenses detected; `docker compose run --rm web bin/rails runner 'puts Rails.env; p MapTiles::Configuration.new.optional_production_layers'` → `development`, `["pois"]`.
- Commit history is traceable: `incant 0008: spec`, `incant 0008: plan`, `incant 0008-P1: config-backed PMTiles commands`, `incant 0008-P2: allow empty production POIs`, and `incant 0008-P2: address POI E2E review` all follow the expected convention.

### Blocker
- Dockerfile.dev:10-19, Dockerfile:32-63, and lib/map_tiles/tippecanoe_builder.rb:12-14 — Phase 0008-P3 / acceptance criteria 8-9 and 11-14 are still not implemented: neither Docker image builds or copies Felt Tippecanoe `2.79.0`, neither image can yet satisfy the required `tippecanoe --version` / inspection-binary availability checks, and missing-binary guidance still points at the legacy Mapbox repository. This leaves the promised Dockerized E2E/prod PMTiles path unavailable. Fix by completing Phase 0008-P3, including Docker dev/production Tippecanoe installation, Felt guidance, local docs hygiene, and the Docker availability gates. status: open

### Major
- config/map_tiles.yml:8-12 and lib/map_tiles/smoke_check.rb:314-327 — The earlier P2 finding is addressed: the development/E2E configuration now exposes `optional_production_layers: [pois]`, and fresh Docker runner output printed `development` and `["pois"]`, so zero-POI strict local production-dump smoke no longer fails solely because Rails is in development. status: addressed

### Minor
- lib/map_tiles/cli.rb:117-120 — The earlier CLI parser finding is addressed: space-form `--version` now rejects following option tokens, with regression coverage in `test/lib/map_tiles/cli_test.rb:93-100`. status: addressed

### Nit
- None.

### Verdict
Ready to release? **No** — P1/P2 review findings are addressed, but one open blocker remains because the Dockerized Felt Tippecanoe/guidance phase is still missing. Return to implementation for 0008-P3 before finalize.
