---
id: "0001"
slug: move-object-storage-to-bunny-storage
branch: incant/0001-move-object-storage-to-bunny-storage
title: Move Object Storage To Bunny Storage
stage: spec
status: awaiting-approval
created: 2026-06-05
commit: aeedbb66
updated: 2026-06-05
---

# Move Object Storage To Bunny Storage

## Goal
Move all currently used production object-storage integrations from Cloudflare R2 to Bunny Storage S3 compatibility so Rails uploads and database backups no longer depend on Cloudflare.

## Context & codebase fit
The app currently has two concrete R2-backed object-storage surfaces:

- `config/storage.yml` defines the production S3-compatible Active Storage service as `amazon`, with the Cloudflare R2 endpoint, `auto` region, `austrian-rocks-data` bucket, and path-style setting hardcoded.
- `config/environments/production.rb` selects `config.active_storage.service = :amazon`, so production uploads, downloads, and variants use the R2-backed service.
- `config/deploy.yml` configures the `db_backup` accessory with R2 values for `S3_REGION`, `S3_BUCKET`, and `S3_ENDPOINT`, while access keys are supplied as Kamal secrets.
- `config/initializers/active_storage.rb` currently contains committed read-only R2 fallback credentials (`S3_READONLY_KEY` / `S3_READONLY_SECRET`) that are consumed by `config/storage.yml`.
- `.gitignore` does not currently ignore `/docs/`, but this item needs a local-only runbook location that will not be pushed.

Likely changed files for implementation:

- `config/storage.yml` — replace the Cloudflare/R2-backed `amazon` service with a Bunny S3-compatible service whose endpoint, region, bucket/zone, and credentials come from env/secrets.
- `config/environments/production.rb` — point production Active Storage at the Bunny service name.
- `config/initializers/active_storage.rb` — remove committed R2 fallback credential constants; keep only unrelated Active Storage routing behavior.
- `config/deploy.yml` — replace backup R2 endpoint/bucket/region with Bunny backup-zone configuration and separate backup credentials.
- `.gitignore` — ignore `/docs/` for local-only operational runbooks.
- `docs/bunny-storage-migration.md` — create locally during implementation as an ignored, uncommitted runbook for Bunny setup, object copy, deploy, and verification.

Relevant files expected to remain unchanged:

- `config/routes.rb`, `app/helpers/shared_helper.rb`, and `app/controllers/proxy_controller.rb` already serve Active Storage through Rails proxy/CDN-style routes; the storage vendor change should not require route/helper/controller changes unless implementation discovers Bunny-specific serving issues.
- `app/controllers/admin/exports_controller.rb` exposes current SQLite/GeoJSON downloads, but this item does not publish those exports to object storage.
- Mapbox/MapLibre files such as `app/javascript/controllers/mapbox_controller.js` and `app/views/layouts/map.html.erb` are future map work and must not be changed for this storage migration.

Future storage uses such as PMTiles, mobile OTA SQLite files, signed manifests, and MapLibre style assets are important context for choosing Bunny as the storage vendor, but this work item does not implement those future artifact pipelines or create speculative object prefixes for them.

## Requirements
1. Production Rails Active Storage must be configurable to use Bunny Storage S3 compatibility instead of Cloudflare R2.
2. Production database backups in `config/deploy.yml` must target a Bunny Storage backup zone instead of Cloudflare R2.
3. Rails uploads and database backups must use two separate Bunny Storage zones/buckets so app-upload credentials and backup credentials can have separate access boundaries.
4. Bunny-specific endpoint, region, zone/bucket names, access keys, and secret keys must be supplied via environment variables and/or Kamal secrets, not hardcoded credentials in committed code.
5. Existing committed R2 read-only Active Storage fallback credentials must be removed from the Rails runtime.
6. The migration must support an operational-only R2 fallback window: R2 may remain read-only outside the app for manual comparison, re-copy, or rollback, but Rails must not implement automatic R2 read fallback.
7. A local-only migration runbook must be supported by ignoring `/docs/` in git and writing a non-committed `docs/bunny-storage-migration.md` during implementation with the Bunny setup, `rclone` copy, deploy, and verification checklist.
8. Generated data artifacts are out of this item except that the storage configuration must not preclude future Bunny-backed artifacts; no PMTiles, OTA SQLite publishing, signed manifest generation, MapLibre migration, or speculative artifact folders/prefixes are implemented here.
9. Automated verification must prove the repository configuration loads and no Cloudflare R2 endpoint or committed R2 credentials remain in the active storage/deploy configuration paths changed by this item.
10. Manual deployment verification must cover upload, download, Active Storage variant serving, and database backup creation against Bunny Storage before R2 credentials are removed operationally.

## In scope / Out of scope
**In scope:**
- Updating `config/storage.yml` to define a Bunny S3-compatible service for production Active Storage.
- Updating `config/environments/production.rb` to use the Bunny service name.
- Updating `config/deploy.yml` backup environment values/secrets to target the Bunny backup zone.
- Removing committed R2 read-only fallback credentials from `config/initializers/active_storage.rb`.
- Adding `/docs/` to `.gitignore` so a local-only migration runbook can exist without being pushed.
- Creating a local `docs/bunny-storage-migration.md` runbook during implementation; it must not be committed.
- Defining automated and manual verification for the migration.

