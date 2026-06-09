---
id: "0005"
slug: maplibre-basemap-at
stage: review
reviewed: 2026-06-09
commit: 393b71aaebedc78de2a5a581a3930158d7aa0e3e
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
- `app/javascript/controllers/map_controller.js:377`, `app/javascript/controllers/map_controller.js:381`, and `app/javascript/controllers/map_controller.js:476` — the P3 review fix now resolves popup links through `problem.id ?? problem.problemId`, preserving Rails deep-link popups while making PMTiles problem-feature popups link to a concrete `problem_id` instead of `undefined`.
- `test/controllers/map_controller_test.rb:43` — the regression check pins the PMTiles-compatible popup ID path and guards against reintroducing the old `problem.id`-only URL interpolation.
- Fresh P3 review-fix quality gate passed this session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test web bash -lc 'bin/rails test test/controllers/map_controller_test.rb test/controllers/mapping/contribution_requests_controller_test.rb && bin/importmap audit'` → `6 runs, 134 assertions, 0 failures, 0 errors, 0 skips`; `bin/importmap audit` reported `No vulnerable packages found`.
- Fresh no-Mapbox-runtime/latest-PMTiles search found only negative test assertions: `rg -n 'api\.mapbox\.com|mapbox://|MAPBOX_DEV_ACCESS_KEY|data-mapbox-token|mapbox-gl\.js|latest_object_key|austrian-rocks-latest|latest\.pmtiles' app config lib test README.md docs/map_tiles.md` → matches only in `test/lib/map_tiles/style_materializer_test.rb` and `test/controllers/map_controller_test.rb` assertions.

### Blocker
- `app/javascript/controllers/map_controller.js:377`, `app/javascript/controllers/map_controller.js:381`, `app/javascript/controllers/map_controller.js:476`, `lib/map_tiles/layer_contract.rb:17`, and `lib/map_tiles/geojson_exporter.rb:75` — previous finding: PMTiles problem features use `problemId`, not `id`, causing clicked public-map problem popups to link to `problem_id=undefined`. The implementation now resolves either Rails deep-link `id` or PMTiles `problemId`, only emits a link when an ID is present, and adds a regression check for the PMTiles-compatible popup path; the fresh P3 review-fix gate passed. status: addressed

### Major
- `lib/map_tiles/bunny_publisher.rb:49`, `lib/map_tiles/bunny_publisher.rb:50`, `lib/map_tiles/bunny_publisher.rb:52`, and `test/lib/map_tiles/bunny_publisher_test.rb:123` — previous finding: the publisher uploaded the non-cached current manifest before public HEAD verification of all versioned assets, risking a manifest that points clients at a broken release. The implementation now uploads and verifies the versioned PMTiles/light/dark styles first, uploads/verifies the manifest last, and asserts that `maps/current.json` is not uploaded when a versioned style HEAD check fails. status: addressed
- `lib/map_tiles/configuration.rb:127`, `lib/map_tiles/configuration.rb:202`, and `test/lib/map_tiles/configuration_test.rb:108` — previous finding: `public_url_for_object_key`/`public_cdn_base` allowed malformed blank/trailing-slash object keys and CDN host query/fragment components. The implementation rejects those cases and the regression assertions passed in the prior Docker/PostGIS gate. status: addressed

### Minor
- None.

### Nit
- None.

### Verdict
Ready to release? **No** — the open `0005-P3` blocker is addressed and this phase has no open blocker/major findings, but the item is not ready to close until planned P4 documentation, full release gates, and manual smoke evidence are completed. Continue with `/incant:implement 0005` for P4 rather than finalizing.
