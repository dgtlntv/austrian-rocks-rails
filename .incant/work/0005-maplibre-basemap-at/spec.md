---
id: "0005"
slug: maplibre-basemap-at
branch: incant/0005-maplibre-basemap-at
title: Migrate Rails web maps from Mapbox to MapLibre with basemap.at
stage: spec
status: awaiting-approval
created: 2026-06-08
commit: 7b6ff0f8
updated: 2026-06-09
---

# Migrate Rails web maps from Mapbox to MapLibre with basemap.at

## Goal
Replace the Rails web map runtime with MapLibre GL and Austrian Rocks-owned basemap.at-based styles while preserving the current public and contribution map behaviours without Mapbox runtime dependencies.

## Context & codebase fit
The current Rails map lives in `app/views/map/index.html.erb`, `app/views/layouts/map.html.erb`, and `app/javascript/controllers/mapbox_controller.js`. It loads Mapbox GL JS/CSS directly from `api.mapbox.com`, injects a Mapbox access token into the page, uses a Mapbox-hosted style and vector source, and implements map controls, URL hash sharing, area/problem centering, popups, grade filters, search-controller events, and a contribution-request overlay.

The existing map routes are `/:locale/map(/:slug)` for the public map and `/:locale/mapping/map(/:slug)` for the contribution map. The contribution map is linked from `app/views/mapping/areas/index.html.erb`, `app/views/mapping/problems/index.html.erb`, `app/views/mapping/problems/show.html.erb`, and admin contribution-request pages. It uses dynamic GeoJSON from `Mapping::ContributionRequestsController#index` to draw open contribution-request markers; it is an overview/helper map, not an editor.

The PMTiles build/publish stack already exists under `lib/map_tiles/`, `config/map_tiles.yml`, `bin/build_pmtiles`, and `test/lib/map_tiles/`. Its layer contract currently defines `problems`, `boulders`, `areas`, `area_hulls`, `clusters`, `cluster_hulls`, `regions`, `region_hulls`, `walking_paths`, and `pois`. The publisher still contains stale `latest.pmtiles` behaviour (`latest_object_key` and latest uploads), which conflicts with the desired CDN-safe manifest strategy and must be removed as part of this work.

A previous MapLibre exploration showed the desired direction: MapLibre GL JS, PMTiles protocol registration, basemap.at vector styling, a lower-opacity `gelände`/terrain layer, and Austrian Rocks PMTiles overlay layers. This item turns that direction into the production Rails map and shared style/publishing contract.

## Requirements
1. The public Rails map routes `/:locale/map` and `/:locale/map/:slug` render with MapLibre GL JS, load without any Mapbox GL JS/CSS, Mapbox access token, `mapbox://` style URL, or `api.mapbox.com` runtime dependency, and keep URL hash sharing enabled.
2. The Rails map preserves the current no-regression behaviours: default Austria bounds, area bounds centering, `pid` problem centering, search-controller `gotoproblem` and `gotoarea` events, scale/navigation/geolocation controls, German control labels, history cleanup on user map movement, problem popups, POI popups, area/cluster/region drill-in clicks, and grade filtering for problem layers.
3. The contribution map route `/:locale/mapping/map(/:slug)` remains available and preserves its current web-only behaviour: it loads open contribution requests from `mapping_requests_path(format: :geojson)`, draws grouped contribution markers and labels, opens popups linking to mapping problems, and centers `pid` deep links on estimated contribution locations.
4. The repo provides two Austrian Rocks-owned MapLibre style JSONs, light and dark, initially derived from basemap.at’s `https://mapsneu.wien.gv.at/basemapvectorneu/root.json`; the Rails web map uses the light style only in this item, with no automatic dark-mode selection and no manual style switcher.
5. Each shared style JSON includes the full map stack needed by web, iOS, and Android: basemap.at vector layers, the lower-opacity `gelände`/terrain-shading layer, correct public attribution, the Austrian Rocks PMTiles vector source, and Austrian Rocks layer styling for every source layer in `MapTiles::LayerContract.layer_names` that may be present in the published PMTiles.
6. Austrian Rocks overlay styling is defined in the shared style JSONs, not duplicated separately in Rails JavaScript, so web/iOS/Android can consume the same source/layer styling. Rails JavaScript may still attach web-only event handlers and dynamic contribution overlays.
7. The map publishing contract uses immutable versioned releases: each publish creates a versioned PMTiles object and matching versioned light/dark style JSON objects whose PMTiles source points to that exact versioned PMTiles URL.
8. A non-cached JSON manifest is published for clients; it identifies the current map release version, the current versioned PMTiles URL, and the current versioned light/dark style JSON URLs. Clients update by fetching this manifest instead of using a mutable `latest.pmtiles` object.
9. All `latest.pmtiles` behaviour is removed from the stack: no `latest_object_key`, no latest PMTiles upload, no latest PMTiles verification, no tests expecting latest uploads, and no documentation or config that tells clients to use `austrian-rocks-latest.pmtiles`.
10. Published object keys, manifest URLs, style URLs, and PMTiles version strings are sanitized so malformed versions or configured prefixes cannot create path traversal, unexpected object keys, or invalid public URLs.
11. The implementation keeps the existing PMTiles schema and export contract intact unless a layer-style requirement exposes a missing property that must be explicitly added and tested through `MapTiles::LayerContract`.
12. The migration is covered by automated tests for map-tile configuration/publishing/manifest behaviour and Rails map markup, plus a documented manual browser smoke check for MapLibre rendering and no-regression interactions.

