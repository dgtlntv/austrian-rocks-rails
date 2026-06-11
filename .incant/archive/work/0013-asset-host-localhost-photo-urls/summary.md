---
id: "0013"
slug: asset-host-localhost-photo-urls
stage: archived
completed: 2026-06-11
commit: e64cf0ac94cf072a407989bcc672d82042fa3bb0
---

# Asset Host Localhost Photo Urls — summary

## What was built
- `MapTiles::GeojsonExporter` no longer falls back to `http://localhost:3000` when generating Active Storage photo URLs for map tile GeoJSON/PMTiles exports.
- Exported `coverPhotoUrl` and `topoPhotoUrl` values now require `Rails.application.config.asset_host` when an attached photo URL is actually needed.
- Blank-host exports with attached cover/topo photos raise `MapTiles::GeojsonExporter::MissingAssetHostError` with a clear configuration message.
- Records without attached cover/topo photos still export successfully without requiring `asset_host`.
- GeoJSON exporter tests now cover configured-host success, blank-host failure, no-photo blank-host success, deterministic proxy URL behavior, and absence of localhost URLs.

## Deviations from spec
- None. The implementation kept Rails `config.asset_host` as the sole host source and preserved `cdn_image_url(..., expires_in: nil, host: ...)` behavior as specified.

## Key decisions
- Fail loudly only when a photo URL is needed, rather than requiring `asset_host` for every export invocation.
- Keep Active Storage proxy URL generation on the existing Rails route helper instead of introducing a separate map tile CDN host setting.
- Capture remediation of already-published artifacts as a follow-up instead of expanding this preventive code fix.

## Links
- Implementation commit: `e64cf0ac94cf072a407989bcc672d82042fa3bb0` (`incant 0013-P1: require asset host for photo URLs`)
- Plan commit: `1ce6bdc1` (`incant 0013: plan`)
- Spec commit: `85e91621` (`incant 0013: spec`)
- PR: not opened by incant.

## Sessions
- `019eb64d-9d57-782f-99ca-c47cea36a2ea`
- `019eb658-c570-7b08-9382-0807fe6ed8d8`
- `019eb67b-7abc-7d67-8ad8-75939a8d6ae8`
- `019eb698-e604-70e7-b2e9-cc1b3dde6100`
- `019eb69c-3a26-7dcf-a098-a4f8692ef990`

## Follow-ups
- Captured to `.incant/inbox.md`: Audit and, if needed, regenerate/re-publish existing map tile PMTiles/GeoJSON artifacts that may already contain localhost Active Storage photo URLs from before item 0013.
