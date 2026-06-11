---
id: "0006"
slug: maplibre-web-interactions
branch: incant/0006-maplibre-web-interactions
title: Polish web map interactions on MapLibre
stage: implement
status: in-progress
created: 2026-06-10
commit: f8a71849
updated: 2026-06-10
---

# Plan — Polish web map interactions on MapLibre

## Status
- Work item: `0006` / `maplibre-web-interactions`
- Stage: implement
- Branch: `incant/0006-maplibre-web-interactions`
- Current phase: `0006-P7` done (2026-06-11, human smoked iteratively in-session); `0006-P6` manual-smoke artifact now records an explicit human waiver for the missing detailed observations
- Next step: `/incant:review 0006` for fresh re-review of the waiver + docs cleanup
- Blockers: none known after the human manual-smoke waiver; release still waits on review-stage verdict
- Review fixes (2026-06-11):
  - Blocker `.incant/work/0006-maplibre-web-interactions/manual-smoke.md:9-54` / blank manual smoke artifact: recorded the human waiver requested in chat, noting the manual smoke was reported complete but detailed environment/browser/URL/observation evidence was not captured.
  - Minor `docs/map_tiles.md` contract drift: added `gradeHistogramJson` to every climbing-entity source-layer optional-property list, updated the cascade paragraph to mention histograms, and changed the CTA description to the current “Zoom to place” / “Zum Ort zoomen” copy.
  - Fresh verification (2026-06-11): documentation/markdown-only update; `ruby -e '...' && git diff --check` verified the waiver text is present, smoke tables have no empty data cells, `docs/map_tiles.md` has six `gradeHistogramJson` optional-property lists, CTA copy mentions “Zoom to place” / “Zum Ort zoomen”, and whitespace checks pass. No code paths changed since the full release gate re-run in review (`bin/rails db:prepare && bin/rails test && bin/importmap audit && bin/rubocop -f github && bin/brakeman --no-pager` → 231 runs, 3383 assertions, 0 failures/errors; importmap audit clean; rubocop clean; Brakeman no warnings).
- P7/P6 wrap-up (2026-06-11):
  - Unified the region/cluster/area pin glyph: all three resting discs and selected balloons now share the region two-peaks artwork (the hierarchy is internal, distinct glyphs carried no user meaning); icon names/layers unchanged, sprite README documents the intentional sharing; PNGs regenerated via the documented vips command.
  - Card stats redesigned: the grade-range text is replaced by a per-letter-grade distribution chart. New `gradeHistogramJson` tile property (sparse `{"6a":12,...}` object; sub-grades fold into letter grades) emitted by the exporter for regions/clusters/areas, allowed in the layer contract, and documented in the interaction contract. The card renders trimmed/padded full-width columns, grade labels under every bar, relative-intensity brand color tiers (300/400/500), hover count bubbles, and falls back to the `gradeMin – gradeMax` text for tiles without the property. New `grade_distribution` de/en string for the chart aria-label.
  - Brakeman release-gate fix: `Guidebook` URL format validation now anchors both ends (`%r{\Ahttps?://\S+\z}i`).
  - Gate evidence (2026-06-11, Docker/PostGIS): full release gate `bin/rails db:prepare && bin/rails test && bin/importmap audit && bin/rubocop -f github && bin/brakeman --no-pager` → 231 runs, 3383 assertions, 0 failures/errors; no vulnerable packages; rubocop clean; brakeman "No warnings found". Stale-reference sweep output contains only the negative guard assertions/comments inside tests (expected); no real stale references.
- P7 fixes (2026-06-10):
  - Reduced and tightened pin label sizing/spacing in both light/dark style templates; region pins are slightly larger.
  - Changed card CTA copy to EN “Zoom to place” / DE “Zum Ort zoomen” and made bounds handling validate main-cluster/full-bounds fallback before flying.
  - Moved the card into the map container, fixed the close button to a square circular hover target, and changed card stats to a compact `shared/_area_levels`-style numbered grade indicator plus problem-count text.
  - Root-caused the region/cluster selected-state failure: unlike areas/POIs, region/cluster symbol layers lacked `text-optional: true`, so MapLibre symbol placement could suppress the selected balloon when its label collided; both base and selected region/cluster layers now allow the icon to render even when the label cannot.
  - Reverted the delayed base-pin hiding experiment; selection again excludes the resting base pin immediately and relies on the selected layer rendering correctly. Added a selected→unselected shrink animation for deselect/close and a slower, smoother damped `icon-rotate` wiggle during the selected grow/settle animation so the selected balloon pivots around the pin anchor/location dot rather than translating around the sprite center.
  - Changed map camera adjustment to a minimal coordinate nudge only when the selected point is actually under the bottom sheet/docked card; no persistent padding reset on close.
  - Limited problem click/pointer handling to z15+ and widened area-pin click/pointer handling to the full visible area-pin range (`z < 16`); cluster/area hull+pin click handlers remain wired.
  - Removed the experimental grade visualizer and restored the simpler card stat line: problem count, middot, grade range.
  - Added problem topo preview data to the tile contract/exporter: `topoPhotoUrl` and `lineCoordinatesJson` are emitted for problems with a published line, coordinates, and attached topo photo; the problem card renders the safe CDN image with an SVG line overlay and start dot. Follow-up polish fixes the preview to an explicit 4:3 frame/viewBox so lines do not appear squished, makes the problem grade more prominent, and moves media-card close buttons into a high-contrast top-right overlay on photos/topos.
  - Fresh automated gate evidence (Docker/PostGIS): `bin/rails db:prepare && bin/rails test test/controllers/map_controller_test.rb && bin/importmap audit && bin/rubocop -f github` → 9 runs, 196 assertions, 0 failures/errors; importmap audit clean; rubocop clean.
- Review fixes (P5 revise loop, 2026-06-10):
  - Blocker `app/controllers/map_controller.rb:16` / `?problem=` deep links: map index
    now resolves `problem_id` from `params[:pid]` or `params[:problem]`, preserving the
    existing `pid` path while honoring the approved spec's `?problem=<id>` alias so the
    view emits `data-map-problem-value` for the new selected-card JS path.
  - Added `test/controllers/map_controller_test.rb` coverage for the `problem` query
    alias rendering problem data.
  - Fresh gate evidence (this session, Docker/PostGIS): `bin/rails db:prepare && bin/rails
    test test/controllers/map_controller_test.rb && bin/rubocop -f github` → 9 runs,
    182 assertions, 0 failures/errors; rubocop clean.
