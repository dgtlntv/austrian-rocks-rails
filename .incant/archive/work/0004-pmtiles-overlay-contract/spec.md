---
id: "0004"
slug: pmtiles-overlay-contract
branch: incant/0004-pmtiles-overlay-contract
title: Austrian Rocks PMTiles Overlay Contract And Bunny Delivery
stage: spec
status: in-progress
created: 2026-06-06
commit: 7ad83370
updated: 2026-06-07
---

# Austrian Rocks PMTiles Overlay Contract And Bunny Delivery

## Goal
Produce a documented, smoke-checked, versioned Austrian Rocks PMTiles overlay artifact from Rails/PostGIS data and publish it to Bunny/CDN as both an immutable version and a stable latest object.

## Context & codebase fit
The current Rails web map uses Mapbox through `app/javascript/controllers/mapbox_controller.js` and a Mapbox vector tileset with ad-hoc source-layer names. The existing export code in `lib/tasks/mapbox.rake` writes GeoJSON files for Mapbox-era uploads, using Rails models such as `Problem`, `Boulder`, `Area`, `Cluster`, `Region`, and `Poi` backed by PostGIS geography columns in `db/schema.rb`.

A previous exploratory branch, `feature/maplibre-render`, prototyped `lib/tasks/map_tiles.rake`, `bin/build_pmtiles`, a local `public/maps/austrian-rocks.pmtiles`, and MapLibre rendering against PMTiles. That branch is useful context only; this work should turn the idea into a production-ready data contract and delivery pipeline rather than copy hacking assumptions.

The iOS app lives outside this repo at `/Users/maximilianblazek/Documents/GitHub/austrian-rocks-ios`. Its current Mapbox implementation is context for consumer needs: stable feature IDs, problem/area/cluster selection, POI actions, filters, and offline/download behavior. This Rails repo owns the shared PMTiles contract and delivery artifact, but not the iOS implementation.

## Requirements
1. Define a PMTiles consumer contract artifact at `docs/map_tiles.md` that lists every layer, geometry type, required property, optional property, naming convention, native max zoom, and Bunny/CDN URL rule. Keep `/docs/` and its contents gitignored for now; this docs contract is a local ignored working artifact and must not be committed in this item.
2. Generate a PMTiles overlay with exactly these initial source layers: `problems`, `boulders`, `areas`, `area_hulls`, `clusters`, `cluster_hulls`, `regions`, `region_hulls`, `walking_paths`, and `pois`.
3. Consume the database relationship cleanup and published `WalkingPath` model/admin source data delivered by completed backlog item `0007`; do not add or recreate those foundations in `0004`.
4. Use camelCase feature property names in the PMTiles contract, while leaving Rails/database internals in their existing snake_case style.
5. Expose stable scalar identifiers and metadata needed by web and iOS consumers; do not encode app-local canonical URLs in PMTiles features. Consumers must build app navigation from IDs/slugs. POI features may include their external `googleUrl`.
6. Include localized feature labels as `name` plus optional `nameEn` where an English value exists and differs from the default name.
7. Include POIs in the first contract. POI point features must include area access relationship metadata derived from `poi_routes` without pretending there is route geometry. Because vector-tile properties are scalar, relationship metadata must be encoded in an explicitly documented scalar representation such as a JSON string property.
8. Document the distinction between PMTiles source layers and later MapLibre style layers: text labels for regions, clusters, areas, and boulders can render from their source layers; hull/polygon fills and outline line styles can render from the same polygon source layers; `walking_paths` renders as line styles.
9. Exclude all circuit-related layers and properties. Circuit data is intentionally removed from this product direction and must not be reintroduced by the PMTiles contract.
10. Generate all overlay layers with PMTiles native max zoom `16`; map clients may overzoom above `16`.
11. Standardize on Tippecanoe for PMTiles generation. The build command must fail clearly when Tippecanoe is missing and include install guidance.
12. Treat generated PMTiles files as build artifacts only. The repository must not commit `.pmtiles` output, and the production pipeline must not rely on Rails serving `public/maps/austrian-rocks.pmtiles`.
13. Publish PMTiles to Bunny/CDN as both an immutable versioned object and a stable latest object. Example shape: `<prefix>/austrian-rocks-<version>.pmtiles` and `<prefix>/austrian-rocks-latest.pmtiles`.
14. Keep map tile public URL, object prefix, and artifact naming/versioning in map-specific configuration, while reusing existing Bunny storage credentials where sensible.
15. Add smoke checks that verify the generated PMTiles artifact exists, is non-empty, exposes the expected layers, has required properties on sampled features, has sane Austria-area bounds, and contains non-zero features for every expected layer in production/export mode.
16. Provide an explicit relaxed smoke-check mode for local/test fixtures where one or more expected layers may legitimately have zero features, while production/export mode fails on zero-feature expected layers.
17. Verify Bunny delivery by checking that both the versioned object and latest object are uploaded and reachable via HTTP `HEAD`.

