---
id: "0009"
slug: pmtiles-publish-workflow
branch: incant/0009-pmtiles-publish-workflow
title: PMTiles publish workflow
stage: plan
status: in-progress
created: 2026-06-08
commit: 055ba8f4
updated: 2026-06-08
---

# PMTiles publish workflow — plan

## Status
- Phase: 0009-P1 pending — plan drafted, awaiting human approval before implementation.
- Stage: plan
- Branch: incant/0009-pmtiles-publish-workflow
- Next: human approves this plan, then run `/incant:implement 0009`.
- Blockers: none.
- Fresh verification: not run during planning; each implementation phase below has its own required gate.
- Key decisions:
  - Persist publish workflow state in one singleton `MapTilePublishState` row plus immutable history rows in `MapTilePublishAttempt`.
  - Treat sliding debounce as one pending automatic attempt row; older delayed jobs that wake up before the current `scheduled_for` self-reschedule and do not build.
  - Protect build concurrency with a transaction lock on the singleton state row before any job marks an attempt `running`.
  - Keep manual publishes immediate and request-scoped work limited to creating an attempt and enqueuing `MapTilePublishJob`.
  - Publish only an immutable versioned PMTiles object plus `austrian-rocks-latest.json`; never upload `austrian-rocks-latest.pmtiles`.
  - Keep callback scheduling production-only; tests may invoke `MapTiles::PublishScheduler` directly outside production.

## Spec freshness check
- `spec.md` records base commit `7b6ff0f8`; current `HEAD` is `055ba8f4`.
- `git diff --name-status 7b6ff0f8..HEAD` shows only `.incant/` artifacts for item `0009`, so the PMTiles library, admin export surface, models, routes, queue config, Docker setup, and tests mapped below have not drifted since the spec was written.

## Files touched

### Incant planning artifacts
- `.incant/work/0009-pmtiles-publish-workflow/plan.md` (edit) — replace the scaffold with this approved-spec implementation plan.
- `.incant/work/0009-pmtiles-publish-workflow/sessions.json` (edit) — record this linked planning session through `incant session link 0009`.
- `.incant/backlog.md` (edit) — move item `0009` from `status:spec` to `status:plan` after writing the plan.
- `.incant/STATE.md` (edit) — record that item `0009` is in planning and awaiting approval.

### Persistence, configuration, and workflow state
- `db/migrate/20260608120000_create_map_tile_publish_workflow.rb` (new) — create `map_tile_publish_states` and `map_tile_publish_attempts` with status/source fields, scheduling timestamps, run timestamps, URLs, version, trigger reason, sanitized errors, and indexes.
- `db/schema.rb` (edit) — reflect the publish workflow migration after `bin/rails db:migrate` or test schema loading.
- `app/models/map_tile_publish_state.rb` (new) — singleton state model with `current!`, status derivation (`up_to_date`, `stale`, `pending`, `running`, `failed`), pending/running/last-success associations, and lock-safe helpers.
- `app/models/map_tile_publish_attempt.rb` (new) — publish history model with source/status enums, timestamp validations, duration helper, safe status transitions, URL fields, and sanitized error storage.
- `config/map_tiles.yml` (edit) — add `automatic_publish_debounce_minutes: 30`, `manifest_cache_ttl_seconds: 60`, and immutable PMTiles cache metadata defaults for every environment.
- `lib/map_tiles/configuration.rb` (edit) — expose debounce duration, manifest TTL, PMTiles cache control, `latest_manifest_object_key`, manifest content type, and keep safe version/object-key validation.

### Automatic scheduling and source-model callbacks
- `app/models/concerns/map_tiles/publish_stale_marker.rb` (new) — `after_commit` concern that marks PMTiles stale only when `Rails.env.production?` for create/update/destroy commits.
- `app/models/problem.rb` (edit) — include `MapTiles::PublishStaleMarker` for PMTiles source edits.
- `app/models/boulder.rb` (edit) — include `MapTiles::PublishStaleMarker` for PMTiles source edits.
- `app/models/area.rb` (edit) — include `MapTiles::PublishStaleMarker` for PMTiles source edits.
- `app/models/cluster.rb` (edit) — include `MapTiles::PublishStaleMarker` for PMTiles source edits.
- `app/models/region.rb` (edit) — include `MapTiles::PublishStaleMarker` for PMTiles source edits.
- `app/models/walking_path.rb` (edit) — include `MapTiles::PublishStaleMarker` for PMTiles source edits.
- `app/models/poi.rb` (edit) — include `MapTiles::PublishStaleMarker` for PMTiles source edits.
- `app/models/poi_route.rb` (edit) — include `MapTiles::PublishStaleMarker` for PMTiles source edits.
- `app/services/map_tiles/publish_scheduler.rb` (new) — create manual attempts, mark stale data, maintain one sliding pending automatic attempt, enqueue delayed jobs, and preserve follow-up work when a publish is running.

