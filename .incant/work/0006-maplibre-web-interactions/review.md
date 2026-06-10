---
id: "0006"
slug: maplibre-web-interactions
stage: review
reviewed: 2026-06-10
commit: 941151c8
---

# Maplibre Web Interactions — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

> Scope of this pass: **phase gate for 0006-P3** through commit `941151c8`.
> Prior P1/P2 findings remain addressed/wontfix as previously recorded; P4–P6 and the remaining runtime/card/release acceptance criteria are reviewed at later gates / before release.

### Strengths
- lib/map_tiles/sprite_builder.rb:10-35,59-79 — the sprite pipeline is a small, documented raster-only builder that returns exactly the four MapLibre artifacts the publish flow needs, keeping SVG rasterisation out of release/test paths as planned.
- lib/map_tiles/sprite_builder.rb:41-56,82-90 and test/lib/map_tiles/sprite_builder_test.rb:21-111 — icon inventory validation catches missing 1x/2x pairs and non-RGBA read failures, while tests verify artifact keys, disjoint sheet rectangles, doubled retina dimensions, and empty-source failure paths.
- lib/map_tiles/configuration.rb:131-150,216-221 and lib/map_tiles/bunny_publisher.rb:42-57,144-156 — sprite object keys/URLs are versioned through a suffix allowlist, uploaded with immutable cache headers, HEAD-verified before the manifest pointer moves, and exposed in `current.json` via lib/map_tiles/release_manifest.rb:34-48.
- lib/map_tiles/style_materializer.rb:21-28,58-67 — materialization rewrites the template sprite URL to the versioned public base URL and fails fast if a template omits a sprite, preserving the no-runtime-`map.addImage` contract.
- config/map_styles/austrian_rocks_light.json:7374-7540 and config/map_styles/austrian_rocks_dark.json:7374-7540 — the hull/boulder handoff is now a real z14→z15 crossfade with boulders hidden before the window and hulls gone after it, matching the falsifiable part of the spec.
- config/map_styles/austrian_rocks_light.json:7733-8338 and config/map_styles/austrian_rocks_dark.json:7733-8338 — regions, clusters, areas, and POIs now use sprite-backed resting pins with labels beside them, plus cleared `-selected` sentinel layers using the selected icon variants and problem selected circle layer.
- test/lib/map_tiles/style_materializer_test.rb:20-40,294-348,351-377,391-406 — style assertions cover both committed templates and materialized output, including pin/selected layer structure, sentinel filters, crossfade invariants, and removal of Bergwerk sprite icon references from all `icon-image` declarations.
- config/map_styles/sprite/README.md:7-32 — the committed sprite inventory documents exact icon names, sizes, selected anchor semantics, and colors, which keeps the human-approved Apple-Maps-style deviation understandable for the P4 runtime work.
- docs/map_tiles.md:38-45 — the local ignored contract note (accepted by prior human decision for `/docs/`) documents sprite artifacts, manifest `spriteUrl`, immutability, and the absence of Bergwerk sprite dependencies.
- Commit history follows incant conventions (`incant 0006-P3: sprite pipeline, pin styles, crossfade`). Fresh P3 gate run in this session passed in Docker/PostGIS: `bin/rails db:prepare && bin/rails test test/lib/map_tiles && bin/rubocop lib/map_tiles test/lib/map_tiles -f github` → 76 runs, 2531 assertions, 0 failures/errors; rubocop exit 0. A separate icon-dimension check in the web container confirmed all 1x/2x PNGs are RGBA and exactly 20×20/40×40 resting or 34×45/68×90 selected.

### Blocker
(none)

### Major
(none)

### Minor
(none)

### Nit
(none)

### Verdict
Ready to release? **Yes** for the P3 phase gate. No open blockers or majors were found in the sprite pipeline, pin/selected style layers, or crossfade work; proceed to `/incant:implement 0006` for `0006-P4`.
