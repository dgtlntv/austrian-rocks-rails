---
id: "0002"
slug: bunny-cdn-assets-uploads-artifacts
branch: incant/0002-bunny-cdn-assets-uploads-artifacts
title: Put Rails assets and Active Storage uploads behind Bunny CDN
stage: implement
status: in-progress
created: 2026-06-06
commit: f7ca585f
updated: 2026-06-06
---

# Plan — Put Rails assets and Active Storage uploads behind Bunny CDN

## Status
- Work item: `0002` / `bunny-cdn-assets-uploads-artifacts`
- Stage: implement
- Branch: `incant/0002-bunny-cdn-assets-uploads-artifacts`
- Current phase: `0002-P1` complete; awaiting phase review
- Next step: run `/incant:review 0002`
- Blockers: none
- Verification evidence: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.invalid -e BUNNY_STORAGE_ACCESS_KEY_ID=dummy -e BUNNY_STORAGE_SECRET_ACCESS_KEY=dummy -e BUNNY_STORAGE_REGION=dummy -e BUNNY_STORAGE_BUCKET=dummy web bash -lc 'bin/rails test test/helpers/cdn_url_generation_test.rb'` passed: 4 runs, 4 assertions, 0 failures, 0 errors, 0 skips. Earlier local attempts failed on missing PostgreSQL/PostGIS; the temporary local `austrian-rocks-test` database was dropped and Homebrew PostgreSQL was stopped afterward.
- Key decisions:
  - Keep `BRAND_CONFIG[:domains][:assets]` as the single source for the CDN hostname and derive the production asset host as explicit HTTPS.
  - Keep Active Storage on Rails proxy routes; Bunny is configured operationally as a Pull Zone/custom hostname in the ignored local checklist.
  - Keep `/docs/` ignored and create the Bunny checklist locally so operational notes are not committed.
  - Do not introduce generated artifact paths, PMTiles, MapLibre styles, mobile OTA database publishing, manifests, purge credentials, or full-domain CDN Acceleration.
  - Spec staleness checked on 2026-06-06: the spec's `commit` was `8ca7b2fd`; current HEAD is `f7ca585f`, whose app-code delta is the committed spec artifact only, so the approved spec still matches the code read for planning.

## Files touched
- `config/environments/production.rb` — change production `config.asset_host` from the bare asset hostname to `https://#{BRAND_CONFIG[:domains][:assets]}` while leaving production Active Storage on `:bunny`.
- `config/routes.rb` — parse an explicit `https://...` asset host into separate route helper `host` and `protocol` options for Active Storage proxy URLs while preserving local/test route behavior.
- `test/helpers/cdn_url_generation_test.rb` — add production-style URL generation tests for Rails static assets, `cdn_image_url` blob proxy URLs, `cdn_image_url` variant proxy URLs, and test-environment local URL behavior without Bunny credentials.
- `test/controllers/proxy_controller_test.rb` — add integration coverage for `/proxy/topos/:id` success cacheability and missing-topo `404 Not Found` behavior.
- `docs/bunny-cdn-checklist.md` — create an ignored local operations checklist for Bunny Pull Zone/custom hostname setup, SSL, origin, scoped cache rules, out-of-scope domains/paths, and header-based verification.
- `.incant/backlog.md` — update work item `0002` from `status:spec` to `status:plan` after writing the plan.
- `.incant/STATE.md` — update the session orientation to show `0002` in planning.
- `.incant/work/0002-bunny-cdn-assets-uploads-artifacts/plan.md` — this approved implementation plan.
- `.incant/work/0002-bunny-cdn-assets-uploads-artifacts/sessions.json` — session links for this work item, including the current planning session.

## Phase 0002-P1 — Explicit HTTPS CDN URL generation
Goal: Production-style URL generation emits `https://assets.austrian.rocks` for Rails assets and Active Storage proxy URLs while local/test behavior stays credential-free.