### Job orchestration and PMTiles pipeline
- `app/jobs/map_tile_publish_job.rb` (new) — Active Job entry point that loads an attempt, self-reschedules early automatic jobs, serializes running state through the singleton lock, and delegates the build/publish pipeline outside the web request.
- `app/services/map_tiles/publish_pipeline.rb` (new) — orchestrate exporter, Tippecanoe builder, production smoke check, Bunny publisher, local cleanup, history timestamps, version generation, URLs, and sanitized failures with injectable collaborators for tests.
- `lib/map_tiles/bunny_publisher.rb` (edit) — publish immutable PMTiles first, verify its public URL, upload and verify `austrian-rocks-latest.json`, set cache metadata, and return PMTiles/manifest URLs for history.
- `lib/map_tiles/cli.rb` (edit) — adapt CLI publish expectations to the publisher return shape while preserving explicit `--skip-smoke` as the only command-line smoke bypass.
- `lib/tasks/map_tiles.rake` (edit) — keep operator task behavior aligned with the CLI after manifest-only publish output changes.

### Admin workflow and legacy GeoJSON removal
- `app/controllers/admin/exports_controller.rb` (edit) — keep SQLite DB download, remove legacy GeoJSON actions, load PMTiles status/history, and add a `publish_pmtiles` POST action that enqueues a manual attempt only.
- `app/views/admin/exports/index.html.erb` (edit) — keep SQLite DB export, remove legacy GeoJSON controls, render PMTiles status/last success/pending time/recent history, and add a confirmation-protected “Publish now” form.
- `app/helpers/admin/exports_helper.rb` (new) — format publish status labels, timestamps, durations, links, and sanitized errors for the admin exports page.
- `config/routes.rb` (edit) — remove `areas_geojson`, `clusters_geojson`, `regions_geojson`, and `problems_geojson` collection routes; add `post :publish_pmtiles` under admin exports.

### Tests
- `test/models/map_tile_publish_state_test.rb` (new) — cover singleton state creation, derived statuses, last success, pending/running state, failed state, and duration derivation through associated attempts.
- `test/models/map_tile_publish_attempt_test.rb` (new) — cover source/status validations, sanitized error text, timestamp transitions, and version/url history fields.
- `test/models/map_tiles/publish_stale_marker_test.rb` (new) — cover production-only callbacks for `Problem`, `Boulder`, `Area`, `Cluster`, `Region`, `WalkingPath`, `Poi`, and `PoiRoute`, and prove non-source models such as `Line` do not include the concern.
- `test/services/map_tiles/publish_scheduler_test.rb` (new) — cover manual immediate attempts, stale marking, one pending automatic attempt, sliding `scheduled_for`, outside-production direct-service behavior, and running-publish follow-up scheduling.
- `test/jobs/map_tile_publish_job_test.rb` (new) — cover pending-to-running-to-succeeded, pending-to-failed, early automatic self-reschedule, concurrent running protection, running-edit follow-up, and no web-request pipeline execution.
- `test/services/map_tiles/publish_pipeline_test.rb` (new) — cover UTC safe version generation, collaborator order, production smoke check with no env bypass, URL/status persistence, cleanup after success, and sanitized errors for Tippecanoe/Bunny/smoke failures.
- `test/lib/map_tiles/bunny_publisher_test.rb` (edit) — replace latest-PMTiles expectations with latest-manifest expectations, cache metadata assertions, manifest JSON assertions, public URL verification, and no `austrian-rocks-latest.pmtiles` upload.
- `test/lib/map_tiles/configuration_test.rb` (edit) — cover new debounce, manifest TTL/cache settings, `latest_manifest_object_key`, and continued safe segment validation.
- `test/lib/map_tiles/cli_test.rb` (edit) — keep command-line publish coverage passing after manifest-only publication while proving `--skip-smoke` remains CLI-only behavior.
- `test/controllers/admin/exports_controller_test.rb` (new) — cover SQLite DB download, PMTiles status/history rendering, confirmation-protected manual publish enqueue, and removed GeoJSON routes/actions.

