---
id: "0002"
slug: bunny-cdn-assets-uploads-artifacts
branch: incant/0002-bunny-cdn-assets-uploads-artifacts
title: Put Rails assets and Active Storage uploads behind Bunny CDN
stage: spec
status: in-progress
created: 2026-06-06
commit: 8ca7b2fd
updated: 2026-06-06
---

# Put Rails assets and Active Storage uploads behind Bunny CDN

## Goal
Production Rails static assets and public Active Storage upload/variant URLs are generated under `https://assets.austrian.rocks` and are verifiably served through Bunny CDN cacheable routes.

## Context & codebase fit
Production already points Rails asset generation at `BRAND_CONFIG[:domains][:assets]` in `config/environments/production.rb`, where `config/brand.rb` defines `assets.austrian.rocks`. Active Storage production storage is already configured as the Bunny S3-compatible `:bunny` service in `config/storage.yml`, with secrets passed through Kamal in `config/deploy.yml`.

The app already uses Rails proxy-style Active Storage CDN URLs. `config/initializers/active_storage.rb` sets `config.active_storage.resolve_model_to_route = :rails_storage_proxy`, and `config/routes.rb` defines `direct :cdn_image` so blobs and variants route through Rails proxy endpoints with `Rails.application.config.asset_host` outside local environments. Views and helpers use this path through `cdn_image_url` and `cdn_image_tag`, for example in `app/helpers/shared_helper.rb`, area/cluster/region cards, topo images, and Open Graph image metadata. `app/controllers/proxy_controller.rb` also exposes `/proxy/topos/:id` as a public, cacheable compatibility endpoint for topo images.

Generated data artifacts exist today as local/admin exports in `app/controllers/admin/exports_controller.rb`, `lib/tasks/app.rake`, and `lib/tasks/mapbox.rake`. Future work may introduce MapLibre, PMTiles, mobile OTA database updates, manifests, and final public artifact paths. Those future artifact paths and publish semantics are deliberately not decided in this item.

## Requirements
1. In production, Rails must generate static asset and Active Storage CDN URLs with the explicit HTTPS host `https://assets.austrian.rocks`, not a scheme-less host value.
2. Existing local and test Active Storage behavior must remain unchanged: local/test URLs and storage continue to use the existing local/test services and must not require Bunny credentials.
3. Existing public upload/variant call sites that use `cdn_image_url` or `cdn_image_tag` must continue generating Rails proxy URLs under the production asset host for blobs and variants.
4. `/proxy/topos/:id` must remain publicly cacheable for published topo images and continue returning `404 Not Found` for missing topo IDs.
5. A local, gitignored Bunny operations checklist must document the required manual Bunny setup for `assets.austrian.rocks`: explicit Pull Zone/custom hostname, SSL, origin target, route/cache rules, and verification steps. The checklist belongs under `/docs/`, which is intentionally ignored by git.
6. The required Bunny cache policy must cover at least these public paths: `/assets/*` with long immutable caching, `/rails/active_storage/blobs/proxy/*` with long public caching, `/rails/active_storage/representations/proxy/*` with long public caching, and `/proxy/topos/*` with public caching.
7. The Bunny checklist must state that `www.austrian.rocks`, `austrian.rocks`, admin paths, contribution flows, and session-dependent Rails traffic are out of this CDN scope and must not be cached by this item.
8. The implementation must not enable Bunny DNS CDN Acceleration for the full app domain as part of this work; CDN delivery is through an explicit Bunny Pull Zone/custom hostname for `assets.austrian.rocks`.
9. The implementation must not design, rename, publish, or purge future generated artifact paths such as PMTiles, MapLibre styles, mobile OTA databases, or manifests.
10. Automated tests must verify production URL generation for Rails assets and Active Storage proxy helpers without needing real Bunny network access.

## In scope / Out of scope
**In scope:**
- Production Rails configuration that makes the CDN asset host explicitly HTTPS.
- Verification that compiled Rails asset URLs and Active Storage proxy URLs use `https://assets.austrian.rocks` in production-style URL generation.
- Preservation of the current Rails-proxy CDN architecture for Active Storage blobs, variants, and `/proxy/topos/:id`.
- A local `/docs/` Bunny setup checklist for manual Pull Zone/cache-rule verification.
- Tests that exercise URL-generation behavior and the public topo proxy edge cases without contacting Bunny.

**Out of scope:**
- Bunny account provisioning automation — reason: this item uses manual Bunny dashboard setup documented in a checklist rather than introducing infrastructure automation.
- Bunny DNS CDN Acceleration for `www.austrian.rocks` or `austrian.rocks` — reason: whole-app acceleration needs separate cache-bypass design and testing for dynamic/session/admin paths.
- Direct-from-Bunny-Storage public object URLs for uploads — reason: the current app uses Rails proxy URLs, and this item prioritizes safe cacheable proxy delivery before optimizing cache-miss latency.
- Generated artifact public paths, PMTiles, MapLibre styles, mobile OTA database updates, manifests, and purge pipeline credentials — reason: those are future features and should be specified when their data model and publish flow are ready.
- Migrating existing uploaded objects or regenerating all variants — reason: storage is already Bunny-backed in production and variant warming/migration is a separate operational concern.
- Bot/scraper rate limiting — reason: no concrete abuse requirement is part of this item; add a separate item if Bunny logs show a need.

