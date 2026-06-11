---
id: "0006"
slug: maplibre-web-interactions
stage: review
reviewed: 2026-06-11
commit: ecdbd687
---

# Maplibre Web Interactions — final review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

> Scope of this pass: **final release review** through commit `ecdbd687` on branch `incant/0006-maplibre-web-interactions`, against spec base `caafed8c`. The user stated in chat that the manual smoke was run, but the release artifact is still blank.

### Strengths
- lib/map_tiles/geojson_exporter.rb:285-329,349-384 — the exporter centralizes card cascade semantics, aggregate problem stats, `gradeHistogramJson`, cover/guidebook/parking fields, and main-cluster bounds in tile properties, which keeps web/mobile clients on one data contract.
- lib/map_tiles/release_manifest.rb:37-45,70 — the manifest now includes and validates `spriteUrl` alongside PMTiles and styles, matching the immutable sprite publication requirement.
- app/javascript/map/selection.js:1-35,37-84 — selection uses dedicated filtered `-selected` layers, a `-1` sentinel, base-symbol exclusion, and no `feature-state`, aligning with the approved MapLibre Native-compatible interaction model.
- app/javascript/map/info_card.js:12-30,62-107,159-180,293-300,538-545 — card rendering uses safe DOM construction, HTTP(S)-only URL checks, and `noopener noreferrer` outbound links for untrusted tile properties.
- app/javascript/map/info_card.js:358-428 — the grade-distribution chart handles the new sparse histogram property and preserves a text grade-range fallback for older tiles.
- app/javascript/controllers/map_controller.js:377-390,488-518,536-583,691-699,821-834 — search/deep-link selection, region/main-cluster bounds CTAs, removal of the old zoom-15 clamp, and bottom-sheet/docked-card visibility nudges are implemented defensively.
- .incant/work/0006-maplibre-web-interactions/plan.md:26 — recorded automated release-gate evidence is current; I re-ran it in this review session: `bin/rails db:prepare && bin/rails test && bin/importmap audit && bin/rubocop -f github && bin/brakeman --no-pager` → 231 runs, 3383 assertions, 0 failures/errors; importmap audit clean; rubocop clean; Brakeman no warnings. The stale-reference sweep only matched negative test assertions/comments, not production references.

### Blocker
- .incant/work/0006-maplibre-web-interactions/manual-smoke.md:9-54 — the approved acceptance criteria require “a manual browser smoke record exists with environment/browser/data/route URLs and observations,” and P6 step 2/P6 quality gate require the completed record. The file is still an empty checklist: run metadata, release/style URLs, and every observation cell are blank. The user’s chat note that the smoke was checked is useful evidence, but it does not satisfy the committed release artifact or leave reproducible observations for mobile/web follow-up. Fix: fill this file with the actual environment/browser/version/data/URLs and pass/fail observations from the smoke run, or explicitly record a human waiver with the rationale before re-review. status: open

### Major
(none)

### Minor
- docs/map_tiles.md:170,225,234,243,252,261,270 — the interaction contract mentions `gradeHistogramJson`, but the per-source-layer optional-property tables for areas/area_hulls/clusters/cluster_hulls/regions/region_hulls omit it, and the CTA prose still names the old “Show on map” copy after P7 renamed the UI to “Zoom to place” / “Zum Ort zoomen.” This is not a runtime bug, but it weakens the mobile contract documentation delivered by requirement 13. Fix: add `gradeHistogramJson` to those optional-property lists and describe the CTA by semantics or current copy. status: open

### Nit
(none)

### Verdict
Ready to release? **No** — one open blocker: the manual smoke record acceptance artifact is still blank. The code and automated gates look release-ready once that record/waiver is added; the documentation-table cleanup is minor and can be fixed or consciously deferred.
