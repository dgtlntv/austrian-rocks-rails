---
id: "0005"
slug: maplibre-basemap-at
stage: review
reviewed: 2026-06-09
commit: a1469a7b8d903673289d1e694e10c4ab320daf03
---

# Migrate Rails web maps from Mapbox to MapLibre with basemap.at — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

### Strengths
- `app/javascript/controllers/map_controller.js:54`, `app/javascript/controllers/map_controller.js:87`, and `app/javascript/controllers/map_controller.js:112` — the web map registers PMTiles, fetches the current release manifest with `cache: "no-store"`, selects the configured style, and initializes MapLibre with hash sharing and Austria bounds, satisfying the central no-Mapbox runtime migration path.
- `app/javascript/controllers/map_controller.js:157`, `app/javascript/controllers/map_controller.js:316`, and `app/javascript/controllers/map_controller.js:418` — contribution-request rendering remains a web-only dynamic GeoJSON overlay with grouped popup rows, keeping it out of the shared mobile style JSONs as required.
- `app/javascript/controllers/map_controller.js:374`, `app/javascript/controllers/map_controller.js:401`, and `app/javascript/controllers/map_controller.js:484` — problem and POI popup content is built with safe DOM/text APIs, problem IDs are URL-encoded, and POI links are constrained to HTTP(S), addressing the spec's untrusted-feature-property security concern.
- `lib/map_tiles/bunny_publisher.rb:40`, `lib/map_tiles/bunny_publisher.rb:104`, and `lib/map_tiles/release_manifest.rb:22` — publication now materializes versioned PMTiles/light/dark style artifacts, verifies immutable assets before publishing the current manifest, and keeps the manifest as the only moving pointer.
- `lib/map_tiles/configuration.rb:117` and `lib/map_tiles/configuration.rb:180` — object-key and CDN-host validation rejects blank/empty/traversal segments, credentials, paths, query strings, and fragments, covering the configured release URL trust boundary.
- `config/map_styles/austrian_rocks_light.json:27` and `config/map_styles/austrian_rocks_light.json:82` — the shared style carries linked `Grundkarte: basemap.at` attribution and Austrian Rocks PMTiles overlay layers rather than duplicating overlay styling in Rails JavaScript.
- `a1469a7b` — P4 is now committed with an incant phase-token subject (`incant 0005-P4: verify MapLibre release gates`), and `plan.md` records the final automated gate plus stale-reference search, addressing the prior traceability concern about reviewing uncommitted P4 work.
- Fresh review gate passed in Docker/PostGIS this session: `bin/rails db:prepare && bin/rails test test/lib/map_tiles && bin/rails test && bin/importmap audit && bin/rubocop -f github && bin/brakeman --no-pager` → `test/lib/map_tiles`: `62 runs, 1405 assertions, 0 failures, 0 errors, 0 skips`; full suite: `190 runs, 2004 assertions, 0 failures, 0 errors, 0 skips`; `bin/importmap audit`: `No vulnerable packages found`; RuboCop reported no offenses; Brakeman reported `Security Warnings: 0`.
- Fresh stale-runtime/latest search passed: `rg -n 'api\.mapbox\.com|mapbox://|MAPBOX_DEV_ACCESS_KEY|data-mapbox-token|latest_object_key|austrian-rocks-latest|latest\.pmtiles' app config lib test README.md docs/map_tiles.md` → no output.

### Blocker
- `app/javascript/controllers/map_controller.js:376`, `app/javascript/controllers/map_controller.js:380`, and `app/javascript/controllers/map_controller.js:476` — previous finding: PMTiles problem features use `problemId`, not Rails deep-link `id`, which made public-map problem popups link to `problem_id=undefined`. The implementation now resolves either `id` or `problemId`, URL-encodes the selected value, and only emits a link when an ID is present; the regression coverage remains in `test/controllers/map_controller_test.rb:43`. status: addressed

### Major
- `config/map_tiles.yml:10`, `config/map_styles/README.md:3`, and `config/map_styles/austrian_rocks_light.json:29` — the release still depends on Bergwerk GIS's testing-only basemap.at style/tile stack, and the README explicitly says the endpoint is “not treated as production-ready” and must be switched before production release. That conflicts with the spec's production migration goal and the requirement for Austrian Rocks-owned basemap.at-derived shared styles suitable for web/mobile release. Fix: switch the committed light/dark styles and config to an official production-ready basemap.at vector source, or get the spec/acceptance criteria explicitly revised before release. status: open
- `.incant/work/0005-maplibre-basemap-at/manual-smoke.md:7`, `.incant/work/0005-maplibre-basemap-at/manual-smoke.md:10`, `.incant/work/0005-maplibre-basemap-at/manual-smoke.md:32`, `.incant/work/0005-maplibre-basemap-at/manual-smoke.md:52`, and `.incant/work/0005-maplibre-basemap-at/manual-smoke.md:80` — the manual smoke artifact is checked off but still has blank environment/browser/data fields and empty observation blocks; its only summary says the items were “marked passed per human request.” That is not enough documented evidence for browser-only requirements such as exact route URLs, attribution clickability, filter/search behaviour, and network proof that Mapbox is absent. Fix: rerun or complete the smoke record with concrete base URL, browser/version, dataset, exact area/problem URLs, and observed console/network/interactions. status: open
- `.incant/work/0005-maplibre-basemap-at/plan.md:19`, `.incant/work/0005-maplibre-basemap-at/plan.md:27`, and `a1469a7b` — previous finding: P4 was being reviewed while uncommitted and the plan still said the phase was in progress. P4 is now committed, the Status block says `0005-P4` is complete, and the final automated gate/stale search evidence is recorded. status: addressed
- `lib/map_tiles/bunny_publisher.rb:49`, `lib/map_tiles/bunny_publisher.rb:50`, and `lib/map_tiles/bunny_publisher.rb:52` — previous finding: the publisher uploaded the non-cached current manifest before public HEAD verification of all versioned assets, risking a manifest that points clients at a broken release. The implementation now uploads/verifies the versioned PMTiles/light/dark styles first, uploads/verifies the manifest last, and the regression test covers style HEAD failure. status: addressed
- `lib/map_tiles/configuration.rb:117`, `lib/map_tiles/configuration.rb:180`, and `test/lib/map_tiles/configuration_test.rb:108` — previous finding: blank/trailing/empty object-key segments and CDN host query/fragment components were accepted. The implementation now rejects those cases and the map-tile suite passed in the fresh review gate. status: addressed

### Minor
- None.

### Nit
- None.

### Verdict
Ready to release? **No** — P4 is now committed and the traceability issue is addressed, but two open major findings remain: the testing-only Bergwerk basemap dependency and insufficient concrete manual smoke evidence. Return to `/incant:implement 0005` to resolve or explicitly revise those before final release.