## Phase 0009-P1 — persisted publish history and map tile workflow configuration
- [ ] Read `db/schema.rb`, `app/models/application_record.rb`, `config/map_tiles.yml`, `lib/map_tiles/configuration.rb`, `test/lib/map_tiles/configuration_test.rb`, and existing migration naming under `db/migrate/` before editing.
- [ ] Add `db/migrate/20260608120000_create_map_tile_publish_workflow.rb` creating `map_tile_publish_states` with `status`, `stale_at`, `pending_automatic_attempt_id`, `running_attempt_id`, `last_successful_attempt_id`, `last_failed_attempt_id`, `last_source_change_at`, `created_at`, and `updated_at`; add indexes for the attempt foreign-key columns.
- [ ] In the same migration create `map_tile_publish_attempts` with `source`, `status`, `trigger_reason`, `version`, `scheduled_for`, `enqueued_at`, `started_at`, `finished_at`, `pmtiles_url`, `manifest_url`, `pmtiles_object_key`, `manifest_object_key`, `error_text`, `created_at`, and `updated_at`; add indexes on `source`, `status`, `scheduled_for`, `created_at`, and `version`.
- [ ] Run the migration in the Docker test/development database path and update `db/schema.rb` so both new tables are reflected with the latest schema version.
- [ ] Add `app/models/map_tile_publish_attempt.rb` with `SOURCES = %w[manual automatic]`, `STATUSES = %w[pending running succeeded failed cancelled]`, validations for inclusion/presence, `duration` returning `finished_at - started_at` when both timestamps exist, and `record_failure!(error, finished_at:)` that strips Bunny secret values and truncates stored text to 2,000 characters.
- [ ] Add `app/models/map_tile_publish_state.rb` with `self.current!` creating or returning the singleton row, associations to `pending_automatic_attempt`, `running_attempt`, `last_successful_attempt`, and `last_failed_attempt`, and `current_status` returning `running`, `pending`, `failed`, `stale`, or `up_to_date` from persisted state.
- [ ] Edit `config/map_tiles.yml` defaults to add `automatic_publish_debounce_minutes: 30`, `manifest_cache_ttl_seconds: 60`, `pmtiles_cache_control: public, max-age=31536000, immutable`, and `manifest_content_type: application/json`; inherit these values in development, test, and production.
- [ ] Edit `lib/map_tiles/configuration.rb` to expose `automatic_publish_debounce`, `manifest_cache_ttl_seconds`, `pmtiles_cache_control`, `manifest_content_type`, `latest_manifest_object_key`, and `latest_manifest_basename` derived from `artifact_basename`; keep `latest_object_key` from returning or naming `austrian-rocks-latest.pmtiles`.
- [ ] Add `test/models/map_tile_publish_attempt_test.rb` covering source/status validation, duration calculation, failed status transition, credential redaction for `BUNNY_STORAGE_ACCESS_KEY_ID` and `BUNNY_STORAGE_SECRET_ACCESS_KEY`, and 2,000-character error truncation.
- [ ] Add `test/models/map_tile_publish_state_test.rb` covering singleton creation, derived `up_to_date`, `stale`, `pending`, `running`, and `failed` statuses, and last successful publish fields.
- [ ] Update `test/lib/map_tiles/configuration_test.rb` to assert the 30-minute debounce, 60-second manifest TTL, immutable PMTiles cache control, `map_tiles/test/austrian-rocks-latest.json`, and absence of any `latest.pmtiles` configuration method expectation.
- [ ] Commit this phase as `incant 0009-P1: persist PMTiles publish state` after the quality gate passes.
**Quality gate:** `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/models/map_tile_publish_attempt_test.rb test/models/map_tile_publish_state_test.rb test/lib/map_tiles/configuration_test.rb` → all persistence and configuration tests pass against Docker-hosted PostgreSQL/PostGIS.

