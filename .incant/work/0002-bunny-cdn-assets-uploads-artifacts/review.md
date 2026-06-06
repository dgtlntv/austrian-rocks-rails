---
id: "0002"
slug: bunny-cdn-assets-uploads-artifacts
stage: review
reviewed: 2026-06-06
commit: c57e2c9f594dd708e7b4b6544f0c1244f5147df2
---

# Bunny Cdn Assets Uploads Artifacts — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

### Strengths
- `config/environments/production.rb:23` keeps the CDN hostname single-sourced from `BRAND_CONFIG[:domains][:assets]` while making the production asset host explicitly HTTPS, satisfying the core configuration requirement without scattering host strings.
- `config/routes.rb:137-144` preserves the existing Rails proxy architecture and correctly splits an explicit `https://...` asset host into `host` plus `protocol` route options, so blob and representation helpers generate fully qualified HTTPS CDN URLs instead of treating the scheme as part of the host.
- `test/helpers/cdn_url_generation_test.rb:39-64` covers static asset, blob proxy, variant proxy, and local/test path generation behavior without touching Bunny network credentials; the fresh P1 quality gate passed in Docker: 4 runs, 4 assertions, 0 failures.

### Blocker
- None.

### Major
- `.incant/work/0002-bunny-cdn-assets-uploads-artifacts/plan.md:60-79` / `.incant/work/0002-bunny-cdn-assets-uploads-artifacts/spec.md:77-79` — Phase `0002-P2` is not implemented: `test/controllers/proxy_controller_test.rb` is absent, `/proxy/topos/:id` success/404 cacheability is unverified, and `docs/bunny-cdn-checklist.md` has not been created under ignored `/docs/`. These are planned tasks and acceptance criteria for the work item, so the item is not release-ready until P2 is completed. status: open
- `.incant/work/0002-bunny-cdn-assets-uploads-artifacts/plan.md:81` / `.incant/work/0002-bunny-cdn-assets-uploads-artifacts/spec.md:81` — the release quality gate has not been completed: only the P1 helper test was freshly run in this review, while the new proxy-controller test, ignored-checklist verification, and full `bin/rails test` gate are still pending. The final acceptance criterion requires the full Rails suite to pass before release. status: open

### Minor
- None.

### Nit
- None.

### Verdict
Ready to release? **No** — Phase `0002-P1` looks sound and its focused quality gate passes, but open major findings remain because the planned P2 topo proxy/checklist work and final full-suite gate are still missing.
