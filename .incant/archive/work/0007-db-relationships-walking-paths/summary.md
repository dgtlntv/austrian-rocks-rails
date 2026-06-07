---
id: "0007"
slug: db-relationships-walking-paths
stage: archived
completed: 2026-06-07
commit: 405aa543abe144ea84ccb14b5d1d36f10e9d9d07
---

# Summary — Database Relationships And Walking Path Admin Foundations

## What was built
- Added optional `problems.boulder_id` with model associations, index, foreign key, deterministic report/backfill service, and repeatable rake tasks that classify matched, missing-location, no-containing-boulder, multiple-containing-boulders, and area-mismatch cases.
- Added verified database indexes/foreign keys for the existing clean area, cluster, region, line, POI route, contribution, contribution request, parent problem, topo, and boulder relationships.
- Corrected the POI-area relationship to use `Poi has_many :areas, through: :poi_routes` and added model coverage for the relationship foundations.
- Added first-class `WalkingPath`, `WalkingPathArea`, and `WalkingPathCluster` records with SRID 4326 LineString/MultiLineString geometry, optional many-to-many area/cluster editorial groupings, and published/draft validation rules.
- Added strict GeoJSON parsing for one LineString or MultiLineString from raw Geometry, Feature, or FeatureCollection input, with clear rejection of malformed JSON, unsupported Point/Polygon input, mixed unsupported sibling geometries, or multiple line geometries.
- Added admin walking-path CRUD under `/admin`, including list/create/edit/delete, publish/unpublish, optional groupings, pasted GeoJSON, uploaded `.geojson`, transactional invalid-input handling, and navigation.
- Added automated model/service/controller coverage plus release-readiness evidence for migrations, production-data reports/backfill, relevant Rails tests, and full RuboCop.

## Deviations from spec
- Walking-path geometry is stored in a generic SRID 4326 PostGIS `geometry` column with a check constraint for LineString/MultiLineString rather than a single `geography` typmod, because PostGIS typmods cannot accept both LineString and MultiLineString in one column.
- No dirty relationship rows were found in the Docker-hosted `dump-prod` verification reports, so no candidate foreign keys were deferred and no dirty-data follow-up was needed.
- Production-data problem-to-boulder report/backfill found zero rows in every category in the checked database, so the backfill task updated zero rows while still proving the reporting/update path.

## Key decisions
- `problems.boulder_id` remains optional; ambiguous, unmatched, missing-location, or area-mismatch rows are reported and left unset instead of guessed.
- Walking paths are independent editorial source records; area and cluster links are optional many-to-many groupings and never required for publishing.
- GeoJSON parsing lives in `WalkingPathGeojsonParser` outside the controller so parser rules and malformed-input behaviour are directly testable.
- Any database quality gate for this item runs against Docker-hosted PostgreSQL/PostGIS rather than a host-created database.

## Links
- Feature branch: `incant/0007-db-relationships-walking-paths`
- Final implementation commit: `405aa543abe144ea84ccb14b5d1d36f10e9d9d07`
- Key commits: `6952d912` spec, `9a3ff5d0` plan, `a3f47e38` P1 relationship foundations, `88cd001a` P2 walking-path model, `790e4456` P2 GeoJSON review fix, `dcdd0f86` P3 admin, `cfc3b737` P3 upload review fix, `e553738f` P4 release readiness, `405aa543` premature-summary cleanup.
- Review verdict: `review.md` says ready to release with no open blocker or major findings.

## Sessions
- `019e9eb9-db00-75bd-b671-0db5b501a030`
- `019ea14a-448d-76f4-a0ac-388e3f57be1f`
- `019ea154-2ee7-7ba3-881e-d242692e5366`
- `019ea163-2688-7e67-b58b-dea93ee4b106`
- `019ea167-2b40-7cef-a602-26ae7d876b8e`
- `019ea16f-7d39-7284-83a0-2163c93035da`
- `019ea173-aed6-75c8-a3e8-6ba8f2ad2f9b`
- `019ea176-b3ea-7236-a85b-362bd380f45f`
- `019ea178-efd8-7a7f-9755-273d30c774c6`
- `019ea17f-8a30-7716-b0e8-8b769927afd2`
- `019ea184-4fda-7805-b0e7-41cf74591f8f`
- `019ea188-a6c2-7599-8935-2b53838f311c`
- `019ea18d-82f3-7db1-b60d-8a5a320a1d2e`
- `019ea193-1365-7586-ba34-3ee88c1cf4ce`
- `019ea198-9d65-749c-9a44-02e21053e7b8`
- `019ea19b-b136-7eb5-a9d8-d6fb8f0bd5e1`
- `019ea19f-af96-71fa-86f7-e918f290d33e`

## Follow-ups
None.
