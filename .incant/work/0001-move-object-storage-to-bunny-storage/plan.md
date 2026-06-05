---
id: "0001"
slug: move-object-storage-to-bunny-storage
branch: incant/0001-move-object-storage-to-bunny-storage
title: Move Object Storage To Bunny Storage
stage: implement
status: phase-0001-P1-complete-awaiting-review
created: 2026-06-05
commit: 3c86d3c7
updated: 2026-06-05
---

# Plan — Move Object Storage To Bunny Storage

## Status
- Work item: `0001` / `move-object-storage-to-bunny-storage`
- Stage: implement
- Branch: `incant/0001-move-object-storage-to-bunny-storage`
- Current phase: `0001-P1` complete, awaiting review
- Next step: run `/incant:review 0001`
- Blockers: none
- Verification evidence:
  - 2026-06-05: Phase 0001-P1 gate passed with installed local Ruby 3.3.11 after temporarily changing `.ruby-version`, `Gemfile`, and `Gemfile.lock` to 3.3.11, then reverting them to 3.3.5. Rails storage verification used `ActiveStorage::Blob.services.instance_variable_get(:@configurations).fetch(:bunny)` because the originally planned `Rails.application.config_for(:storage).fetch(:bunny)` returns nil for Active Storage service configuration in this app.
- Key decisions:
  - Use a new production Active Storage service named `bunny`, not the old `amazon` service name.
  - Use separate environment variable and Kamal secret names for Rails uploads and backup storage credentials.
  - Keep any R2 fallback operational only; Rails configuration will not read from R2.
  - Create `docs/bunny-storage-migration.md` during implementation as a local ignored runbook and do not commit it.

## Files touched
- `config/storage.yml` — replace the Cloudflare R2-backed production S3 service with a Bunny S3-compatible Active Storage service driven by `BUNNY_STORAGE_*` environment variables.
- `config/environments/production.rb` — switch production Active Storage from `:amazon` to `:bunny`.
- `config/initializers/active_storage.rb` — remove committed R2 read-only credential constants while preserving proxy-route behavior.
- `config/deploy.yml` — expose Bunny upload environment variables/secrets to the Rails container and point the `db_backup` accessory at the Bunny backup zone with its own credential secret names.
- `.gitignore` — ignore `/docs/` so operational migration notes stay local.
- `docs/bunny-storage-migration.md` — create an ignored local runbook for Bunny setup, object copy, deploy, verification, R2 read-only fallback, and credential removal.
- `.incant/backlog.md` — update work item `0001` from `status:spec` to `status:plan` after writing the plan.
- `.incant/STATE.md` — update the session orientation to show `0001` in planning.
- `.incant/work/0001-move-object-storage-to-bunny-storage/plan.md` — this approved implementation plan.
- `.incant/work/0001-move-object-storage-to-bunny-storage/sessions.json` — session link created by `incant session link 0001`.

## Phase 0001-P1 — Bunny runtime configuration
Goal: Rails uploads and database backups are configured for Bunny Storage without committed R2 endpoints or fallback credentials.

- [x] Read `config/storage.yml`, `config/environments/production.rb`, `config/initializers/active_storage.rb`, and `config/deploy.yml` before editing.
- [x] In `config/storage.yml`, rename the production S3-compatible service from `amazon` to `bunny` and define it as:
  - `service: S3`
  - `endpoint: <%= ENV.fetch("BUNNY_STORAGE_ENDPOINT") %>`
  - `access_key_id: <%= ENV.fetch("BUNNY_STORAGE_ACCESS_KEY_ID") %>`
  - `secret_access_key: <%= ENV.fetch("BUNNY_STORAGE_SECRET_ACCESS_KEY") %>`
  - `region: <%= ENV.fetch("BUNNY_STORAGE_REGION") %>`
  - `bucket: <%= ENV.fetch("BUNNY_STORAGE_BUCKET") %>`
  - `force_path_style: true`
- [x] Remove the committed Cloudflare R2 endpoint, bucket, `auto` region comment, `S3_READONLY_KEY`, and `S3_READONLY_SECRET` references from `config/storage.yml`.
- [x] In `config/environments/production.rb`, change `config.active_storage.service = :amazon` to `config.active_storage.service = :bunny` and update the nearby comment to state that production uploads use the Bunny S3-compatible service from `config/storage.yml`.
- [x] In `config/initializers/active_storage.rb`, keep `Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy` and delete the `S3_READONLY_KEY` and `S3_READONLY_SECRET` constants plus their R2 fallback comment.
- [x] In `config/deploy.yml` under top-level `env.clear`, add non-secret Rails upload settings `BUNNY_STORAGE_ENDPOINT: <%= ENV.fetch("BUNNY_STORAGE_ENDPOINT") %>`, `BUNNY_STORAGE_REGION: <%= ENV.fetch("BUNNY_STORAGE_REGION") %>`, and `BUNNY_STORAGE_BUCKET: <%= ENV.fetch("BUNNY_STORAGE_BUCKET") %>`.
- [x] In `config/deploy.yml` under top-level `env.secret`, add `BUNNY_STORAGE_ACCESS_KEY_ID` and `BUNNY_STORAGE_SECRET_ACCESS_KEY` for Rails upload credentials.
- [x] In `config/deploy.yml` under `accessories.db_backup.env.clear`, replace the R2 values with backup image S3 variables fed by Bunny backup-zone deployment environment values: `S3_REGION: <%= ENV.fetch("BUNNY_BACKUP_REGION") %>`, `S3_BUCKET: <%= ENV.fetch("BUNNY_BACKUP_BUCKET") %>`, and `S3_ENDPOINT: <%= ENV.fetch("BUNNY_BACKUP_ENDPOINT") %>`; keep `S3_PREFIX: backups`.
- [x] In `config/deploy.yml` under `accessories.db_backup.env.secret`, keep the image-required `S3_ACCESS_KEY_ID` and `S3_SECRET_ACCESS_KEY` names and ensure the Kamal secrets with those names contain the backup-zone credentials, separate from the Rails `BUNNY_STORAGE_ACCESS_KEY_ID` and `BUNNY_STORAGE_SECRET_ACCESS_KEY` credentials.
- [x] Run a repository search and remove any Cloudflare R2 endpoint or committed `S3_READONLY_` credential fallback that remains in the changed runtime configuration files.

