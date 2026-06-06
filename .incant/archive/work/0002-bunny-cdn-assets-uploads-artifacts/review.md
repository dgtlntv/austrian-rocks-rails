---
id: "0002"
slug: bunny-cdn-assets-uploads-artifacts
stage: review
reviewed: 2026-06-06
commit: 7608d510d80e839413bc99d53d342cf0a2d4705a
---

# Bunny Cdn Assets Uploads Artifacts — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

### Strengths
- `config/environments/production.rb:23` keeps the CDN hostname single-sourced from `BRAND_CONFIG[:domains][:assets]` while making the production asset host explicitly HTTPS, satisfying the core production URL requirement without scattering the asset domain through application logic.
- `config/routes.rb:135-145` preserves the existing Rails proxy architecture for `cdn_image` and correctly splits explicit `https://...` asset hosts into `host` plus `protocol`, so Active Storage blob and representation proxy helpers generate CDN URLs with the intended scheme and host.
- `test/helpers/cdn_url_generation_test.rb:39-64` covers production-style Rails static asset, Active Storage blob proxy, Active Storage representation proxy, and local/test path generation without real Bunny network access or credentials.
- `test/controllers/proxy_controller_test.rb:26-40` now verifies both required `/proxy/topos/:id` behaviours: public cacheable success for an existing topo with a photo, and `404 Not Found` for a missing topo ID.
- `docs/bunny-cdn-checklist.md:10-53` documents the manual Bunny Pull Zone/custom hostname setup, SSL/DNS/origin requirements, scoped cache rules, out-of-scope app traffic, generated-artifact deferral, header-based verification, and rollback notes while remaining ignored by git.
- Fresh review gate passed in Docker: helper tests 4 runs/4 assertions/0 failures; proxy tests 2 runs/6 assertions/0 failures; ignored checklist path verified; full `bin/rails test` 7 runs/11 assertions/0 failures.

### Blocker
- None.

### Major
- `.incant/work/0002-bunny-cdn-assets-uploads-artifacts/plan.md:60-79` / `.incant/work/0002-bunny-cdn-assets-uploads-artifacts/spec.md:77-79` — prior finding addressed: Phase `0002-P2` is now implemented via `test/controllers/proxy_controller_test.rb` and the ignored `docs/bunny-cdn-checklist.md`, covering the planned topo proxy tests and local Bunny checklist acceptance criteria. status: addressed
- `.incant/work/0002-bunny-cdn-assets-uploads-artifacts/plan.md:81` / `.incant/work/0002-bunny-cdn-assets-uploads-artifacts/spec.md:81` — prior finding addressed: the full release quality gate was rerun freshly in this review and passed, including helper tests, proxy controller tests, ignored-checklist verification, and the full Rails test suite. status: addressed

### Minor
- None.

### Nit
- None.

### Verdict
Ready to release? **Yes** — the implementation meets the spec acceptance criteria, honours the active configuration/security/testability/documentation principles, and has no open blocker or major findings.
