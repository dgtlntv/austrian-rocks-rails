---
id: "0005"
slug: maplibre-basemap-at
stage: review
reviewed: 2026-06-09
commit: 4a9dd0e77ff84b7035a8587a7fbf7cbb2ccc5611
---

# Migrate Rails web maps from Mapbox to MapLibre with basemap.at — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

### Strengths
- `app/views/map/index.html.erb:21` and `app/views/map/index.html.erb:25` — the public/contribution map markup now uses the neutral `map` controller and passes the configured manifest/default style through data attributes instead of exposing a Mapbox token or hardcoded style URL, matching the config-vs-code and no-Mapbox requirements.
- `app/javascript/controllers/map_controller.js:54`, `app/javascript/controllers/map_controller.js:87`, and `app/javascript/controllers/map_controller.js:112` — the runtime registers PMTiles, fetches the manifest with `cache: "no-store"`, selects the configured style, and initializes MapLibre with hash sharing and Austria bounds, which is the core migration path promised in P3.
- `app/javascript/controllers/map_controller.js:157` and `app/javascript/controllers/map_controller.js:413` — contribution-request rendering remains web-only and the popup rows are built with DOM/text APIs instead of raw HTML interpolation.
- `app/javascript/controllers/map_controller.js:396` and `app/javascript/controllers/map_controller.js:443` — POI URLs are constrained to HTTP(S), and malformed contribution problem payloads fail closed instead of throwing during popup construction.
- `test/controllers/map_controller_test.rb:55` and `test/controllers/map_controller_test.rb:65` — focused markup coverage proves the rendered map pages include MapLibre/importmap hooks and exclude Mapbox runtime/token markers.
- Fresh P3 quality gate passed this session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test web bash -lc 'bin/rails test test/controllers/map_controller_test.rb test/controllers/mapping/contribution_requests_controller_test.rb && bin/importmap audit'` → `5 runs, 128 assertions, 0 failures, 0 errors, 0 skips`; `bin/importmap audit` reported `No vulnerable packages found`.
- Fresh no-Mapbox-runtime search found only negative test assertions: `rg -n 'api\.mapbox\.com|mapbox://|MAPBOX_DEV_ACCESS_KEY|data-mapbox-token|mapbox-gl\.js' app config lib test README.md docs/map_tiles.md` → matches only in `test/lib/map_tiles/style_materializer_test.rb` and `test/controllers/map_controller_test.rb` assertions.

### Blocker
- `app/javascript/controllers/map_controller.js:378`, `lib/map_tiles/layer_contract.rb:17`, and `lib/map_tiles/geojson_exporter.rb:75` — PMTiles problem features use `problemId`, not `id`, but clicked public-map problem popups build `/redirects/new?problem_id=` from `problem.id`. For features coming from the shared PMTiles style this produces a broken `problem_id=undefined` link, so the required problem-popup no-regression behaviour is not met. Fix by accepting both shapes (for example `problem.id ?? problem.problemId`) and add a regression check for PMTiles-style problem properties. status: open

### Major
- `lib/map_tiles/bunny_publisher.rb:49`, `lib/map_tiles/bunny_publisher.rb:50`, `lib/map_tiles/bunny_publisher.rb:52`, and `test/lib/map_tiles/bunny_publisher_test.rb:123` — previous finding: the publisher uploaded the non-cached current manifest before public HEAD verification of all versioned assets, risking a manifest that points clients at a broken release. The implementation now uploads and verifies the versioned PMTiles/light/dark styles first, uploads/verifies the manifest last, and asserts that `maps/current.json` is not uploaded when a versioned style HEAD check fails. status: addressed
- `lib/map_tiles/configuration.rb:127`, `lib/map_tiles/configuration.rb:202`, and `test/lib/map_tiles/configuration_test.rb:108` — previous finding: `public_url_for_object_key`/`public_cdn_base` allowed malformed blank/trailing-slash object keys and CDN host query/fragment components. The implementation rejects those cases and the regression assertions passed in the prior Docker/PostGIS gate. status: addressed

### Minor
- None.

### Nit
- None.

### Verdict
Ready to release? **No** — `0005-P3` has one open blocker: public-map PMTiles problem popups link to an undefined problem id. Return to `/incant:implement 0005`; after the blocker is fixed and re-verified, re-run review before proceeding toward P4/finalization.