**Out of scope:**
- Creating Bunny Storage zones in code — reason: zones are account infrastructure created manually in Bunny.
- Committing Bunny credentials, endpoint secrets, or migration object listings — reason: secrets and operational data must not enter the repository or `.incant/`.
- Implementing PMTiles generation or publishing — reason: future MapLibre/offline-map work is a separate product/data-pipeline item.
- Implementing OTA SQLite export publishing or signed manifests — reason: future mobile update semantics are not yet defined.
- Creating speculative Bunny folders/prefixes for future artifacts — reason: exact future requirements are unknown.
- Moving assets/uploads/generated artifacts behind Bunny CDN — reason: CDN rollout is tracked separately by backlog item `0002`.
- Adding automatic Rails fallback reads from R2 — reason: it would keep Cloudflare coupled to runtime and hide migration misses.

## Approach
Use Bunny Storage through Rails' existing S3-compatible Active Storage adapter and the existing S3-compatible backup container, but replace Cloudflare-specific literals and committed fallback credentials with environment/Kamal-secret driven configuration.

The intended production shape is:

- one Bunny Storage zone for Rails Active Storage uploads;
- one Bunny Storage zone for PostgreSQL backups;
- separate credentials for each zone where Bunny allows it;
- R2 retained only as a short-lived operational read-only source for manual re-copy or rollback after the first Bunny deploy.

A local runbook will document the one-time operational sequence: create Bunny zones, create S3-compatible keys, configure local `rclone` remotes, copy objects from R2 to Bunny, deploy, verify uploads/downloads/variants/backups, keep R2 read-only briefly, then remove R2 credentials after validation. The runbook belongs under ignored `/docs/` so it can include local command details without being pushed.

Rejected alternatives:

- Keep the service named `amazon`: rejected because a Bunny-specific service name in `config/storage.yml` and `config/environments/production.rb` makes production intent clear and avoids carrying Cloudflare-era semantics.
- Add automatic R2 fallback in Rails: rejected because it adds runtime complexity, requires R2 credentials to remain available to the app, and can mask incomplete object copies.
- Implement future artifact storage now: rejected because PMTiles, OTA SQLite publishing, manifests, and MapLibre assets need their own requirements and should not be guessed in a storage-vendor migration.

## Considerations

### Config vs code
Bunny values are configuration, not application logic. `config/storage.yml` should load the Active Storage endpoint, region, bucket/zone name, access key, and secret key from environment variables and Rails credentials only if already appropriate for the deployment pattern. `config/deploy.yml` should pass non-secret names as clear env values only when they are not sensitive, and should list credentials under Kamal `secret`. No provider endpoint, bucket name, access key, or secret key should be embedded in model/controller/service code.

### Security
Storage credentials must never be committed to the repository, `.incant/`, or session artifacts. The existing committed R2 fallback constants in `config/initializers/active_storage.rb` must be removed. Blast radius is reduced by using separate Bunny zones and credentials for app uploads and backups. User-uploaded files remain served through the existing Active Storage proxy/CDN URL pattern; this item does not add new public direct object URLs or broaden authorization. The R2 fallback window is operational only, so Cloudflare credentials are not kept in the Rails runtime after migration.

### Testability
Automated checks should run without live Bunny credentials and verify that Rails configuration can load, storage configuration parses, and the changed files no longer contain active R2 endpoint/credential fallbacks. The plan should include the exact commands available in this Rails app, expected to include `bin/rails test` plus targeted grep/config checks. Live Bunny behavior is manually verified during deployment using the local runbook: upload a file, download/render an existing attachment, process and serve an Active Storage variant, run or observe a database backup, and confirm the resulting objects exist in the correct Bunny zones.

### Code documentation
This item primarily changes configuration and an initializer, so inline documentation should be limited to concise comments where they clarify non-obvious Bunny S3 compatibility requirements or fallback-window behavior. The local runbook should document operational steps and why they exist. No JavaScript files are expected to be touched, so JSDoc requirements do not apply.

## Acceptance criteria
- [ ] Production Active Storage configuration points at a Bunny S3-compatible service and does not contain the Cloudflare R2 endpoint.
- [ ] Production database backup configuration points at the Bunny backup zone and does not contain the Cloudflare R2 endpoint.
- [ ] Rails uploads and backups are configured for separate Bunny zones/buckets and separate credential sets.
- [ ] `config/initializers/active_storage.rb` no longer contains committed R2 access key or secret fallback constants.
- [ ] Bunny credentials are read from environment/Kamal secrets and no new credentials are committed.
- [ ] `/docs/` is gitignored and a local, uncommitted `docs/bunny-storage-migration.md` runbook exists after implementation.
- [ ] Automated checks pass locally without Bunny credentials.
- [ ] Manual deploy checklist verifies Bunny upload, download, variant serving, and backup creation.
- [ ] R2 remains only an operational read-only fallback after deploy; Rails has no automatic R2 fallback path.

## Risks & open questions
- Bunny S3 compatibility details may require endpoint, region, or path-style settings that differ from Cloudflare R2; final values must come from Bunny Trail documentation/account settings during implementation.
- The backup container may have provider-specific behavior around endpoint or region values; this must be verified with a live backup during deployment.
- Existing object copy completeness is operationally critical; the runbook must include a repeatable copy and verification step before R2 credentials are removed.
