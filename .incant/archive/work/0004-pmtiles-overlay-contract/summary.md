---
id: "0004"
slug: pmtiles-overlay-contract
stage: archived
completed: 2026-06-07
commit: f680990bf792d5853fee55c8e1ae2fff805307ab
---

# Summary — Austrian Rocks PMTiles Overlay Contract And Bunny Delivery

## What was built
- Added a Rails-side `MapTiles` subsystem for deterministic GeoJSON export, Tippecanoe PMTiles generation, smoke checking, and Bunny/CDN publication.
- Defined the ten PMTiles source layers required by the contract: `problems`, `boulders`, `areas`, `area_hulls`, `clusters`, `cluster_hulls`, `regions`, `region_hulls`, `walking_paths`, and `pois`.
- Exported consumer-safe camelCase scalar properties with stable IDs/slugs, localized `name`/optional `nameEn` behavior where available, no circuit fields, and no app-local canonical URLs.
- Included published `WalkingPath` line geometry and POI `accessAreasJson` scalar JSON metadata derived from `poi_routes`.
- Added `bin/build_pmtiles` and `rails map_tiles:*` entry points for `export`, `build`, `smoke`, and `publish`.
- Added Tippecanoe missing-binary guidance, native max zoom `16`, strict production smoke checks, relaxed local smoke checks, Bunny dual upload to immutable/latest object keys, and HTTP `HEAD` reachability verification.
- Created the ignored local consumer/maintainer contract at `docs/map_tiles.md`; `/docs/` remains gitignored as specified.

## Verification
- Targeted map tile tests: `28 runs, 793 assertions, 0 failures, 0 errors, 0 skips`.
- Full Rails test suite, single process: `68 runs, 930 assertions, 0 failures, 0 errors, 0 skips`.
- RuboCop: `261 files inspected, no offenses detected` in the final implementation gate; final focused review gate also passed with `14 files inspected, no offenses detected`.
- Brakeman: `Security Warnings: 0`.
- Final review verdict: **Yes** — no open blocker or major findings remain.

## Deviations from spec
- No functional deviations from the accepted spec.
- `Gemfile.lock` updates Brakeman from `7.0.0` to `8.0.4` so the existing `bin/brakeman --ensure-latest` binstub/final gate can pass.
- Blank-but-valid problem grades are exported as the documented scalar fallback `unknown` to keep the required `grade` property present.

## Key decisions
- Built a new `lib/map_tiles/` subsystem instead of extending the Mapbox-era rake task.
- Kept generated GeoJSON/PMTiles under ignored `tmp/map_tiles/` and kept production delivery on Bunny/CDN, not Rails `public/maps`.
- Reused Bunny S3-compatible credentials while keeping map tile CDN host, Bunny prefix, and version naming map-specific.
- Smoke checks read PMTiles archive metadata directly rather than trusting a sidecar file.
- Optional PMTiles fields are allowed to be absent from Tippecanoe metadata, while required fields, unexpected fields, circuit fields, and app URL fields remain checked.

## Links
- Branch: `incant/0004-pmtiles-overlay-contract`
- Final implementation commit: `f680990bf792d5853fee55c8e1ae2fff805307ab`
- Key commits:
  - `f71dd309` — `incant 0004-P1: contract and source alignment`
  - `7e4b5ada` — `incant 0004-P1: keep contract in ignored docs`
  - `5d38d12f` — `incant 0004-P1: address review findings`
  - `c40f12f4` — `incant 0004-P2: deterministic export and Tippecanoe build`
  - `33a3d76a` — `incant 0004-P2: address exporter review blocker`
  - `8af61875` — `incant 0004-P3: add PMTiles smoke checks`
  - `2ec715f8` — `incant 0004-P3: inspect PMTiles artifact metadata`
  - `f615a740` — `incant 0004-P3: allow Tippecanoe metadata variations`
  - `f680990b` — `incant 0004-P4: publish PMTiles to Bunny`

## Sessions
- `019e9d7f-06fb-7d13-b303-699c0a7bfe94`
- `019e9eb9-db00-75bd-b671-0db5b501a030`
- `019ea364-ab20-75b0-86b5-a24e147db2a4`
- `019ea386-1456-7aed-aacf-e32de6ec332d`
- `019ea38b-e7f5-7db9-870b-8f3f643ff640`
- `019ea38f-e67c-740b-acad-d4b32b8a6edb`
- `019ea391-dfec-7e14-ac7a-4917f5d002ef`
- `019ea39b-a588-74c2-93d4-27b4f75730c6`
- `019ea39f-78b1-7d85-8399-ad9eccfc0d35`
- `019ea3a5-478b-7f41-86e5-421e79b9f3c7`
- `019ea3a9-f206-7d9a-a2dc-db1f152e226a`
- `019ea3b3-6dba-763e-9423-1511efde8433`
- `019ea3b5-ec86-799e-a756-ae661e7ffd6a`
- `019ea3b9-9a62-797f-89ce-a731fbe2e5dc`
- `019ea3bc-7b5b-778d-b1dd-3df274a5ad19`
- `019ea3bf-54b5-7bcd-a5f9-c8a02e882b96`
- `019ea3c2-21a1-7314-8055-782acd668544`
- `019ea3cf-3200-7774-8fd3-f663e42a3507`

## Follow-ups
- None spawned; final review found no open blocker, major, minor, or nit work requiring a new inbox item.
