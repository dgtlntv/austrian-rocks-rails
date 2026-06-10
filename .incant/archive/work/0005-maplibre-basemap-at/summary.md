---
id: "0005"
slug: maplibre-basemap-at
stage: archived
completed: 2026-06-10
commit: 8afca76a53434487ea46d8eaf275ecec06042882
---

# Summary — Migrate Rails web maps from Mapbox to MapLibre with basemap.at

## What was built
- Replaced the Rails web map runtime with MapLibre GL and PMTiles protocol loading, removing browser Mapbox JS/CSS/token/style/runtime dependencies from public and contribution map routes.
- Added shared Austrian Rocks light/dark MapLibre style templates with basemap.at-derived base styling, `gelände` shading, linked `Grundkarte: basemap.at` attribution, Austrian Rocks PMTiles overlay layers, and mobile-consumable style/manifest contracts.
- Changed the map tile publishing flow to immutable versioned PMTiles plus versioned light/dark style JSON objects, with `map_tiles/current.json` as the non-cached manifest pointer and no `latest.pmtiles` behavior.
- Preserved public map and contribution map behaviours: bounds/problem centering, search events, hash/history handling, controls, grade filters, safe problem/POI popups, drill-in clicks, and dynamic contribution-request markers/popups.
- Updated README/docs/tests/manual-smoke artifacts and passed the final Docker/PostGIS automated release gate plus stale Mapbox/latest-reference search.

## Deviations from spec
- The shared style currently depends on Bergwerk GIS's testing-only basemap.at vector/tile stack rather than a production-ready Austrian Rocks-owned/official basemap.at-derived endpoint. The human explicitly accepted this as `wontfix` for this release on 2026-06-09.
- Manual smoke evidence was marked passed per human request, but the artifact lacks concrete environment/browser/data/observation details. The human explicitly accepted this evidence level as `wontfix` for this release on 2026-06-09.

## Key decisions
- Keep the Rails route/controller shape and rename only the browser Stimulus surface from `mapbox` to `map`.
- Fetch the release manifest with `cache: "no-store"`; clients load immutable versioned style/PMTiles URLs from that manifest.
- Keep Austrian Rocks overlay styling in shared style JSONs so web/iOS/Android can consume one map contract; Rails JavaScript only wires runtime interactions and the web-only contribution overlay.
- Upload and verify immutable PMTiles/light/dark style objects before uploading/verifying the current manifest, limiting broken-release blast radius.
- Build popup/link content through safe DOM/text APIs and validate configured public object keys/URLs at the map-release boundary.

## Links
- Branch: `incant/0005-maplibre-basemap-at`
- Final commit: `8afca76a53434487ea46d8eaf275ecec06042882` (`incant 0005: accept P4 review findings`)
- Reviewed implementation commit: `a1469a7b8d903673289d1e694e10c4ab320daf03`
- PR: not created by incant.

## Sessions
- `019ea95d-71a8-79c0-93a9-5b3bb232f8ce`
- `019eab9d-908a-71a4-976b-5c367b10941b`
- `019eaba7-becd-70af-9d3a-79da15b9a55e`
- `019eabb2-ec95-705d-b862-cd03f26c7862`
- `019eabb8-3a5e-777d-8f43-944d52a41eb3`
- `019eabc3-682a-7311-8241-8628453b8942`
- `019eabca-6b0b-7cf8-956a-09697c57d4a0`
- `019eabdf-5f29-71f0-b066-e64a0eef2dc9`
- `019eabe5-2cab-7236-ba50-aad04fdd9eb6`
- `019eabea-9eb4-7c8c-a91f-1e3f56653ccc`
- `019eabed-df9a-7b82-9bb7-d34b20255a0b`
- `019eabf9-54bc-71a0-9b04-4cdf8a9ca4e9`
- `019eabfe-0370-79d0-8800-70f9e7140ce9`
- `019eac00-e8e6-7f2b-9c2e-582b70c35be3`
- `019eac04-9eda-7c50-b1c5-ffc804f7c325`
- `019eaced-ad16-715c-8762-b3618a8f4327`
- `019ead07-10db-74da-8508-3efc1fe0c462`
- `019eae5e-40a7-7f6d-9bef-015aa583b737`
- `019eb0c0-f4a1-75df-8d3f-ee3426f38ed8`

## Follow-ups
- Captured 2026-06-10: Replace Bergwerk GIS testing-only basemap.at vector/tile endpoint with an official production-ready basemap.at-derived style/source before production map release; keep linked `Grundkarte: basemap.at` attribution and the shared web/mobile style contract.
- Captured 2026-06-10: Re-run and document concrete manual browser smoke evidence for the MapLibre/basemap.at Rails maps, including environment/browser/data, route URLs, attribution clickability, filters/search/hash/history behaviour, contribution markers, console output, and network proof that Mapbox is absent.