- Review fixes (P4 revise loop, 2026-06-10):
  - Blocker `map_controller.js:411-421` / docked-card pin visibility: `adjustSheetPadding`
    now branches by breakpoint — below `lg` the existing bottom-sheet logic
    (`adjustBottomSheetPadding`); at `lg`+ the new `adjustDockedPanelPadding` maps the
    fixed-position card rect into map-container coordinates, reserves left map padding up
    to the panel's right edge, and `easeTo`s the selected coordinate when its projected
    point falls under the card rect (16px margin), so the selected pin stays visible in
    the docked-panel layout. `clearSelection` already resets padding for both layouts.
  - Fresh gate evidence (this session, Docker/PostGIS): `bin/rails db:prepare && bin/rails
    test test/controllers/map_controller_test.rb test/controllers/mapping/contribution_requests_controller_test.rb
    && bin/importmap audit && bin/rubocop -f github` → 9 runs, 171 assertions, 0
    failures/errors; no vulnerable packages; rubocop clean.
- P4 as-built deviations from the plan text:
  - `MapSelection` also excludes the selected id from the base symbol layer's filter
    (per the P3 note below) so the resting pin does not render under the balloon; the
    `problems` base layer is deliberately NOT excluded — its filter is owned by the
    grade-filter UI (`applyLayerFilter` replaces it wholesale) and the bigger stroked
    selected circle fully covers the base circle anyway.
  - Added a `details` card string key (problem CTA label) beyond the planned string
    list — the plan named the redirect CTA but no label for it.
  - `registerProblemClicks`, `registerPoiClicks`, `poiPopupContent`, and the
    controller's `safeHttpUrl` were already removed in P4 (they became dead code once
    `registerSelectClicks` took over layer clicks; `InfoCard` carries its own
    `safeHttpUrl`). `problemPopupContent`/`problemFeatureId`/`createPopup` stay for the
    `?pid=`/search deep-link popups until P5 rewires those flows.
- P3 as-built deviations from the plan text:
  - Icon design reworked per human feedback during the phase (Apple-Maps direction):
    resting pins are 20×20 colored discs with white glyphs + label beside; selected pins
    are 34×45 balloons (bubble + small tail) with an anchor dot on the feature location,
    rendered via `icon-anchor: bottom` + `icon-offset: [0, 4]`. Parking is blue
    `#3173de`, train stations slate `#5a6b7a`, climbing entities brand red `#ef3340`.
  - `SpriteBuilder` packs icons by inserting onto a transparent canvas (tight packing
    with mixed icon sizes) instead of `arrayjoin`, which pads cells to uniform size.
  - `lib/map_tiles/local_artifact_cleaner.rb` (+ test) also extended so old local sprite
    artifacts are pruned like styles/PMTiles (not in the planned file list).
  - Note for P4: the base symbol layers keep rendering the selected feature underneath
    the balloon; the P4 runtime should also exclude the selected id from the base
    layer's filter (same single-id mechanism as the `-selected` filter) and P6 must
    document that in the interaction contract.
- Key decisions:
  - **Sprite delivery: single self-hosted Austrian Rocks sprite** (not MapLibre multi-sprite).
    The only Bergwerk sprite icon the committed styles use is `flugplatz` on the two
    airport label layers (`label_airport_regional`, `label_airport_international`);
    per human decision the airport icon is not needed — those layers drop their
    `icon-*` properties (text labels stay) and the sprite contains only our pin icons,
    removing the Bergwerk sprite dependency entirely. Multi-sprite support in MapLibre
    Native is less proven, and this also shrinks the Bergwerk testing-endpoint
    dependency (0005 follow-up).
  - **Sprite build inputs are committed PNGs** (1x + 2x per icon, plus committed SVG
    sources for future editing). The publish-time `MapTiles::SpriteBuilder` does pure
    raster compositing via `ruby-vips` (already a transitive dependency of
    `image_processing ~> 1.2`) — no SVG rasterisation in the test/publish path, so the
    pipeline has no new external binary or librsvg dependency.
  - **Selection = dedicated single-feature layers filtered by entity id** with a `-1`
    sentinel filter (`["==", ["get", "regionId"], -1]` etc.); no `feature-state` (MapLibre
    Native parity, per spec).
  - **Crossfade window: z14 → z15** (handoff midpoint z14.5, later than today's z13
    boulder appearance). Hull opacity ramps 1→0 across the window; boulder opacity 0→1;
    `boulders`/`boulders-outline` `minzoom` = 14 so boulders never render before the
    window. Exact stops are template values, tunable by eye during implementation —
    the style tests assert the structure (complementary stops, no early boulders), not
    one blessed midpoint.
  - **Responsive breakpoint: Tailwind `lg` (1024px)** — below: bottom sheet; at/above:
    docked floating panel. Satisfies the ≈375px / ≥1280px acceptance checks.
  - **Card DOM is built in JS with safe text APIs** from tile feature properties;
    localized static strings come from Rails via a `data-map-card-strings-value` JSON
    blob (`t()` in `MapHelper`), matching the existing popup-content building style.
  - **Cover photo URLs** are baked via the existing `cdn_image` direct route with
    `expires_in: nil` (non-expiring signed proxy URL; the route self-overrides host with
    `config.asset_host` outside local envs).
