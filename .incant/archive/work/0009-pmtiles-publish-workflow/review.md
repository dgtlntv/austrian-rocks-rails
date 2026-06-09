---
id: "0009"
slug: pmtiles-publish-workflow
stage: review
reviewed: 2026-06-08
commit: 4b0e0951933b05a262e76dd5a46632e51feaa325
---

# PMTiles publish workflow — review

### Strengths
- `app/services/map_tiles/publish_scheduler.rb:20` and `app/jobs/map_tile_publish_job.rb:40` — manual publishes create a durable pending attempt and the job claims it under the singleton state lock before any expensive build/publish work, so admin requests do not run the pipeline inline.
- `app/services/map_tiles/publish_scheduler.rb:35` and `app/services/map_tiles/publish_scheduler.rb:46` — the automatic scheduler documents and implements the sliding-debounce invariant as one pending automatic attempt whose `scheduled_for` moves forward on repeated source edits.
- `test/models/map_tiles/publish_stale_marker_test.rb:326` and `test/models/map_tiles/publish_stale_marker_test.rb:357` — production-stubbed integration coverage exercises all eight PMTiles source models through the real scheduler/default `MapTilePublishJob` path and proves they maintain one pending automatic attempt.
- `app/services/map_tiles/publish_pipeline.rb:45`, `app/services/map_tiles/publish_pipeline.rb:60`, and `app/services/map_tiles/publish_pipeline.rb:93` — the publish pipeline runs the production smoke check before upload and records success/failure state, URLs, object keys, timestamps, and sanitized errors through the persistent history models.
- `lib/map_tiles/bunny_publisher.rb:42`, `lib/map_tiles/bunny_publisher.rb:49`, and `lib/map_tiles/bunny_publisher.rb:90` — Bunny publication uploads/verifies the immutable versioned PMTiles object plus `latest.json`, applies distinct cache metadata, and avoids the removed `latest.pmtiles` upload path.
- `app/controllers/admin/exports_controller.rb:18`, `app/views/admin/exports/index.html.erb:29`, and `app/views/admin/exports/index.html.erb:82` — the authenticated admin exports page now exposes queued PMTiles publishing, confirmation protection, current status, last-success/pending details, and recent history while preserving SQLite export.
- `test/controllers/admin/exports_controller_test.rb:92`, `test/controllers/admin/exports_controller_test.rb:111`, and `test/controllers/admin/exports_controller_test.rb:122` — controller tests cover manual enqueue without pipeline execution, absence of legacy GeoJSON controls, removed GeoJSON route helpers/requests, and retained DB export behavior.
- `app/models/map_tile_publish_attempt.rb:25` and `app/helpers/admin/exports_helper.rb:52` — failure text is redacted at persistence and presentation boundaries, including dynamic Bunny secret values.
- `.incant/work/0009-pmtiles-publish-workflow/plan.md:16`, `.incant/work/0009-pmtiles-publish-workflow/plan.md:21`, and `.incant/work/0009-pmtiles-publish-workflow/plan.md:200` — the previously open release-readiness artifact issue is fixed: P6 is checked off, backlog/STATE are aligned for review, and the final gate evidence is recorded.
- Fresh review gates passed in this session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/lib/map_tiles test/jobs test/models test/controllers` → 154 runs, 1302 assertions, 0 failures, 0 errors; `docker compose run --rm web bin/rubocop` → 281 files inspected, no offenses. `git diff --check 7b6ff0f8..HEAD` was clean, and the pre-review working tree contained only the linked `sessions.json` update.

### Blocker
- `app/services/map_tiles/publish_scheduler.rb:86` — previous finding: the default scheduler could not enqueue because no `MapTilePublishJob` class existed. P3 added `app/jobs/map_tile_publish_job.rb`, the default scheduler resolves it, and production-stubbed source-save coverage exercises the real scheduler/default job path. status: addressed
- `app/models/map_tile_publish_attempt.rb:25` — previous finding: `record_failure!` did not redact bare Bunny secret values from error messages. The implementation now redacts dynamic Bunny secret values from `ENV` before persistence. status: addressed

### Major
- `.incant/work/0009-pmtiles-publish-workflow/plan.md:16`, `.incant/work/0009-pmtiles-publish-workflow/plan.md:21`, `.incant/backlog.md:5`, and `.incant/STATE.md:2` — previous finding: Phase 0009-P6 remained open in durable status artifacts. P6 is now complete, the full acceptance/RuboCop evidence is recorded, backlog/STATE point to final review, and commit `4b0e0951` contains `incant 0009-P6: verify PMTiles publish workflow`. status: addressed
- `app/services/map_tiles/publish_pipeline.rb:83`, `app/services/map_tiles/publish_pipeline.rb:125`, and `test/services/map_tiles/publish_pipeline_test.rb:58` — previous finding: a successful manual publish did not clear or cancel an older pending automatic attempt when that manual run covered the stale data. The fix now clears stale state, cancels the superseded pending automatic attempt, and has regression coverage. status: addressed
- `test/models/map_tiles/publish_stale_marker_test.rb:357` — previous finding: callback tests did not prove real pending-attempt maintenance through the default scheduler/job path. The current test asserts one pending automatic attempt and eight `MapTilePublishJob` enqueues across all source models. status: addressed
- `app/models/map_tile_publish_state.rb:29` — previous finding: `current_status` hid a failed publish after a previous success. It now compares the latest failed attempt against the latest successful attempt. status: addressed
- `db/migrate/20260608120001_enforce_singleton_map_tile_publish_state.rb:12` — previous finding: no DB-level singleton constraint. The follow-up migration adds the boolean singleton column and partial unique index. status: addressed

### Minor
- `.incant/work/0009-pmtiles-publish-workflow/plan.md:118` — previous finding: the P1 checklist contradicted restored legacy `latest_object_key` behavior. The plan now explains that the method remains for legacy CLI compatibility while Bunny publisher usage moved to the manifest key. status: addressed

### Nit
- None.

### Verdict
Ready to release? **Yes** — no open blocker or major findings remain. The implementation matches the spec and plan, the active config/security/testability/code-documentation principles are covered, and the final Docker acceptance and RuboCop gates passed cleanly in this review session.
