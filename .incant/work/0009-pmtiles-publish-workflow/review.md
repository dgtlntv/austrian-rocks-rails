---
id: "0009"
slug: pmtiles-publish-workflow
stage: review
reviewed: 2026-06-08
commit: 593dd21f9e12aad21ebe387927b5a0e8b3b40c3b
---

# PMTiles publish workflow — review

### Strengths
- `lib/map_tiles/bunny_publisher.rb:41` — P4 now uploads the immutable versioned PMTiles object first and verifies its public URL before touching the latest manifest, preserving the safety property that the manifest only points at a reachable versioned archive.
- `lib/map_tiles/bunny_publisher.rb:46` — the publisher uses `latest_manifest_object_key` for `austrian-rocks-latest.json`; there is no remaining publisher path that uploads `austrian-rocks-latest.pmtiles`.
- `lib/map_tiles/bunny_publisher.rb:48` — the code documents the range-request/cache rationale right at the overwritten-object boundary, reducing the chance that a future change reintroduces overwritten PMTiles archives.
- `lib/map_tiles/bunny_publisher.rb:79` and `lib/map_tiles/bunny_publisher.rb:90` — cache metadata is split correctly: immutable PMTiles cache control comes from configuration, while the manifest uses the configured short TTL (`public, max-age=60` by default).
- `lib/map_tiles/bunny_publisher.rb:111` — the latest manifest includes the promised stable fields: version, PMTiles URL, published timestamp, artifact basename, object key, and object basename.
- `lib/map_tiles/cli.rb:98` and `test/lib/map_tiles/cli_test.rb:86` — command-line publication still runs the production smoke check by default and ignores the legacy `MAP_TILES_SKIP_SMOKE` env bypass, while preserving explicit operator `--skip-smoke` behavior.
- `lib/map_tiles/cli.rb:103` and `test/lib/map_tiles/cli_test.rb:73` — CLI publication consumes the new publisher return shape and prints the latest manifest URL for operators.
- `test/lib/map_tiles/bunny_publisher_test.rb:65` — P4 tests cover PMTiles and manifest keys, content types, cache control, manifest JSON, verification URLs, and output, including an assertion that `austrian-rocks-latest.pmtiles` is absent.
- `test/lib/map_tiles/bunny_publisher_test.rb:98` and `test/lib/map_tiles/bunny_publisher_test.rb:123` — regression coverage proves repeated publishes overwrite only the JSON manifest and that manifest HEAD verification failures are surfaced.
- Fresh phase gates passed in this review session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/lib/map_tiles/bunny_publisher_test.rb test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/cli_test.rb` → 32 runs, 147 assertions, 0 failures, 0 errors; `docker compose run --rm web bin/rubocop lib/map_tiles/bunny_publisher.rb lib/map_tiles/cli.rb lib/tasks/map_tiles.rake test/lib/map_tiles/bunny_publisher_test.rb test/lib/map_tiles/cli_test.rb` → 5 files inspected, no offenses detected.

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
Ready to release? **No** — no open blocker or major findings remain in the reviewed P4 work, but the overall item is not ready to close because planned phases P5–P6 are still incomplete. Continue implementation with P5 before final release review.
