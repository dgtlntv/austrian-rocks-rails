---
id: "0009"
slug: pmtiles-publish-workflow
stage: review
reviewed: 2026-06-08
commit: 0f62d0e9dcd74b35f6dcb7db805bc4b9f65c7814
---

# PMTiles publish workflow — review

### Strengths
- `app/controllers/admin/exports_controller.rb:3` and `app/controllers/admin/exports_controller.rb:30` — P5 cleanly loads the singleton publish state, last success, pending automatic attempt, and bounded recent history for the authenticated admin exports page.
- `app/controllers/admin/exports_controller.rb:18` and `app/services/map_tiles/publish_scheduler.rb:20` — manual admin publishes create a pending manual attempt and enqueue the background job, keeping the build/smoke/publish pipeline out of the web request.
- `app/views/admin/exports/index.html.erb:17` and `app/views/admin/exports/index.html.erb:29` — the SQLite DB export remains available while PMTiles publishing gets a confirmation-protected `Publish now` action.
- `app/views/admin/exports/index.html.erb:37`, `app/views/admin/exports/index.html.erb:83`, and `app/views/admin/exports/index.html.erb:116` — the admin UI renders current status, last-success/pending/history data, artifact links, durations, and sanitized errors as promised.
- `test/controllers/admin/exports_controller_test.rb:82`, `test/controllers/admin/exports_controller_test.rb:98`, and `test/controllers/admin/exports_controller_test.rb:132` — P5 controller coverage verifies SQLite preservation, manual enqueue behavior without pipeline execution, and removal of legacy GeoJSON routes.
- `app/models/concerns/map_tiles/publish_stale_marker.rb:17` and `app/models/concerns/map_tiles/publish_stale_marker.rb:23` — source-model callbacks are production-only and scoped to commit events, matching the safety requirement that development/test saves do not schedule automatic publishes.
- `app/services/map_tiles/publish_scheduler.rb:35`, `app/jobs/map_tile_publish_job.rb:23`, and `app/services/map_tiles/publish_pipeline.rb:75` — the automatic workflow documents and enforces sliding debounce plus singleton-row locking before running expensive work.
- `app/services/map_tiles/publish_pipeline.rb:45` and `lib/map_tiles/bunny_publisher.rb:42` — admin/job publishes always run the production smoke check before publishing the immutable PMTiles artifact and latest manifest.
- `lib/map_tiles/bunny_publisher.rb:46`, `lib/map_tiles/bunny_publisher.rb:111`, and `test/lib/map_tiles/bunny_publisher_test.rb:106` — publication now uses `austrian-rocks-latest.json` with manifest content and test coverage proving `austrian-rocks-latest.pmtiles` is not uploaded.
- Fresh review gates passed in this session: P5 gate `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/controllers/admin/exports_controller_test.rb` → 7 runs, 62 assertions, 0 failures, 0 errors; targeted P5 RuboCop `docker compose run --rm web bin/rubocop app/controllers/admin/exports_controller.rb app/helpers/admin/exports_helper.rb test/controllers/admin/exports_controller_test.rb` → 3 files inspected, no offenses.
- Fresh full acceptance evidence also passed in this review session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/lib/map_tiles test/jobs test/models test/controllers` → 154 runs, 1302 assertions, 0 failures, 0 errors; `docker compose run --rm web bin/rubocop` → 281 files inspected, no offenses.

### Blocker
- `app/services/map_tiles/publish_scheduler.rb:86` — previous finding: the default scheduler could not enqueue because no `MapTilePublishJob` class existed. P3 adds `app/jobs/map_tile_publish_job.rb`, the default scheduler resolves it, and production-stubbed source-save coverage exercises the real scheduler/default job path. status: addressed
- `app/models/map_tile_publish_attempt.rb:25` — previous finding: `record_failure!` did not redact bare Bunny secret values from error messages. The implementation now redacts dynamic Bunny secret values from `ENV` before persistence. status: addressed

### Major
- `.incant/work/0009-pmtiles-publish-workflow/plan.md:185`, `.incant/work/0009-pmtiles-publish-workflow/plan.md:190`, `.incant/backlog.md:5`, and `.incant/STATE.md:2` — Phase 0009-P6 is still open in the durable plan/status artifacts even though it is the release-readiness phase: the plan checklist has not recorded the full acceptance/RuboCop evidence, the backlog still says `phase:0009-P5`, and STATE still says P5 is ready for review. This leaves the item not ready to finalize because the planned final status/evidence/commit step is incomplete. Fix: rerun the acceptance tests and RuboCop in the implement session, inspect the tracked diff, update the plan Status/P6 checklist plus backlog/STATE to `phase:0009-P6`, and commit `incant 0009-P6: verify PMTiles publish workflow`. status: open
- `app/services/map_tiles/publish_pipeline.rb:83`, `app/services/map_tiles/publish_pipeline.rb:125`, and `test/services/map_tiles/publish_pipeline_test.rb:58` — previous finding: a successful manual publish did not clear or cancel an older pending automatic attempt when that manual run covered the stale data. The fix now clears stale state, cancels the superseded pending automatic attempt, and has regression coverage. status: addressed
- `test/models/map_tiles/publish_stale_marker_test.rb:357` — previous finding: callback tests did not prove real pending-attempt maintenance through the default scheduler/job path. The current test asserts one pending automatic attempt and eight `MapTilePublishJob` enqueues across all source models. status: addressed
- `app/models/map_tile_publish_state.rb:29` — previous finding: `current_status` hid a failed publish after a previous success. It now compares the latest failed attempt against the latest successful attempt. status: addressed
- `db/migrate/20260608120001_enforce_singleton_map_tile_publish_state.rb:12` — previous finding: no DB-level singleton constraint. The follow-up migration adds the boolean singleton column and partial unique index. status: addressed

### Minor
- `.incant/work/0009-pmtiles-publish-workflow/plan.md:118` — previous finding: the P1 checklist contradicted restored legacy `latest_object_key` behavior. The plan now explains that the method remains for legacy CLI compatibility while Bunny publisher usage moved to the manifest key. status: addressed

### Nit
- None.

### Verdict
Ready to release? **No** — one open major remains in the release-readiness artifacts. The implementation and fresh code gates look healthy, but 0009-P6 must be completed and committed before finalizing the item.
