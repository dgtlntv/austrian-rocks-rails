---
id: "0007"
slug: db-relationships-walking-paths
branch: incant/0007-db-relationships-walking-paths
title: Database Relationships And Walking Path Admin Foundations
stage: spec
status: in-progress
created: 2026-06-07
commit: 3cd48232
updated: 2026-06-07
---

# Database Relationships And Walking Path Admin Foundations

## Goal
Add verified relational foundations for boulders/topos/problems/POI routes and a first-class admin-managed walking-path data source that the later PMTiles pipeline can consume safely.

## Context & codebase fit
The current schema in `db/schema.rb` only enforces foreign keys for Active Storage, `boulders.area_id`, and `problems.area_id`. Several Rails associations exist in models but are not backed by database foreign keys, including `lines.problem_id`, `lines.topo_id`, `poi_routes.area_id`, `poi_routes.poi_id`, `clusters.region_id`, `areas.cluster_id`, `contributions.problem_id`, `contribution_requests.problem_id`, and `problems.parent_id`.

The bouldering hierarchy is already partially represented: `Boulder` belongs to `Area`, `Problem` belongs to `Area`, and `Topo` has a `boulder_id` column populated by `lib/tasks/geo.rake`, but the models do not expose `Topo belongs_to :boulder` or `Boulder has_many :topos`. Problems currently have no direct `boulder_id`; code infers boulder membership spatially from `Problem.location` and `Boulder.polygon` within the same area. Adding a direct, backfilled, verified optional relation will make admin queries, PMTiles exports, and later map interactions less ambiguous.

The POI schema stores access relationships in `poi_routes`, and `app/models/poi.rb` currently declares `has_many :areas` without `through: :poi_routes`, even though the join model exists. The upcoming PMTiles POI export needs accurate POI-area relationship metadata.

Walking paths do not exist yet. Backlog item `0004` needs published LineString/MultiLineString approach and connector paths as a first-class Rails/PostGIS source, plus admin UI support so maintainers can create, edit, publish, unpublish, delete, paste, or upload path geometry before the PMTiles exporter reads it.

## Requirements
1. Add an optional `problems.boulder_id` relation to `boulders.id`, with an index, model associations, and a deterministic backfill from existing published and unpublished data.
2. Backfill `problems.boulder_id` only when exactly one boulder in the problem's area contains or closely matches the problem location; leave unmatched or ambiguous problems unset and report them clearly.
3. Provide a repeatable verification/report command for problem-to-boulder assignment counts, including matched, missing-location, no-containing-boulder, multiple-containing-boulders, and area-mismatch cases.
4. Add model associations for existing `topos.boulder_id`: `Topo belongs_to :boulder, optional: true` and `Boulder has_many :topos`, and add or validate the database foreign key/index when existing data permits it.
5. Correct the POI relationship model so `Poi has_many :areas, through: :poi_routes`, while preserving existing `PoiRoute belongs_to :poi` and `PoiRoute belongs_to :area` behaviour.
6. Add database foreign keys for clean existing relationship columns where current data validates: `areas.cluster_id`, `clusters.region_id`, `lines.problem_id`, `lines.topo_id`, `poi_routes.area_id`, `poi_routes.poi_id`, `contribution_requests.problem_id`, `contributions.problem_id`, `problems.parent_id`, `clusters.main_area_id`, and `regions.main_cluster_id`.
7. If any candidate foreign key cannot be added because existing data is dirty, do not silently discard data; document the failing rows in the verification output and leave that foreign key out with a clear follow-up note.
8. Add a Rails/PostGIS `WalkingPath` model/table for approach and connector paths with optional labels, slug, description, published flag, and SRID 4326 LineString/MultiLineString geometry. The model must not force a single-area or single-cluster ownership assumption.
9. Provide optional many-to-many associations from walking paths to areas, and from walking paths to clusters if the UI/export needs explicit editorial grouping, without making either association required for publishing.
10. Provide an admin UI for walking paths under the existing `/admin` namespace so maintainers can list, create, edit, publish/unpublish, and delete paths.
11. The walking-path admin UI must support both pasted GeoJSON and uploaded `.geojson` files containing a LineString or MultiLineString geometry, either as a raw geometry or as a Feature/FeatureCollection with exactly one valid line geometry.
12. Invalid walking-path geometry input, unsupported geometry types such as Point/Polygon, malformed JSON, and multi-feature uploads with more than one line geometry must show clear validation errors and must not partially save invalid records.
13. Walking paths marked published must have a slug and valid line geometry; unpublished draft walking paths may be saved without geometry.
14. All new migrations must be generated with Rails migration commands and then edited; migrations must be reversible or provide explicit irreversible-operation rationale.
15. The implementation must include automated model, migration/backfill/report, and admin controller tests, plus fresh passing evidence for `bin/rubocop` and relevant Rails tests before review.

## In scope / Out of scope
**In scope:**
- `problems.boulder_id` column, association, deterministic backfill, and verification/report command.
- Model associations and database foreign keys for existing clean relationships listed in the requirements.
- Correct POI `areas` association through `poi_routes`.
- First-class walking-path model/table with PostGIS line geometry.
- Optional walking-path grouping through areas and clusters if needed for admin/export ergonomics.
- Admin walking-path CRUD with publish/unpublish, delete, GeoJSON paste, and GeoJSON upload.
- Tests for relationships, backfill/report behaviour, walking-path validations, and admin geometry handling.

