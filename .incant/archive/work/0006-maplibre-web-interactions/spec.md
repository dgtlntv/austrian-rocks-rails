---
id: "0006"
slug: maplibre-web-interactions
branch: incant/0006-maplibre-web-interactions
title: Polish web map interactions on MapLibre
stage: spec
status: in-progress
created: 2026-06-10
commit: caafed8c
updated: 2026-06-10
---

# Polish web map interactions on MapLibre

## Goal

Replace the text-tap drill-in on the Austrian Rocks MapLibre maps with a style-driven
pin → info-card interaction model for regions, clusters, areas, POIs, and problems —
defined in the shared style/tile contract so web and the future mobile apps render
identical pins from the same data — and fix the area-hull→boulder zoom handoff and the
region drill-in camera target (Maltatal bug).

## Context & codebase fit

- `app/javascript/controllers/map_controller.js` — the only map runtime. Today
  regions/clusters/areas are text-only symbol layers; clicking the text flies to bounds.
  `flyToBounds` (line ~510) clamps every drill-in to `zoom ≥ 15`, which is why clicking
  the Maltatal region text lands the camera in the empty middle of the region. Problem
  and POI clicks open small `maplibregl.Popup`s built with safe DOM APIs.
- `config/map_styles/austrian_rocks_light.json` / `…_dark.json` — shared style
  templates. Overlay layers: `regions` (symbol, ≤z9.5), `clusters` (z9–12), `areas`
  (z12–16), `areas-hulls` (z11–16), `boulders-outline` (z13+), `boulders` (z14+),
  `problems` (circle, z15+), `pois` (symbol). The hull/boulder zoom ranges overlap by
  2–3 levels at full opacity — the transition complaint. Glyphs and the sprite currently
  come from the Bergwerk GIS testing endpoint.
- `lib/map_tiles/geojson_exporter.rb` — bakes feature properties into the tile layers:
  ids, localized names, bounds (`southWest*`/`northEast*`), problem grade/steepness/
  height/landing/popularity. This is where card data and cascade resolution will live.
- `lib/map_tiles/bunny_publisher.rb` / `release_manifest.rb` / `style_materializer.rb` —
  the versioned-immutable-artifacts + `current.json` manifest release flow (0005/0009).
  The new sprite ships through this same flow.
- DB (`db/schema.rb`): `areas` already have `warning_de/en` and `description_de/en` and
  belong to clusters; `clusters` have `main_area_id` and belong to regions; `regions`
  have `main_cluster_id` (the Maltatal fix data already exists). `pois` (mostly
  `poi_type: parking`) have `google_url` but no association to climbing entities. No
  guidebook model and no ascents data exist.
- Admin CRUD exists under `app/controllers/admin/` + `app/views/admin/` for regions,
  clusters, areas, pois — the new fields are managed by extending these forms.
- `app/views/map/index.html.erb` + `_filters*.html.erb` — map page markup; the card UI
  mounts here. Search (`search_controller.js`) dispatches `gotoproblem`/`gotoarea`
  window events the map controller handles.

## Requirements

1. Regions, clusters, areas, and POIs render as sprite-based **pin icons with the name
   label beside the pin** (symbol layers with `icon-image` + `text-field`) in **both**
   shared light and dark styles, replacing the text-only symbols. The existing zoom
   laddering (regions → clusters → areas) is preserved; exact ranges may be tuned.
2. The pin icons ship in an **Austrian Rocks sprite published as a versioned object
   through the existing Bunny release flow** and referenced from the shared styles. Pin
   rendering must not depend on runtime-injected images (`map.addImage`), so mobile
   clients get pins from the style alone.
3. Tapping a pin or problem **selects** it: a dedicated single-feature "selected" layer
   (filtered by feature id, styled from the same sprite/style) grows smoothly on web
   (icon-size tween via requestAnimationFrame; circle-radius for problems) and the info
   card opens. Tapping the map elsewhere, closing the card, or selecting another feature
   deselects and restores the resting state. No `feature-state` usage (MapLibre Native
   compatibility).
4. The info card is **responsive**: below a defined breakpoint it is a bottom sheet
   sliding over the map; at/above it, a floating panel docked to one side. The selected
   pin stays visible (map padding adjusts when the sheet covers it).
5. Card content per entity type, all read from tile feature properties:
   - **Region/cluster/area:** name, cover photo, problem count + grade range, warning/
     PSA block (when present), recommended guidebook with outbound link (when present),
     closest parking with a Directions CTA (when present), and a primary "Show on map"
     CTA that flies to the entity bounds.
   - **Problem:** localized name, grade, steepness, height, primary CTA = the existing
     problem redirect link.
   - **POI:** name, type, Directions CTA (`google_url`).
6. DB & admin: `warning_de/en` added to clusters and regions; a `Guidebook` model
   (title, author optional, URL) with an optional association from region, cluster, and
   area; an optional parking-POI association on region, cluster, and area. Admin forms
   (and guidebook CRUD) manage all of these.