## In scope / Out of scope
**In scope:**
- Replace the Rails map runtime from Mapbox GL to MapLibre GL.
- Add PMTiles protocol support needed by the Rails web map.
- Add light and dark Austrian Rocks-owned MapLibre style JSONs based on basemap.at, including the `gelände`/terrain-shading stack and Austrian Rocks PMTiles layers.
- Publish/version the style JSONs together with PMTiles and publish a non-cached current-release manifest.
- Remove all stale `latest.pmtiles` publishing/config/test behaviour.
- Preserve existing public map and contribution map interactions at their current capability level.
- Update README or map-tile documentation so web/mobile clients know to read the manifest and then load a versioned style URL.

**Out of scope:**
- Rebuilding map interactions beyond no-regression parity — reason: backlog item `0006` is reserved for richer MapLibre interactions.
- Implementing iOS or Android app code changes — reason: this item defines and publishes the shared style/manifest contract those apps can consume later.
- Automatic dark-mode selection or a user-facing style switcher — reason: the rest of the website does not support dark mode yet.
- A full custom cartographic redesign beyond the initial light/dark basemap.at-derived styles — reason: this item is the migration foundation.
- Turning the contribution map into an editor or drawing tool — reason: the existing route is an overview/helper map and editing is not part of this migration.
- Changing PMTiles data generation semantics unrelated to rendering the existing layer contract — reason: data pipeline changes should stay separate unless required by a tested style property.

## Approach
Use MapLibre GL as the browser map runtime and load a shared Austrian Rocks light style for Rails web. The style JSONs become the cross-platform map definition: they own basemap.at sources/layers, the lower-opacity `gelände` layer, the Austrian Rocks PMTiles source, and all Austrian Rocks layer styling. Rails JavaScript owns runtime concerns only: MapLibre setup, PMTiles protocol registration, no-regression event handlers, popups, filters, search events, route-specific centering, and dynamic contribution-request overlays.

Extend the existing `MapTiles` publishing stack so a map release is atomic: build/export/smoke the versioned PMTiles, materialize light and dark style JSONs for the same version with the exact versioned PMTiles URL, upload the immutable PMTiles and style JSONs, and upload a small non-cached manifest that points to the current release. Remove the mutable latest PMTiles path entirely instead of trying to tune CDN cache invalidation around it.

Rejected alternatives: using an external basemap.at style URL directly was rejected because Austrian Rocks needs control over light/dark styles and a shared web/mobile stack; runtime PMTiles URL injection into otherwise-static style JSONs was rejected because versioned style JSONs are small, cache-friendly, client-simple, and make each map release reproducible.

