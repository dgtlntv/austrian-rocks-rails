---
id: "0007"
slug: db-relationships-walking-paths
branch: incant/0007-db-relationships-walking-paths
title: Database Relationships And Walking Path Admin Foundations
stage: implement
status: in-progress
created: 2026-06-07
updated: 2026-06-07
---

# Plan — Database Relationships And Walking Path Admin Foundations

## Status
- Current phase: `0007-P1` complete; awaiting review.
- Stage: implement
- Branch: `incant/0007-db-relationships-walking-paths`
- Next step: run `/incant:review 0007` for Phase 0007-P1.
- Blockers: none. Relationship verification against the Docker-hosted `dump-prod` database reported every candidate relationship clean before adding foreign keys.
- Fresh evidence:
  - `PATH="$(rbenv root)/shims:$PATH" DATABASE_URL=postgis://austrian-rocks:password@127.0.0.1:5432/dump-prod ... bin/rails relationship_foreign_keys:report` → all candidate relationships clean, no dirty row IDs.
  - `PATH="$(rbenv root)/shims:$PATH" DATABASE_URL=postgis://austrian-rocks:password@127.0.0.1:5432/dump-prod ... bin/rails db:migrate` → migrations `20260607091029` and `20260607091030` applied successfully in the Docker PostgreSQL/PostGIS container.
  - `PATH="$(rbenv root)/shims:$PATH" RAILS_ENV=test DATABASE_URL=postgis://austrian-rocks:password@127.0.0.1:5432/austrian-rocks-test ... bin/rails db:prepare` → test database prepared in the Docker PostgreSQL/PostGIS container.
  - `PATH="$(rbenv root)/shims:$PATH" RAILS_ENV=test DATABASE_URL=postgis://austrian-rocks:password@127.0.0.1:5432/austrian-rocks-test ... bin/rails test test/models/problem_boulder_assignment_test.rb test/models/relationship_foreign_key_report_test.rb test/models/topo_test.rb test/models/boulder_test.rb test/models/poi_test.rb` → 7 runs, 19 assertions, 0 failures, 0 errors, 0 skips.
- Key decisions:
  - The spec was approved by the human. `spec.md` frontmatter `commit: 3cd48232` is behind current `HEAD` (`6952d912`), but `HEAD` is the spec commit itself and code files have not changed since the spec was written; no spec rewrite is needed before planning.
  - `problems.boulder_id` remains optional; ambiguous and unmatched legacy rows are reported, not guessed.
  - Walking paths are independent editorial records; area/cluster links are optional many-to-many groupings only.
  - GeoJSON parsing lives outside the controller so model/service tests can cover malformed JSON, unsupported geometry, Feature, FeatureCollection, LineString, and MultiLineString cases.
  - Any quality-gate command that needs a database must run against PostgreSQL/PostGIS in a Docker container, not a database created directly on the host machine.

## Quality gate database rule
If a phase quality gate or Rails test requires a database, start or reuse a PostgreSQL/PostGIS database in a Docker container and point Rails at that container for the command. Do not create, initialize, or depend on a PostgreSQL/PostGIS database directly on the local machine.

