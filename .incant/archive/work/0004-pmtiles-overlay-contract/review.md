---
id: "0004"
slug: pmtiles-overlay-contract
stage: review
reviewed: 2026-06-07
commit: f680990bf792d5853fee55c8e1ae2fff805307ab
---

# Pmtiles Overlay Contract — final review

### Strengths
- lib/map_tiles/layer_contract.rb:13-lib/map_tiles/layer_contract.rb:73 and docs/map_tiles.md — the code and ignored consumer contract define the same ten source layers, native max zoom `16`, camelCase scalar properties, POI `accessAreasJson`, walking-path semantics, and circuit/app-canonical-URL exclusions required by the spec.
- lib/map_tiles/geojson_exporter.rb:66-lib/map_tiles/geojson_exporter.rb:209 — exporter coverage is contract-driven and consumer-safe: published-area problem/boulder/area/cluster/region data, published `WalkingPath` line geometry, POI route metadata encoded as a JSON string, stable IDs/slugs, and required label/grade fallbacks are all present.
- lib/map_tiles/smoke_check.rb:46-lib/map_tiles/smoke_check.rb:323 — smoke checks inspect the actual PMTiles metadata blob plus generated GeoJSON, validate expected layers/fields, scalar properties, production zero-feature failures, relaxed empty-layer mode, and sane Austria bounds.
- lib/map_tiles/bunny_publisher.rb:38-lib/map_tiles/bunny_publisher.rb:113 and lib/map_tiles/cli.rb:67-lib/map_tiles/cli.rb:79 — publication uploads both immutable and latest Bunny object keys, verifies both public URLs with HTTP `HEAD`, avoids credential leakage in error messages, and runs production smoke checks before publish unless the documented emergency skip flag is set.
- test/lib/map_tiles/*.rb — targeted tests cover layer contract shape, exporter properties and fallbacks, missing-Tippecanoe guidance, PMTiles smoke failures, and Bunny dual-upload/HEAD behavior. Fresh review gates passed: targeted map tile tests `28 runs, 793 assertions, 0 failures`; full suite `68 runs, 930 assertions, 0 failures`; focused RuboCop `14 files inspected, no offenses`; Brakeman `Security Warnings: 0`.

### Blocker
- lib/map_tiles/smoke_check.rb:187-lib/map_tiles/smoke_check.rb:209 and test/lib/map_tiles/smoke_check_test.rb:63-test/lib/map_tiles/smoke_check_test.rb:92 — previous P3 blocker about real Tippecanoe metadata ordering and absent optional fields remains addressed: layer names are compared as sets, only required fields are mandatory, unexpected/circuit/app-URL fields still fail, regression coverage mimics the Tippecanoe variation, and a real Tippecanoe-built PMTiles fixture passed the earlier smoke check. status: addressed
- lib/map_tiles/smoke_check.rb:122-lib/map_tiles/smoke_check.rb:176, lib/map_tiles/tippecanoe_builder.rb:25-lib/map_tiles/tippecanoe_builder.rb:33, and test/lib/map_tiles/smoke_check_test.rb:53-test/lib/map_tiles/smoke_check_test.rb:60 — previous P3 blocker about trusting a generated sidecar instead of inspecting the PMTiles artifact remains addressed: metadata is parsed from the archive header/blob, invalid/non-PMTiles artifacts are rejected, and the builder no longer emits the sidecar. status: addressed
- lib/map_tiles/geojson_exporter.rb:48-lib/map_tiles/geojson_exporter.rb:51 and lib/map_tiles/geojson_exporter.rb:79 — previous P2 blocker about blank-but-valid problem grades omitting required `grade` remains fixed: `problem_grade` returns `"unknown"` for blank grades, docs/map_tiles.md documents that scalar fallback, and exporter regression coverage covers required label/grade fallbacks. status: addressed

### Major
- docs/map_tiles.md and .incant/work/0004-pmtiles-overlay-contract/plan.md — previous P1 finding about the missing `WalkingPath.published` scope shorthand remains fixed: both artifacts now describe `WalkingPath` records where `published` is true. status: addressed

### Minor
- .incant/work/0004-pmtiles-overlay-contract/plan.md — previous P1 stale handoff notes remain fixed: backlog/state/plan now point at the completed P4 final-review handoff. status: addressed

### Nit
- None.

### Verdict
Ready to release? **Yes** — no open blocker or major findings remain, the implementation satisfies the spec acceptance criteria, and fresh tests/lint/security gates pass. Proceed to `/incant:finalize 0004` when ready to close the item.
