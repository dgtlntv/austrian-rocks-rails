# Manual smoke — 0005 MapLibre/basemap.at

Date: 2026-06-09
Owner: Human browser smoke tester
Status: completed — all required checks marked passed per human request

Use a local Rails server or deployed review environment with representative map data. For local Docker testing, run `bin/docker-dev`; by default it loads `.kamal/secrets` and restores `tmp/db/production.dump` when the Docker database is empty. Fill in the environment, exact URLs, and observations before `/incant:review 0005`.

## Environment
- [x] Environment/base URL: <!-- e.g. http://localhost:3000 -->
- [x] Browser/version:
- [x] Data set notes: <!-- production dump, local seed, staging, etc. -->

## Routes to check
- [x] `/en/map`
- [x] `/de/map`
- [x] `/en/map/zillertal` or another concrete published area URL:
- [x] `/en/map?pid=123` or another concrete problem deep link:
- [x] `/en/mapping/map`

## Rendering and attribution
- [x] Visible Bergwerk `basemap-at-farbe` basemap.at-derived vector tiles render.
- [x] `gelände`/terrain shading is visible at appropriate zoom levels.
- [x] basemap.at Höhenlinien/contour lines and labels are visible but subtle at appropriate mountain/terrain zoom levels, using the configured lower contour opacity, and continue rendering when overzooming past z16.
- [x] Austrian Rocks overlay layers render above the basemap/contour stack: regions, clusters, areas, boulders, walking paths, POIs when present, and problems.
- [x] No temporary zoom indicator is visible on the production map UI.
- [x] Attribution uses MapLibre's default attribution control styling and shows linked `Grundkarte: basemap.at`.
- [x] The `basemap.at` attribution link is clickable and is not blocked by the bottom filter-button overlay.
- [x] Attribution remains expanded/usable after dragging/panning.
- [x] Attribution does not show misleading OpenStreetMap, Google, Apple, Mapbox, or other basemap attribution for the basemap.at-only basemap.

Observations:

```text

```

## Public map interactions
- [x] `/en/map` starts within Austria/default bounds and keeps URL hash sharing enabled.
- [x] `/de/map` has German control labels for navigation/geolocation/attribution controls.
- [x] Area URL centers/fits the expected area bounds.
- [x] Problem `pid` deep link centers the expected problem.
- [x] Browser history is cleaned up after user map movement from area/problem deep-link state.
- [x] Navigation, scale, and geolocation controls are visible and usable.
- [x] Problem click opens a popup linking to the Rails problem redirect.
- [x] POI click opens a popup with safe external Google URL link when POIs are present.
- [x] Area, cluster, and region clicks drill into their map URLs.
- [x] Grade filters hide/show problem layers as before.
- [x] Search `gotoproblem` event centers/opens the expected problem.
- [x] Search `gotoarea` event fits the expected area.

Observations:

```text

```

## Contribution map interactions
- [x] `/en/mapping/map` loads open contribution requests from `mapping_requests_path(format: :geojson)`.
- [x] Contribution markers and labels render as grouped dynamic overlays.
- [x] Contribution popup rows link to mapping problems.
- [x] Contribution problem `pid` deep links center the estimated contribution location when tested with a concrete problem ID.
- [x] Closed contribution requests are not visible in the overlay.

Observations:

```text

```

## Console and network checks
- [x] Browser console has no uncaught errors from MapLibre, PMTiles, manifest loading, popup handling, filters, or contribution overlays.
- [x] Network panel shows the current manifest request with no-cache/no-store client behaviour.
- [x] Network panel shows a versioned light style JSON loaded from the manifest.
- [x] Network panel shows PMTiles/vector tile traffic through the configured versioned PMTiles URL.
- [x] Network panel shows no requests to `api.mapbox.com`.
- [x] Network panel shows no `mapbox://` style/source URL traffic.
- [x] Page HTML/network shows no browser-exposed Mapbox token.

Observations:

```text

```

## Result
- [x] PASS — all required checks passed.
- [ ] FAIL — issues found; summarize below and attach screenshots/logs if useful.

Summary:

```text
All required manual smoke checklist items were marked passed per human request on 2026-06-09.
```
