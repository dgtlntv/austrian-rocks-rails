---
id: "0007"
slug: db-relationships-walking-paths
stage: review
reviewed: 2026-06-07
commit: a3f47e383e8387ee8719a1036fed10e2b0fa3896
---

# Db Relationships Walking Paths — review

### Strengths
- app/services/problem_boulder_assignment.rb:46 — The assignment classifier explicitly separates matched, missing-location, no-containing-boulder, multiple-containing-boulders, and area-mismatch outcomes, matching the phase promise instead of silently guessing legacy data.
- app/services/problem_boulder_assignment.rb:66 — The spatial matching rule is documented at the trust boundary and remains conservative: exactly one same-area boulder must cover or be within the named near-boundary tolerance before a backfill update is made.
- app/services/relationship_foreign_key_report.rb:2 — The candidate relationship list covers the spec-required foreign keys plus `topos.boulder_id`, and the report returns clean/deferred status with dirty row IDs for follow-up.
- db/migrate/20260607091030_add_verified_relationship_foreign_keys.rb:15 — Relationship constraints are added with matching indexes/column type corrections and a reversible `down`, preserving existing Active Storage and existing area constraints.
- lib/tasks/problem_boulder_assignments.rake:18 — The report/backfill tasks print counts and row identifiers for every assignment category before reporting updates, which gives maintainers repeatable operational evidence.
- test/models/problem_boulder_assignment_test.rb:9 and test/models/relationship_foreign_key_report_test.rb:4 — The phase has targeted model/service coverage for the key backfill categories and dirty-row relationship reporting.
- Fresh gate evidence: `PATH="$(rbenv root)/shims:$PATH" RAILS_ENV=test DATABASE_URL=postgis://austrian-rocks:password@127.0.0.1:5432/austrian-rocks-test BUNNY_STORAGE_ENDPOINT=http://example.test BUNNY_STORAGE_ACCESS_KEY_ID=test BUNNY_STORAGE_SECRET_ACCESS_KEY=test BUNNY_STORAGE_REGION=us-east-1 BUNNY_STORAGE_BUCKET=test bin/rails test test/models/problem_boulder_assignment_test.rb test/models/relationship_foreign_key_report_test.rb test/models/topo_test.rb test/models/boulder_test.rb test/models/poi_test.rb` → 7 runs, 19 assertions, 0 failures, 0 errors, 0 skips.
- Fresh data-check evidence: `PATH="$(rbenv root)/shims:$PATH" DATABASE_URL=postgis://austrian-rocks:password@127.0.0.1:5432/dump-prod BUNNY_STORAGE_ENDPOINT=http://example.test BUNNY_STORAGE_ACCESS_KEY_ID=test BUNNY_STORAGE_SECRET_ACCESS_KEY=test BUNNY_STORAGE_REGION=us-east-1 BUNNY_STORAGE_BUCKET=test bin/rails relationship_foreign_keys:report` → every candidate relationship clean, no dirty row IDs.

### Blocker
None.

### Major
None.

### Minor
None.

### Nit
None.

### Verdict
Ready to release? **Yes** — for the 0007-P1 phase gate. The relationship foundations, reports, migrations, associations, and targeted tests align with the approved spec/plan; the full work item still needs P2–P4 before final release.