- [x] Read `config/environments/production.rb`, `config/brand.rb`, `config/initializers/active_storage.rb`, `config/routes.rb`, `app/helpers/shared_helper.rb`, `config/storage.yml`, and `test/test_helper.rb` before editing.
- [x] In `config/environments/production.rb`, replace `config.asset_host = BRAND_CONFIG[:domains][:assets]` with `config.asset_host = "https://#{BRAND_CONFIG[:domains][:assets]}"`.
- [x] Keep `config.active_storage.service = :bunny` unchanged in `config/environments/production.rb`.
- [x] Keep `Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy` unchanged in `config/initializers/active_storage.rb`.
- [x] Keep the `direct :cdn_image` route in `config/routes.rb` on Rails proxy route helpers and keep its local-environment guard; parse explicit `https://...` asset hosts into separate `host` and `protocol` route options so production proxy URLs keep the HTTPS scheme.
- [x] Create `test/helpers/cdn_url_generation_test.rb` with `require "test_helper"` and a `CdnUrlGenerationTest < ActionView::TestCase` class that includes `SharedHelper` and `Rails.application.routes.url_helpers`.
- [x] In `test/helpers/cdn_url_generation_test.rb`, add setup that stores `@original_asset_host = Rails.application.config.asset_host`, sets `Rails.application.config.asset_host = "https://assets.austrian.rocks"`, builds an in-memory PNG upload with `StringIO.new(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="))`, and attaches it to a saved `Region.create!(name: "CDN test", slug: "cdn-test-#{SecureRandom.hex(4)}", published: true)` as `cover` with filename `cdn-test.png` and content type `image/png`.
- [x] In teardown of `test/helpers/cdn_url_generation_test.rb`, purge `@region.cover` if attached, destroy `@region` if persisted, and restore `Rails.application.config.asset_host = @original_asset_host`.
- [x] Add a static asset assertion in `test/helpers/cdn_url_generation_test.rb` that `asset_url("tailwind.css")` starts with `https://assets.austrian.rocks/` when `Rails.application.config.asset_host` is set to that explicit HTTPS value.
- [x] Add an Active Storage blob assertion in `test/helpers/cdn_url_generation_test.rb` that `cdn_image_url(@region.cover.blob)` starts with `https://assets.austrian.rocks/rails/active_storage/blobs/proxy/`.
- [x] Add an Active Storage variant assertion in `test/helpers/cdn_url_generation_test.rb` that `cdn_image_url(@region.cover.variant(:thumb))` starts with `https://assets.austrian.rocks/rails/active_storage/representations/proxy/`.
- [x] Add a local/test preservation assertion in `test/helpers/cdn_url_generation_test.rb` that temporarily sets `Rails.application.config.asset_host = "https://assets.austrian.rocks"`, calls `Rails.application.routes.url_helpers.rails_blob_path(@region.cover.blob, only_path: true)`, and verifies the result starts with `/rails/active_storage/blobs/`, proving the test storage service can generate local paths without Bunny credentials or network access.
- [x] Ensure `test/helpers/cdn_url_generation_test.rb` requires only test-local dependencies (`base64`, `stringio`, and `securerandom` if needed) and does not read `BUNNY_STORAGE_*` environment variables.

**Quality gate:** `bin/rails test test/helpers/cdn_url_generation_test.rb` → the new URL-generation tests pass without real Bunny credentials or Bunny network access.

## Phase 0002-P2 — Topo proxy coverage and local Bunny checklist
Goal: `/proxy/topos/:id` behavior is verified, the local Bunny Pull Zone checklist documents the required cache policy, and the full Rails test suite passes.