7. **Cascade-down resolution at tile export:** effective warning, guidebook, and parking
   for a feature = its own value, else its parent's effective value (area → cluster →
   region). Baked into tile properties so every platform resolves identically.
8. Tile export additions: problem count, grade range (min/max), cover-photo CDN URL
   (own area cover; clusters/regions use their main-child chain's area cover), cascaded
   card fields, and the region's **main-cluster bounds**.
9. The region card's "Show on map" CTA flies to the **main cluster bounds** (fallback:
   full region bounds when no main cluster is set). The `zoom ≥ 15` clamp in
   `flyToBounds` is removed so every drill-in level fits its target bounds correctly.
10. Area-hull → boulder transition is a **crossfade**: hull opacity ramps down while
    boulder opacity ramps up across ~1 zoom level around a single handoff zoom (later
    than today's z13; exact value tuned by eye during implementation). Outside the
    crossfade window only one of the two is visible; boulders never render before the
    window starts.
11. Search results (`gotoproblem`/`gotoarea`) and deep links (`?problem=…`, area pages)
    open the new selected state + card; the legacy problem and POI popups are removed.
    Hash/history behaviour is preserved.
12. All card UI strings are localized (de/en) following the existing locale pattern.
13. The shared map contract documentation (style/manifest/tile schema docs from
    0005/0009) is updated, including a short interaction-contract note (states, CTAs,
    cascade semantics) so the mobile apps implement the same model without reverse-
    engineering the web code.

## In scope / Out of scope

**In scope:**
- Pin symbol layers + selected layers in both shared style templates; sprite authoring
  and versioned publishing via the Bunny release flow.
- Web interaction runtime: selection, grow animation, responsive card UI, deselection,
  search/deep-link integration.
- Schema migrations, `Guidebook` model, parking/guidebook associations, admin forms.
- `geojson_exporter` cascade resolution + new feature properties; exporter tests.
- Crossfade zoom handoff in the style templates; region main-cluster zoom fix and
  `flyToBounds` clamp fix.
- Contract documentation updates.

**Out of scope:**
- iOS/Android implementation — separate repos; they consume the updated contract.
- Self-hosting the Inter font/glyphs — independently shippable publish-pipeline work,
  captured in the inbox on 2026-06-10.
- Card-ifying the contribution-request overlay (`/mapping/map`) — web-only overlay with
  different data needs; keeps its current grouped popups.
- Hover highlight states on features — not part of the requested interaction model.
- Dark-mode style switcher — the website has no dark mode yet (carried over from 0005).
- Long-form descriptions on cards — `description_de/en` stays off the card to keep tiles
  and the card scannable; revisit if cards feel thin in practice.
- Ascents count on public problem cards — no ascents data exists in the DB.

## Approach

**Style-driven pins with an animated select layer** (mirrors how Apple Maps works:
symbols rendered by the engine, data in tiles — adapted to MapLibre's constraints). The
pin look (resting + selected variants, light/dark) lives entirely in the shared
sprite + style JSONs; card data lives in tile feature properties with cascade resolved
at export. Per platform, only thin code remains: tap wiring, a ~20-line size tween on
the dedicated single-feature selected layer, and the native card UI reading the same
properties. Selection uses layer filters on feature ids, not `feature-state`, for
MapLibre Native parity.

Sprite delivery: either MapLibre multi-sprite (`sprite: [{id,url},…]`, keeping the
Bergwerk basemap sprite separate) or merging the Bergwerk sprite into a single
self-hosted spritesheet at publish time. Decision deferred to planning; merging is the
likely winner since multi-sprite support in MapLibre Native is less proven and a single
self-hosted sprite also shrinks the Bergwerk testing-endpoint dependency.

**Rejected alternatives:** DOM/HTML markers (web-only — pins would be drawn three times
and drift, against the stated sync priority); hybrid DOM-selected-marker à la MapKit JS
(selected-state drift); `feature-state`-driven selection (uncertain MapLibre Native
support); Rails GeoJSON endpoint for pin data (fresher card content, but splits the
data contract — tiles already rebuild automatically on relevant changes).

## Considerations

### Config vs code
Zoom ranges, crossfade window, pin/text sizing, and colors live in the style templates
(`config/map_styles/*.json`) — declarative config consumed by all platforms; tuning them
is a style edit + republish, not a code change. Object keys/CDN host stay in the
existing `lib/map_tiles/configuration.rb` env-driven config. The responsive breakpoint
uses the site's existing Tailwind breakpoints rather than a new constant. Card field →
DOM mapping is code; it changes with design, not deployment environment, so it is not
externalised.

### Security
Tile feature properties remain **untrusted input** to the card renderer: all card
content is built with the safe DOM/text APIs already used by the popup code (no HTML
interpolation), and outbound links (guidebook URL, POI `google_url`) pass the existing
`safeHttpUrl` http(s) allowlist plus `rel="noopener noreferrer"`. Admin-entered
guidebook URLs are also validated as http(s) at the model layer. New write surfaces
(warnings, guidebook, parking association) sit behind the existing admin authentication
like the current region/cluster/area forms. No secrets are involved; `.incant/` stays
secret-free. Blast radius: styles/sprite/tiles publish as immutable versioned objects
gated by the `current.json` manifest, so a bad release is rolled back by repointing the
manifest, same as 0005.

### Testability
- **Automated (Rails/minitest, run against Docker-hosted PostGIS per STATE.md):** model
  validations and associations (Guidebook, warnings, parking links), cascade resolution
  and new feature properties in `geojson_exporter` tests (own value, inherited value,
  override, missing everywhere; main-cluster bounds and fallback), style template
  assertions (pin/selected layers present, hull/boulder zoom ranges non-overlapping
  outside the crossfade window), admin controller tests for the new fields, and map
  view markup tests. Command: the existing `bin/rails test` suite in the Docker
  PostGIS environment used by 0005/0009 gates.
- **Manual (documented):** the repo has no JS test harness, so selection animation,
  card responsiveness (≈375 px and ≥1280 px), crossfade appearance, and the Maltatal
  drill-in are verified by a manual browser smoke check recorded with environment,
  browser, data, route URLs, and observations — explicitly avoiding the thin smoke
  evidence accepted as wontfix in 0005.
- **Seams:** cascade resolution implemented as a pure, directly-testable method on the
  exporter (record in, effective values out); card rendering reads a plain properties
  object so it can later be unit-tested if a JS harness lands.

### Code documentation
`map_controller.js` already carries file- and function-level JSDoc; new/changed JS
(selection state machine, tween, card component) keeps that standard, documenting the
non-obvious parts: why selection uses a filtered single-feature layer instead of
`feature-state`, and the deselect invariants. Ruby docs at module boundaries: cascade
semantics on the exporter methods, Guidebook/parking association intent on the models.
The shared-contract docs (style/tile schema + interaction contract) are the primary
documentation deliverable for mobile consumers. No comment noise on self-explanatory
form/view changes.

## Acceptance criteria

- [ ] On both light and dark styles, regions, clusters, areas, and POIs render as pin
      icons with name labels at their zoom ranges; no text-only tap targets remain.
- [ ] Tapping a pin (or problem circle) grows it smoothly and opens the card; tapping
      elsewhere, the close control, or another feature deselects and restores size.
- [ ] At ≈375 px width the card is a bottom sheet; at ≥1280 px it is a docked floating
      panel; the selected pin remains visible in both.
- [ ] An area with its own warning shows it; an area without one shows its cluster's,
      else its region's; identical cascade for guidebook and parking — each case covered
      by a passing automated exporter test.
- [ ] Region cards show a "Show on map" CTA that lands on the main cluster bounds
      (Maltatal lands on boulders, not the empty region middle); a region without a main
      cluster falls back to its full bounds.
- [ ] No zoom level outside the crossfade window renders area hulls and boulders
      simultaneously; within the window their opacities are complementary; boulders are
      invisible below the window's start zoom.
- [ ] Search result selection and `?problem=` deep links open the selected card; the
      legacy problem/POI popups are gone; URL hash/history behaviour unchanged.
- [ ] Admin can CRUD guidebooks, edit warnings on clusters and regions, and assign a
      guidebook and parking POI on region, cluster, and area.
- [ ] The sprite and updated style JSONs publish as immutable versioned objects through
      the existing release flow, with `current.json` as the only moving pointer.
- [ ] `bin/rails test` passes against Docker-hosted PostgreSQL/PostGIS.
- [ ] A manual browser smoke record exists with environment/browser/data/route URLs and
      observations for selection, card layouts, crossfade, and the Maltatal drill-in.
- [ ] All card strings render in both `de` and `en` locales.

## Risks & open questions

- **MapLibre Native sprite support:** multi-sprite arrays may be weakly supported on
  iOS/Android; mitigation chosen at planning — merge into one self-hosted spritesheet
  (also reduces the Bergwerk testing-endpoint dependency flagged in 0005 follow-ups).
- **Animated `icon-size` relayout cost:** tweening a layout property re-lays-out the
  layer each frame; with a single-feature selected layer this should be cheap. Fallback
  if it janks: step-change to the larger variant with the card providing the motion.
- **Stale cover-photo URLs in tiles:** CDN variant URLs are baked at export and can go
  stale if a cover changes between republishes — accepted; tiles rebuild on relevant
  changes and cards must degrade gracefully when an image 404s.
- **Tile property growth:** card fields enlarge region/cluster/area features; feature
  counts are small so impact is negligible (problems gain nothing new beyond what the
  card needs).
- **Crossfade tuning is visual:** the exact handoff zoom and window are judged by eye
  during implementation; the falsifiable part (no full-opacity overlap, no early
  boulders) is encoded in style assertions + smoke.
- **Bottom-sheet scope creep:** v1 is open/close only (no drag-resize half/full states);
  richer sheet gestures are a future polish item if wanted.