**Quality gate:** `BUNNY_STORAGE_ENDPOINT=https://example.bunnycdn.test BUNNY_STORAGE_ACCESS_KEY_ID=test-key BUNNY_STORAGE_SECRET_ACCESS_KEY=test-secret BUNNY_STORAGE_REGION=de BUNNY_STORAGE_BUCKET=test-zone bin/rails runner 'config = ActiveStorage::Blob.services.instance_variable_get(:@configurations).fetch(:bunny); config.fetch(:endpoint); config.fetch(:bucket)' && ! grep -R "cloudflarestorage.com\|S3_READONLY_KEY\|S3_READONLY_SECRET" config/storage.yml config/environments/production.rb config/initializers/active_storage.rb config/deploy.yml` → Rails loads the Bunny storage configuration with dummy local values and the changed runtime configuration files contain no R2 endpoint or committed R2 fallback credential names.

## Phase 0001-P2 — Local runbook and repository verification
Goal: The operational migration checklist exists locally, `/docs/` is ignored, and the full automated verification passes without live Bunny credentials.

- [ ] Read `.gitignore` before editing.
- [ ] Add `/docs/` to `.gitignore` under a clear comment such as `# Ignore local operational runbooks.`.
- [ ] Create `docs/bunny-storage-migration.md` locally with sections for prerequisites, Bunny upload zone setup, Bunny backup zone setup, S3-compatible key placement in Kamal secrets, `rclone` R2-to-Bunny copy commands, copy verification, deployment, upload/download/variant checks, database backup checks, R2 read-only fallback window, rollback by re-copy/redeploy, and final R2 credential removal.
- [ ] Ensure `docs/bunny-storage-migration.md` names the Rails upload credentials as `BUNNY_STORAGE_ACCESS_KEY_ID` and `BUNNY_STORAGE_SECRET_ACCESS_KEY` and the backup credentials according to the final `config/deploy.yml` backup secret names.
- [ ] Ensure `docs/bunny-storage-migration.md` explicitly states that R2 remains read-only outside Rails only during the fallback window and that Rails has no automatic R2 fallback path.
- [ ] Run `git status --short --ignored docs` and confirm `docs/bunny-storage-migration.md` is ignored and will not be committed.
- [ ] Run the Phase 0001-P1 quality gate again after the runbook and `.gitignore` changes.
- [ ] Run the full Rails test suite.

**Quality gate:** `BUNNY_STORAGE_ENDPOINT=https://example.bunnycdn.test BUNNY_STORAGE_ACCESS_KEY_ID=test-key BUNNY_STORAGE_SECRET_ACCESS_KEY=test-secret BUNNY_STORAGE_REGION=de BUNNY_STORAGE_BUCKET=test-zone bin/rails runner 'ActiveStorage::Blob.services.instance_variable_get(:@configurations).fetch(:bunny)' && ! grep -R "cloudflarestorage.com\|S3_READONLY_KEY\|S3_READONLY_SECRET" config/storage.yml config/environments/production.rb config/initializers/active_storage.rb config/deploy.yml && git status --short --ignored docs | grep '^!! docs/bunny-storage-migration.md$' && bin/rails test` → storage config loads without live Bunny credentials, R2 endpoint/fallback credential names are absent from changed runtime config files, the runbook is ignored, and all Rails tests pass.

## Coverage self-review
- Requirement 1: Phase 0001-P1 changes `config/storage.yml` to a `bunny` S3-compatible service and Phase 0001-P1 switches production to `:bunny`.
- Requirement 2: Phase 0001-P1 changes `accessories.db_backup` in `config/deploy.yml` to Bunny backup-zone values.
- Requirement 3: Phase 0001-P1 uses separate Rails upload `BUNNY_STORAGE_*` credentials and backup-zone credential names/secret mapping.
- Requirement 4: Phase 0001-P1 reads Bunny endpoint, region, bucket, access key, and secret key from environment/Kamal values.
- Requirement 5: Phase 0001-P1 removes `S3_READONLY_KEY` and `S3_READONLY_SECRET` constants from the Rails runtime.
- Requirement 6: Phase 0001-P1 removes Rails R2 fallback paths; Phase 0001-P2 documents R2 as operational read-only fallback only.
- Requirement 7: Phase 0001-P2 ignores `/docs/` and creates the local uncommitted migration runbook.
- Requirement 8: Both phases avoid PMTiles, OTA SQLite publishing, signed manifests, MapLibre changes, and speculative artifact folders.
- Requirement 9: Both phase gates load configuration and grep changed runtime paths for R2 endpoint/fallback credentials.
- Requirement 10: Phase 0001-P2 writes the manual deploy checklist for upload, download, variant serving, and database backup creation.

No placeholders remain in this plan; all file paths, phase IDs, environment variable names, and quality-gate commands are explicit.

## Human approval checkpoint
This plan must be approved by the human before implementation starts. After approval, run `/incant:implement 0001`.