## Files touched
- `.incant/backlog.md` — move item `0007` from `status:spec` to `status:plan` after plan creation.
- `.incant/STATE.md` — record that `0007` is planned and awaiting approval.
- `.incant/work/0007-db-relationships-walking-paths/plan.md` — this plan.
- `.incant/work/0007-db-relationships-walking-paths/sessions.json` — session link created by `incant session link 0007`.
- `db/migrate/*_add_boulder_id_to_problems.rb` — Rails-generated migration for optional `problems.boulder_id`, index, and foreign key when verification permits.
- `db/migrate/*_add_verified_relationship_foreign_keys.rb` — Rails-generated migration for clean existing foreign keys and indexes listed in the spec.
- `db/migrate/*_create_walking_paths.rb` — Rails-generated migration for walking paths and optional walking-path area/cluster join tables.
- `db/schema.rb` — schema output from running migrations.
- `app/models/problem.rb` — add optional boulder association and keep parent validation intact.
- `app/models/boulder.rb` — add `has_many :problems` and `has_many :topos` associations.
- `app/models/topo.rb` — add optional boulder association.
- `app/models/poi.rb` — change area relationship to `has_many :areas, through: :poi_routes`.
- `app/models/area.rb` — add optional walking-path join associations.
- `app/models/cluster.rb` — add optional walking-path join associations.
- `app/models/walking_path.rb` — new model with draft/published validations and geometry helpers.
- `app/models/walking_path_area.rb` — new join model from walking paths to areas.
- `app/models/walking_path_cluster.rb` — new join model from walking paths to clusters.
- `app/services/problem_boulder_assignment.rb` — new deterministic assignment/report service for problem-to-boulder matching.
- `app/services/relationship_foreign_key_report.rb` — new report helper for orphan candidate foreign-key rows.
- `app/services/walking_path_geojson_parser.rb` — new strict GeoJSON parser for one LineString or MultiLineString geometry.
- `lib/tasks/problem_boulder_assignments.rake` — repeatable report/backfill commands for problem-to-boulder assignments.
- `lib/tasks/relationship_foreign_keys.rake` — repeatable relationship verification report for candidate foreign keys.
- `config/routes.rb` — add admin walking-path resource routes and publish/unpublish member actions.
- `app/controllers/admin/walking_paths_controller.rb` — new admin CRUD, publish/unpublish, delete, pasted GeoJSON, and uploaded `.geojson` handling.
- `app/views/layouts/admin.html.erb` — add a navigation link to walking paths.
- `app/views/admin/walking_paths/index.html.erb` — list walking paths and actions.
- `app/views/admin/walking_paths/new.html.erb` — new walking-path form page.
- `app/views/admin/walking_paths/edit.html.erb` — edit walking-path form page.
- `app/views/admin/walking_paths/_form.html.erb` — shared fields for metadata, published flag, groupings, GeoJSON paste, and GeoJSON upload.
- `test/models/problem_boulder_assignment_test.rb` — assignment cases for matched, missing-location, no-containing-boulder, multiple-containing-boulders, and area-mismatch.
- `test/models/relationship_foreign_key_report_test.rb` — dirty-row report coverage for candidate relationships.
- `test/models/walking_path_test.rb` — walking-path validations and optional grouping associations.
- `test/models/topo_test.rb` — boulder association coverage.
- `test/models/boulder_test.rb` — problem/topo association coverage.
- `test/models/poi_test.rb` — `Poi has_many :areas, through: :poi_routes` coverage.
- `test/controllers/admin/walking_paths_controller_test.rb` — admin CRUD, publish/unpublish, delete, GeoJSON paste/upload, invalid input, and no partial save coverage.
- `test/fixtures/walking_paths.yml` — walking-path fixture records.
- `test/fixtures/walking_path_areas.yml` — optional area grouping fixture records.
- `test/fixtures/walking_path_clusters.yml` — optional cluster grouping fixture records.
- `test/fixtures/poi_routes.yml` — POI-area join fixture records for association tests if current fixtures are insufficient.
- `test/fixtures/lines.yml` — line fixture records for foreign-key/report tests if current fixtures are insufficient.
- `test/fixtures/contributions.yml` — contribution fixture records for foreign-key/report tests if current fixtures are insufficient.
- `test/fixtures/contribution_requests.yml` — contribution request fixture records for foreign-key/report tests if current fixtures are insufficient.
- `test/fixtures/files/valid_walking_path.geojson` — valid uploaded LineString fixture.
- `test/fixtures/files/invalid_walking_path.geojson` — invalid uploaded geometry fixture.

## Phase 0007-P1 — Relationship foundations and verification reports
Goal: add safe database-backed relationship foundations for existing models and a repeatable problem-to-boulder assignment/report path.