**Out of scope:**
- PMTiles export/build/smoke/Bunny publication — reason: handled by `0004` after these database foundations are complete.
- Web MapLibre rendering and map interactions — reason: handled by later map items after the PMTiles artifact exists.
- Automatic reassignment of ambiguous problems to boulders — reason: ambiguous spatial data requires explicit maintainer review.
- Direct `lines.boulder_id` — reason: line-to-boulder can be derived through `line.problem.boulder` and/or `line.topo.boulder`; duplicating it risks inconsistent data.
- Reworking topo photo/line drawing UX beyond the walking-path admin UI — reason: this item focuses on relational foundations and path source data.

## Approach
Create a focused database-foundations item before `0004`. Use Rails-generated migrations for schema changes. Backfill `problems.boulder_id` from spatial containment within each problem's area, and make the relation optional so dirty or ambiguous legacy data does not block deployment. Add verification/reporting before enforcing each new foreign key so the implementation can add clean constraints confidently and document any deferred constraints.

Walking paths should be managed as their own editorial data source, not inferred from POI access metadata and not attached to exactly one area. Store path geometry as SRID 4326 line geography and expose simple admin CRUD. Accept GeoJSON because it is the practical interchange format for edited path geometry, but validate it strictly before converting it into database geometry.

Rejected alternatives:
- Put all of this into `0004`: rejected because broad database cleanup and admin data-entry foundations would make the PMTiles delivery item too large and hard to review.
- Add `lines.boulder_id`: rejected because it duplicates relationships available through problems/topos and would require extra consistency rules.
- Force every walking path to belong to one area: rejected because approach and connector paths may span multiple areas or clusters.
- Auto-pick a boulder for ambiguous problem locations: rejected because silent wrong assignments are worse than explicit unresolved reports.

## Considerations

### Config vs code
This item is mostly schema and model work, so most values are not runtime configuration. The spatial backfill/report command may use a small, documented default tolerance for near-boundary point/polygon matching; if that tolerance is needed, keep it as a named constant or command option at the backfill boundary rather than scattering literals through model code. Admin-accepted geometry formats are fixed product behaviour, not environment configuration.

### Security
Admin walking-path geometry input is untrusted even though it comes through authenticated admin routes. The controller must parse uploaded and pasted GeoJSON with size-conscious handling, reject malformed JSON and unsupported geometry types, and render validation errors without echoing unsafe HTML. File uploads are read as data only; no uploaded filename should influence filesystem paths. No secrets are involved. The blast radius of invalid geometry is contained by transactionally rejecting invalid `WalkingPath` records before save.

### Testability
Automated tests should cover model associations, walking-path validations, GeoJSON parsing, admin CRUD, and the problem-to-boulder backfill/report decision cases. Use fixtures or explicit test records for one matched problem, one missing-location problem, one no-containing-boulder problem, and one ambiguous problem. Relevant commands include targeted tests such as `bin/rails test test/models/walking_path_test.rb test/models/problem_boulder_assignment_test.rb test/controllers/admin/walking_paths_controller_test.rb`, plus `bin/rubocop` before review.

### Code documentation
Document non-obvious boundaries: the problem-to-boulder assignment service/report should explain its matching rules and why ambiguous rows are left unset; the walking-path GeoJSON parser should explain accepted shapes and rejection behaviour. Avoid noisy comments on standard Rails associations, validations, and CRUD actions.

## Acceptance criteria
- [ ] `problems.boulder_id` exists with model associations, an index, an added foreign key when data permits, and a deterministic backfill that leaves ambiguous/unmatched rows unset.
- [ ] A repeatable verification/report command outputs counts and row identifiers for matched, missing-location, no-containing-boulder, multiple-containing-boulders, and area-mismatch problem assignment cases.
- [ ] `Topo`/`Boulder` associations exist for `topos.boulder_id`, and the database relation is indexed and foreign-keyed when existing data validates.
- [ ] `Poi has_many :areas, through: :poi_routes` works and is covered by a model test.
- [ ] Clean existing relationships listed in the requirements have database foreign keys, or each deferred foreign key has documented dirty rows and a follow-up note.
- [ ] `WalkingPath` exists with published/draft validation rules and SRID 4326 LineString/MultiLineString geometry support.
- [ ] Admin users can list, create, edit, publish/unpublish, delete, paste GeoJSON, and upload `.geojson` for walking paths.
- [ ] Invalid walking-path GeoJSON and unsupported geometry types fail with clear errors and do not partially save records.
- [ ] Walking paths do not require single-area ownership; any area/cluster associations are optional many-to-many editorial groupings.
- [ ] Relevant Rails tests and `bin/rubocop` pass with fresh evidence before review.

## Risks & open questions
- Existing production data may contain orphan relationship IDs; the implementation should report and defer unsafe foreign keys rather than guessing destructive cleanup.
- Some problem locations may fall near boulder polygon boundaries; the first implementation should prefer explicit unresolved reporting over aggressive tolerance.
- Adding walking-path area/cluster join tables may be useful for admin filtering, but they should remain optional so they do not recreate a single-owner path assumption.
