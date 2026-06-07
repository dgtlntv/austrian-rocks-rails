---
id: "0004"
slug: pmtiles-overlay-contract
stage: review
reviewed: 2026-06-07
commit: 33a3d76a
---

# Pmtiles Overlay Contract — review

### Strengths
- docs/map_tiles.md:9 and docs/map_tiles.md:40-docs/map_tiles.md:159 — the ignored consumer contract still documents native max zoom `16` and all ten required PMTiles source layers with geometry, identifiers, properties, and navigation guidance.
- lib/map_tiles/layer_contract.rb:11-lib/map_tiles/layer_contract.rb:72 and lib/map_tiles/layer_contract.rb:92 — `LayerContract` centralizes the ten source layers, native max zoom, camelCase properties, and a circuit-field guard, giving exporter/tests a single contract source.
- lib/map_tiles/geojson_exporter.rb:66-lib/map_tiles/geojson_exporter.rb:89 and lib/map_tiles/geojson_exporter.rb:337-lib/map_tiles/geojson_exporter.rb:347 — the P2 rework now preserves required problem `grade` with an explicit `unknown` fallback and keeps required labels present through source-field/fallback display labels.
- lib/map_tiles/geojson_exporter.rb:172-lib/map_tiles/geojson_exporter.rb:190 — published walking paths and POI `accessAreasJson` are exported in the planned scalar shape without app-local canonical URL properties.
- lib/map_tiles/configuration.rb:45-lib/map_tiles/configuration.rb:52 and lib/map_tiles/tippecanoe_builder.rb:36-lib/map_tiles/tippecanoe_builder.rb:50 — map-tile object naming and the Tippecanoe named-layer command are config-driven and match the planned version/latest artifact shape.
- test/lib/map_tiles/geojson_exporter_test.rb:81-test/lib/map_tiles/geojson_exporter_test.rb:109 — regression coverage now exercises blank-but-valid labels/grades and confirms the exporter still emits contract-required properties.
- Fresh P2 gate evidence: `eval "$(rbenv init - bash)" && DATABASE_URL=postgis://austrian-rocks:password@localhost:5432/austrian-rocks-test BUNNY_STORAGE_ENDPOINT=http://example.test BUNNY_STORAGE_ACCESS_KEY_ID=test BUNNY_STORAGE_SECRET_ACCESS_KEY=test BUNNY_STORAGE_REGION=de BUNNY_STORAGE_BUCKET=test bin/rails test test/lib/map_tiles/layer_contract_test.rb test/lib/map_tiles/geojson_exporter_test.rb test/lib/map_tiles/tippecanoe_builder_test.rb` → `12 runs, 712 assertions, 0 failures, 0 errors, 0 skips`.

### Blocker
- lib/map_tiles/geojson_exporter.rb:48-lib/map_tiles/geojson_exporter.rb:51 and lib/map_tiles/geojson_exporter.rb:79 — previous P2 blocker about blank-but-valid problem grades omitting required `grade` is fixed: `problem_grade` now returns `"unknown"` for blank grades, docs/map_tiles.md:46 documents that scalar fallback, and test/lib/map_tiles/geojson_exporter_test.rb:81-test/lib/map_tiles/geojson_exporter_test.rb:109 covers the regression plus required label fallbacks. status: addressed

### Major
- docs/map_tiles.md:112 and .incant/work/0004-pmtiles-overlay-contract/plan.md:78 — previous P1 finding about the missing `WalkingPath.published` scope shorthand remains fixed: both artifacts now describe `WalkingPath` records where `published` is true. status: addressed

### Minor
- .incant/work/0004-pmtiles-overlay-contract/plan.md:50-.incant/work/0004-pmtiles-overlay-contract/plan.md:51 — previous P1 stale handoff notes remain fixed: backlog/state now point at the current phase review handoff. status: addressed

### Nit
- None.

### Verdict
Ready to release? **Yes** for the `0004-P2` phase gate — no blocker or major findings remain open, and the fresh P2 quality gate passes. This is not a final item release verdict; planned `0004-P3` smoke checks and `0004-P4` Bunny publication work still need implementation before finalization.
