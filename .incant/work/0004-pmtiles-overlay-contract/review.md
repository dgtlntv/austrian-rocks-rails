---
id: "0004"
slug: pmtiles-overlay-contract
stage: review
reviewed: 2026-06-07
commit: 7e4b5ada
---

# Pmtiles Overlay Contract — review

### Strengths
- docs/map_tiles.md:3 and `.gitignore:29` — the contract is present as the spec-requested ignored `/docs/` artifact rather than a committed file; the fresh P1 gate passed with `P1 quality gate passed: ignored docs contract exists, includes walking_paths, and documents native max zoom`.
- docs/map_tiles.md:40-docs/map_tiles.md:159 — all ten required source layers are enumerated with geometry, stable IDs, required/optional properties, and navigation guidance; no circuit layer/property appears in the contract.
- docs/map_tiles.md:29-docs/map_tiles.md:36 — the PMTiles source-layer vs later MapLibre style-layer distinction is clear, including label/fill/outline/line usage.
- docs/map_tiles.md:121-docs/map_tiles.md:144 — POIs are included, `googleUrl` is treated as the allowed external URL, and `accessAreasJson` is explicitly documented as scalar JSON metadata rather than route geometry.
- .incant/work/0004-pmtiles-overlay-contract/plan.md:21-.incant/work/0004-pmtiles-overlay-contract/plan.md:23 — the phase records fresh verification evidence, and I re-ran the documented gate successfully during review.

### Blocker
- None.

### Major
- docs/map_tiles.md:118 and .incant/work/0004-pmtiles-overlay-contract/plan.md:74 — both say the exporter will use `WalkingPath.published`, but the delivered `0007` model currently defines no `scope :published` (app/models/walking_path.rb:1-app/models/walking_path.rb:38). Implementing P2 literally will fail with `NoMethodError`, and P1's source-alignment contract is therefore not aligned with the source it claims to consume. Fix by either updating the contract/plan to say records where `published` is true, or explicitly adding a tested P2 step to introduce `scope :published, -> { where(published: true) }` before the exporter calls it. status: open

### Minor
- .incant/work/0004-pmtiles-overlay-contract/plan.md:46-.incant/work/0004-pmtiles-overlay-contract/plan.md:47 — the Files touched notes still describe keeping the backlog/state at the plan stage, while the actual backlog is now `status:review phase:0004-P1` (.incant/backlog.md:5) and STATE says the item awaits review (.incant/STATE.md:6). Update these notes so the work artifact does not send the next implementer back to a stale stage. status: open

### Nit
- None.

### Verdict
Ready to release? **No** — one open major. The P1 contract is close and the gate passes, but the `WalkingPath.published` source mismatch should be corrected before starting P2 so the exporter plan is executable against the merged `0007` code.
