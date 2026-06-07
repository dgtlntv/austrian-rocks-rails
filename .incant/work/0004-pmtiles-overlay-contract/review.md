---
id: "0004"
slug: pmtiles-overlay-contract
stage: review
reviewed: 2026-06-07
commit: 8af61875
---

# Pmtiles Overlay Contract — review

### Strengths
- lib/map_tiles/smoke_check.rb:60-lib/map_tiles/smoke_check.rb:81 — smoke-check options are small and explicit: production vs relaxed modes are validated, `--allow-empty` is parsed predictably, and unknown layer names fail before checks run.
- lib/map_tiles/smoke_check.rb:153-lib/map_tiles/smoke_check.rb:224 — each exported GeoJSON layer is checked as a FeatureCollection, with geometry type, required-property, unexpected-property, circuit-field, app-local URL, and scalar-value validation against `LayerContract`.
- lib/map_tiles/smoke_check.rb:226-lib/map_tiles/smoke_check.rb:250 — strict production mode now fails zero-feature expected layers, while relaxed mode allows only explicitly named empty layers and still enforces sane Austria-area combined bounds.
- lib/map_tiles/cli.rb:54-lib/map_tiles/cli.rb:61 and bin/build_pmtiles:1-bin/build_pmtiles:7 — `bin/build_pmtiles smoke --mode=... --allow-empty=...` delegates to the same `SmokeCheck` implementation and returns a non-zero exit code with actionable error text on failure.
- test/lib/map_tiles/smoke_check_test.rb:27-test/lib/map_tiles/smoke_check_test.rb:136 — P3 coverage exercises happy-path production smoke checks plus missing/empty artifact, metadata mismatch, required-property, bounds, zero-feature, relaxed-empty, circuit URL, and scalar validation failures.
- Fresh P3 gate evidence: `eval "$(rbenv init - bash)" && DATABASE_URL=postgis://austrian-rocks:password@localhost:5432/austrian-rocks-test BUNNY_STORAGE_ENDPOINT=http://example.test BUNNY_STORAGE_ACCESS_KEY_ID=test BUNNY_STORAGE_SECRET_ACCESS_KEY=test BUNNY_STORAGE_REGION=de BUNNY_STORAGE_BUCKET=test bin/rails test test/lib/map_tiles/smoke_check_test.rb` → `8 runs, 38 assertions, 0 failures, 0 errors, 0 skips`.

### Blocker
- lib/map_tiles/smoke_check.rb:88-lib/map_tiles/smoke_check.rb:135, lib/map_tiles/tippecanoe_builder.rb:56-lib/map_tiles/tippecanoe_builder.rb:70, and test/lib/map_tiles/smoke_check_test.rb:17-test/lib/map_tiles/smoke_check_test.rb:19 — the smoke check does not inspect the generated PMTiles artifact for source layers or fields. It only checks that `artifact_path` exists and is non-empty, then trusts a sidecar metadata JSON file that `TippecanoeBuilder` writes directly from `LayerContract`; the test fixture proves an arbitrary text file (`"pmtiles fixture"`) can pass as the PMTiles artifact. This leaves the P3 goal and acceptance criterion unmet: a corrupt/non-PMTiles archive, or a Tippecanoe output missing layers/fields, can still pass smoke checks. Fix by deriving metadata from the actual PMTiles output with a reliable inspector/tool (or otherwise validating the archive itself) and add a regression test that an invalid/non-PMTiles artifact is rejected. status: open
- lib/map_tiles/geojson_exporter.rb:48-lib/map_tiles/geojson_exporter.rb:51 and lib/map_tiles/geojson_exporter.rb:79 — previous P2 blocker about blank-but-valid problem grades omitting required `grade` is fixed: `problem_grade` now returns `"unknown"` for blank grades, docs/map_tiles.md documents that scalar fallback, and exporter regression coverage covers the required label/grade fallbacks. status: addressed

### Major
- docs/map_tiles.md:112 and .incant/work/0004-pmtiles-overlay-contract/plan.md:78 — previous P1 finding about the missing `WalkingPath.published` scope shorthand remains fixed: both artifacts now describe `WalkingPath` records where `published` is true. status: addressed

### Minor
- .incant/work/0004-pmtiles-overlay-contract/plan.md:50-.incant/work/0004-pmtiles-overlay-contract/plan.md:51 — previous P1 stale handoff notes remain fixed: backlog/state now point at the current phase review handoff. status: addressed

### Nit
- None.

### Verdict
Ready to release? **No** for the `0004-P3` phase gate — one open blocker means the smoke check can certify a non-PMTiles file without validating the generated archive's layer/field metadata. Return to `/incant:implement 0004` to make the artifact inspection real before moving to `0004-P4`.