- Verification evidence:
  - `0006-P1` (2026-06-10): Docker gate green — `bin/rails db:prepare && bin/rails test test/models test/controllers/admin` → 111 runs, 409 assertions, 0 failures, 0 errors; `bin/rubocop -f github` → exit 0, no offenses. Schema regenerated to version 2026_06_10_090002 with warnings on clusters/regions, guidebooks table, and guidebook/parking FKs on regions/clusters/areas.
  - `0006-P1` review fixes (2026-06-10): addressed all P1 review findings — guidebook destroy now refuses with a flash error when assigned to regions/clusters/areas (new controller test), `flash.now` on re-render branches, redundant `null: true` removed from the FK migration. Docker gate re-run green: 112 runs, 415 assertions, 0 failures, 0 errors; rubocop exit 0.
  - `0006-P2` (2026-06-10): Docker gate green — `bin/rails db:prepare && bin/rails test test/lib/map_tiles && bin/rubocop lib/map_tiles test/lib/map_tiles -f github` → 66 runs, 1939 assertions, 0 failures, 0 errors; rubocop exit 0. Exporter now emits cascaded warning/guidebook/parking fields, cover URLs, aggregate problem counts/grade ranges, and main-cluster bounds; layer/smoke contracts allow the new card URL fields.
  - `0006-P2` review fixes (2026-06-10): accepted the intentionally ignored `/docs/` contract note as `wontfix`; added exporter coverage for area cover URLs cascading to cluster main-area and region main-cluster→main-area card properties, plus absent-cover fallback. Docker gate re-run green — `bin/rails db:prepare && bin/rails test test/lib/map_tiles && bin/rubocop lib/map_tiles test/lib/map_tiles -f github` → 66 runs, 1947 assertions, 0 failures, 0 errors; rubocop exit 0.
  - `0006-P3` (2026-06-10): Docker gate green — `bin/rails db:prepare && bin/rails test test/lib/map_tiles && bin/rubocop lib/map_tiles test/lib/map_tiles -f github` → 76 runs, 2531 assertions, 0 failures, 0 errors; rubocop exit 0. Sprite pipeline (builder + 4 versioned uploads + manifest `spriteUrl` + materializer sprite rewrite/validation), 10 committed icons (20 PNGs + SVG sources + README), both templates carry pin/selected layers with `-1` sentinel filters, z14→15 hull/boulder crossfade, dev sprite URL, and no Bergwerk sprite references (`flugplatz` gone; style test proves every `icon-image` resolves to a committed icon). Icons visually verified via rendered previews during authoring.
  - `0006-P4` (2026-06-10): Docker gate green — `bin/rails db:prepare && bin/rails test test/controllers/map_controller_test.rb test/controllers/mapping/contribution_requests_controller_test.rb && bin/importmap audit && bin/rubocop -f github` → 9 runs, 171 assertions, 0 failures, 0 errors; no vulnerable packages; rubocop exit 0 (`GATE_EXIT=0`). New `map/selection.js` (single-selection invariant, `-1` sentinel filters, base-layer exclusion, 180ms ease-out grow tween) and `map/info_card.js` (safe-DOM card, bottom sheet / `lg:` docked panel), importmap `pin_all_from app/javascript/map`, controller select wiring + background-click deselect + sheet padding, `map_card_strings` helper + `views.map.card.*` de/en locales, card target + data attributes in the view, new markup tests.
  - `0006-P5` (2026-06-10): Docker gate green — `bin/rails db:prepare && bin/rails test test/controllers/map_controller_test.rb && bin/rubocop -f github` → 8 runs, 163 assertions, 0 failures, 0 errors; rubocop exit 0. Search and `?pid=`/`?slug=` deep links now select tile features and open cards via `selectFeatureWhenIdle`, legacy problem popup code/deferred popup replay is removed, and the `flyToBounds` zoom-15 clamp is gone.
  - `0006-P5` review fixes (2026-06-10): addressed the open `?problem=` deep-link blocker by accepting it as a `pid` alias and covering it in `test/controllers/map_controller_test.rb`. Docker gate re-run green — `bin/rails db:prepare && bin/rails test test/controllers/map_controller_test.rb && bin/rubocop -f github` → 9 runs, 182 assertions, 0 failures, 0 errors; rubocop exit 0.

## Files touched

### Phase P1 — data model & admin
- `db/migrate/XXXX_add_warnings_to_clusters_and_regions.rb` — new: `warning_de`/`warning_en` text columns on clusters and regions
- `db/migrate/XXXX_create_guidebooks.rb` — new: guidebooks table (title, author, url)
- `db/migrate/XXXX_add_guidebook_and_parking_to_climbing_entities.rb` — new: `guidebook_id` + `parking_poi_id` FKs on regions, clusters, areas
- `db/schema.rb` — regenerated by migrations
- `app/models/guidebook.rb` — new model: validations, associations, audited, publish-stale marker
- `app/models/region.rb`, `app/models/cluster.rb` — warnings normalization, guidebook/parking associations
- `app/models/area.rb` — guidebook/parking associations
- `app/controllers/admin/guidebooks_controller.rb` — new admin CRUD
- `app/views/admin/guidebooks/{index,new,edit,_form}.html.erb` — new admin views
- `app/views/admin/regions/_form.html.erb`, `app/views/admin/clusters/_form.html.erb`, `app/views/admin/areas/_form.html.erb` — warning/guidebook/parking fields
- `app/controllers/admin/regions_controller.rb`, `…/clusters_controller.rb`, `…/areas_controller.rb` — strong-params additions
- `config/routes.rb` — `resources :guidebooks` in the admin namespace
- `test/models/guidebook_test.rb`, `test/models/region_test.rb`, `test/models/cluster_test.rb`, `test/models/area_test.rb` — model tests
- `test/controllers/admin/guidebooks_controller_test.rb` and updates to existing admin region/cluster/area controller tests

### Phase P2 — tile contract
- `lib/map_tiles/geojson_exporter.rb` — cascade resolution + new card properties + region main-cluster bounds
- `lib/map_tiles/layer_contract.rb` — new optional properties on areas/area_hulls/clusters/cluster_hulls/regions/region_hulls
- `lib/map_tiles/smoke_check.rb` — URL-field allowlist updated for the new safe card URL properties
- `test/lib/map_tiles/geojson_exporter_test.rb` — cascade matrix + new property tests
- `test/lib/map_tiles/layer_contract_test.rb` — contract additions
- `docs/map_tiles.md` — source-layer schema sections updated

### Phase P3 — sprite pipeline + pin styles + crossfade
- `config/map_styles/sprite/` — new: committed icon PNGs (1x/2x), SVG sources, README
- `lib/map_tiles/sprite_builder.rb` — new: packs PNGs into sprite.png/.json (+@2x)
- `lib/map_tiles/configuration.rb` — sprite object keys / artifact paths / public base URL
- `lib/map_tiles/style_materializer.rb` — rewrite `"sprite"` to the versioned public base URL; validate templates declare a sprite
- `lib/map_tiles/bunny_publisher.rb` — 4 additional versioned sprite uploads
- `lib/map_tiles/release_manifest.rb` — `spriteUrl` entry
- `config/map_styles/austrian_rocks_light.json`, `…_dark.json` — pin layers, selected layers, crossfade stops, sprite URL
- `test/lib/map_tiles/sprite_builder_test.rb` — new
- `test/lib/map_tiles/{configuration,style_materializer,bunny_publisher,release_manifest}_test.rb` — updated
- `docs/map_tiles.md` — sprite artifact + manifest documentation

### Phases P4/P5 — web runtime
- `config/importmap.rb` — `pin_all_from "app/javascript/map", under: "map"`
- `app/javascript/map/selection.js` — new: selection state machine + grow tween
- `app/javascript/map/info_card.js` — new: card renderer (safe DOM building)
- `app/javascript/controllers/map_controller.js` — selection wiring, card mount, search/deep-link integration, popup removal, `flyToBounds` clamp removal
- `app/views/map/index.html.erb` — card container target + card-strings/area-id data attributes
- `app/helpers/map_helper.rb` — `map_card_strings` helper
- `app/controllers/map_controller.rb` — expose `@area.id` for the slug deep link
- `config/locales/en.yml`, `config/locales/de.yml` — `views.map.card.*` strings
- `test/controllers/map_controller_test.rb` — view markup + data-attribute tests

### Phase P6 — contract docs + release + smoke
- `docs/map_tiles.md` — interaction-contract section
- `.incant/work/0006-maplibre-web-interactions/manual-smoke.md` — new smoke record

## Phase 0006-P1 — warnings, guidebooks, parking links (DB + admin)

Goal: admins can enter every piece of card data the exporter will bake: warnings on
clusters/regions (areas already have them), guidebooks, and a designated parking POI per
region/cluster/area.

- [x] step 1: read `db/schema.rb` (tables `regions`, `clusters`, `areas`, `pois`, plus a
      recent migration under `db/migrate/`) before writing migrations.