- [x] Run `bin/rails generate migration AddBoulderIdToProblems boulder:references` and edit the generated migration so `problems.boulder_id` is nullable, indexed, references `boulders`, and is reversible.
- [x] Run `bin/rails generate migration AddVerifiedRelationshipForeignKeys` and edit the generated migration to add indexes where missing and add foreign keys for clean data only: `areas.cluster_id`, `clusters.region_id`, `lines.problem_id`, `lines.topo_id`, `poi_routes.area_id`, `poi_routes.poi_id`, `contribution_requests.problem_id`, `contributions.problem_id`, `problems.parent_id`, `clusters.main_area_id`, and `regions.main_cluster_id`.
- [x] Read `db/schema.rb` and the generated migrations before editing; keep existing Active Storage and `boulders.area_id`/`problems.area_id` constraints unchanged.
- [x] Read `app/models/problem.rb`, then add `belongs_to :boulder, optional: true` without changing existing `area`, `lines`, `topos`, `parent`, contribution, or validation behaviour.
- [x] Read `app/models/boulder.rb`, then add `has_many :problems` and `has_many :topos` associations.
- [x] Read `app/models/topo.rb`, then add `belongs_to :boulder, optional: true` while preserving photo, line, problem, audit, scope, and metadata behaviour.
- [x] Read `app/models/poi.rb`, then change `has_many :areas` to `has_many :areas, through: :poi_routes` and keep `has_many :poi_routes`.
- [x] Add `app/services/problem_boulder_assignment.rb` with one public report method and one backfill method. The service must classify each problem into `matched`, `missing_location`, `no_containing_boulder`, `multiple_containing_boulders`, or `area_mismatch`; matching must only assign when exactly one boulder in the same area contains the problem location using PostGIS predicates.
- [x] Add `app/services/relationship_foreign_key_report.rb` that checks each candidate relationship for orphan IDs and returns table, column, target table, count, and row IDs for dirty rows.
- [x] Add `lib/tasks/problem_boulder_assignments.rake` with `problem_boulder_assignments:report` and `problem_boulder_assignments:backfill` tasks that print counts and row IDs for every category before any update summary.
- [x] Add `lib/tasks/relationship_foreign_keys.rake` with `relationship_foreign_keys:report` that prints clean/deferred status and dirty row IDs for every candidate relationship.
- [x] Add or update model/service tests in `test/models/problem_boulder_assignment_test.rb`, `test/models/relationship_foreign_key_report_test.rb`, `test/models/topo_test.rb`, `test/models/boulder_test.rb`, and `test/models/poi_test.rb`.
- [x] Run migrations in the test/development database with `bin/rails db:migrate` and inspect `db/schema.rb` for expected columns, indexes, and foreign keys.

**Quality gate:** `bin/rails test test/models/problem_boulder_assignment_test.rb test/models/relationship_foreign_key_report_test.rb test/models/topo_test.rb test/models/boulder_test.rb test/models/poi_test.rb` → all relationship, report, and association tests pass.

## Phase 0007-P2 — Walking-path data model and strict GeoJSON parsing
Goal: create the first-class Rails/PostGIS walking-path source with draft/published validation rules and optional editorial groupings.

- [ ] Run `bin/rails generate model WalkingPath label:string slug:string description:text published:boolean` and edit the generated migration to add `geometry` as SRID 4326 geography accepting LineString/MultiLineString, default `published: false`, timestamps, a slug index, and a spatial index.
- [ ] Run Rails migration generators for `WalkingPathArea walking_path:references area:references` and `WalkingPathCluster walking_path:references cluster:references`, then edit them to create optional many-to-many grouping join tables with unique compound indexes and foreign keys.
- [ ] Read `app/models/area.rb`, `app/models/cluster.rb`, and the new join models before editing; add optional `has_many :walking_path_areas`, `has_many :walking_paths, through: :walking_path_areas`, `has_many :walking_path_clusters`, and `has_many :walking_paths, through: :walking_path_clusters` associations with appropriate dependent cleanup on join records.
- [ ] Implement `app/models/walking_path.rb` with associations, normalized label/slug/description fields, validation that published records require slug and valid line geometry, validation that draft records may omit geometry, and helper methods for GeoJSON display.
- [ ] Implement `app/models/walking_path_area.rb` and `app/models/walking_path_cluster.rb` with required `belongs_to` associations and uniqueness validations scoped to the joined record.
- [ ] Add `app/services/walking_path_geojson_parser.rb` that accepts a JSON string, parses raw Geometry, Feature, or FeatureCollection, extracts exactly one LineString or MultiLineString, rejects Point/Polygon and multi-feature input with more than one line geometry, and returns an SRID 4326 RGeo geometry plus a clear error message.
- [ ] Document in the parser class why only exactly one line geometry is accepted and why invalid input is rejected before model persistence.
- [ ] Add `test/models/walking_path_test.rb` covering published slug/geometry requirements, draft without geometry, LineString, MultiLineString, unsupported geometry, malformed JSON, multi-line FeatureCollection rejection, and optional area/cluster groupings.
- [ ] Add `test/fixtures/walking_paths.yml`, `test/fixtures/walking_path_areas.yml`, and `test/fixtures/walking_path_clusters.yml` with valid draft and published examples.
- [ ] Run `bin/rails db:migrate` and inspect `db/schema.rb` for walking-path table, join tables, indexes, spatial column, and foreign keys.

