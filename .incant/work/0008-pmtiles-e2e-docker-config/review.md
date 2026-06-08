---
id: "0008"
slug: pmtiles-e2e-docker-config
stage: review
reviewed: 2026-06-08
commit: 372129e1
---

# Pmtiles E2e Docker Config — review

### Strengths
- config/map_tiles.yml:1-20 — The committed Rails config covers the required stable non-secret values, including the development `map_tiles/e2e`, test `map_tiles/test`, production `map_tiles`, and production optional `pois` settings.
- lib/map_tiles/configuration.rb:12-19 and lib/map_tiles/configuration.rb:30-49 — `Configuration` now loads injected/Rails settings, carries the explicit per-run version through `with_version`, and sanitizes artifact basename plus Bunny prefix segments before file/object-key use.
- lib/map_tiles/configuration.rb:34-37 and lib/map_tiles/configuration.rb:62-75 — Artifact-specific access now requires an explicit version while `output_dir`/`geojson_dir` remain available for versionless export, matching the spec boundary.
- lib/map_tiles/cli.rb:73-100 — Build/smoke/publish are routed through a versioned configuration, and publish runs production smoke by default with only `--skip-smoke` bypassing that gate.
- lib/map_tiles/bunny_publisher.rb:53-62 — Publication validation now requires only Bunny storage secret env vars, while CDN host/prefix/artifact/version are validated through configuration-backed methods.
- Fresh verification passed during review: `docker compose run --rm web bin/rails test test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/cli_test.rb test/lib/map_tiles/bunny_publisher_test.rb test/lib/map_tiles/tippecanoe_builder_test.rb test/lib/map_tiles/geojson_exporter_test.rb` → 29 runs, 225 assertions, 0 failures, 0 errors, 0 skips.

### Blocker
- None.

### Major
- None.

### Minor
- lib/map_tiles/cli.rb:117-121 — The space-form parser accepts a following option token as the version value, so `bin/build_pmtiles build --version --bogus` treats `--bogus` as a safe version instead of reporting a missing version/unknown option. This is confusing operator feedback rather than a release-blocking correctness issue; reject `--version` values that begin with `--` unless supplied in `--version=<value>` form, and add a CLI regression test. status: open

### Nit
- None.

### Verdict
Ready to release? **No** — Phase 0008-P1 aligns with its plan and has no blocker/major findings, but the full item is not release-complete because phases 0008-P2 and 0008-P3 are still unimplemented. Continue implementation for the remaining phases; the open minor can be folded into that pass.