- [ ] Read `app/controllers/proxy_controller.rb`, `app/models/topo.rb`, `test/test_helper.rb`, `.gitignore`, and `config/routes.rb` before editing.
- [ ] Create `test/controllers/proxy_controller_test.rb` with `require "test_helper"` and a `ProxyControllerTest < ActionDispatch::IntegrationTest` class.
- [ ] In `test/controllers/proxy_controller_test.rb`, add setup that creates a published `Topo`, attaches the same explicit in-memory PNG fixture used by `test/helpers/cdn_url_generation_test.rb` to `topo.photo` with filename `topo-test.png` and content type `image/png`, and stores it in `@topo`.
- [ ] In teardown of `test/controllers/proxy_controller_test.rb`, purge `@topo.photo` if attached and destroy `@topo` if persisted.
- [ ] Add a `/proxy/topos/:id` success test in `test/controllers/proxy_controller_test.rb` that calls `get topo_proxy_path(@topo)`, asserts `:success`, asserts the response `Cache-Control` header includes `public`, and asserts the header includes either `max-age=` or `immutable` from `http_cache_forever public: true`.
- [ ] Add a missing-topo test in `test/controllers/proxy_controller_test.rb` that calls `get topo_proxy_path(Topo.maximum(:id).to_i + 1000)` and asserts `:not_found`.
- [ ] Confirm `.gitignore` already contains `/docs/`; do not change `.gitignore` unless `/docs/` is no longer ignored.
- [ ] Create `docs/bunny-cdn-checklist.md` locally with sections for prerequisites, Bunny Pull Zone creation, custom hostname `assets.austrian.rocks`, SSL enablement, DNS CNAME target, Rails origin target, cache rules, out-of-scope traffic, verification, and rollback/disable notes.
- [ ] In `docs/bunny-cdn-checklist.md`, specify that CDN delivery is through an explicit Pull Zone/custom hostname for `assets.austrian.rocks` and that Bunny DNS CDN Acceleration for `www.austrian.rocks` or `austrian.rocks` must not be enabled by this item.
- [ ] In `docs/bunny-cdn-checklist.md`, document cache rules for `/assets/*` as long-lived immutable public caching, `/rails/active_storage/blobs/proxy/*` as long-lived public caching, `/rails/active_storage/representations/proxy/*` as long-lived public caching, and `/proxy/topos/*` as public caching.
- [ ] In `docs/bunny-cdn-checklist.md`, state that `www.austrian.rocks`, `austrian.rocks`, `/admin/*`, contribution flows, signed-in/session-dependent Rails traffic, and all other dynamic app paths are out of scope and must not be cached by this item.
- [ ] In `docs/bunny-cdn-checklist.md`, state that generated artifact paths such as PMTiles, MapLibre styles, mobile OTA databases, manifests, and purge behavior are intentionally deferred and must not be invented or renamed by this item.
- [ ] In `docs/bunny-cdn-checklist.md`, add verification commands using representative production URLs for one fingerprinted `/assets/*` file, one `/rails/active_storage/blobs/proxy/*` URL, one `/rails/active_storage/representations/proxy/*` URL, and one `/proxy/topos/*` URL, with expected Bunny response headers including `cdn-pullzone` and `cdn-cache`.
- [ ] Run `git status --short --ignored docs` and confirm `docs/bunny-cdn-checklist.md` appears as ignored (`!! docs/bunny-cdn-checklist.md`) and is not staged or committed.
- [ ] Run the Phase 0002-P1 quality gate again after the controller tests and checklist work.
- [ ] Run the new proxy controller test directly.
- [ ] Run the full Rails test suite.

**Quality gate:** `bin/rails test test/helpers/cdn_url_generation_test.rb && bin/rails test test/controllers/proxy_controller_test.rb && git status --short --ignored docs | grep '^!! docs/bunny-cdn-checklist.md$' && bin/rails test` → CDN URL tests pass, topo proxy tests pass, the Bunny checklist is ignored locally, and all Rails tests pass without real Bunny credentials or Bunny network access.

## Coverage self-review
- Requirement 1: Phase 0002-P1 updates `config/environments/production.rb` to derive `config.asset_host` as explicit `https://#{BRAND_CONFIG[:domains][:assets]}` and tests Rails static asset URLs.
- Requirement 2: Phase 0002-P1 keeps local/test Active Storage services unchanged in `config/storage.yml` and tests local/test path generation without Bunny credentials.
- Requirement 3: Phase 0002-P1 keeps the existing `cdn_image_url`/`cdn_image_tag` proxy route architecture and tests blob and variant proxy URL prefixes under the production asset host.
- Requirement 4: Phase 0002-P2 tests `/proxy/topos/:id` success cacheability and missing-ID `404 Not Found` behavior.
- Requirement 5: Phase 0002-P2 creates ignored `docs/bunny-cdn-checklist.md` under the already ignored `/docs/` directory.
- Requirement 6: Phase 0002-P2 documents required Bunny cache rules for `/assets/*`, `/rails/active_storage/blobs/proxy/*`, `/rails/active_storage/representations/proxy/*`, and `/proxy/topos/*`.
- Requirement 7: Phase 0002-P2 documents that main app domains, admin paths, contribution flows, and session-dependent Rails traffic are out of CDN scope and must not be cached.
- Requirement 8: Phase 0002-P2 documents that Bunny DNS CDN Acceleration for the full app domains must not be enabled; both phases avoid full-domain CDN config.
- Requirement 9: Both phases avoid future generated artifact paths, PMTiles, MapLibre style hosting, mobile OTA publish behavior, manifests, purge credentials, and related renames.
- Requirement 10: Phase 0002-P1 and Phase 0002-P2 add automated tests for production-style Rails asset and Active Storage proxy URL generation without Bunny network access.
- Acceptance criterion `bin/rails test` passes: Phase 0002-P2 includes the full Rails test suite in its quality gate.

No placeholders remain in this plan; all file paths, phase IDs, test class names, helper names, route names, checklist path, and quality-gate commands are explicit.

## Human approval checkpoint
This plan must be approved by the human before implementation starts. After approval, run `/incant:implement 0002`.