## Considerations
### Config vs code
Configuration must stay out of scattered JavaScript literals. The configurable map-release values are the public tile CDN host, object prefixes for PMTiles, style JSONs, and manifest, basemap.at source endpoints, default Rails style choice (`light`), and `gelände` opacity. These belong in committed configuration such as `config/map_tiles.yml`, a dedicated map-style config file, and the style JSONs themselves. Rails code should consume those values through helpers/config objects and generated data attributes rather than hardcoding release URLs in controllers or Stimulus logic. Defaults are: light style for Rails web, dark style published but unused by Rails web, basemap.at-derived styling, versioned PMTiles/style objects, and a non-cached manifest pointer.

### Security
This migration removes the browser-exposed Mapbox token requirement. All map styles, PMTiles, and manifests are public data and must not contain credentials or secrets. Treat manifest/style JSON, PMTiles feature properties, dynamic contribution GeoJSON, and basemap.at network responses as data crossing trust boundaries: version and object-key inputs must be sanitized; popup content must be escaped or assembled through safe DOM/text APIs instead of interpolating untrusted properties into raw HTML; and published PMTiles properties must continue to exclude app URL fields except the already-permitted `googleUrl`. The blast radius of a bad map release should be limited to map rendering by using immutable versioned objects and a manifest rollback path.

### Testability
Automated tests should cover the durable contract: `bin/rails test test/lib/map_tiles` for configuration, publishing, manifest, style materialization, layer contract, and stale latest-removal behaviour; focused Rails controller/view tests for map markup proving MapLibre assets/data attributes are present and Mapbox tokens/assets are absent; and existing relevant controller tests for contribution GeoJSON. `bin/importmap audit`, `bin/brakeman --no-pager`, and `bin/rubocop -f github` remain security/style gates. Because there is no JavaScript unit-test harness in the repo today, browser-only behaviours need a documented manual smoke check in this item: load `/en/map`, `/de/map`, an area map, a `pid` deep link, and `/en/mapping/map`; verify tiles, controls, popups, filters, search events, hash/history behaviour, contribution markers, and console/network errors.

### Code documentation
New or changed JavaScript source files must include concise file-level JSDoc describing the controller’s responsibility, and each function should have accurate JSDoc for parameters/returns where applicable. Ruby map-release/publisher classes should document non-obvious invariants: immutable PMTiles/style objects, why `latest.pmtiles` is forbidden, and why the manifest is the only moving pointer. Style JSON generation or template files should include a short README explaining how the light/dark styles relate to basemap.at, the `gelände` layer, the Austrian Rocks PMTiles source, and mobile client consumption. Avoid noisy comments that restate obvious code.

## Acceptance criteria
- [ ] `/en/map` loads with MapLibre GL, visible basemap.at-derived basemap, `gelände` shading, Austrian Rocks overlays, and no browser request to Mapbox JS/CSS/styles/tiles.
- [ ] `/en/map/:slug`, `/en/map?pid=<id>`, search `gotoproblem`, search `gotoarea`, popups, controls, URL hash sharing, history cleanup, and grade filters match current user-visible behaviour.
- [ ] `/en/mapping/map` still loads dynamic contribution-request markers and popups from `mapping_requests_path(format: :geojson)` without adding that dynamic overlay to the shared mobile style JSONs.
- [ ] Light and dark shared style JSONs exist, validate as MapLibre style version 8 JSON, include basemap.at vector styling, `gelände`, attribution, the Austrian Rocks PMTiles source, and layers for the `MapTiles::LayerContract` source layers.
- [ ] Publishing a map release uploads one versioned PMTiles object, one versioned light style JSON, one versioned dark style JSON, and one non-cached manifest pointing at those versioned objects.
- [ ] The codebase has no remaining `latest.pmtiles` object-key generation, upload, verification, test expectation, or client/documentation guidance.
- [ ] Automated tests and documented manual smoke checks provide fresh pass/fail evidence for the migration before implementation is considered complete.

## Risks & open questions
- Basemap.at endpoint or licensing details may require attribution or URL adjustments; implementation must verify against the current basemap.at terms and style metadata.
- Mobile SDK PMTiles protocol details may differ from web MapLibre; this item publishes standard style/manifest URLs, while mobile app integration remains a later consumer task.
- The current repo lacks JavaScript unit tests, so some interaction parity will rely on manual browser smoke evidence unless a JS/system-test harness is introduced during planning.
- No open product questions remain for this spec.
