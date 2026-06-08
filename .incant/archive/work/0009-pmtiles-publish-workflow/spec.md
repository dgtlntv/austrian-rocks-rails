---
id: "0009"
slug: pmtiles-publish-workflow
branch: incant/0009-pmtiles-publish-workflow
title: PMTiles publish workflow
stage: spec
status: in-progress
created: 2026-06-08
commit: 7b6ff0f8
updated: 2026-06-08
---

# PMTiles publish workflow

## Goal
Provide an authenticated admin workflow and production-only debounced automatic workflow that build, smoke-check, and publish PMTiles artifacts when map source data changes, with visible publish history and no legacy GeoJSON export UI.

## Context & codebase fit
The app already has a PMTiles build and publish core under `lib/map_tiles/`: `GeojsonExporter` writes deterministic source-layer GeoJSON, `TippecanoeBuilder` builds `austrian-rocks-<version>.pmtiles`, `SmokeCheck` validates artifact/layer contracts, `BunnyPublisher` uploads to Bunny Storage, and `LocalArtifactCleaner` removes old local artifacts. These are exposed through `bin/build_pmtiles` and `lib/tasks/map_tiles.rake` commands: `export`, `build`, `smoke`, and `publish`.

Map tile settings live in `config/map_tiles.yml`, while Bunny credentials are runtime secrets wired through `.kamal/secrets` and `config/deploy.yml`. Production already uses Solid Queue (`config/environments/production.rb`, `config/queue.yml`, `config/puma.rb`) and MissionControl Jobs is mounted at `/jobs`, so background PMTiles publishing can fit the existing Rails job infrastructure.

The current admin export surface is `Admin::ExportsController`, `app/views/admin/exports/index.html.erb`, and routes under `resources :exports`. The SQLite DB export driven by `AppDbExporter` is still required. The legacy GeoJSON downloads in `Admin::ExportsController` were used for Mapbox Studio import and should be removed from this admin surface now that PMTiles/MapLibre is the publication path. Other GeoJSON-based editing tools, such as area-specific admin map downloads and import flows, are not part of this legacy export surface and should remain.

The PMTiles source layers currently depend on `Problem`, `Boulder`, `Area`, `Cluster`, `Region`, `WalkingPath`, `Poi`, and `PoiRoute`. `Topo`, `Line`, and photo-only data do not feed the current PMTiles layers directly and must not trigger automatic tile publishes for this item.

## Requirements
1. An authenticated admin user can trigger a PMTiles build-and-publish from the admin panel without using the command line.
2. Manual admin publishes enqueue one background job immediately and never run the build/publish pipeline inside the web request.
3. In production only, create/update/destroy commits on `Problem`, `Boulder`, `Area`, `Cluster`, `Region`, `WalkingPath`, `Poi`, and `PoiRoute` mark PMTiles as stale and schedule one automatic publish for the configured debounce delay.
4. The automatic publish debounce is sliding: each relevant edit while an automatic publish is pending moves the scheduled run time to `now + debounce_delay` instead of creating an additional build.
5. The default debounce delay is 30 minutes and is configurable in `config/map_tiles.yml`.
6. Automatic publish callbacks are disabled outside production; development and test must not publish or schedule publishes from normal model saves unless a test invokes the scheduling service directly.
7. If a publish is already running, new relevant edits must record that another automatic publish is needed and must not start a second concurrent build.
8. Each publish attempt records persistent history with source (`manual` or `automatic`), status (`pending`, `running`, `succeeded`, `failed`, or `cancelled`), trigger reason, version, relevant timestamps, duration or enough timestamps to derive duration, PMTiles URL, manifest URL, and sanitized error text when it fails.
9. The admin panel shows current tile source status (`up to date`, `stale`, `pending`, `running`, or `failed`), last successful publish details, pending automatic publish time when present, a confirmation-protected “Publish now” action, and a recent history table.
10. Publish versions are generated at job start from UTC timestamps in the existing safe segment format, e.g. `2026-06-08T16-45-30Z`.
11. The publisher uploads only the immutable versioned PMTiles object (`austrian-rocks-<version>.pmtiles`) and a `austrian-rocks-latest.json` manifest that points clients to the current versioned PMTiles URL; it no longer uploads or exposes `austrian-rocks-latest.pmtiles`.
12. Versioned PMTiles uploads use long immutable cache metadata suitable for range-requested PMTiles, while `latest.json` uses a short cache TTL of 60 seconds.
13. Admin/job publishing runs the existing production smoke check before upload with no admin UI bypass; no environment variable silently bypasses smoke checks, and the existing CLI `--skip-smoke` remains command-line operator behavior only.
14. The legacy admin GeoJSON export UI and controller actions for areas, clusters, regions, and problems are removed, along with their routes, while the SQLite DB export remains available.
15. Existing command-line PMTiles flows continue to work for local/operator use, updated only as needed for manifest-only latest publication.
16. Failure modes are visible in history and admin status; missing Tippecanoe, missing Bunny credentials, smoke-check failures, upload failures, and manifest verification failures must not be swallowed.
17. The implementation includes automated tests for scheduling/debounce behavior, job status transitions, manifest publishing/cache metadata, admin trigger/history behavior, and GeoJSON export removal while preserving SQLite export.