- [x] step 2: migration `AddWarningsToClustersAndRegions`
      (`ActiveRecord::Migration[8.0]`): `add_column :clusters, :warning_de, :text`,
      `add_column :clusters, :warning_en, :text`, same two for `:regions` — mirroring the
      existing `areas.warning_de/_en` text columns.
- [x] step 3: migration `CreateGuidebooks`: table `guidebooks` with `t.string :title,
      null: false`, `t.string :author`, `t.string :url, null: false`, `t.timestamps`.
- [x] step 4: migration `AddGuidebookAndParkingToClimbingEntities`: for each of
      `:regions`, `:clusters`, `:areas` — `add_reference table, :guidebook,
      foreign_key: true, null: true` and `add_reference table, :parking_poi,
      foreign_key: { to_table: :pois }, null: true`.
- [x] step 5: `app/models/guidebook.rb` — `class Guidebook < ApplicationRecord` with
      `has_many :regions`, `has_many :clusters`, `has_many :areas`,
      `validates :title, presence: true`,
      `validates :url, presence: true, format: { with: %r{\Ahttps?://}i, message: "must be an http(s) URL" }`,
      `normalizes :title, :author, :url, with: ->(s) { s.strip.presence }`, `audited`,
      and `include MapTiles::PublishStaleMarker` (guidebook edits change baked tile
      properties, so production saves must schedule a republish). Add a brief class
      comment stating the cascade intent (entities inherit the closest ancestor's
      guidebook at tile export).
- [x] step 6: read `app/models/region.rb`, `app/models/cluster.rb`,
      `app/models/area.rb`; then add to each: `belongs_to :guidebook, optional: true`
      and `belongs_to :parking_poi, class_name: "Poi", optional: true` plus
      `validate :parking_poi_must_be_parking` defined as: errors on `:parking_poi`
      unless `parking_poi.nil? || parking_poi.poi_type == "parking"`. On `Region` and
      `Cluster` also add `normalizes :warning_de, :warning_en, with: ->(s) { s.strip.presence }`
      (Area already normalizes its warnings).
- [x] step 7: read `config/routes.rb` admin namespace; add `resources :guidebooks`
      alongside the existing flat admin resources.
- [x] step 8: `app/controllers/admin/guidebooks_controller.rb` — follow the
      `Admin::PoisController` / `Admin::ClustersController` structure (inherit
      `Admin::BaseController`): `index` (ordered list), `new`, `create`, `edit`,
      `update`, `destroy`; strong params
      `params.require(:guidebook).permit(:title, :author, :url)`; redirect to
      `edit_admin_guidebook_path` after save like the sibling controllers.
- [x] step 9: read `app/views/admin/areas/_form.html.erb` and one sibling `index.html.erb`
      for markup conventions; create `app/views/admin/guidebooks/{index,new,edit,_form}.html.erb`
      using the `DefaultFormBuilder` field pattern (`form.label` + `form.text_field` in
      `col-span-6 sm:col-span-4` wrappers; index as the usual admin table).
- [x] step 10: extend admin forms:
      - `app/views/admin/regions/_form.html.erb` and `app/views/admin/clusters/_form.html.erb`:
        `form.text_area :warning_de, rows: 3` + `:warning_en` (copy the area form's
        warning block), `form.collection_select :guidebook_id, Guidebook.order(:title), :id, :title, { include_blank: true }`,
        `form.collection_select :parking_poi_id, Poi.parking.order(:name), :id, :name, { include_blank: true }`.
      - `app/views/admin/areas/_form.html.erb`: the same guidebook + parking selects
        (warnings already exist there).
- [x] step 11: read then update strong params: `Admin::RegionsController` and
      `Admin::ClustersController` permit `:warning_de, :warning_en, :guidebook_id,
      :parking_poi_id`; `Admin::AreasController#area_params` additionally permits
      `:guidebook_id, :parking_poi_id`.
- [x] step 12: tests —
      - `test/models/guidebook_test.rb`: title/url presence, rejects `javascript:` and
        bare-word URLs, accepts http/https.
      - model tests for region/cluster/area: guidebook + parking association round-trip;
        `parking_poi` validation rejects a `train_station` POI and accepts a `parking` POI.
      - `test/controllers/admin/guidebooks_controller_test.rb`: index/new/create/edit/
        update/destroy happy paths (pattern of
        `test/controllers/admin/walking_paths_controller_test.rb`).
      - extend existing admin region/cluster/area controller tests: update with the new
        permitted fields persists them.

**Quality gate:** `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.invalid -e BUNNY_STORAGE_ACCESS_KEY_ID=dummy -e BUNNY_STORAGE_SECRET_ACCESS_KEY=dummy -e BUNNY_STORAGE_REGION=dummy -e BUNNY_STORAGE_BUCKET=dummy web bash -lc 'bin/rails db:prepare && bin/rails test test/models test/controllers/admin && bin/rubocop -f github'` → all green, no offenses. This narrower gate covers the phase because only models, migrations, admin controllers/views, and routes changed; the full suite runs again in P6.

## Phase 0006-P2 — exporter cascade + card tile properties

Goal: every property the cards need ships in the tiles, cascade resolved identically for
all platforms, with the region main-cluster bounds for the Maltatal fix.

- [x] step 1: read `lib/map_tiles/geojson_exporter.rb`, `lib/map_tiles/layer_contract.rb`,
      and `test/lib/map_tiles/geojson_exporter_test.rb` before editing.
- [x] step 2: add a pure cascade method to `GeojsonExporter`:
      `def effective_card_attributes(record)` — walks `record` → parent (`area.cluster` →
      `cluster.region`) and returns
      `{ warning_de:, warning_en:, guidebook:, parking_poi: }` where each value is the
      record's own value if present, else the nearest ancestor's. Document the cascade
      semantics in a method comment (this is the exporter's contract seam). Reuse it for
      areas, clusters (cluster → region), and regions (own values only).
- [x] step 3: add aggregate helpers: `problem_count_for_area_ids(area_ids)` (count of
      problems in published areas) and `grade_range_for_area_ids(area_ids)` returning
      `[min, max]` grade strings ordered by index in `Problem::GRADE_VALUES` (ignore
      blank grades; nil when no graded problems).
- [x] step 4: add `cover_photo_url(record)`: resolves the cover attachment — a record's
      own attached `cover` wins (regions/clusters/areas all have `has_one_attached
      :cover`); else a cluster falls back to its `main_area`'s cover and a region to its
      `main_cluster`'s effective cover (main-child chain). Returns
      `Rails.application.routes.url_helpers.cdn_image_url(cover.variant(:medium), expires_in: nil, host: Rails.application.config.asset_host.presence || "http://localhost:3000")`
      (the direct route overrides host with `asset_host` outside local envs), nil when
      no cover is attached. Note: `Cluster`'s `has_one_attached :cover` currently
      declares no variants — add the same `:thumb`/`:medium` variant block Region and
      Area already define.
- [x] step 5: extend `area_properties` / `cluster_properties` / `region_properties` (used
      by both point and hull features) with, following the existing `name`/`nameEn`
      localization pattern (`warning` = de value, `warningEn` only when different):
      `problemCount`, `gradeMin`, `gradeMax`, `coverPhotoUrl`, `warning`, `warningEn`,
      `guidebookTitle`, `guidebookAuthor`, `guidebookUrl`, `parkingPoiId`, `parkingName`,
      `parkingGoogleUrl` — all via `effective_card_attributes` so blank values cascade.
      `region_properties` additionally gains `mainClusterSouthWestLat/Lon`,
      `mainClusterNorthEastLat/Lon` from the main cluster's `sw`/`ne` (or its boulder
      bounds via `explicit_or_boulder_bounds`), omitted when no main cluster is set.
      `compact_properties` already drops nils.