## Phase 0009-P2 — production-only stale marking and sliding automatic scheduling
- [ ] Read `app/models/problem.rb`, `app/models/boulder.rb`, `app/models/area.rb`, `app/models/cluster.rb`, `app/models/region.rb`, `app/models/walking_path.rb`, `app/models/poi.rb`, `app/models/poi_route.rb`, `app/models/line.rb`, `app/models/topo.rb`, and `app/jobs/application_job.rb` before editing.
- [ ] Add `app/services/map_tiles/publish_scheduler.rb` with `enqueue_manual!(reason:, at: Time.current)` creating a `manual`/`pending` attempt with `scheduled_for` and `enqueued_at` equal to `at`, enqueueing `MapTilePublishJob.perform_later(attempt.id)`, and returning the attempt.
- [ ] In `MapTiles::PublishScheduler`, add `mark_stale!(reason:, at: Time.current)` that locks `MapTilePublishState.current!`, sets `stale_at` and `last_source_change_at` to `at`, finds or creates exactly one `automatic`/`pending` attempt, updates its `trigger_reason`, `scheduled_for` to `at + configuration.automatic_publish_debounce`, records it as `pending_automatic_attempt`, and enqueues `MapTilePublishJob.set(wait_until: scheduled_for).perform_later(attempt.id)`.
- [ ] In `MapTiles::PublishScheduler`, preserve the sliding debounce invariant in a code comment near the locked update: many edits collapse into one pending automatic attempt, and edits during a running publish request a follow-up attempt rather than a concurrent build.
- [ ] Add `app/models/concerns/map_tiles/publish_stale_marker.rb` using `ActiveSupport::Concern`, `after_commit :mark_map_tiles_stale_for_publish`, `on: %i[create update destroy]`, returning unless `Rails.env.production?`, and passing a trigger reason containing the model class and id without user-entered attributes.
- [ ] Include `MapTiles::PublishStaleMarker` in `Problem`, `Boulder`, `Area`, `Cluster`, `Region`, `WalkingPath`, `Poi`, and `PoiRoute`; do not include it in `Topo`, `Line`, Active Storage models, or photo-only paths.
- [ ] Add `test/services/map_tiles/publish_scheduler_test.rb` using Active Job test helpers and Rails time helpers to prove manual attempts enqueue immediately, direct service calls outside production work, one pending automatic attempt is maintained, repeated edits move `scheduled_for` to 30 minutes after the newest edit, and edits while `running_attempt_id` is set leave the running attempt untouched while maintaining the pending automatic follow-up.
- [ ] Add `test/models/map_tiles/publish_stale_marker_test.rb` that stubs `Rails.env.production?` to `true` for create/update/destroy commits on `Problem`, `Boulder`, `Area`, `Cluster`, `Region`, `WalkingPath`, `Poi`, and `PoiRoute`; assert each marks state stale and keeps one pending automatic attempt.
- [ ] In the same callback test, stub `Rails.env.production?` to `false` and assert normal saves do not schedule automatic publishes; assert `Line` and `Topo` do not respond to `mark_map_tiles_stale_for_publish` and do not schedule publishes when saved.
- [ ] Commit this phase as `incant 0009-P2: debounce PMTiles source changes` after the quality gate passes.
**Quality gate:** `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/services/map_tiles/publish_scheduler_test.rb test/models/map_tiles/publish_stale_marker_test.rb` → scheduler and callback tests pass against Docker-hosted PostgreSQL/PostGIS.