## In scope / Out of scope
**In scope:**
- A persisted PMTiles publish state/history model or equivalent persisted representation.
- A background job/service that orchestrates build, smoke check, publish, cleanup, and history updates.
- Production-only automatic stale marking and sliding-debounce scheduling for PMTiles source models.
- An admin UI for status, history, and manual publish triggering.
- Bunny publisher changes to publish immutable PMTiles plus short-TTL `latest.json`, and to stop publishing `latest.pmtiles`.
- Config additions for debounce delay and manifest/cache settings where needed.
- Removal of legacy admin GeoJSON export downloads and related routes/actions/views, while keeping SQLite DB export.
- Tests covering the workflow without invoking real Tippecanoe, real Bunny, or external network calls.

**Out of scope:**
- MapLibre client integration that reads `latest.json` — reason: that belongs to the later web map migration items.
- CDN purge API integration — reason: immutable PMTiles plus short-TTL manifest avoids purge credentials for v1.
- Daily or other fixed scheduled publishes — reason: data changes infrequently and publishes should be data-driven.
- Live progress bars or streaming build logs in admin — reason: simple history is enough for v1; detailed logs remain in Rails logs/MissionControl.
- Changes to area-specific admin map GeoJSON editing/import workflows — reason: those support map editing, not the removed Mapbox Studio export flow.
- Automatic triggers for `Topo`, `Line`, or photo-only changes — reason: current PMTiles layers do not consume those data directly.
- Changing the PMTiles layer contract or map styling — reason: this item is about publication workflow, not tile schema or rendering.

## Approach
Build on the existing `MapTiles` core instead of replacing it. Add a small persisted publication workflow around it: model source edits mark tile data stale; a scheduler service maintains one sliding-debounce automatic publish attempt; a Solid Queue job claims attempts, generates a timestamp version, runs the existing export/build/smoke/publish pipeline, updates history, and schedules a follow-up automatic publish if edits arrived while a job was running.

Expose this workflow through a new or revised admin PMTiles section in the existing admin area. The page should keep the SQLite DB export available, remove the legacy GeoJSON export controls, show status/history, and provide a confirmation-protected manual publish button. The web request only enqueues work and reports that the publish was queued.

Change Bunny publication semantics from “versioned plus latest PMTiles” to “versioned PMTiles plus latest manifest.” The manifest should contain enough stable data for future clients and operators to inspect: version, PMTiles URL, generated/published timestamp, artifact basename, and object key. The versioned PMTiles object is canonical and cacheable immutably; the manifest is the only overwritten object and has a short TTL.

Rejected alternatives:
- Fixed daily schedule: rejected because source data changes rarely and daily rebuilds waste compute/storage.
- Immediate publish on every save: rejected because rapid editing would trigger repeated expensive builds.
- Overwriting `latest.pmtiles`: rejected because PMTiles range requests and CDN/browser caches can produce stale or mixed byte ranges when a large archive URL is overwritten.
- Keeping legacy GeoJSON admin downloads: rejected because their known Mapbox Studio publication use case is obsolete; SQLite export remains because it has a separate still-needed use case.

## Considerations

### Config vs code
Configurable PMTiles workflow values should live in `config/map_tiles.yml`, not as literals scattered through services. At minimum this includes `automatic_publish_debounce_minutes` with a default of `30`, manifest cache TTL with a default of `60` seconds, and immutable PMTiles cache metadata. Existing settings for artifact basename, output dir, public CDN host, Bunny prefix, and optional production layers stay in the same config file and are consumed through `MapTiles::Configuration` or a closely related configuration object. The defaults reflect the agreed v1 behavior: 30 minutes collapses rapid editing sessions into one build, and 60 seconds makes manifest updates visible quickly without CDN purge integration.

