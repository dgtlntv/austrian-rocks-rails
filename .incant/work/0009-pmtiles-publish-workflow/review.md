---
id: "0009"
slug: pmtiles-publish-workflow
stage: review
reviewed: 2026-06-08
commit: b4319f7fd83145274d5642b62afdbabe96db986d
---

# PMTiles publish workflow — review

### Strengths
- `db/migrate/20260608120000_create_map_tile_publish_workflow.rb:20` — the publish-attempt history table captures the planned lifecycle fields (`source`, `status`, scheduling/run timestamps, version, object keys/URLs, and error text), giving later job/admin phases a solid persistence base.
- `lib/map_tiles/configuration.rb:78` — the new workflow settings are exposed through configuration rather than hard-coded, matching the config-vs-code principle and making debounce/cache behavior testable.
- `test/models/map_tile_publish_attempt_test.rb:72` and `test/models/map_tile_publish_state_test.rb:23` — the phase added focused model coverage for status validation, durations, failures, and derived state labels, and the fresh Docker quality gate passed: 39 tests, 106 assertions, 0 failures, 0 errors.

### Blocker
- `app/models/map_tile_publish_attempt.rb:43` — `record_failure!` only redacts strings shaped like `BUNNY_STORAGE_SECRET_ACCESS_KEY=value`; it does not redact the actual secret values from `ENV`/`configuration.env` if they appear bare or in provider-formatted messages. The spec explicitly says Bunny credentials must never be stored in history/admin output, so a failed publish can persist secrets. Fix by building a redaction set from the configured Bunny secret env values (skip blanks), replacing those values anywhere in the message, retaining key-name redaction, and adding tests where `ENV["BUNNY_STORAGE_SECRET_ACCESS_KEY"]`'s value appears without the key name. status: open

### Major
- `app/models/map_tile_publish_state.rb:32` — `current_status` hides a failed publish when there was any previous success and no newer `stale_at`: a manual publish can fail after a successful publish but the admin status will still derive `up_to_date`. That violates the requirement that failed publish modes remain visible in status/history. Fix by comparing `last_failed_attempt.finished_at` (or created/updated time fallback) against `last_successful_attempt.finished_at` and returning `failed` when the latest relevant attempt failed and nothing is running/pending. status: open
- `app/models/map_tile_publish_state.rb:22` and `db/migrate/20260608120000_create_map_tile_publish_workflow.rb:5` — the singleton state is only `first_or_create!`; there is no database constraint or stable singleton key preventing duplicate rows under concurrent first access or accidental inserts. Later phases rely on locking this row to prevent concurrent PMTiles builds, so duplicate state rows would split locks and undermine that safety property. Add a singleton key/boolean with a unique index (or equivalent DB-enforced invariant) and make `current!` use it, with a test for duplicate prevention. status: open

### Minor
- `lib/map_tiles/configuration.rb:74` and `test/lib/map_tiles/configuration_test.rb:60` — Phase 0009-P1 is checked off as keeping `latest_object_key` from returning/naming `austrian-rocks-latest.pmtiles`, but the method and test still expose that key. If this is intentionally deferred to 0009-P4, reword/uncheck the P1 checkbox so the plan is accurate; otherwise remove/rename the API now and update the configuration test. status: open

### Nit
- None.

### Verdict
Ready to release? **No** — one open blocker and two open majors. The persistence/configuration foundation is close, but secret redaction, failed-status derivation, and singleton enforcement need fixes before continuing to build later workflow phases on top of this state model.
