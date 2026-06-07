---
id: "0004"
slug: pmtiles-overlay-contract
stage: review
reviewed: 2026-06-07
commit: c40f12f4
---

# Pmtiles Overlay Contract — review

### Strengths
- docs/map_tiles.md:9 and docs/map_tiles.md:40-docs/map_tiles.md:159 — the ignored consumer contract still documents native max zoom `16` and all ten required PMTiles source layers with geometry, identifiers, properties, and navigation guidance.
- lib/map_tiles/layer_contract.rb:11-lib/map_tiles/layer_contract.rb:72 and lib/map_tiles/layer_contract.rb:92 — `LayerContract` centralizes the ten source layers, native max zoom, camelCase properties, and a circuit-field guard, giving exporter/tests a single contract source.
- lib/map_tiles/geojson_exporter.rb:17-lib/map_tiles/geojson_exporter.rb:30 — the exporter writes deterministic per-layer GeoJSON files for every expected source layer, including `walking_paths` and `pois`.
- lib/map_tiles/geojson_exporter.rb:172-lib/map_tiles/geojson_exporter.rb:190 — published walking paths and POI `accessAreasJson` are exported in the planned scalar shape without app-local canonical URL properties.
- lib/map_tiles/configuration.rb:45-lib/map_tiles/configuration.rb:52 and lib/map_tiles/tippecanoe_builder.rb:36-lib/map_tiles/tippecanoe_builder.rb:50 — map-tile object naming and the Tippecanoe named-layer command are config-driven and match the planned version/latest artifact shape.
- test/lib/map_tiles/layer_contract_test.rb:7-test/lib/map_tiles/layer_contract_test.rb:39, test/lib/map_tiles/geojson_exporter_test.rb:26-test/lib/map_tiles/geojson_exporter_test.rb:88, and test/lib/map_tiles/tippecanoe_builder_test.rb:24-test/lib/map_tiles/tippecanoe_builder_test.rb:66 — P2 has useful targeted coverage for layer order/properties, fixture-backed exports, POI metadata, published walking paths, and missing-Tippecanoe guidance.
- Fresh P2 gate evidence: `eval "$(rbenv init - bash)" && DATABASE_URL=postgis://austrian-rocks:password@localhost:5432/austrian-rocks-test BUNNY_STORAGE_ENDPOINT=http://example.test BUNNY_STORAGE_ACCESS_KEY_ID=test BUNNY_STORAGE_SECRET_ACCESS_KEY=test BUNNY_STORAGE_REGION=de BUNNY_STORAGE_BUCKET=test bin/rails test test/lib/map_tiles/layer_contract_test.rb test/lib/map_tiles/geojson_exporter_test.rb test/lib/map_tiles/tippecanoe_builder_test.rb` → `11 runs, 705 assertions, 0 failures, 0 errors, 0 skips`.

### Blocker
- lib/map_tiles/geojson_exporter.rb:48-lib/map_tiles/geojson_exporter.rb:51 and lib/map_tiles/geojson_exporter.rb:79 — `grade` is contract-required for every `problems` feature, but valid problems may have blank grades (`app/models/problem.rb:35`, `db/schema.rb:190`). The exporter converts `nil` to `""`, then `compact_properties` drops the empty string, producing a feature without the required `grade` property. I reproduced this with a published-area, located problem with `grade: nil`; the exported problem properties reported `grade missing`. Fix by making required properties impossible to omit (for example, contract-approved fallback value or explicit validation/skip with a clear reason), and add regression coverage for blank-but-valid source fields. Audit the same compaction path for other required label fields before P3 smoke checks. status: open

### Major
- docs/map_tiles.md:112 and .incant/work/0004-pmtiles-overlay-contract/plan.md:78 — previous P1 finding about the missing `WalkingPath.published` scope shorthand remains fixed: both artifacts now describe `WalkingPath` records where `published` is true. status: addressed

### Minor
- .incant/work/0004-pmtiles-overlay-contract/plan.md:50-.incant/work/0004-pmtiles-overlay-contract/plan.md:51 — previous P1 stale handoff notes remain fixed: backlog/state now point at the current phase review handoff. status: addressed

### Nit
- None.

### Verdict
Ready to release? **No** — one open blocker means `0004-P2` should return to implementation before starting `0004-P3`. The P2 test gate passes, but the exporter can currently violate its own required-property contract for valid production data.