- [x] step 6: extend `lib/map_tiles/layer_contract.rb`: add the new property names to
      `optional_properties` of `areas`, `area_hulls`, `clusters`, `cluster_hulls`,
      `regions`, `region_hulls` (main-cluster bounds props on the two region layers only).
- [x] step 7: tests in `test/lib/map_tiles/geojson_exporter_test.rb` —
      - update `assert_no_canonical_url` allowlist to permit exactly `coverPhotoUrl`,
        `guidebookUrl`, `parkingGoogleUrl` besides `googleUrl`;
      - cascade matrix for warning, guidebook, parking (the spec's acceptance grid):
        area with own value; area inheriting from cluster; area inheriting from region;
        area overriding cluster's value; value missing everywhere → property absent;
      - `problemCount`/`gradeMin`/`gradeMax` aggregation on area, cluster, region
        features (cluster/region aggregate over published descendant areas only);
      - region `mainCluster*` bounds present when `main_cluster_id` set, absent
        otherwise;
      - `coverPhotoUrl`: attach a fixture image (`test/fixtures/files`) to an area —
        property present, points at the blob-representation proxy path, and exporting
        twice yields byte-identical URLs (non-expiring determinism); absent without a
        cover;
      - update `test/lib/map_tiles/layer_contract_test.rb` for the new optional
        properties.
- [x] step 8: read `docs/map_tiles.md` source-layer sections; update the `areas`,
      `area_hulls`, `clusters`, `cluster_hulls`, `regions`, `region_hulls` property
      tables with the new optional properties and a short "card data cascade" paragraph
      (own value → cluster → region, resolved at export).

**Quality gate:** `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.invalid -e BUNNY_STORAGE_ACCESS_KEY_ID=dummy -e BUNNY_STORAGE_SECRET_ACCESS_KEY=dummy -e BUNNY_STORAGE_REGION=dummy -e BUNNY_STORAGE_BUCKET=dummy web bash -lc 'bin/rails db:prepare && bin/rails test test/lib/map_tiles && bin/rubocop lib/map_tiles test/lib/map_tiles -f github'` → all green. Narrower gate is sufficient: only `lib/map_tiles`, its tests, and docs changed.

## Phase 0006-P3 — sprite pipeline, pin styles, crossfade

Goal: both shared styles render sprite-based pins with labels beside them and a clean
hull→boulder crossfade; the sprite publishes as versioned immutable objects through the
existing Bunny flow. (Pins reference only style-declared sprite icons — no `map.addImage`.)

- [x] step 1: create `config/map_styles/sprite/` with icon assets. Author SVG sources
      (`ar-pin-region.svg`, `ar-pin-cluster.svg`, `ar-pin-area.svg`, `ar-pin-parking.svg`,
      `ar-pin-train.svg`, plus a `-selected` variant of each — selected = filled/darker
      brand-red `#ef3340` pin so the grow animation lands on a visually distinct state);
      render each to committed PNGs at 1x (28×36) and 2x (56×72) locally (vips/rsvg —
      authoring-time only, not a pipeline dependency). Add
      `config/map_styles/sprite/README.md` documenting the icon list, sizes, and the
      regeneration command.
      *(As built, per human feedback during the phase: Apple-Maps-style icons instead of
      classic teardrops — resting = 20×20 colored disc with white glyph, selected =
      34×45 balloon with tail + anchor dot, `icon-anchor: bottom` + `icon-offset: [0,4]`;
      parking is blue `#3173de`, train slate `#5a6b7a`, climbing entities brand red.
      PNGs rendered with librsvg-backed vips in the dev container because host
      ImageMagick drops SVG strokes — command documented in the sprite README.)*
- [x] step 2: `lib/map_tiles/sprite_builder.rb` — `MapTiles::SpriteBuilder` with
      `initialize(configuration:)` and `#build` that, per pixel ratio (1, 2): loads every
      `config/map_styles/sprite/*.png` (suffix `@2x` selects ratio 2) via
      `Vips::Image.new_from_file`, packs them left-to-right into one sheet
      (`Vips::Image.arrayjoin` across one row), writes
      `<output_dir>/<artifact_basename>-<version>-sprite[@2x].png` and the matching
      `.json` index `{ "<icon-name>": { "x":, "y":, "width":, "height":, "pixelRatio": } }`,
      and returns `{ "sprite.png" => path, "sprite.json" => path, "sprite@2x.png" => …, "sprite@2x.json" => … }`.
      Raise a named error when an icon is missing its 2x counterpart.
- [x] step 3: read then extend `lib/map_tiles/configuration.rb`: `sprite_basename` =
      `"#{artifact_basename}-#{version}-sprite"`, `sprite_artifact_path(suffix)`,
      `sprite_object_key(suffix)` under `style_prefix`
      (`map_styles/austrian-rocks-<version>-sprite.png|.json|@2x.png|@2x.json`),
      `sprite_public_url(suffix)`, and `sprite_public_base_url` (no extension — the
      MapLibre style `sprite` value).
- [x] step 4: read then extend `lib/map_tiles/style_materializer.rb`: validate the
      template declares a non-empty string `sprite`; on materialize set
      `style["sprite"] = configuration.sprite_public_base_url`.
- [x] step 5: read then extend `lib/map_tiles/bunny_publisher.rb`: instantiate
      `SpriteBuilder` (injectable like `style_materializer`), call it in `publish`, add
      its four artifacts to `upload_plan` as versioned immutable uploads (`image/png`
      content type for the PNGs, `JSON_CONTENT_TYPE` for the indexes) so they upload and
      HEAD-verify before the manifest like every other versioned object.
- [x] step 6: read then extend `lib/map_tiles/release_manifest.rb`: add
      `"spriteUrl" => configuration.sprite_public_base_url` validated like the other URLs.
- [x] step 7: edit **both** style templates (`config/map_styles/austrian_rocks_light.json`,
      `…_dark.json`):
      - set top-level `"sprite"` to the dev value
        `https://tiles.austrian.rocks/map_styles/e2e/austrian-rocks-dev-sprite`
        (mirrors the committed dev PMTiles URL convention; materializer rewrites it);
      - remove the `icon-image` and other `icon-*` layout properties from the
        `label_airport_regional` and `label_airport_international` basemap layers in
        both templates (their `text-field` airport labels stay) — no layer references a
        Bergwerk sprite icon anymore;
      - `regions`/`clusters`/`areas` symbol layers: add `icon-image`
        (`ar-pin-region`/`ar-pin-cluster`/`ar-pin-area`), keep `icon-allow-overlap: true`,
        move the label beside the pin (`text-anchor: "left"`, `text-offset: [1.1, 0]`,
        drop `text-variable-anchor`), keep each layer's zoom range, sort keys, fonts,
        and per-style text colors; make the existing `icon-opacity` ramps match the
        layer's `text-opacity` ramps so icon and label fade together;
      - `pois` layer: `icon-image` = `["match", ["get", "poiType"], "train_station", "ar-pin-train", "ar-pin-parking"]`,
        label beside the pin as above;
      - add five selected layers after their base layers: `regions-selected`,
        `clusters-selected`, `areas-selected`, `pois-selected` (symbol; same
        source-layer/zoom range as base; filter sentinel
        `["==", ["get", "<entity>Id"], -1]`; `icon-image` the `-selected` icon variant;
        `icon-size: 1`; `icon-allow-overlap: true`; same label treatment) and
        `problems-selected` (circle; filter `["==", ["get", "problemId"], -1]`; radius
        +3px over the base ramp; 2px white stroke);
      - crossfade: `areas-hulls` + `areas-hulls-outline` opacity stops become
        `[…, 14, 1, 15, 0]` with `maxzoom` 15; `boulders` gains
        `fill-opacity [..., 14, 0, 15, 1]` with `minzoom` 14; `boulders-outline`
        `minzoom` 13→14 and `line-opacity` stops `[…, 14, 0, 15, 1]`.
- [x] step 8: tests —
      - new `test/lib/map_tiles/sprite_builder_test.rb`: builds from the committed
        sprite dir; JSON index covers every committed icon name at both pixel ratios;
        rects are disjoint and within the sheet; missing-2x raises;
      - read then update `test/lib/map_tiles/configuration_test.rb` (sprite keys/URLs,
        traversal-safe), `test/lib/map_tiles/release_manifest_test.rb` (`spriteUrl`),
        `test/lib/map_tiles/bunny_publisher_test.rb` (sprite uploads in the versioned
        batch, uploaded and HEAD-verified before the manifest);
      - read then update `test/lib/map_tiles/style_materializer_test.rb`:
        `assert_austrian_rocks_overlay_zoom_hierarchy` reflects the 18-layer overlay
        stack (13 existing + 5 selected layers), pin `icon-image` on
        regions/clusters/areas/pois, selected-layer sentinel filters, sprite rewrite to
        `configuration.sprite_public_base_url`, an assertion that every `icon-image`
        referenced by any layer (basemap included) resolves to an icon name in
        `config/map_styles/sprite/` — proving no Bergwerk sprite icon (e.g. `flugplatz`)
        is referenced anymore — and a new
        `assert_hull_boulder_crossfade` helper asserting: hull and boulder opacity
        expressions share the same window stops, hull ends at 0 where boulder reaches 1,
        `boulders`/`boulders-outline` `minzoom` equals the window start, and
        `areas-hulls` `maxzoom` equals the window end — written against the expressions'
        zoom stops, not hard-coded z-values, so by-eye tuning inside the templates
        doesn't break the falsifiable property (no full-opacity overlap, no early
        boulders).
