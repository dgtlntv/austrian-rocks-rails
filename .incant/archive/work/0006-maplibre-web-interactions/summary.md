---
id: "0006"
slug: maplibre-web-interactions
stage: archived
completed: 2026-06-11
commit: 10b3a734
---

# Summary — Polish web map interactions on MapLibre

## What was built

- Replaced text-only map drill-in targets with sprite-driven pins and labels for regions, clusters, areas, and POIs in both shared MapLibre styles.
- Added selected-state layers filtered by feature id (no `feature-state`) plus web selection animations and responsive info cards for climbing entities, problems, and POIs.
- Added card data to the tile contract: warnings, guidebooks, parking links, cover photos, problem counts, grade ranges/histograms, and region main-cluster bounds, with cascade semantics resolved during tile export.
- Added guidebook/admin data entry, warning fields on clusters/regions, and parking/guidebook associations for regions, clusters, and areas.
- Published an Austrian Rocks sprite through the existing immutable Bunny release flow and removed the Bergwerk sprite dependency from the shared styles.
- Fixed the Maltatal/region drill-in camera target by using main-cluster bounds where available and removing the old zoom-15 clamp.
- Reworked the area-hull → boulder transition as a z14→z15 crossfade.
- Rewired search and deep links to open the selected card model and removed the legacy problem/POI popups.
- Documented the shared style/tile/interaction contract for mobile consumers.

## Deviations from spec

- Sprite delivery was implemented as a single self-hosted Austrian Rocks sprite rather than MapLibre multi-sprite, to keep MapLibre Native compatibility low-risk and remove the Bergwerk test endpoint dependency.
- Pin artwork changed during implementation from classic teardrops to Apple-Maps-style resting discs plus selected balloons; region, cluster, and area now intentionally share the same two-peaks glyph because distinct hierarchy glyphs did not carry user meaning.
- The region/cluster/area card stat line evolved from `problemCount + gradeMin–gradeMax` text to a grade-distribution chart backed by `gradeHistogramJson`, with a text fallback for older tiles.
- Problem cards gained topo preview tile properties/rendering; follow-up polish for the preview frame, grade emphasis, and media close buttons was captured separately.
- The required manual smoke artifact records a human waiver for missing detailed observations rather than fabricated post-hoc smoke notes.

## Key decisions

- Selection uses dedicated `-selected` layers with id filters and a `-1` sentinel instead of `feature-state`, preserving the approved web/mobile contract.
- Card UI treats tile properties as untrusted data and builds DOM with safe text/element APIs; outbound links are http(s)-allowlisted.
- Card inheritance is baked at export time (own value → parent chain), so every client renders the same effective warning, guidebook, and parking information.
- Region “Zoom to place” uses main-cluster bounds with full-region bounds as the fallback.
- Crossfade is declarative in shared styles (boulders hidden before z14; hull/boulder opacities complementary through z15).

## Links

- Branch: `incant/0006-maplibre-web-interactions`
- Commit range: `caafed8c..10b3a734`
- Key commits: `d0c11809` P1 data/admin, `7c50fdaa` P2 exporter contract, `941151c8` P3 sprite/style/crossfade, `15879a50` P4 selection/card runtime, `6aa1c923` P5 search/deep-link rewiring, `ecdbd687` P7 polish + histogram, `10b3a734` smoke waiver/docs cleanup.
- PR: not opened by incant.

## Sessions

- `019eb0c0-f4a1-75df-8d3f-ee3426f38ed8`
- `019eb1e0-3985-71ff-a802-3a4ba4941d99`
- `019eb1e7-5eb8-7f9a-aa81-ac2d74100fab`
- `019eb22a-a20f-70b6-a695-3cd737cb21c1`
- `019eb23b-c20b-72f1-8b2a-ba4349d6338e`
- `019eb243-3484-731b-9f4a-7273a5a565de`
- `019eb246-3688-7352-a475-e9ff407cbd4f`
- `019eb24b-a2ae-79b0-b084-7a391bc8a6f0`
- `019eb24f-d4d5-7924-8b07-dfb50c071c03`
- `019eb253-3493-7774-b839-2e5b8f2d3c85`
- `019eb256-1d62-7108-9f9c-9e78889c5b55`
- `019eb28d-0e3f-7530-90bf-346298d7f14a`
- `019eb5cf-e2ad-7838-844e-d915ee2086c3`
- `019eb5dd-5fcb-7d07-8b96-b3f51758b652`
- `019eb5e4-dd9b-7439-ba62-29cd664dba58`

## Follow-ups

Captured in `.incant/inbox.md`:

- Replace the Bergwerk GIS testing-only basemap.at vector/tile endpoint before production release.
- Re-run and document concrete manual browser smoke evidence for the MapLibre/basemap.at Rails maps.
- Self-host Inter glyphs/fonts through the map tile/style release flow.
- Polish problem topo previews: explicit 4:3 frame/viewBox, more prominent grades, and high-contrast media close buttons.
