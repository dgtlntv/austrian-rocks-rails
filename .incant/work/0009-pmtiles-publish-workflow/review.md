---
id: "0009"
slug: pmtiles-publish-workflow
stage: review
reviewed: 2026-06-08
commit: ea1f368364e5e6dd2d4fb146dbd9aa64bca1682b
---

# PMTiles publish workflow — review

### Strengths
- `app/jobs/map_tile_publish_job.rb:23` — attempt claiming is serialized under the singleton publish-state row lock before the pipeline runs, which is the right concurrency boundary for preventing overlapping PMTiles builds.
- `app/jobs/map_tile_publish_job.rb:27` and `app/jobs/map_tile_publish_job.rb:55` — early automatic jobs self-reschedule and automatic attempts remain pending when another publish is running, preserving the sliding debounce design from P2.
- `app/services/map_tiles/publish_pipeline.rb:43` — the pipeline composes the existing exporter, Tippecanoe builder, production smoke check, Bunny publisher, and local cleaner in the promised order, with injectable collaborators for deterministic tests.
- `app/services/map_tiles/publish_pipeline.rb:56` and `test/services/map_tiles/publish_pipeline_test.rb:22` — publish versions are generated from UTC timestamps in the safe segment format, and the test explicitly proves `2026-06-08T16-45-30Z` from a non-UTC clock value.
- `test/models/map_tiles/publish_stale_marker_test.rb:326` — the previous P2 major is now covered by a production-stubbed callback path through the real default scheduler/job class, proving all eight source models maintain a single pending automatic attempt.
- Fresh phase gates passed in this review session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/jobs/map_tile_publish_job_test.rb test/services/map_tiles/publish_pipeline_test.rb` → 10 runs, 58 assertions, 0 failures, 0 errors; `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/services/map_tiles/publish_scheduler_test.rb test/models/map_tiles/publish_stale_marker_test.rb` → 35 runs, 108 assertions, 0 failures, 0 errors.

### Blocker
- `app/services/map_tiles/publish_scheduler.rb:80` — previous finding: the default scheduler could not enqueue because no `MapTilePublishJob` class existed. P3 adds `app/jobs/map_tile_publish_job.rb`, the default scheduler resolves it, and `test/models/map_tiles/publish_stale_marker_test.rb:326` exercises production-stubbed source saves through the real scheduler/default job path. status: addressed
- `app/models/map_tile_publish_attempt.rb:25` — previous finding: `record_failure!` did not redact bare Bunny secret values from error messages. The implementation builds a dynamic redaction set from `ENV` and tests a bare secret value. status: addressed

### Major
- `app/services/map_tiles/publish_pipeline.rb:80` and `app/jobs/map_tile_publish_job.rb:39` — a successful manual publish does not clear or cancel an already-pending automatic attempt when that manual run covers the stale data. `MapTilePublishJob` only clears `pending_automatic_attempt_id` when claiming that same automatic attempt, and `PublishPipeline#record_success!` clears `stale_at` for covered changes without clearing the stale automatic attempt. Reproduced with a pending automatic attempt whose `stale_at` predates a manual run: after success, `stale_at` is `nil` but `current_status` remains `pending`, so the delayed automatic job will later rebuild unnecessarily. This undermines the debounce/status model and will make the admin page show pending instead of up to date after an admin publish succeeds. Fix: when a successful publish covers all stale changes (`stale_at` blank or `<= started_at`), clear `pending_automatic_attempt_id` and cancel/delete any pending automatic attempt that was superseded, with regression coverage for “manual success supersedes pending automatic”. status: open
- `test/models/map_tiles/publish_stale_marker_test.rb:326` — previous finding: callback tests did not prove real pending-attempt maintenance through the default scheduler/job path. The new integration test asserts state rows, one pending automatic attempt, and eight `MapTilePublishJob` enqueues across all source models. status: addressed
- `app/models/map_tile_publish_state.rb:29` — previous finding: `current_status` hid a failed publish after a previous success. It now compares the latest failed attempt’s `finished_at` with the latest successful attempt and has regression coverage. status: addressed
- `db/migrate/20260608120001_enforce_singleton_map_tile_publish_state.rb:12` — previous finding: no DB-level singleton constraint. The follow-up migration adds the `singleton` column and a partial unique index, and `MapTilePublishState.current!` now uses that key. status: addressed

### Minor
- `.incant/work/0009-pmtiles-publish-workflow/plan.md:116` — previous finding: the P1 checklist contradicted the restored legacy `latest_object_key` behavior. The checklist now explicitly says `latest_object_key` remains for legacy CLI compatibility until P4 removes Bunny publisher usage. status: addressed

### Nit
- None.

### Verdict
Ready to release? **No** — one open major remains. P3 largely delivers the job/pipeline foundation and resolves the prior blocker/major findings, but manual publishes must supersede stale pending automatic attempts before the workflow can report accurate status or avoid redundant builds.