## In scope / Out of scope
**In scope:**
- A production-ready Rails-side exporter/build command for Austrian Rocks overlay GeoJSON and PMTiles.
- A stable PMTiles layer/property contract for web and external iOS consumption.
- Export of published walking path line geometries from the `WalkingPath` data source delivered by backlog item `0007`.
- Tippecanoe-based PMTiles generation with native max zoom `16`.
- Smoke checks for artifact structure, expected layers, sampled properties, bounds, feature counts, and Bunny reachability.
- Bunny/CDN upload of immutable versioned and stable latest PMTiles objects.
- Map-specific configuration for public CDN host, Bunny object prefix, and artifact version naming.
- A PMTiles contract artifact in `docs/map_tiles.md` for consumers and maintainers; `/docs/` and its contents remain gitignored and must not be committed for now.

**Out of scope:**
- Database relationship cleanup, `problems.boulder_id`, `WalkingPath` model/table, and walking path admin UI — reason: completed backlog item `0007` already owns and delivered those foundations.
- Rails web MapLibre rendering — reason: handled by backlog item `0005` after the overlay contract exists.
- Rails web map tap/preview/card interactions — reason: handled by backlog item `0006` after rendering is stable.
- iOS MapLibre implementation — reason: the iOS app is outside this repository.
- basemap.at basemap, hillshade, contour style work — reason: this item owns Austrian Rocks overlays, not basemap rendering.
- Circuit data — reason: circuits are intentionally being removed and must not be part of the new contract.
- Committing generated `.pmtiles` artifacts — reason: generated map tiles belong on Bunny/CDN, not in git.
- Real route/path geometry for POI access — reason: `walking_paths` are general approach/connector map overlays, while the current `poi_routes` schema stores access metadata rather than per-POI route geometries.

## Approach
Create a small, documented map-tile export subsystem rather than extending the old Mapbox-specific task in place. Completed backlog item `0007` has already delivered the relational cleanup and first-class walking-path source data that this exporter consumes. The exporter should query published Rails/PostGIS data, write deterministic intermediate GeoJSON under `tmp/`, build a single PMTiles artifact with Tippecanoe named layers, smoke-check the artifact, and upload it to Bunny/CDN using map-specific destination config.

The PMTiles contract should use stable, human-readable layer names instead of Mapbox-generated source-layer names. Feature properties should be deliberately chosen, documented, and kept scalar where vector-tile tooling requires it. Walking paths should be line features with stable IDs and optional editorial metadata, not attached to a single area when they can span areas or clusters. POI-to-area access metadata should be represented as documented scalar metadata, not as fake geometry.

Rejected alternatives:
- Continue using Mapbox tilesets: rejected because the product direction is MapLibre plus self-controlled PMTiles/Bunny delivery.
- Commit PMTiles into `public/maps`: rejected because production delivery should be Bunny/CDN-only and generated artifacts should not live in git.
- Contract-only documentation without a working pipeline: rejected because downstream web/iOS work needs a verified artifact, not a theoretical contract.
- Include circuit layers for iOS parity: rejected because circuits are intentionally being removed.

## Considerations

