---
id: "0009"
slug: pmtiles-publish-workflow
stage: archived
completed: 2026-06-08
commit: 4b0e0951933b05a262e76dd5a46632e51feaa325
---

# PMTiles publish workflow — summary

## What was built
Added a persisted PMTiles publish workflow around the existing `MapTiles` build/publish core. The workflow stores singleton current state plus per-attempt history for manual and automatic publishes, including source, status, trigger reason, version, scheduling/run timestamps, object keys, PMTiles/manifest URLs, duration derivation, and sanitized failure text.

Added production-only source-model callbacks for `Problem`, `Boulder`, `Area`, `Cluster`, `Region`, `WalkingPath`, `Poi`, and `PoiRoute`. Relevant commits mark tiles stale and maintain one sliding-debounced automatic publish attempt using the configured 30-minute default delay. Development/test model saves remain no-ops unless tests call the scheduler directly. Running publishes are serialized through the singleton state row lock; edits during a run request a follow-up automatic attempt instead of starting a concurrent build.

Added `MapTilePublishJob` and `MapTiles::PublishPipeline` to run the existing export → Tippecanoe build → production smoke check → Bunny publish → local cleanup sequence outside web requests. Publish versions are generated at job start from UTC timestamps such as `2026-06-08T16-45-30Z`. Successes and failures update durable history and visible current state.

Changed Bunny publication from versioned PMTiles plus overwritten `latest.pmtiles` to immutable versioned PMTiles plus overwritten `austrian-rocks-latest.json`. Versioned PMTiles uploads use long immutable cache metadata; the manifest uses `application/json` and 60-second cache metadata, points to the current versioned PMTiles URL, and is verified separately.

Reworked the admin exports page to keep the SQLite DB download, remove the legacy Mapbox Studio GeoJSON exports for areas/clusters/regions/problems, and add an authenticated PMTiles publishing section with current status, last successful publish, pending automatic schedule, recent history, sanitized errors, and a confirmation-protected “Publish now” action that only enqueues a background job.

## Deviations from spec
None — all acceptance criteria are met. The legacy `Configuration#latest_object_key` method remains for local/operator CLI compatibility, but Bunny publishing no longer uses it and no `austrian-rocks-latest.pmtiles` object is uploaded or exposed by the new publisher flow.

## Key decisions
- Persist workflow state in one DB-enforced singleton `MapTilePublishState` row plus immutable `MapTilePublishAttempt` history rows.
- Implement sliding debounce as one pending automatic attempt; stale-marker calls update that row and enqueue delayed jobs, while early jobs self-reschedule.
- Use the singleton state row lock to serialize publish claims before expensive build/publish work.
- Keep manual admin publishes immediate from a scheduling perspective, but always run the pipeline in `MapTilePublishJob`, never in the web request.
- Always run the production PMTiles smoke check in admin/job publishing; only the operator CLI keeps the explicit `--skip-smoke` bypass.
- Publish only immutable versioned PMTiles plus `latest.json` to avoid stale or mixed range responses from overwritten PMTiles archives.
- Keep PMTiles workflow config in `config/map_tiles.yml`; Bunny credentials remain runtime secrets.

## Links
- Branch: `incant/0009-pmtiles-publish-workflow`
- Commits: `incant 0009: spec` → `incant 0009: plan` → `incant 0009-P1: persist PMTiles publish state` → `incant 0009-P1 (review fixes): address blocker/major/minor findings` → `incant 0009-P1: restore latest_object_key for legacy CLI compatibility` → `incant 0009-P2: debounce PMTiles source changes` → `incant 0009-P2: address review findings — production callback tests for all 8 source models, plan consistency fix` → `incant 0009-P3: run PMTiles publish jobs` → `incant 0009-P3: address PMTiles publish follow-up` → `incant 0009-P3: record PMTiles publish re-review` → `incant 0009-P4: publish PMTiles latest manifest` → `incant 0009-P4: record PMTiles publish review` → `incant 0009-P5: add admin PMTiles publishing` → `incant 0009-P6: verify PMTiles publish workflow`

## Sessions
- `019ea799-d1b3-7ba0-8af9-0e2c6b94d5a9`
- `019ea7b0-3ec1-709a-8bec-ac22bfc0ac74`
- `019ea7b8-d2e0-7728-b27e-b610dec4dd82`
- `019ea7c0-9821-7508-9f81-d2be60b0052c`
- `019ea7c4-74b4-7c45-bfc8-35b5adfa0328`
- `019ea7c8-dddc-729b-ad24-d9f0ac6c485b`
- `019ea7cb-a43d-7c08-8ba1-4bdc99b35dce`
- `019ea7cd-1ca0-7d4b-8ba6-16b5e02a2268`
- `019ea7d1-cfbf-7ba2-95f3-af3bd85fd9d3`
- `019ea7da-ae09-702a-a200-738027668710`
- `019ea7de-b628-753b-8d5c-55c5186a3358`
- `019ea7e7-096b-7f2f-a71d-5bd91d29d7a6`
- `019ea7eb-d62f-7ba3-bb53-fad30a5fc75c`
- `019ea7f9-b3ed-7ed1-8dd1-6e6038ec4ae5`
- `019ea7fd-c784-71b8-9c68-120b48c68300`
- `019ea801-8ccc-7427-9b28-816073a523e1`
- `019ea804-59e1-7155-9285-87c05693ae66`
- `019ea812-a83e-7163-8bf0-2894303a6bc7`
- `019ea814-d581-7626-9d8b-016959528b18`
- `019ea81e-6d63-790f-9b78-f0a6186acf10`
- `019ea824-41e9-760e-828c-6212d085b5a3`
- `019ea826-7d37-73c4-9508-2e663ff8631f`

## Follow-ups
None.
