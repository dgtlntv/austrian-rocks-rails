---
id: "0011"
slug: self-host-inter-glyphs-for-shared-map-styles
stage: archived
completed: 2026-06-11
commit: 30edca3a33753b9cd41e4d265f2c02d3562723f7
---

# Self-host Inter glyphs for shared map styles — summary

## What was built
- Shared light and dark MapLibre style templates now use self-hosted Inter glyphs at `https://tiles.austrian.rocks/map_styles/fonts/inter-v1/{fontstack}/{range}.pbf`.
- All committed and materialized shared style `text-font` stacks are constrained to the approved Inter stacks, and the web-only dynamic contribution text layer now uses `Inter Regular`.
- `config/map_tiles.yml` exposes the `fonts/inter-v1` glyph subpath, with configuration helpers deriving the local glyph root, Bunny object prefix, and public MapLibre glyph template.
- The committed runtime glyph PBF tree lives under `config/map_styles/fonts/inter-v1/` with README/license provenance, approved-stack documentation, and no Inter source font binaries.
- `MapTiles::FontPublisher`, `bin/build_pmtiles publish-fonts`, and `map_tiles:publish_fonts` provide a dedicated idempotent Bunny/CDN upload path with safe object keys, PBF headers, immutable cache control, and credential-safe errors.
- Normal PMTiles/style/sprite/manifest publishing remains separate and is tested not to upload `/fonts/` objects.
- Tests and final review gates enforce the absence of Bergwerk glyph URLs, Mapbox glyph URLs, and Roboto font stacks in shared style artifacts.

## Deviations from spec
- None for the implementation. Actual production font publishing and representative CDN URL verification are rollout operations, so they were captured as a follow-up rather than performed during this code item.

## Key decisions
- Keep glyph assets versioned as `fonts/inter-v1` under the existing `map_styles` CDN prefix so current CDN routing/cache behaviour can be reused.
- Treat generated PBF glyphs as committed runtime assets and avoid committing `.ttf`, `.otf`, `.woff`, or `.woff2` source font binaries.
- Publish fonts through a separate developer/operator command instead of coupling them to every map release or exposing them in the admin exports UI.
- Preserve immutable `inter-v1` objects; future font updates should introduce a new configured subpath such as `fonts/inter-v2`.

## Links
- Final feature commit: `30edca3a33753b9cd41e4d265f2c02d3562723f7` (`incant 0011-P4: document font publish separation`).
- Earlier phase commits: `7012d886` (`incant 0011-P1: derive Inter map glyph styles`), `59fa681a` (`incant 0011-P2: add Inter glyph assets`), `6bb6c82a` (`incant 0011-P3: add font glyph publisher`).
- Plan commit: `3d3c1f8a` (`incant 0011: plan`).
- Spec commit: `73d3705d` (`incant 0011: spec`).
- Review verdict: ready to release; no blocker, major, minor, or nit findings.
- PR: not opened by incant.

## Sessions
- `019eb6a7-2b41-747e-b1ba-cf9038b28804`
- `019eb717-484c-7fe0-8dd0-dd58bf6ebdee`
- `019eb71f-9bfa-7a44-bf83-ca451ad557b4`
- `019eb726-cacf-74a1-bcc2-2474d202ba78`
- `019eb72a-024c-7c82-913d-de4517c9d889`
- `019eb72d-ac64-7abb-8b63-0442da641efb`
- `019eb730-2d0b-741d-873e-ce843aa485da`
- `019eb735-6507-72d3-8639-890a5a5c3202`
- `019eb738-b0f8-72de-9859-6aeea27d01a1`
- `019eb73c-2307-7985-a078-000a14431a10`
- `019eb73f-f047-7a0c-bc0b-7746d00ffa4d`

## Follow-ups
- Captured to `.incant/inbox.md`: Publish the self-hosted Inter v1 glyph PBF tree to Bunny/CDN with `bin/build_pmtiles publish-fonts` (or `bin/rails map_tiles:publish_fonts`) and verify representative URLs such as `https://tiles.austrian.rocks/map_styles/fonts/inter-v1/Inter%20Regular/0-255.pbf` before serving the updated shared styles in production.