- [x] step 9: update `docs/map_tiles.md` artifact/delivery rules: sprite objects, their
      key pattern, immutability, and the manifest `spriteUrl` field; note the styles no
      longer reference the Bergwerk sprite.

**Quality gate:** `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.invalid -e BUNNY_STORAGE_ACCESS_KEY_ID=dummy -e BUNNY_STORAGE_SECRET_ACCESS_KEY=dummy -e BUNNY_STORAGE_REGION=dummy -e BUNNY_STORAGE_BUCKET=dummy web bash -lc 'bin/rails db:prepare && bin/rails test test/lib/map_tiles && bin/rubocop lib/map_tiles test/lib/map_tiles -f github'` → all green. Narrower gate is sufficient: only the map_tiles pipeline, style templates, and their tests changed.

## Phase 0006-P4 — selection runtime + info card

Goal: tapping any pin or problem on `/map` selects it (smooth grow) and opens a
responsive, localized info card; tapping elsewhere/closing deselects.

- [x] step 1: read `config/importmap.rb`; add
      `pin_all_from "app/javascript/map", under: "map"`.
- [x] step 2: new `app/javascript/map/selection.js` exporting class `MapSelection`:
      - `constructor(map)`; tracks `{ kind, id, layerId }` of the current selection;
      - `select(kind, id)` / `clear()` set the matching `-selected` layer's filter
        (`["==", ["get", "<kind>Id"], id]`, sentinel `-1` to clear) and run the grow
        tween; selecting while something else is selected clears it first (invariant:
        at most one selected feature, ever — documented in the file JSDoc along with
        *why* a filtered single-feature layer is used instead of `feature-state`);
      - tween: `requestAnimationFrame` loop, ~180ms ease-out, animating `icon-size`
        1.0→1.25 via `setLayoutProperty` for symbol layers and `circle-radius` base→+40%
        via `setPaintProperty` for `problems-selected`; `clear()` cancels any running
        frame and resets the property.
- [x] step 3: new `app/javascript/map/info_card.js` exporting class `InfoCard`:
      - `constructor(container, strings, locale)` — container is the Stimulus target,
        `strings` the parsed `data-map-card-strings-value` JSON;
      - `show(kind, properties, callbacks)` builds the card DOM exclusively with
        `createElement`/`textContent` (no HTML interpolation; tile properties are
        untrusted input):
        - region/cluster/area: cover `<img>` (only when `coverPhotoUrl` passes the
          http(s) check; `onerror` hides the image so a stale CDN URL degrades to no
          photo), localized name, `problemCount` + `gradeMin`–`gradeMax` line, warning
          block when `warning`/`warningEn` present, guidebook link when present,
          parking row with a Directions link (`parkingGoogleUrl`) when present, primary
          "Show on map" button invoking `callbacks.showOnMap`;
        - problem: localized name, grade, steepness (translated via
          `strings.steepness[value]`), height, primary CTA linking to
          `/<locale>/redirects/new?problem_id=<id>` (the existing redirect link);
        - poi: name, translated type, Directions link from `googleUrl`;
        - every outbound link goes through a `safeHttpUrl` check and gets
          `target="_blank" rel="noopener noreferrer"`; a close button invokes
          `callbacks.close`;
      - `hide()`; responsive layout via Tailwind classes on the container: base =
        bottom sheet (`fixed inset-x-0 bottom-0 …`), `lg:` = docked left panel
        (`lg:inset-auto lg:left-4 lg:top-4 lg:w-96 lg:rounded-xl …`).
