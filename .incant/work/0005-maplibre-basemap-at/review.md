---
id: "0005"
slug: maplibre-basemap-at
stage: review
reviewed: 2026-06-09
commit: 3fe63f60fcbcb62960467c8848a7c3669afdc921
---

# Migrate Rails web maps from Mapbox to MapLibre with basemap.at — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

### Strengths
- `config/map_styles/austrian_rocks_light.json:1` and `config/map_styles/austrian_rocks_dark.json:1` — both committed templates parse as MapLibre style version 8, include basemap.at sources/layers, the lower-opacity `gelände` layer, linked `Grundkarte: basemap.at` attribution, no default OpenStreetMap attribution, and Austrian Rocks layers for every `MapTiles::LayerContract.layer_names` source layer.
- `lib/map_tiles/style_materializer.rb:19` — style materialization is narrowly scoped and reproducible: it validates each template, rewrites only the Austrian Rocks source to the exact versioned PMTiles public URL, writes minified artifacts, and fails fast when layer-contract coverage is incomplete.
- `lib/map_tiles/configuration.rb:127` and `lib/map_tiles/configuration.rb:194` — the review-fix commit closes the prior URL/object-key sanitization gap by rejecting blank object keys, leading/trailing/empty object-key path segments, and `public_cdn_host` query/fragment components before building public PMTiles/style/manifest URLs.
- Fresh P1 re-review quality gate passed this session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test web bash -lc 'bin/rails test test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/style_materializer_test.rb'` → `13 runs, 115 assertions, 0 failures, 0 errors, 0 skips`.

### Blocker
- None.

### Major
- `lib/map_tiles/configuration.rb:127`, `lib/map_tiles/configuration.rb:202`, and `test/lib/map_tiles/configuration_test.rb:109` — previous finding: `public_url_for_object_key`/`public_cdn_base` allowed malformed blank/trailing-slash object keys and CDN host query/fragment components. The implementation now raises for those cases and the regression assertions pass in the fresh Docker/PostGIS gate. status: addressed

### Minor
- None.

### Nit
- None.

### Verdict
Ready to release? **No** — P1 has no open blocker or major findings and can proceed to the next planned phase, but the work item is not release-ready until P2–P4 are implemented and reviewed.