### Security
Admin triggering remains behind the existing `Admin::BaseController` authentication outside local environments. Model-change automatic scheduling runs only server-side in production and accepts no user-provided network destinations or shell fragments. Version strings are generated by the job and must use the existing safe path-segment validation before becoming object keys. Bunny credentials continue to come from environment/secret wiring and must never be committed, rendered in admin, stored in `.incant/`, or included in error messages. Error text persisted to history must be sanitized to avoid leaking access keys or provider response bodies that may contain secrets.

The main trust boundaries are admin web requests, Active Record callbacks from persisted data changes, Tippecanoe process execution, and Bunny S3-compatible uploads. Avoid injection/path traversal by reusing sanitized configuration methods and by invoking Tippecanoe through the existing array-based command builder. Avoid authz gaps by exposing trigger/history only in the authenticated admin namespace. The blast radius of a failure should be contained to a failed publish attempt and stale status; existing published PMTiles remain available because the manifest is updated only after a successful versioned artifact upload and verification.

### Testability
The workflow should be tested with unit/integration seams around the expensive and external parts. Automated tests should cover the scheduler/debounce service and source-model callbacks with `bin/rails test test/models test/jobs` or targeted equivalents; job orchestration with fake exporter/builder/smoke/publisher/cleaner collaborators; Bunny publisher manifest/cache behavior with fake S3 and fake HEAD responses; and admin controller/system-level behavior with Rails controller tests where practical. Existing map tile tests under `test/lib/map_tiles` should be updated for the removal of `latest.pmtiles` and addition of `latest.json`.

The design needs injectable collaborators for the publish job/service so tests do not run real Tippecanoe, upload to Bunny, or perform network calls. Time should be controllable with Rails time helpers so timestamp versions and sliding debounce behavior are deterministic. Acceptance maps to observable checks: database history rows, enqueued/scheduled jobs, rendered admin content, object keys/cache metadata passed to fake S3, and removed GeoJSON routes returning no route.

### Code documentation
New workflow boundary classes should have concise documentation explaining what they coordinate and why they exist, especially the debounced scheduler, the publish job/service, and the manifest publisher behavior. Document the sliding debounce invariant near the scheduling code: many edits collapse into one pending automatic attempt, and edits during a running publish request a follow-up attempt. Document the cache rationale near manifest/latest publication code so future maintainers do not reintroduce `latest.pmtiles` casually. Avoid noisy comments that restate obvious Active Record validations or Rails conventions.

## Acceptance criteria
- [ ] In production-mode scheduling tests, saves/destroys for `Problem`, `Boulder`, `Area`, `Cluster`, `Region`, `WalkingPath`, `Poi`, and `PoiRoute` mark PMTiles stale and maintain one pending automatic publish attempt.
- [ ] Repeated relevant edits reset the pending automatic publish time to 30 minutes after the most recent edit by default.
- [ ] Relevant edits outside production do not schedule automatic publishes through normal model callbacks.
- [ ] Manual admin publish creates an immediate background publish attempt and displays queued feedback without running the pipeline in the request.
- [ ] Concurrent/running publish handling prevents two builds from running at once and records or schedules a follow-up when edits arrive during a run.
- [ ] Successful publish history records version, timestamps, PMTiles URL, manifest URL, source, and succeeded status.
- [ ] Failed publish history records failed status and sanitized error text without credentials.
- [ ] Bunny publishing uploads `austrian-rocks-<version>.pmtiles` and `austrian-rocks-latest.json`, applies long immutable cache metadata to PMTiles, applies 60-second cache metadata to the manifest, verifies public URLs, and does not upload `austrian-rocks-latest.pmtiles`.
- [ ] The admin PMTiles/history page shows current status, last success, pending automatic publish time when present, recent attempts, and a confirmation-protected “Publish now” control.
- [ ] The admin SQLite DB export still downloads successfully.
- [ ] Legacy admin GeoJSON export controls and routes/actions for areas, clusters, regions, and problems are gone.
- [ ] Existing command-line PMTiles build/smoke/publish tests pass after being updated for manifest-only latest publication.
- [ ] `bin/rails test test/lib/map_tiles test/jobs test/models test/controllers` and `bin/rubocop` pass, using Docker-hosted PostgreSQL/PostGIS for database-backed tests in this project.

## Risks & open questions
- Solid Queue delayed execution and cancellation/rescheduling details may require choosing between updating a persisted pending attempt, cancelling scheduled jobs, or having jobs self-skip until their current `scheduled_for`; the implementation must preserve the sliding debounce behavior regardless of mechanism.
- Production build duration may be long enough that edits often arrive while a publish is running; the follow-up scheduling path needs explicit tests.
- Existing external consumers of admin GeoJSON downloads are unknown, but the confirmed retained export is SQLite DB; removal is scoped to legacy admin Mapbox Studio downloads only.