## Phase 0009-P3 — background publish job and pipeline orchestration
- [ ] Read `app/jobs/application_job.rb`, `lib/map_tiles/geojson_exporter.rb`, `lib/map_tiles/tippecanoe_builder.rb`, `lib/map_tiles/smoke_check.rb`, `lib/map_tiles/bunny_publisher.rb`, `lib/map_tiles/local_artifact_cleaner.rb`, and `lib/map_tiles/cli.rb` before editing.
- [ ] Add `app/jobs/map_tile_publish_job.rb` with `queue_as :default` and `perform(attempt_id)` loading the attempt and delegating claim/reschedule logic to private methods that lock `MapTilePublishState.current!` before changing attempt status.
- [ ] In `MapTilePublishJob`, if an automatic attempt wakes before its current `scheduled_for`, enqueue the same attempt at the current `scheduled_for` and return without changing status or running the pipeline.
- [ ] In `MapTilePublishJob`, if another attempt is recorded as running, leave an automatic attempt pending and enqueue it for the later of its `scheduled_for` and the debounce delay; mark a manual attempt `cancelled` with sanitized reason `Another PMTiles publish is already running` so a second build cannot start.
- [ ] In `MapTilePublishJob`, when no publish is running, mark the attempt `running`, set `started_at`, clear `pending_automatic_attempt_id` when claiming that attempt, set `running_attempt_id`, and call `MapTiles::PublishPipeline` outside the state lock.
- [ ] Add `app/services/map_tiles/publish_pipeline.rb` with injectable `configuration`, `exporter_class`, `builder_class`, `smoke_check_class`, `publisher_class`, `cleaner_class`, and `clock`; generate version at job start with `clock.call.utc.strftime("%Y-%m-%dT%H-%M-%SZ")` and pass it through `configuration.with_version(version)`.
- [ ] In `MapTiles::PublishPipeline`, run `GeojsonExporter#export`, `TippecanoeBuilder#build`, `SmokeCheck.new(argv: ["--mode=production"]).run`, `BunnyPublisher#publish`, and `LocalArtifactCleaner#clean` in that order; do not read `MAP_TILES_SKIP_SMOKE` or accept a UI bypass.
- [ ] In `MapTiles::PublishPipeline`, on success persist `version`, `pmtiles_url`, `manifest_url`, object keys, `finished_at`, and `succeeded`; under the state lock clear `running_attempt_id`, set `last_successful_attempt_id`, clear stale state only when `stale_at` is blank or not newer than `started_at`, and otherwise ensure a pending automatic follow-up exists.
- [ ] In `MapTiles::PublishPipeline`, rescue missing Tippecanoe, build failures, smoke-check failures, Bunny configuration/upload/verification failures, and other standard errors; persist `failed`, `finished_at`, and sanitized `error_text`; clear `running_attempt_id`; set `last_failed_attempt_id`; keep stale status visible.
- [ ] Add `test/jobs/map_tile_publish_job_test.rb` covering successful claim, early automatic self-reschedule, manual cancellation when a run is active, automatic follow-up when a run is active, and no pipeline call from controller/request code.
- [ ] Add `test/services/map_tiles/publish_pipeline_test.rb` with fake collaborators proving collaborator order, safe UTC version generation, production smoke invocation, success URL persistence, cleanup after success, stale clearing only when no newer source edit exists, follow-up scheduling after running edits, and sanitized failure recording for each major failure class.
- [ ] Commit this phase as `incant 0009-P3: run PMTiles publish jobs` after the quality gate passes.
**Quality gate:** `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/jobs/map_tile_publish_job_test.rb test/services/map_tiles/publish_pipeline_test.rb` → job orchestration and pipeline tests pass against Docker-hosted PostgreSQL/PostGIS.

## Phase 0009-P4 — manifest-only Bunny publication and command-line compatibility
- [ ] Read `lib/map_tiles/bunny_publisher.rb`, `lib/map_tiles/configuration.rb`, `lib/map_tiles/cli.rb`, `lib/tasks/map_tiles.rake`, `test/lib/map_tiles/bunny_publisher_test.rb`, `test/lib/map_tiles/configuration_test.rb`, and `test/lib/map_tiles/cli_test.rb` before editing.
- [ ] Edit `lib/map_tiles/bunny_publisher.rb` so `publish` uploads only `configuration.versioned_object_key` and `configuration.latest_manifest_object_key`; remove the upload path for `austrian-rocks-latest.pmtiles` entirely.
- [ ] In `BunnyPublisher#publish`, upload the versioned PMTiles object with `content_type: application/octet-stream` and `cache_control: configuration.pmtiles_cache_control`, verify its public URL, then build manifest JSON containing `version`, `pmtiles_url`, `published_at`, `artifact_basename`, `pmtiles_object_key`, and `pmtiles_object_basename`.
- [ ] In `BunnyPublisher#publish`, upload `austrian-rocks-latest.json` with `content_type: configuration.manifest_content_type` and `cache_control: "public, max-age=#{configuration.manifest_cache_ttl_seconds}"`, verify its public URL, print both published object URLs, and return `{ pmtiles: { key:, url: }, manifest: { key:, url: } }`.
- [ ] Add a concise code comment near the manifest upload explaining that `latest.json` is the only overwritten object because overwritten PMTiles archives can produce stale or mixed range responses.
- [ ] Keep Bunny credential validation limited to Bunny storage environment variables and continue to redact provider/credential details from upload errors.
- [ ] Edit `lib/map_tiles/cli.rb` and `lib/tasks/map_tiles.rake` so `bin/build_pmtiles publish --version=2026-06-08T16-45-30Z` and `bin/rails "map_tiles:publish[2026-06-08T16-45-30Z,false]"` print the manifest URL, keep the existing exit-status behavior, and keep working with manifest-only publication.
- [ ] Update `test/lib/map_tiles/bunny_publisher_test.rb` to assert PMTiles and JSON manifest keys, body content, cache metadata, content types, public URL verification order, no `austrian-rocks-latest.pmtiles` put, and sanitized failures.
- [ ] Update `test/lib/map_tiles/configuration_test.rb` and `test/lib/map_tiles/cli_test.rb` for the new manifest key and publisher return shape while preserving command-line smoke and `--skip-smoke` behavior.
- [ ] Commit this phase as `incant 0009-P4: publish PMTiles latest manifest` after the quality gate passes.
**Quality gate:** `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/lib/map_tiles/bunny_publisher_test.rb test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/cli_test.rb` → map tile publisher, configuration, and CLI tests pass against Docker-hosted PostgreSQL/PostGIS.