- [x] step 4: read `app/helpers/map_helper.rb`; add `map_card_strings` returning a hash
      of every static card string from `t()` (`show_on_map`, `directions`, `guidebook`,
      `problems`, `warning`, `close`, `height_meters`, a `steepness` values map, a
      `poi_types` map). Add the matching keys under `views.map.card` in
      `config/locales/en.yml` and `config/locales/de.yml` (reuse the existing
      `problem.steepness.*` translations for the steepness map).
- [x] step 5: read `app/views/map/index.html.erb`; add inside the controller div:
      `<div data-map-target="card" class="hidden …"></div>` and the attributes
      `data-map-card-strings-value="<%= map_card_strings.to_json %>"` and, when `@area`,
      `data-map-area-id-value="<%= @area.id %>"`. Read `app/controllers/map_controller.rb`
      — `@area` already exists for meta tags; no controller change needed beyond what
      P5 uses.
- [x] step 6: rewire `app/javascript/controllers/map_controller.js` (read fully first;
      keep its JSDoc standard):
      - import `MapSelection` and `InfoCard`; add the `card` target and `cardStrings` /
        `areaId` values; instantiate both on `load`;
      - add `registerSelectClicks(layerId, kind, zoomPredicate)` applied to `problems`,
        `pois`, `areas`, `areas-hulls`, `clusters`, `cluster-hulls`, `regions`,
        `region-hulls` (hulls select the same entity as their pin; the existing
        per-layer zoom predicates from `setupClickEvents` are preserved): on click →
        `selection.select(kind, props.<kind>Id)` + `card.show(kind, props, callbacks)`;
        the legacy `registerBoundsClicks` drill-in wiring is removed (drill-in now goes
        through the card CTA);
      - background click (a plain `map.on("click")` handler that found no interactive
        feature via `queryRenderedFeatures` over the interactive + selected layers) →
        `selection.clear()` + `card.hide()`; the card close button does the same;
      - card `showOnMap` callback: for regions use `mainClusterSouthWest*`/`NorthEast*`
        bounds when present, else the feature's own bounds; clusters/areas use their own
        `southWest*`/`northEast*` — all through `flyToBounds`, then close the card;
      - sheet handling: when the card opens below the `lg` breakpoint
        (`window.matchMedia("(min-width: 1024px)")`), call
        `this.map.setPadding({ bottom: <card element height> })` and `easeTo` the
        selected coordinate if it is covered; restore `setPadding({ bottom: 0 })` on
        close — the selected pin stays visible;
      - keep `createPopup`/`contributionPopupContent` for the contribution overlay only
        (problem/POI popup removal happens in P5 together with the entry-point rewires).
- [x] step 7: extend `test/controllers/map_controller_test.rb` (read first): the map page
      renders the card target, `data-map-card-strings-value` containing the localized
      `show_on_map` string per locale, and `data-map-area-id-value` for `?slug=` requests;
      strings render in both `de` and `en`.

**Quality gate:** `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.invalid -e BUNNY_STORAGE_ACCESS_KEY_ID=dummy -e BUNNY_STORAGE_SECRET_ACCESS_KEY=dummy -e BUNNY_STORAGE_REGION=dummy -e BUNNY_STORAGE_BUCKET=dummy web bash -lc 'bin/rails db:prepare && bin/rails test test/controllers/map_controller_test.rb test/controllers/mapping/contribution_requests_controller_test.rb && bin/importmap audit && bin/rubocop -f github'` → all green. Narrower gate is sufficient: this phase changes the map page, its helper/locales, and importmap-pinned JS; the JS behaviour itself is covered by the documented P6 manual smoke (no JS harness exists).

## Phase 0006-P5 — search/deep-link integration, popup removal, drill-in fixes

Goal: every entry point (search, `?pid=`, `?slug=`) lands in the new selected-card model;
legacy problem/POI popups are gone; region drill-in lands on the main cluster.

- [x] step 1: read `app/javascript/controllers/map_controller.js` again as left by P4;
      then:
      - `flyToBounds`: delete `cameraOptions.zoom = Math.max(15, cameraOptions.zoom)` —
        every drill-in now fits its target bounds (the Maltatal camera fix);
      - add `selectFeatureWhenIdle(sourceLayer, idProperty, id, kind)`: after a
        `flyTo`/`flyToBounds`, on the next `map.once("idle")` run
        `querySourceFeatures("austrian-rocks", { sourceLayer, filter: ["==", ["get", idProperty], id] })`
        (fallback `queryRenderedFeatures`), and when found select + open the card; when
        not found (feature outside zoom range / not yet loaded) retry once on the next
        `idle`, then give up silently leaving the plain map — never throw;
      - `gotoproblem(event)`: fly as today, then
        `selectFeatureWhenIdle("problems", "problemId", event.detail.id, "problem")`
        (replaces the popup);
      - `gotoarea(event)`: fly as today, then
        `selectFeatureWhenIdle("areas", "areaId", event.detail.id, "area")`
        (`search_controller.js` already sends `detail.id`; its events and detail shape
        are unchanged);
      - `centerMap()`: the `?slug=` flow chains `selectFeatureWhenIdle("areas", "areaId", this.areaIdValue, "area")`;
        the `?pid=` flow flies then selects the problem the same way; delete the
        deferred `this.popup` + `moveend` replay logic;
      - delete `problemPopupContent`, `poiPopupContent`, `registerProblemClicks`,
        `registerPoiClicks`, and `problemFeatureId` (the card path reads `problemId`
        from tile properties; Rails deep links supply the id explicitly);
        `cleanHistory` and `hash: true` stay untouched so URL/history behaviour is
        unchanged.
- [x] step 2: read then update `test/controllers/map_controller_test.rb`: deep-link
      `?pid=` page still embeds `data-map-problem-value`; assert the served controller
      JS (`app/javascript/controllers/map_controller.js`) no longer contains
      `problemPopupContent`, `poiPopupContent`, or a `Math.max(15,` zoom clamp, and does
      contain `selectFeatureWhenIdle` (string assertions on the file, matching how 0005
      regression-checked controller code).
- [x] step 3: grep `app/views` and `app/javascript` for now-dead references
      (`problemPopupContent`, `poiPopupContent`, popup-only CSS hooks) and remove
      leftovers.

**Quality gate:** `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.invalid -e BUNNY_STORAGE_ACCESS_KEY_ID=dummy -e BUNNY_STORAGE_SECRET_ACCESS_KEY=dummy -e BUNNY_STORAGE_REGION=dummy -e BUNNY_STORAGE_BUCKET=dummy web bash -lc 'bin/rails db:prepare && bin/rails test test/controllers/map_controller_test.rb && bin/rubocop -f github'` → 8 runs, 163 assertions, 0 failures, 0 errors; rubocop exit 0. Narrower gate is sufficient: only the map controller JS and its markup tests changed; the full suite and manual smoke follow in P6.

