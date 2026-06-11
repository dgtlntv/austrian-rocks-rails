---
id: "0013"
slug: asset-host-localhost-photo-urls
branch: incant/0013-asset-host-localhost-photo-urls
title: Asset host localhost photo URLs
stage: spec
status: in-progress
created: 2026-06-11
commit: 5aa362fe
updated: 2026-06-11
---

# Asset host localhost photo URLs

## Goal
Prevent map tile GeoJSON/PMTiles exports from emitting `http://localhost:3000` Active Storage photo URLs by failing the export when a photo URL is needed and `Rails.application.config.asset_host` is blank.

## Context & codebase fit
`lib/map_tiles/geojson_exporter.rb` writes the source GeoJSON layers consumed by the PMTiles build/publish pipeline. Its `card_properties` method adds optional `coverPhotoUrl` values for areas, clusters, and regions via `cover_photo_url`, while `problem_topo_properties` adds optional `topoPhotoUrl` values for problem topo previews. Both paths call `cdn_variant_url`, which currently passes `Rails.application.config.asset_host.presence || "http://localhost:3000"` into `Rails.application.routes.url_helpers.cdn_image_url` with `expires_in: nil`.

That fallback can bake localhost photo URLs into published PMTiles when `asset_host` is unset, causing Chrome Local Network Access prompts on `austrian.rocks` when users open affected map cards. Production already configures the asset host in `config/environments/production.rb` from `BRAND_CONFIG[:domains][:assets]`, and the shared `cdn_image` route in `config/routes.rb` knows how to generate Active Storage proxy URLs from the configured host. Existing coverage in `test/lib/map_tiles/geojson_exporter_test.rb` verifies deterministic cover/topo photo URL export behavior.

## Requirements
1. `MapTiles::GeojsonExporter` must not contain or use a hardcoded localhost fallback for CDN/Active Storage photo URL generation.
2. When an attached cover or topo photo requires a GeoJSON photo URL and `Rails.application.config.asset_host` is blank, export must raise a clear configuration error before any `coverPhotoUrl` or `topoPhotoUrl` value can be serialized with a localhost host.
3. When `Rails.application.config.asset_host` is present, exported `coverPhotoUrl` and `topoPhotoUrl` values must continue to use `cdn_image_url`, preserve the existing `expires_in: nil` deterministic URL behavior, and include the configured asset host rather than localhost.
4. Records without attached cover/topo photos must continue exporting without photo URL fields and must not require `asset_host` solely because the exporter ran.
5. Existing CLI/publish behavior must surface the raised export error through the existing command/pipeline failure paths; no publish attempt should succeed with localhost photo URLs.
6. Automated tests must cover both the blank-`asset_host` failure path and the configured-host success path for exported photo URLs.

## In scope / Out of scope
**In scope:**
- Remove the localhost fallback from `lib/map_tiles/geojson_exporter.rb`.
- Add a clear error path for blank `Rails.application.config.asset_host` when generating `coverPhotoUrl` or `topoPhotoUrl`.
- Adjust/add GeoJSON exporter tests around asset host handling and photo URL output.

**Out of scope:**
- Changing the PMTiles layer schema or removing `coverPhotoUrl` / `topoPhotoUrl` from the layer contract — reason: clients already consume these optional fields and the bug is the host fallback, not the schema.
- Switching map tile photo URL generation to `MapTiles::Configuration#public_cdn_host` — reason: Active Storage proxy URL generation already uses Rails `asset_host`; this item should fix the unsafe fallback without introducing a second source of truth.
- Cleaning previously published PMTiles artifacts that may already contain localhost URLs — reason: this item prevents future bad exports; artifact remediation is separate operational work.
- Browser/client-side Local Network Access handling — reason: clients should not receive localhost URLs from production tile data in the first place.

## Approach
Use the existing Rails `asset_host` configuration as the sole host source for exported Active Storage photo URLs. Replace the inline fallback in `cdn_variant_url` with a small required-host path that reads `Rails.application.config.asset_host.presence` and raises a descriptive configuration error when blank. Keep calling `cdn_image_url(variant, expires_in: nil, host: asset_host)` when the host is present so deterministic proxy URLs and current route behavior remain intact.

Rejected alternatives: silently omitting affected photo URL fields was rejected because it would hide a deployment configuration error and could still publish incomplete PMTiles without alerting operators. Moving these URLs to `public_cdn_host` was rejected because PMTiles artifact hosting and Active Storage image proxy hosting are distinct existing configurations.

## Considerations
### Config vs code
No new configuration value is needed. The configurable value is the existing Rails `config.asset_host`, set in `config/environments/production.rb` for production and overridden explicitly in tests. The exporter should consume that configuration directly and should not encode a default host in code. A blank default is intentional: it is acceptable until a record with an attached photo needs a public URL, at which point export fails loudly.

### Security
There are no new secrets or credentials. The change reduces data leakage and client-side risk by preventing internal/local hosts from being published in public PMTiles due to an implicit fallback. The generated URLs remain Active Storage proxy URLs produced by Rails route helpers; untrusted user data is not interpolated into hosts. The blast radius of a missing asset host becomes a failed export/publish attempt rather than a public artifact containing localhost URLs.

### Testability
Verification should be automated at the exporter test level because the bug is in `MapTiles::GeojsonExporter#cdn_variant_url`. `test/lib/map_tiles/geojson_exporter_test.rb` should set and restore `Rails.application.config.asset_host` around relevant tests, assert that a configured HTTPS host appears in `coverPhotoUrl` and `topoPhotoUrl`, and assert that blank `asset_host` raises the expected configuration error when an attached photo URL is exported. The targeted command is `bin/rails test test/lib/map_tiles/geojson_exporter_test.rb`.

### Code documentation
No broad documentation changes are required. If the implementation introduces a named error message constant or helper method for the required asset host, keep the name/message self-explanatory; add only a concise comment if needed to clarify why exporter photo URLs intentionally fail instead of falling back to localhost.

## Acceptance criteria
- [ ] `lib/map_tiles/geojson_exporter.rb` no longer contains `http://localhost:3000` or any localhost fallback for photo URL hosts.
- [ ] With `Rails.application.config.asset_host` blank and an exported attached cover/topo photo present, `MapTiles::GeojsonExporter#export` raises a clear configuration error instead of writing a localhost URL.
- [ ] With `Rails.application.config.asset_host` set to an HTTPS asset host, exported `coverPhotoUrl` and `topoPhotoUrl` values use that host and keep deterministic proxy URL behavior.
- [ ] Records without attached cover/topo photos still omit photo URL properties and export successfully.
- [ ] `bin/rails test test/lib/map_tiles/geojson_exporter_test.rb` passes.

## Risks & open questions
- Risk: existing tests may have relied on the previous implicit localhost fallback; they should be updated to set `asset_host` explicitly where photo URL assertions are intentional.
- Open questions: none.