## Approach
Keep the current Rails-proxy CDN architecture. Rails remains the origin for Active Storage proxy and variant responses on cache miss, while Bunny serves repeated requests from edge cache for the explicitly cacheable public paths. This avoids exposing or depending on Active Storage object-key semantics and preserves Rails variant processing.

Update production asset-host configuration so the configured host is explicitly `https://assets.austrian.rocks`, preferably derived from `BRAND_CONFIG[:domains][:assets]` to keep the brand domain single-sourced. Add tests around production-style URL generation for Rails static assets and `cdn_image_url`/Active Storage proxy routes. Add a local `/docs/` checklist that records the manual Bunny Pull Zone/custom hostname setup, expected cache rules, and header-based verification using `cdn-pullzone`, `cdn-cache`, and related Bunny response headers.

Rejected alternatives: enabling Bunny DNS CDN Acceleration for the main app domain is rejected because it risks caching dynamic Rails traffic without a dedicated bypass spec. Direct CDN origin to Bunny Storage is rejected for this item because it is a larger change and does not handle Rails-generated variants as cleanly as the existing proxy architecture.

## Considerations
### Config vs code
The CDN hostname remains configuration, not scattered code. `config/brand.rb` continues to own `BRAND_CONFIG[:domains][:assets]`, and `config/environments/production.rb` should derive the explicit HTTPS `config.asset_host` from that value. Bunny storage credentials remain in environment variables referenced by `config/storage.yml` and Kamal secrets in `config/deploy.yml`. Cache-rule values and Pull Zone choices are operational configuration documented in `/docs/`, not hardcoded into request logic.

### Security
Bunny storage credentials are secrets and must stay in environment/Kamal secret handling; they must not be committed to `.incant/`, `/docs/`, or tests. The public CDN trust boundary is limited to intentionally public media and fingerprinted assets under `assets.austrian.rocks`. Rails remains responsible for signed Active Storage proxy URLs and variant generation, avoiding direct exposure of storage object paths. Admin pages, contribution flows, sessions, and the main app hosts must not be accelerated or cached by this item, limiting blast radius if a Bunny cache rule is misconfigured. URL generation must not accept untrusted host input; it uses trusted application configuration.

### Testability
Automated tests should cover URL generation and proxy behavior without real Bunny access. Suitable commands are `bin/rails test` for the Rails test suite, with narrower controller/helper tests acceptable during implementation. Tests should assert that production-style asset and Active Storage helper URLs include `https://assets.austrian.rocks`, that local/test storage behavior still works without Bunny credentials, and that `/proxy/topos/:id` keeps its expected success and not-found behavior. Bunny dashboard setup is verified manually by requesting representative asset, Active Storage blob/variant, and `/proxy/topos/:id` URLs and checking for Bunny headers such as `cdn-pullzone` and `cdn-cache`.

### Code documentation
Inline documentation should stay light. If production CDN configuration receives non-obvious comments, they should explain why the asset host is explicit HTTPS and why Active Storage stays on Rails proxy URLs for CDN caching. The `/docs/` checklist should document the operational Bunny settings and verification steps. No JavaScript or TypeScript source is expected to change.

## Acceptance criteria
- [ ] In production-style URL generation, a Rails static asset URL starts with `https://assets.austrian.rocks/`.
- [ ] In production-style URL generation, an Active Storage blob proxy URL starts with `https://assets.austrian.rocks/rails/active_storage/blobs/proxy/`.
- [ ] In production-style URL generation, an Active Storage variant proxy URL starts with `https://assets.austrian.rocks/rails/active_storage/representations/proxy/`.
- [ ] `/proxy/topos/:id` still returns a public cacheable response for an existing topo with a photo and `404 Not Found` for a missing topo.
- [ ] Development and test environments do not require Bunny credentials to boot or run the relevant tests.
- [ ] A local `/docs/` Bunny checklist exists with Pull Zone/custom hostname setup, SSL, cache rules for `/assets/*`, `/rails/active_storage/blobs/proxy/*`, `/rails/active_storage/representations/proxy/*`, and `/proxy/topos/*`, and header-based verification steps.
- [ ] The implementation does not add generated artifact public paths, PMTiles, MapLibre style hosting, mobile OTA publish behavior, manifest purging, or full-domain CDN Acceleration.
- [ ] `bin/rails test` passes.

## Risks & open questions
- Bunny cache HIT rates depend on correct dashboard cache rules and real traffic patterns; this item can verify headers and URL generation but cannot guarantee long-term hit ratio without production monitoring.
- Rails proxy cache MISS requests still pass through Rails and Bunny Storage. If logs show unacceptable MISS latency or Rails load, a later item should evaluate direct Bunny Storage delivery for originals and a variant publishing strategy.
- No material open questions remain for this spec; generated artifact CDN publishing is intentionally deferred to future work.