**Quality gate:** `bin/rails test test/models/walking_path_test.rb` → all walking-path model, parser, and grouping tests pass.

## Phase 0007-P3 — Admin walking-path CRUD and geometry input UX
Goal: let maintainers manage walking paths under `/admin`, including publish/unpublish, delete, pasted GeoJSON, and uploaded `.geojson` files without partial saves.

- [ ] Read `config/routes.rb`, then add `resources :walking_paths` inside the existing localized `admin` namespace with member `patch :publish` and `patch :unpublish` routes.
- [ ] Read `app/controllers/admin/pois_controller.rb` and `app/controllers/admin/poi_routes_controller.rb` before creating `app/controllers/admin/walking_paths_controller.rb`; follow the existing admin style while using non-bang persistence for user-submitted invalid geometry so clear errors render with `status: :unprocessable_entity`.
- [ ] Implement `Admin::WalkingPathsController#index`, `new`, `create`, `edit`, `update`, `destroy`, `publish`, and `unpublish`; wrap attribute updates plus GeoJSON parse/application in a transaction so invalid geometry cannot partially save metadata or groupings.
- [ ] In strong params, permit label, slug, description, published, pasted GeoJSON text, uploaded GeoJSON file, `area_ids: []`, and `cluster_ids: []`; never use uploaded filenames for filesystem paths.
- [ ] Read `app/views/admin/pois/index.html.erb`, `new.html.erb`, `edit.html.erb`, and `_form.html.erb` before adding walking-path views that match the existing admin layout and Tailwind classes.
- [ ] Add `app/views/admin/walking_paths/index.html.erb` with ID, label, slug, published/draft state, area/cluster grouping summary, edit link, publish/unpublish actions, delete action, and a new-record link.
- [ ] Add `app/views/admin/walking_paths/new.html.erb`, `edit.html.erb`, and `_form.html.erb` with fields for label, slug, description, published flag, optional area/cluster multi-selects, pasted GeoJSON textarea, uploaded `.geojson` file input, and clear help text listing accepted GeoJSON shapes.
- [ ] Read `app/views/layouts/admin.html.erb`, then add a `Walking paths` navigation link without removing existing navigation.
- [ ] Add `test/controllers/admin/walking_paths_controller_test.rb` covering index, new, create from pasted LineString, create from uploaded `.geojson`, edit/update, publish, unpublish, destroy, invalid malformed JSON, unsupported Point/Polygon JSON, multi-line FeatureCollection rejection, and no partial save on invalid input.
- [ ] Add `test/fixtures/files/valid_walking_path.geojson` and `test/fixtures/files/invalid_walking_path.geojson` for upload tests.

**Quality gate:** `bin/rails test test/controllers/admin/walking_paths_controller_test.rb test/models/walking_path_test.rb` → all admin walking-path and walking-path validation tests pass.

## Phase 0007-P4 — End-to-end verification and review readiness
Goal: prove the full item meets the spec, document any deferred dirty foreign keys, and leave the branch ready for review.

