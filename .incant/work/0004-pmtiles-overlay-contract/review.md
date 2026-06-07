---
id: "0004"
slug: pmtiles-overlay-contract
stage: review
reviewed: 2026-06-07
commit: f615a740
---

# Pmtiles Overlay Contract — review

### Strengths
- lib/map_tiles/smoke_check.rb:187-lib/map_tiles/smoke_check.rb:199 — the Tippecanoe metadata fix now compares source-layer names order-independently and validates only required fields as mandatory while still rejecting unexpected fields, matching real archives where layer order and optional-field presence vary with source data.
- lib/map_tiles/smoke_check.rb:207-lib/map_tiles/smoke_check.rb:209 — metadata validation retains the important safety checks for forbidden circuit fields and app-local URL fields even after relaxing optional-field handling.
- test/lib/map_tiles/smoke_check_test.rb:63-test/lib/map_tiles/smoke_check_test.rb:72 — regression coverage now exercises reversed Tippecanoe-style layer ordering with only required properties present, which directly covers the previous P3 blocker.
- Fresh P3 re-review evidence: `eval "$(rbenv init - bash)" && DATABASE_URL=postgis://austrian-rocks:password@localhost:5432/austrian-rocks-test BUNNY_STORAGE_ENDPOINT=http://example.test BUNNY_STORAGE_ACCESS_KEY_ID=test BUNNY_STORAGE_SECRET_ACCESS_KEY=test BUNNY_STORAGE_REGION=de BUNNY_STORAGE_BUCKET=test bin/rails test test/lib/map_tiles/smoke_check_test.rb && bin/rubocop lib/map_tiles/smoke_check.rb test/lib/map_tiles/smoke_check_test.rb` → `10 runs, 50 assertions, 0 failures, 0 errors, 0 skips`; `2 files inspected, no offenses detected`.
- Fresh real-Tippecanoe smoke evidence: generated one minimal valid feature for each expected layer, built `tmp/review-0004-tippecanoe/austrian-rocks-review-real.pmtiles` with `/opt/homebrew/bin/tippecanoe`, and ran `MapTiles::SmokeCheck` in production mode → smoke check passed for all ten layers with bounds `lon 16.0..16.1, lat 48.0..48.1`.

### Blocker
- lib/map_tiles/smoke_check.rb:187-lib/map_tiles/smoke_check.rb:209 and test/lib/map_tiles/smoke_check_test.rb:63-test/lib/map_tiles/smoke_check_test.rb:92 — previous P3 blocker about real Tippecanoe metadata ordering and absent optional fields is addressed: layer names are compared as sets, only required fields are mandatory, unexpected/circuit/app-URL fields still fail, regression coverage mimics the Tippecanoe variation, and a real Tippecanoe-built PMTiles fixture passed the smoke check during re-review. status: addressed
- lib/map_tiles/smoke_check.rb:122-lib/map_tiles/smoke_check.rb:176, lib/map_tiles/tippecanoe_builder.rb:25-lib/map_tiles/tippecanoe_builder.rb:33, and test/lib/map_tiles/smoke_check_test.rb:53-test/lib/map_tiles/smoke_check_test.rb:60 — previous P3 blocker about trusting a generated sidecar instead of inspecting the PMTiles artifact remains addressed: metadata is parsed from the archive header/blob, invalid/non-PMTiles artifacts are rejected, and the builder no longer emits the sidecar. status: addressed
- lib/map_tiles/geojson_exporter.rb:48-lib/map_tiles/geojson_exporter.rb:51 and lib/map_tiles/geojson_exporter.rb:79 — previous P2 blocker about blank-but-valid problem grades omitting required `grade` remains fixed: `problem_grade` returns `"unknown"` for blank grades, docs/map_tiles.md documents that scalar fallback, and exporter regression coverage covers the required label/grade fallbacks. status: addressed

### Major
- docs/map_tiles.md:112 and .incant/work/0004-pmtiles-overlay-contract/plan.md:78 — previous P1 finding about the missing `WalkingPath.published` scope shorthand remains fixed: both artifacts now describe `WalkingPath` records where `published` is true. status: addressed

### Minor
- .incant/work/0004-pmtiles-overlay-contract/plan.md:50-.incant/work/0004-pmtiles-overlay-contract/plan.md:51 — previous P1 stale handoff notes remain fixed: backlog/state now point at the current phase review handoff. status: addressed

### Nit
- None.

### Verdict
Ready to release? **Yes** for the `0004-P3` phase gate — no open blocker or major findings remain for the implemented P1–P3 scope, and the prior Tippecanoe metadata blocker is fixed with fresh unit and real-build evidence. This is not final item release yet; continue to `0004-P4` before `/incant:finalize 0004`.
