---
id: "0009"
slug: pmtiles-publish-workflow
stage: review
reviewed: 2026-06-08
commit: 57a701668b8ff92e2dc24630df14f6d5d3278100
---

# PMTiles publish workflow — review

### Strengths
- `app/jobs/map_tile_publish_job.rb:23` — attempt claiming is serialized under the singleton publish-state row lock before the pipeline runs, which is the right concurrency boundary for preventing overlapping PMTiles builds.
- `app/jobs/map_tile_publish_job.rb:27` and `app/jobs/map_tile_publish_job.rb:55` — early automatic jobs self-reschedule and automatic attempts remain pending when another publish is running, preserving the sliding debounce design from P2.
- `app/services/map_tiles/publish_pipeline.rb:43` — the pipeline composes the existing exporter, Tippecanoe builder, production smoke check, Bunny publisher, and local cleaner in the promised order, with injectable collaborators for deterministic tests.
- `app/services/map_tiles/publish_pipeline.rb:56` and `test/services/map_tiles/publish_pipeline_test.rb:22` — publish versions are generated from UTC timestamps in the safe segment format, and the test explicitly proves `2026-06-08T16-45-30Z` from a non-UTC clock value.
- `test/models/map_tiles/publish_stale_marker_test.rb:326` — the previous P2 major is now covered by a production-stubbed callback path through the real default scheduler/job class, proving all eight source models maintain a single pending automatic attempt.
- `app/services/map_tiles/publish_pipeline.rb:83` and `app/services/map_tiles/publish_pipeline.rb:125` — the P3 review fix now clears stale state and supersedes an older pending automatic attempt when a successful manual publish covers all known source edits, preventing redundant follow-up builds and restoring an accurate `up_to_date` status.
- `test/services/map_tiles/publish_pipeline_test.rb:58` — regression coverage proves the manual-success supersede path cancels the pending automatic row, clears `pending_automatic_attempt_id`, reports `up_to_date`, and enqueues no follow-up.
- Fresh phase gates passed in this review session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/jobs/map_tile_publish_job_test.rb test/services/map_tiles/publish_pipeline_test.rb` → 11 runs, 66 assertions, 0 failures, 0 errors; `docker compose run --rm web bin/rubocop app/services/map_tiles/publish_pipeline.rb test/services/map_tiles/publish_pipeline_test.rb` → 2 files inspected, no offenses detected.

### Blocker
- `app/services/map_tiles/publish_scheduler.rb:80` — previous finding: the default scheduler could not enqueue because no `MapTilePublishJob` class existed. P3 adds `app/jobs/map_tile_publish_job.rb`, the default scheduler resolves it, and `test/models/map_tiles/publish_stale_marker_test.rb:326` exercises production-stubbed source saves through the real scheduler/default job path. status: addressed
- `app/models/map_tile_publish_attempt.rb:25` — previous finding: `record_failure!` did not redact bare Bunny secret values from error messages. The implementation builds a dynamic redaction set from `ENV` and tests a bare secret value. status: addressed

### Major
- `app/services/map_tiles/publish_pipeline.rb:83`, `app/services/map_tiles/publish_pipeline.rb:125`, and `test/services/map_tiles/publish_pipeline_test.rb:58` — previous finding: a successful manual publish did not clear or cancel an older pending automatic attempt when that manual run covered the stale data. The fix now clears `stale_at`, cancels the superseded pending automatic attempt with a durable reason, clears `pending_automatic_attempt_id`, and regression coverage verifies `current_status` returns `up_to_date` with no follow-up job enqueued. status: addressed
- `test/models/map_tiles/publish_stale_marker_test.rb:326` — previous finding: callback tests did not prove real pending-attempt maintenance through the default scheduler/job path. The new integration test asserts state rows, one pending automatic attempt, and eight `MapTilePublishJob` enqueues across all source models. status: addressed
- `app/models/map_tile_publish_state.rb:29` — previous finding: `current_status` hid a failed publish after a previous success. It now compares the latest failed attempt’s `finished_at` with the latest successful attempt and has regression coverage. status: addressed
- `db/migrate/20260608120001_enforce_singleton_map_tile_publish_state.rb:12` — previous finding: no DB-level singleton constraint. The follow-up migration adds the `singleton` column and a partial unique index, and `MapTilePublishState.current!` now uses that key. status: addressed

### Minor
- `.incant/work/0009-pmtiles-publish-workflow/plan.md:116` — previous finding: the P1 checklist contradicted the restored legacy `latest_object_key` behavior. The checklist now explicitly says `latest_object_key` remains for legacy CLI compatibility until P4 removes Bunny publisher usage. status: addressed

### Nit
- None.

### Verdict
Ready to release? **No** — no open blocker or major findings remain in the reviewed P3 work, but the overall item is not ready to close because planned phases P4–P6 are still incomplete. Continue implementation with P4 before final release review.