- [ ] Run `bin/rails db:migrate` once more and confirm no pending migrations remain with `bin/rails db:migrate:status`.
- [ ] Run `bin/rails problem_boulder_assignments:report` and save the terminal evidence in the implementation notes; verify it prints matched, missing-location, no-containing-boulder, multiple-containing-boulders, and area-mismatch counts and row IDs.
- [ ] Run `bin/rails relationship_foreign_keys:report` and save the terminal evidence in the implementation notes; for any deferred foreign key, record the dirty row IDs and the follow-up needed instead of deleting data.
- [ ] Run `bin/rails problem_boulder_assignments:backfill` in the appropriate local/test context and verify matched problems receive `boulder_id` while unmatched and ambiguous rows remain unset.
- [ ] Run the full relevant Rails test set: `bin/rails test test/models/problem_boulder_assignment_test.rb test/models/relationship_foreign_key_report_test.rb test/models/walking_path_test.rb test/models/topo_test.rb test/models/boulder_test.rb test/models/poi_test.rb test/controllers/admin/walking_paths_controller_test.rb`.
- [ ] Run `bin/rubocop` and fix any offenses introduced by this item.
- [ ] Review `db/schema.rb`, `config/routes.rb`, admin views, model associations, services, rake tasks, fixtures, and tests for consistency with every acceptance criterion.
- [ ] Update `.incant/STATE.md` and `.incant/backlog.md` to `status:implement` only during implementation after plan approval; do not mark implementation complete in this planning commit.

**Quality gate:** `bin/rails test test/models/problem_boulder_assignment_test.rb test/models/relationship_foreign_key_report_test.rb test/models/walking_path_test.rb test/models/topo_test.rb test/models/boulder_test.rb test/models/poi_test.rb test/controllers/admin/walking_paths_controller_test.rb && bin/rubocop` → all relevant tests and RuboCop pass with fresh evidence before review.

## Coverage self-review
- [x] Requirement 1 maps to Phase 0007-P1 migration/model/backfill steps.
- [x] Requirement 2 maps to Phase 0007-P1 deterministic assignment categories and Phase 0007-P4 backfill verification.
- [x] Requirement 3 maps to Phase 0007-P1 report task/service and Phase 0007-P4 report evidence.
- [x] Requirement 4 maps to Phase 0007-P1 topo/boulder association and foreign-key/index work.
- [x] Requirement 5 maps to Phase 0007-P1 POI association update and test.
- [x] Requirement 6 maps to Phase 0007-P1 verified foreign-key migration and report helper.
- [x] Requirement 7 maps to Phase 0007-P1 dirty-row reporting and Phase 0007-P4 follow-up recording.
- [x] Requirement 8 maps to Phase 0007-P2 walking-path table/model and line geometry support.
- [x] Requirement 9 maps to Phase 0007-P2 optional area/cluster join tables and associations.
- [x] Requirement 10 maps to Phase 0007-P3 admin resource, views, and controller actions.
- [x] Requirement 11 maps to Phase 0007-P2 parser and Phase 0007-P3 pasted/uploaded GeoJSON handling.
- [x] Requirement 12 maps to Phase 0007-P2 parser validations and Phase 0007-P3 transaction/no-partial-save controller tests.
- [x] Requirement 13 maps to Phase 0007-P2 published/draft validations.
- [x] Requirement 14 maps to Phase 0007-P1 and Phase 0007-P2 Rails generator steps plus migration edit/review steps.
- [x] Requirement 15 maps to Phase 0007-P1/P2/P3 tests and Phase 0007-P4 Rails/RuboCop gates.
- [x] Symbol/signature consistency checked: `ProblemBoulderAssignment`, `RelationshipForeignKeyReport`, `WalkingPathGeojsonParser`, `WalkingPath`, `WalkingPathArea`, `WalkingPathCluster`, and rake task names are used consistently above.
- [x] Goal-level verification is covered by Phase 0007-P4's report, targeted tests, and RuboCop gate.
- [x] No placeholders remain in this plan.

## Human approval checkpoint
This plan is committed as `incant 0007: plan` and implementation must not begin until the human approves it.

Next after approval: `/incant:implement 0007`.