## Phase 0009-P5 — admin publish UI, history, and legacy GeoJSON export removal
- [ ] Read `app/controllers/admin/base_controller.rb`, `app/controllers/admin/exports_controller.rb`, `app/views/admin/exports/index.html.erb`, `app/views/layouts/admin.html.erb`, `config/routes.rb`, and existing admin controller tests before editing.
- [ ] Edit `config/routes.rb` under admin exports to keep `get :db`, add `post :publish_pmtiles`, and remove `get :areas_geojson`, `get :clusters_geojson`, `get :regions_geojson`, and `get :problems_geojson`.
- [ ] Edit `app/controllers/admin/exports_controller.rb` so `index` loads `@map_tile_state = MapTilePublishState.current!`, `@last_successful_attempt`, `@pending_automatic_attempt`, and `@recent_map_tile_attempts = MapTilePublishAttempt.order(created_at: :desc).limit(25)`.
- [ ] In `Admin::ExportsController`, keep `db` as the SQLite download action, remove `areas_geojson`, `clusters_geojson`, `regions_geojson`, and `problems_geojson`, and add `publish_pmtiles` that calls `MapTiles::PublishScheduler.new.enqueue_manual!(reason: "Manual admin publish")`, sets queued flash text, and redirects to `admin_exports_path`.
- [ ] Add `app/helpers/admin/exports_helper.rb` with deterministic helpers for status label text, timestamp formatting, duration formatting, external link rendering, and safe error display; helpers must not render Bunny credentials or raw provider bodies.
- [ ] Edit `app/views/admin/exports/index.html.erb` to show the SQLite Database download, a PMTiles card with status (`up to date`, `stale`, `pending`, `running`, or `failed`), last successful version/URLs/timestamp, pending automatic publish time, recent attempts table, and a `button_to "Publish now"` using `data: { turbo_confirm: "Build, smoke-check, and publish PMTiles now?" }`.
- [ ] Remove all legacy admin GeoJSON controls from `app/views/admin/exports/index.html.erb`; do not touch area-specific admin map downloads or import/editing GeoJSON flows outside this exports page.
- [ ] Add `test/controllers/admin/exports_controller_test.rb` covering `GET /:locale/admin/exports`, SQLite DB download, manual publish POST creating a pending manual attempt and one enqueued job without invoking fake pipeline collaborators, rendered status/last success/pending/history fields, confirm-protected button markup, and absence of legacy GeoJSON controls.
- [ ] In the same controller test, assert route helpers and requests for `areas_geojson`, `clusters_geojson`, `regions_geojson`, and `problems_geojson` are removed while `db_admin_exports_path` still succeeds.
- [ ] Commit this phase as `incant 0009-P5: add admin PMTiles publishing` after the quality gate passes.
**Quality gate:** `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/controllers/admin/exports_controller_test.rb` → admin trigger/history and GeoJSON-removal tests pass against Docker-hosted PostgreSQL/PostGIS.

