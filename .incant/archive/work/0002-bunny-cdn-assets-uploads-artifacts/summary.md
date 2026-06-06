---
id: "0002"
slug: bunny-cdn-assets-uploads-artifacts
stage: archived
completed: 2026-06-06
commit: 7608d510d80e839413bc99d53d342cf0a2d4705a
---

# Summary — Put Rails assets and Active Storage uploads behind Bunny CDN

## What was built
- Production Rails asset URLs now use the explicit HTTPS host `https://assets.austrian.rocks`, derived from `BRAND_CONFIG[:domains][:assets]`.
- Active Storage blob and variant helper URLs keep the existing Rails proxy architecture while generating production-style CDN URLs under `assets.austrian.rocks`.
- `/proxy/topos/:id` has automated coverage for public cacheable success and missing-topo `404 Not Found` behavior.
- A local ignored `docs/bunny-cdn-checklist.md` documents Bunny Pull Zone/custom hostname setup, SSL/DNS/origin requirements, scoped cache rules, verification headers, out-of-scope traffic, generated-artifact deferral, and rollback notes.

## Deviations from spec
- None. Generated artifact paths, PMTiles/MapLibre/mobile OTA publishing, purge behavior, and full-domain CDN Acceleration remain intentionally out of scope.

## Key decisions
- Keep the CDN hostname single-sourced in `BRAND_CONFIG[:domains][:assets]` and derive an explicit HTTPS `config.asset_host` in production.
- Keep Active Storage on Rails proxy URLs so Bunny can cache public proxy responses without exposing direct storage object paths.
- Keep Bunny dashboard/cache-rule details in a gitignored local checklist under `/docs/`, not committed application configuration.

## Links
- Final commit: `7608d510d80e839413bc99d53d342cf0a2d4705a`
- Feature branch: `incant/0002-bunny-cdn-assets-uploads-artifacts`
- Review verdict: ready to release; no open blocker or major findings.

## Sessions
- `019e9ccb-3e1f-7f4e-aeca-dcc76ed5ae86`
- `019e9cde-4f56-7b95-bd48-51b317c8eda2`
- `019e9d31-341c-7882-b0fd-643fba17ce18`
- `019e9d44-6390-7733-a8b3-41fe6b6c6557`
- `019e9d46-87f2-7ce2-98b8-d5f321ff9209`
- `019e9d50-ac2b-7dc5-83bc-e02f1457b605`
- `019e9d5f-808f-7eca-86d8-8e3b991bafc1`

## Follow-ups
- None.
