---
id: "0004"
slug: pmtiles-overlay-contract
stage: review
reviewed: 2026-06-07
commit: 5d38d12f
---

# Pmtiles Overlay Contract — review

### Strengths
- docs/map_tiles.md:3 and `.gitignore:29` — the contract remains the spec-requested ignored `/docs/` artifact rather than a committed docs file.
- docs/map_tiles.md:7-docs/map_tiles.md:15 — artifact naming, native max zoom `16`, ignored build-output policy, Bunny immutable/latest object names, and map-specific CDN configuration are documented clearly for later implementation.
- docs/map_tiles.md:17-docs/map_tiles.md:27 — the naming/data rules keep source layers stable, properties camelCase/scalar, navigation ID/slug-based, circuit data excluded, and walking paths tied to `WalkingPath` records where `published` is true.
- docs/map_tiles.md:29-docs/map_tiles.md:36 — the source-layer vs later MapLibre style-layer distinction is explicit for labels, fills, outlines, and `walking_paths` line styling.
- docs/map_tiles.md:40-docs/map_tiles.md:159 — all ten required source layers are enumerated with geometry, stable identifiers, required/optional properties, and navigation guidance.
- docs/map_tiles.md:121-docs/map_tiles.md:144 — POIs include the allowed external `googleUrl`, and `accessAreasJson` is documented as scalar JSON metadata derived from `poi_routes`, not route geometry.
- .incant/work/0004-pmtiles-overlay-contract/plan.md:21-.incant/work/0004-pmtiles-overlay-contract/plan.md:27 — review fixes and fresh P1 gate evidence are recorded; I re-ran the review-fix gate successfully during this review.

### Blocker
- None.

### Major
- docs/map_tiles.md:118 and .incant/work/0004-pmtiles-overlay-contract/plan.md:78 — previous finding about `WalkingPath.published` is fixed: both artifacts now describe `WalkingPath` records where `published` is true, matching the delivered model shape in app/models/walking_path.rb:1-app/models/walking_path.rb:38. Fresh gate: `test -f docs/map_tiles.md && git check-ignore -q docs/map_tiles.md && grep -q "walking_paths" docs/map_tiles.md && grep -q "native max zoom" docs/map_tiles.md && ! rg -q 'WalkingPath\\.published' docs/map_tiles.md .incant/work/0004-pmtiles-overlay-contract/plan.md` → passed. status: addressed

### Minor
- .incant/work/0004-pmtiles-overlay-contract/plan.md:50-.incant/work/0004-pmtiles-overlay-contract/plan.md:51 — previous stale Files touched notes are fixed: they now match the current backlog/state handoff at `.incant/backlog.md:5` and `.incant/STATE.md:6`. status: addressed

### Nit
- None.

### Verdict
Ready to release? **With fixes** — no open blocker or major findings remain for the `0004-P1` phase gate, and P1 is clear to proceed to `0004-P2`. The overall item is not release-complete yet because the planned exporter, smoke checks, and Bunny publication phases remain unimplemented.