## Phase 0009-P6 — acceptance sweep, status updates, and release readiness
- [ ] Read `.incant/work/0009-pmtiles-publish-workflow/spec.md`, this `plan.md`, `.incant/backlog.md`, `.incant/STATE.md`, and the current `git diff --stat` before editing any incant status artifacts.
- [ ] Run the full acceptance test set named in the spec: `test/lib/map_tiles`, `test/jobs`, `test/models`, and `test/controllers`, using Docker-hosted PostgreSQL/PostGIS.
- [ ] Run `bin/rubocop` in Docker after the acceptance tests pass.
- [ ] Inspect `git diff --name-only` and confirm no secrets, generated PMTiles artifacts, generated GeoJSON, temporary dumps, or ignored helper scripts are tracked.
- [ ] Update this plan’s `## Status` block with completed phase evidence, set `.incant/backlog.md` to `status:review phase:0009-P6`, and update `.incant/STATE.md` to say item `0009` is awaiting review.
- [ ] Commit this phase as `incant 0009-P6: verify PMTiles publish workflow` after the quality gate passes.
**Quality gate:** `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:password@db:5432/austrian-rocks-test web bin/rails test test/lib/map_tiles test/jobs test/models test/controllers && docker compose run --rm web bin/rubocop` → specified Rails tests and RuboCop pass; tracked diff contains no secrets or generated tile artifacts.

## Coverage self-review
- Requirement 1 → Phase 0009-P5 adds authenticated admin PMTiles publish UI under `Admin::ExportsController`.
- Requirement 2 → Phases 0009-P2, 0009-P3, and 0009-P5 create an immediate manual attempt and enqueue `MapTilePublishJob` without running the pipeline in the request.
- Requirement 3 → Phase 0009-P2 adds production-only callbacks for `Problem`, `Boulder`, `Area`, `Cluster`, `Region`, `WalkingPath`, `Poi`, and `PoiRoute`.
- Requirement 4 → Phase 0009-P2 implements one pending automatic attempt with sliding `scheduled_for` updates.
- Requirement 5 → Phase 0009-P1 adds `automatic_publish_debounce_minutes: 30` to `config/map_tiles.yml` and `MapTiles::Configuration`.
- Requirement 6 → Phase 0009-P2 gates model callbacks with `Rails.env.production?` while keeping direct scheduler tests possible.
- Requirement 7 → Phases 0009-P2 and 0009-P3 preserve follow-up pending automatic attempts while a publish is running and prevent a second concurrent build.
- Requirement 8 → Phase 0009-P1 persists source, status, trigger reason, version, timestamps, URLs, duration derivation, and sanitized error text.
- Requirement 9 → Phase 0009-P5 renders current status, last success, pending automatic time, publish action, and recent history.
- Requirement 10 → Phase 0009-P3 generates UTC timestamp versions in the safe `2026-06-08T16-45-30Z` format.
- Requirement 11 → Phase 0009-P4 removes `austrian-rocks-latest.pmtiles` and publishes `austrian-rocks-latest.json` pointing at the immutable versioned PMTiles URL.
- Requirement 12 → Phases 0009-P1 and 0009-P4 configure and apply immutable PMTiles cache metadata and 60-second manifest cache metadata.
- Requirement 13 → Phase 0009-P3 runs production smoke checks in job/admin publishing without a UI or environment bypass; Phase 0009-P4 keeps CLI `--skip-smoke` operator-only behavior.
- Requirement 14 → Phase 0009-P5 removes legacy admin GeoJSON routes/actions/controls for areas, clusters, regions, and problems while preserving SQLite DB export.
- Requirement 15 → Phase 0009-P4 keeps command-line PMTiles publish flows working with manifest-only latest publication.
- Requirement 16 → Phases 0009-P3 and 0009-P4 make missing Tippecanoe, Bunny credential, smoke-check, upload, and manifest verification failures visible in failed history.
- Requirement 17 → Phases 0009-P1 through 0009-P6 add targeted automated tests for scheduling/debounce, job transitions, Bunny manifest/cache behavior, admin trigger/history, GeoJSON removal, SQLite preservation, map tile CLI compatibility, and final Rails/RuboCop gates.
- Symbol/signature consistency checked: `MapTilePublishState.current!`, `MapTilePublishState#current_status`, `MapTilePublishAttempt::SOURCES`, `MapTilePublishAttempt::STATUSES`, `MapTiles::PublishScheduler#enqueue_manual!`, `MapTiles::PublishScheduler#mark_stale!`, `MapTilePublishJob.perform(attempt_id)`, `MapTiles::PublishPipeline#call(attempt)`, `Configuration#latest_manifest_object_key`, and `BunnyPublisher#publish` are named consistently across phases.
- Goal-level verification checked: Phase 0009-P6 reruns the exact spec acceptance commands `bin/rails test test/lib/map_tiles test/jobs test/models test/controllers` and `bin/rubocop` in Docker.
- Scaffold markers removed; every phase has concrete paths, symbols, commands, and expected results.
