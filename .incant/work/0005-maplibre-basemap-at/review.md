---
id: "0005"
slug: maplibre-basemap-at
stage: review
reviewed: 2026-06-09
commit: e5833dfb9b608d55c24ef895368ff57b00fee409
---

# Migrate Rails web maps from Mapbox to MapLibre with basemap.at — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

### Strengths
- `config/map_styles/austrian_rocks_light.json:1` and `config/map_styles/austrian_rocks_dark.json:1` — both committed templates parse as MapLibre style version 8, include basemap.at sources/layers, the lower-opacity `gelände` layer, linked `Grundkarte: basemap.at` attribution, no default OpenStreetMap attribution, and Austrian Rocks layers for every `MapTiles::LayerContract.layer_names` source layer.
- `lib/map_tiles/style_materializer.rb:19` — style materialization is narrowly scoped and reproducible: it validates each template, rewrites only the Austrian Rocks source to the exact versioned PMTiles public URL, writes minified artifacts, and fails fast when layer-contract coverage is incomplete.
- `lib/map_tiles/configuration.rb:43` — the old `latest_object_key` helper is removed and the new PMTiles/style/manifest key helpers centralize release URL construction instead of scattering literals.
- Fresh P1 quality gate passed this session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test web bash -lc 'bin/rails test test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/style_materializer_test.rb'` → `13 runs, 108 assertions, 0 failures, 0 errors, 0 skips`.

### Blocker
- None.

### Major
- `lib/map_tiles/configuration.rb:127` and `lib/map_tiles/configuration.rb:190` — `public_url_for_object_key`/`public_cdn_base` still allow malformed public URL inputs that the P1 plan and spec require to be sanitized. A blank object key returns `https://cdn.example.test/`, trailing slash object keys are silently normalized by `String#split`, and a CDN host with query/fragment components is accepted, producing URLs such as `https://cdn.example.test?token=x/maps/austrian-rocks-2026-06-09.pmtiles` instead of raising. This leaves the versioned PMTiles/style/manifest URL contract with an avoidable sanitization gap before P2 publishes and writes manifests. Fix: reject blank object keys and object keys with leading/trailing/empty segments, and reject `public_cdn_host` values with query or fragment components; add regression tests for those cases. status: open

### Minor
- None.

### Nit
- None.

### Verdict
Ready to release? **No** — one open major finding in the P1 URL-sanitization contract must be fixed before this phase should proceed. The style templates and materializer otherwise align well with the approved plan and passed the fresh Docker/PostGIS quality gate.
