---
id: "0009"
slug: pmtiles-publish-workflow
stage: review
reviewed: 2026-06-08
commit: b0eac40b29b85dc22e8694d3591416f33616fd73
---

# PMTiles publish workflow — review

### Strengths
- `app/services/map_tiles/publish_scheduler.rb:50` — the scheduler still updates stale timestamps and the pending automatic attempt under the singleton state row lock, which is the right core for the sliding debounce invariant.
- `app/models/concerns/map_tiles/publish_stale_marker.rb:22` — source-model callbacks remain production-gated and persist only class/id trigger reasons, avoiding user-entered data and keeping non-production saves quiet.
- `test/models/map_tiles/publish_stale_marker_test.rb:166` — the review-fix commit materially expanded callback coverage to create/update/destroy paths for all eight PMTiles source models instead of only manually invoking one callback.
- Fresh phase gate passed in this review session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/services/map_tiles/publish_scheduler_test.rb test/models/map_tiles/publish_stale_marker_test.rb` → 35 runs, 109 assertions, 0 failures, 0 errors.
- `app/models/map_tile_publish_attempt.rb:25`, `app/models/map_tile_publish_state.rb:29`, and `db/migrate/20260608120001_enforce_singleton_map_tile_publish_state.rb:12` — the earlier P1 blocker/majors remain addressed: Bunny secret values are redacted, failed status can outrank an older success, and the singleton state has a DB-backed unique constraint.

### Blocker
- `app/services/map_tiles/publish_scheduler.rb:28`, `app/services/map_tiles/publish_scheduler.rb:75`, and `app/services/map_tiles/publish_scheduler.rb:86` — previous finding remains open: the default scheduler still resolves and enqueues `MapTilePublishJob`, but `app/jobs/` contains no `MapTilePublishJob` class on this reviewed HEAD. Production callbacks call `MapTiles::PublishScheduler.new` without an injected job (`app/models/concerns/map_tiles/publish_stale_marker.rb:25`), so a real production source edit can raise on `nil.perform_later`/`nil.set` instead of scheduling the required automatic publish. The plan acknowledges this is not resolved until P3 (`.incant/work/0009-pmtiles-publish-workflow/plan.md:47`); keep this open until a usable job class exists and the default path is covered. status: open
- `app/models/map_tile_publish_attempt.rb:25` — previous finding: `record_failure!` did not redact bare Bunny secret values from error messages. The implementation now builds a dynamic redaction set from `ENV` and tests a bare secret value (`test/models/map_tile_publish_attempt_test.rb:101`). status: addressed

### Major
- `test/models/map_tiles/publish_stale_marker_test.rb:140`, `test/models/map_tiles/publish_stale_marker_test.rb:316`, and `test/models/map_tiles/publish_stale_marker_test.rb:325` — previous finding is only partially addressed: the new tests cover all eight models' callback triggers, but they deliberately mock the scheduler and the test named “production-mode saves maintain exactly one pending automatic attempt” does not assert any `MapTilePublishAttempt`/`MapTilePublishState` rows. This still misses the spec acceptance criterion that production-mode saves/destroys for all eight source models mark PMTiles stale and maintain one pending automatic publish attempt, and it continues to mask the missing default job path above. Add a production-stubbed integration test with an enqueueable fake/default job class that lets the real scheduler create/update the singleton pending automatic attempt. status: open
- `app/models/map_tile_publish_state.rb:29` — previous finding: `current_status` hid a failed publish after a previous success. It now compares the latest failed attempt’s `finished_at` with the latest successful attempt and has regression coverage (`test/models/map_tile_publish_state_test.rb:77`). status: addressed
- `db/migrate/20260608120001_enforce_singleton_map_tile_publish_state.rb:12` — previous finding: no DB-level singleton constraint. The follow-up migration adds the `singleton` column and a partial unique index, and `MapTilePublishState.current!` now uses that key. status: addressed

### Minor
- `.incant/work/0009-pmtiles-publish-workflow/plan.md:116` — previous finding remains open: the P1 checklist still says to keep `latest_object_key` from returning/naming `austrian-rocks-latest.pmtiles`, while the review-fix row now correctly says it was restored for legacy CLI compatibility (`plan.md:39`). Reword the checklist item so the artifact consistently documents the intentional P4 deferral. status: open
- `.incant/work/0009-pmtiles-publish-workflow/plan.md:20` and `.incant/work/0009-pmtiles-publish-workflow/plan.md:21` — the Status block says “Blockers: none” and still lists the old 26-test evidence even though the current re-review still has an open blocker and fresh evidence is 35 runs / 109 assertions. Update the Status block during the revise loop so the next reader is not misled. status: open

### Nit
- None.

### Verdict
Ready to release? **No** — one open blocker and one open major remain. The all-model callback coverage improved, but the production/default scheduler path still cannot enqueue until P3 adds `MapTilePublishJob`, and the tests still need to prove real pending-attempt maintenance through callbacks.