## Phase 0006-P6 — interaction contract docs, release gate, manual smoke

Goal: the shared contract is documented for the mobile apps, the whole suite is green,
and the visual/interactive behaviour is verified in a real browser and recorded.

- [x] step 1: read `docs/map_tiles.md`; add an **Interaction contract** section: pin →
      selected-state model (dedicated `-selected` layers, id filters, sentinel `-1`, no
      `feature-state`), card field → tile-property mapping per entity kind, CTA semantics
      ("Show on map" = entity bounds; region = main-cluster bounds with full-bounds
      fallback; Directions = `parkingGoogleUrl`/`googleUrl`; problem CTA = redirect
      link), cascade semantics reference, crossfade window contract, and the sprite icon
      name inventory — enough that iOS/Android implement the same model without reading
      web code.
- [x] step 2: write `.incant/work/0006-maplibre-web-interactions/manual-smoke.md` —
      checklist with columns for environment, browser, data set, route URLs, and
      observations covering: pin+label rendering for regions/clusters/areas/POIs in the
      light style and in the published dark style JSON (loaded directly, since the site
      has no dark switcher), select-grow + card open/close/switch on each entity kind,
      bottom sheet at ≈375px with the selected pin visible, docked panel at ≥1280px,
      hull/boulder crossfade around the window (no simultaneous full-opacity rendering
      outside it, no boulders below it), Maltatal region card "Show on map" landing on
      the main-cluster boulders, a region without a main cluster falling back to full
      bounds, search → problem and area cards, `?pid=` and `?slug=` deep links,
      contribution overlay popups unaffected, and both locales. Execute it in the
      browser against Docker dev with a published e2e release
      (`bin/rails "map_tiles:publish[<version>]"` flow) and record concrete
      observations — explicitly avoiding the thin smoke evidence accepted as wontfix
      in 0005. As completed after final review: the human explicitly waived the missing
      detailed observation record after reporting that the smoke was checked; the artifact
      records that waiver instead of reconstructing observations.
- [x] step 3: run the full automated release gate (command below) and the stale-reference
      sweep `rg -n 'basemap-download/webapp/api/sprites|flugplatz|problemPopupContent|poiPopupContent|Math\.max\(15' app config lib test docs/map_tiles.md` → expect no output.
- [x] step 4: check every spec acceptance criterion against evidence; update this plan's
      Status block and `.incant/STATE.md`; request `/incant:review 0006`.

**Quality gate:** `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.invalid -e BUNNY_STORAGE_ACCESS_KEY_ID=dummy -e BUNNY_STORAGE_SECRET_ACCESS_KEY=dummy -e BUNNY_STORAGE_REGION=dummy -e BUNNY_STORAGE_BUCKET=dummy web bash -lc 'bin/rails db:prepare && bin/rails test && bin/importmap audit && bin/rubocop -f github && bin/brakeman --no-pager'` → full suite green, no vulnerable packages, no offenses, no warnings; **plus** the completed manual smoke record with observations.

## Phase 0006-P7 — human-smoke interaction polish

Goal: address the human-smoke UX concerns before final release. Keep this phase focused on
polishing the shipped interaction model rather than redesigning the map from scratch.

- [x] Pin labels: reduce the font sizes beside pins, especially region labels; tighten the
      region pin-to-text spacing so labels feel sized to the new pin icons rather than the old
      text-only map.
- [x] Selection animation: preserve/restore the grow transition when opening the first card,
      not only when switching while a card is already open; add a tasteful Apple-Maps-like
      wiggle/settle on selection without making it distracting.
- [x] Card CTA: rename the German/English “Show on map” copy to something that means “zoom
      to this place/area” instead of implying the user is not already on the map; also fix the
      CTA if it does nothing in manual smoke.
- [x] Card close button: make the close hover background a true circle, not a squashed oval.
- [x] Card placement: keep the card within the map area so it does not cover the search bar.
- [x] Map padding/camera shift: only shift the map when the card would actually cover the
      selected pin; make that shift smooth; do not automatically “unshift” the map on close.
- [x] Card stats: present problem count and grade range more nicely, using existing grade-range
      indicator patterns where possible. Consider showing a small set of popular routes only if
      the data contract supports it or the phase intentionally extends the tile properties.
- [x] Region pins: evaluate making region pins slightly larger in both selected and unselected
      states while keeping label sizing balanced.

**Quality gate:** rerun the relevant automated gate for the touched files (at minimum the map
controller/markup tests, map tile style tests if style JSON changes, `bin/importmap audit`, and
`bin/rubocop -f github`) and repeat the affected manual-smoke checks from
`.incant/work/0006-maplibre-web-interactions/manual-smoke.md`.

## Coverage self-review

| Spec requirement | Phase / steps |
|---|---|
| 1. Pins + labels, both styles, zoom ladder preserved | P3 step 7 |
| 2. Versioned sprite via Bunny flow, no `map.addImage` | P3 steps 1–6, 9 |
| 3. Select layer + grow tween + deselect invariants, no feature-state | P3 step 7 (layers), P4 steps 2, 6 |
| 4. Responsive card, pin stays visible | P4 steps 3, 6 (padding) |
| 5. Card content per entity from tile properties | P2 step 5 (data), P4 step 3 (render) |
| 6. DB & admin (warnings, Guidebook, parking) | P1 steps 2–12 |
| 7. Cascade-down resolution at export | P2 steps 2, 5, 7 |
| 8. problemCount/gradeRange/cover/cascade/main-cluster bounds in tiles | P2 steps 3–6 |
| 9. Region CTA → main-cluster bounds; zoom-15 clamp removed | P4 step 6 (CTA), P5 step 1 (clamp) |
| 10. Hull→boulder crossfade | P3 steps 7–8 |
| 11. Search/deep links open card; legacy popups removed; history preserved | P5 steps 1–3 |
| 12. Card strings localized de/en | P4 steps 4, 7 |
| 13. Contract docs incl. interaction contract | P2 step 8, P3 step 9, P6 step 1 |

- Symbol/signature consistency checked: `MapSelection#select(kind, id)` / `#clear()`,
  `InfoCard#show(kind, properties, callbacks)` / `#hide()`,
  `effective_card_attributes(record)`,
  `selectFeatureWhenIdle(sourceLayer, idProperty, id, kind)`,
  `registerSelectClicks(layerId, kind, zoomPredicate)`, `SpriteBuilder#build`, and
  `sprite_public_base_url` are referenced with the same names/arities everywhere above.
- Goal-level verification: P6 maps every acceptance criterion to automated gates (P1–P5)
  plus the recorded manual smoke for the JS-visual criteria the repo cannot test
  automatically.
- No placeholders: every step names real paths, concrete columns, layer ids, filters,
  zoom stops, and commands.