### Config vs code
Map tile delivery values are configuration, not hardcoded behavior. The implementation should introduce map-specific configuration for at least the public CDN host, Bunny object prefix, and version/latest naming rules. Existing Bunny S3-compatible credentials may be reused where appropriate, but map tile public URLs and object names must not be coupled to Active Storage blob paths. Defaults should support local development using `tmp/` build output, while production/export mode requires explicit Bunny/CDN destination config before upload.

### Security
The exporter trusts Rails database records as application data but must treat filesystem paths, environment variables, and Bunny responses carefully. Bunny credentials remain in environment variables or the existing secret-management path and must not be committed or written into `.incant/`, ignored docs, logs, or generated metadata. Upload code must avoid path traversal by constructing object keys from fixed prefixes and generated version strings, not arbitrary user input. Generated PMTiles are public artifacts; only public map properties belong in the contract. Sensitive internal fields, credentials, private notes, unpublished data, or unpublished walking paths must not be exported.

### Testability
The pipeline should have automated checks around both the data contract and delivery behavior. Unit or task-level tests should cover layer/property definitions and exporter behavior against fixtures where practical. Smoke checks should be runnable as a command after generation and should fail with clear messages when expected layers/properties/counts/bounds are missing. Bunny upload reachability can be verified with HTTP `HEAD` in export mode; tests should isolate network calls or use a dry-run/fake client seam so normal local test runs do not require Bunny credentials. Relevant commands should include the existing project gates `bin/rubocop`, `bin/brakeman --no-pager`, and targeted Rails tests or smoke-check commands introduced by this work.

### Code documentation
New exporter, smoke-check, and upload entry points should be documented at their module or command boundaries: what data they export, why layer/property names are stable, how version/latest upload works, and what failures mean. JavaScript is not expected to be touched in this item. Documentation should be concise and useful, avoiding comments that merely restate obvious code.

## Acceptance criteria
- [ ] `docs/map_tiles.md` exists locally as an ignored/untracked docs artifact and documents the PMTiles source layers, geometry types, required/optional properties, POI relationship metadata representation, walking path layer semantics, expected derived style-layer usage for labels/fills/outlines/lines, native max zoom `16`, and Bunny URL/versioning rules; `/docs/` contents are not committed.
- [ ] The exporter reads published walking paths from the `WalkingPath` source delivered by `0007`, without adding new walking-path schema/admin code.
- [ ] A Rails-side command can generate intermediate GeoJSON and build a PMTiles artifact with the expected layer names using Tippecanoe.
- [ ] The build fails clearly with install guidance when Tippecanoe is unavailable.
- [ ] Generated PMTiles are ignored/not committed and the production path uploads to Bunny/CDN instead of relying on `public/maps/austrian-rocks.pmtiles`.
- [ ] Smoke checks pass for a dataful export and verify expected layers, required properties, non-zero production feature counts, sane Austria-area bounds, and artifact non-emptiness.
- [ ] A relaxed smoke-check mode exists for local/test fixtures that may have zero features in selected layers.
- [ ] Bunny upload creates both a versioned PMTiles object and `austrian-rocks-latest.pmtiles`, and both are reachable by HTTP `HEAD` after upload.
- [ ] The PMTiles contract contains no circuit layers/properties and no app-local canonical URLs.
- [ ] POI features are included with documented area access relationship metadata derived from `poi_routes`.
- [ ] Walking path features are included as the `walking_paths` PMTiles source layer and rendered later from the same contract as line style layers.
- [ ] The implementation provides fresh passing evidence for relevant automated tests, `bin/rubocop`, and `bin/brakeman --no-pager` before review.

## Risks & open questions
- PMTiles metadata inspection may require an additional helper/tool if Tippecanoe alone does not expose everything needed for smoke checks; the plan should choose the smallest reliable inspection approach.
- Production feature-count thresholds beyond “non-zero” may need tuning after the first dataful export; the initial contract should keep exact counts observable without making them brittle.
- Bunny bucket/pull-zone cache behavior may require operational configuration outside this repo; this work should document any required external setup without storing secrets.
- `0004` implementation should run on a branch that includes `0007`'s final merged changes so exporter code compiles against `WalkingPath`, optional `problems.boulder_id`, and corrected POI associations.
