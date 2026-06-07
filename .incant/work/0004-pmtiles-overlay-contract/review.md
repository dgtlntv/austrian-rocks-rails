---
id: "0004"
slug: pmtiles-overlay-contract
stage: review
reviewed: 2026-06-07
commit: 2ec715f
---

# Pmtiles Overlay Contract — review

### Strengths
- lib/map_tiles/smoke_check.rb:122-lib/map_tiles/smoke_check.rb:176 — the previous sidecar trust issue is materially improved: `SmokeCheck` now reads the PMTiles header and JSON metadata blob from the artifact itself, validates the v3 magic/version, handles none/gzip internal compression, and reports malformed/short metadata reads as smoke-check failures.
- lib/map_tiles/tippecanoe_builder.rb:25-lib/map_tiles/tippecanoe_builder.rb:33 — `TippecanoeBuilder` no longer writes a contract-derived metadata sidecar after a build, so the smoke path is no longer certifying data it generated independently of the archive.
- test/lib/map_tiles/smoke_check_test.rb:53-test/lib/map_tiles/smoke_check_test.rb:60 — regression coverage now proves the old arbitrary text artifact (`"pmtiles fixture"`) is rejected as a non-PMTiles archive.
- Fresh P3 gate evidence: `eval "$(rbenv init - bash)" && DATABASE_URL=postgis://austrian-rocks:password@localhost:5432/austrian-rocks-test BUNNY_STORAGE_ENDPOINT=http://example.test BUNNY_STORAGE_ACCESS_KEY_ID=test BUNNY_STORAGE_SECRET_ACCESS_KEY=test BUNNY_STORAGE_REGION=de BUNNY_STORAGE_BUCKET=test bin/rails test test/lib/map_tiles/smoke_check_test.rb` → `9 runs, 41 assertions, 0 failures, 0 errors, 0 skips`.

### Blocker
- lib/map_tiles/smoke_check.rb:187-lib/map_tiles/smoke_check.rb:200 and test/lib/map_tiles/smoke_check_test.rb:151-test/lib/map_tiles/smoke_check_test.rb:155 — the real PMTiles metadata validation is too strict for Tippecanoe output, so the phase smoke check can fail a valid archive built by this item. `verify_metadata!` requires layer order to equal `LayerContract.layer_names` and requires every optional property to appear in metadata. A quick reproduction with Tippecanoe and one valid feature per expected layer produced metadata ordered `area_hulls, areas, boulders, ...` and omitted optional fields that were absent from the input features; `SmokeCheck` then failed with a layer-order mismatch plus optional-field mismatches even though all expected layers and required properties were present. This leaves the P3 acceptance path unusable for legitimate datasets where optional values (for example `nameEn`, `shortName`, `boulderId`, `googleUrl`) may be absent. Fix by comparing layer names as a set/order-independent collection, requiring only contract required properties in PMTiles metadata, and failing unexpected non-contract/circuit/app-URL fields; add a regression fixture that mimics real Tippecanoe ordering and absent optional fields. status: open
- lib/map_tiles/smoke_check.rb:122-lib/map_tiles/smoke_check.rb:176, lib/map_tiles/tippecanoe_builder.rb:25-lib/map_tiles/tippecanoe_builder.rb:33, and test/lib/map_tiles/smoke_check_test.rb:53-test/lib/map_tiles/smoke_check_test.rb:60 — previous P3 blocker about trusting a generated sidecar instead of inspecting the PMTiles artifact is addressed: metadata is parsed from the archive header/blob, invalid/non-PMTiles artifacts are rejected, and the builder no longer emits the sidecar. status: addressed
- lib/map_tiles/geojson_exporter.rb:48-lib/map_tiles/geojson_exporter.rb:51 and lib/map_tiles/geojson_exporter.rb:79 — previous P2 blocker about blank-but-valid problem grades omitting required `grade` remains fixed: `problem_grade` returns `"unknown"` for blank grades, docs/map_tiles.md documents that scalar fallback, and exporter regression coverage covers the required label/grade fallbacks. status: addressed

### Major
- docs/map_tiles.md:112 and .incant/work/0004-pmtiles-overlay-contract/plan.md:78 — previous P1 finding about the missing `WalkingPath.published` scope shorthand remains fixed: both artifacts now describe `WalkingPath` records where `published` is true. status: addressed

### Minor
- .incant/work/0004-pmtiles-overlay-contract/plan.md:50-.incant/work/0004-pmtiles-overlay-contract/plan.md:51 — previous P1 stale handoff notes remain fixed: backlog/state now point at the current phase review handoff. status: addressed

### Nit
- None.

### Verdict
Ready to release? **No** for the `0004-P3` phase gate — one open blocker remains because real Tippecanoe PMTiles metadata can fail the smoke check due to ordering and optional-field assumptions. Return to `/incant:implement 0004` before moving to `0004-P4`.
