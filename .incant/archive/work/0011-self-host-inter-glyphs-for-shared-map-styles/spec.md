---
id: "0011"
slug: self-host-inter-glyphs-for-shared-map-styles
branch: incant/0011-self-host-inter-glyphs-for-shared-map-styles
title: Self-host Inter glyphs for shared map styles
stage: spec
status: in-progress
created: 2026-06-11
commit: 581501fe
updated: 2026-06-11
---

# Self-host Inter glyphs for shared map styles

## Goal
Ship the shared Austrian Rocks MapLibre styles with self-hosted Inter glyph PBFs under the existing `map_styles` CDN prefix, with no Bergwerk font URL or Roboto font stack required for map labels.

## Context & codebase fit
The shared MapLibre style templates live in `config/map_styles/austrian_rocks_light.json` and `config/map_styles/austrian_rocks_dark.json`. They currently declare `glyphs` as `https://basemap.bergwerk-gis.at/basemap-download/webapp/fonts/{fontstack}/{range}.pbf` and use Roboto font stacks across both upstream basemap/contour label layers and Austrian Rocks overlay label layers. The web-only dynamic contribution layer in `app/javascript/controllers/map_controller.js` also uses `Roboto-Regular` for its text labels.

Map release publication is handled by `MapTiles::BunnyPublisher`, which materializes versioned style JSON via `MapTiles::StyleMaterializer`, builds sprites via `MapTiles::SpriteBuilder`, writes a non-cached release manifest via `MapTiles::ReleaseManifest`, uploads immutable artifacts to Bunny/CDN, HEAD-verifies public URLs, and only then moves the manifest pointer. Sprites already publish under `config/map_tiles.yml`'s existing `style_prefix` (`map_styles`), so font glyphs can reuse the same CDN edge rules without introducing a new top-level prefix.

The Inter glyph PBFs are static font assets, not per-map-release artifacts. They should be published separately from the normal PMTiles/style/sprite release flow while committed in the repository as the runtime PBF form consumed by MapLibre. PMTiles archives themselves do not contain fonts; their labels are rendered by the shared style's `text-font` declarations, so all Austrian Rocks overlay label layers must be converted to Inter as part of the style change.

The user has already generated a full Inter glyph output tree at `tmp/font-maker-2026-06-11T14_25_38.391Z/`. It contains more font stacks than this item needs; implementation should copy only the approved runtime stacks into `config/map_styles/fonts/inter-v1/` and leave the rest of the generated output ignored in `tmp/`.

## Requirements
1. The committed light and dark style templates must set `glyphs` to `https://tiles.austrian.rocks/map_styles/fonts/inter-v1/{fontstack}/{range}.pbf` and must not contain `basemap.bergwerk-gis.at/basemap-download/webapp/fonts`.
2. Every `layout.text-font` value in the committed light and dark style templates must reference only these Inter font stacks: `Inter Light`, `Inter Regular`, `Inter Medium`, `Inter Bold`, `Inter Medium Italic`, and `Inter Bold Italic`.
3. The Austrian Rocks PMTiles overlay label layers in the committed shared styles must use Inter font stacks, including `regions`, `clusters`, `areas`, `boulders-texts`, and any other `austrian-rocks` symbol layer with a `text-font` layout.
4. The web-only dynamic contribution text layer in `app/javascript/controllers/map_controller.js` must use an Inter font stack instead of `Roboto-Regular`.
5. The repository must contain the runtime Inter glyph PBF tree under `config/map_styles/fonts/inter-v1/`, including the PBF directories needed by all Inter font stacks named in the styles and documentation that records source/provenance and license information.
6. The repository must not commit Inter source font binaries (`.ttf`, `.otf`, `.woff`, `.woff2`) for this work; the committed runtime glyph PBFs are the source of truth for the deployed map glyph assets.
7. `config/map_tiles.yml` must expose the font glyph subpath/version (default `fonts/inter-v1`) so code derives the public glyph URL from `public_cdn_host`, `style_prefix`, and that configured subpath instead of scattering the value through publisher logic.
8. A separate idempotent publish path must upload the committed `config/map_styles/fonts/inter-v1/` tree to Bunny at object keys rooted at `map_styles/fonts/inter-v1/`, using safe content types and immutable cache control for `.pbf` objects.
9. The normal PMTiles/style/sprite publish flow must not regenerate or re-upload the Inter glyph PBF tree on every map release.
10. Automated tests must fail if committed style templates or materialized style artifacts reference Bergwerk glyph URLs, Mapbox glyph URLs, or Roboto font stacks.
11. Automated tests must cover the static font publish path's object-key construction, idempotent upload behaviour, content type/cache-control choices, and credential-safe error handling.

## In scope / Out of scope
**In scope:**
- Updating the committed light and dark MapLibre style templates to use self-hosted Inter glyphs and Inter font stacks for basemap, contour, and Austrian Rocks overlay labels.
- Updating web-only dynamic contribution label styling from Roboto to Inter.
- Committing Inter glyph PBF runtime assets and their license/provenance documentation under `config/map_styles/fonts/inter-v1/`.
- Adding a dedicated, repeatable font publish task/command for Bunny/CDN that uploads the committed PBF tree under `map_styles/fonts/inter-v1/`.
- Documenting the font publish/update workflow concisely in `docs/map_tiles.md` and adding a short committed pointer in `config/map_styles/README.md`.
- Extending existing map style/materializer/publisher tests to enforce the glyph URL and font-stack contract.

**Out of scope:**
- Adding font publishing to the admin exports page — reason: font changes are rare developer/release operations, so a separate CLI/Rake command is safer and simpler than exposing it in admin UI.
- Changing CDN edge rules — reason: the fonts will be served under the existing `map_styles` prefix to reuse current routing/cache behaviour.
- Uploading fonts during every normal map release — reason: font glyphs are static and should not be coupled to PMTiles/style/sprite release cadence.
- Committing or maintaining a font-to-PBF generation tool in the regular app pipeline — reason: this item commits the runtime PBFs directly, and future font upgrades can regenerate a new version outside the normal release path.
- Replacing the app-wide CSS `inter-font` setup — reason: this item targets MapLibre glyphs and map label font stacks only.
- Changing basemap data sources, sprite icons, PMTiles layer contracts, or map interaction behaviour — reason: those are separate map concerns unrelated to glyph hosting.

## Approach
Use a stable, font-versioned CDN path inside the existing style prefix: `map_styles/fonts/inter-v1/{fontstack}/{range}.pbf`. Commit the Inter v1 glyph PBF folders used by the style's Inter stacks under `config/map_styles/fonts/inter-v1/`, alongside concise README/license/provenance documentation. Update both shared style templates so their top-level `glyphs` URL points at the self-hosted path, convert every Roboto `text-font` stack to the approved Inter stack, and update the dynamic contribution layer to use Inter.

Add a dedicated font publisher that walks the committed glyph tree and uploads it idempotently to Bunny. It should be callable separately from the existing `publish` map-release flow so routine PMTiles/style/sprite releases remain unchanged. It should reuse the existing configuration surfaces for CDN host, Bunny credentials, and `style_prefix`, and should validate/sanitize object keys in the same spirit as `MapTiles::Configuration` and `MapTiles::BunnyPublisher`.

Rejected alternatives: versioning glyphs with every map release was rejected because Inter changes rarely and re-uploading all glyph ranges on each PMTiles release wastes deploy work without improving cache safety. Using a new top-level CDN prefix such as `map_fonts` was rejected because it would require CDN edge-rule changes. Committing both source font binaries and generated PBFs was rejected because it creates two sources of truth for the same runtime asset.

## Considerations
### Config vs code
The canonical glyph URL is configuration derived from existing map tile settings in `config/map_tiles.yml`: `public_cdn_host` plus `style_prefix` plus a dedicated font glyph subpath defaulting to `fonts/inter-v1`. The `inter-v1` version should live in that config surface and be consumed through `MapTiles::Configuration` or an equivalent helper, not repeated across publisher code and assertions. The default is `inter-v1` because this is the first pinned Inter glyph set used by the shared styles; future font updates should create `inter-v2` rather than mutating already-cached objects.

### Security
The glyph PBF tree is committed static data and the publisher only reads local files under `config/map_styles/fonts/inter-v1/`; paths must be normalized so uploads cannot escape that root or create traversal object keys. Bunny credentials remain environment-provided secrets and must not be committed, written to `.incant/`, or included in error messages. Public URLs must remain HTTPS and credential-free. The main blast radius of a bad font publish is broken map labels; the normal release manifest and PMTiles artifacts should remain independent because font publishing is a separate command.

### Testability
Use automated tests at the map style and publisher layers. `bin/rails test test/lib/map_tiles/style_materializer_test.rb` should prove committed and materialized styles use the self-hosted Inter glyph URL, contain no Bergwerk/Mapbox glyph URLs, contain no Roboto font stacks, and still satisfy existing source/layer/sprite contracts. A new or extended map font publisher test should run with fake Bunny/S3 clients and assert deterministic object keys under `map_styles/fonts/inter-v1/`, idempotent behaviour, immutable cache control, PBF content type, and sanitized errors. Manual verification is limited to running the dedicated font publish command against real Bunny credentials before the first production rollout and confirming representative glyph URLs return 2xx.

### Code documentation
Add concise documentation near the font publisher explaining that committed glyph PBFs are static runtime assets published separately from map releases. Update the ignored maintainer doc `docs/map_tiles.md` with the operator workflow: when to run the separate font publish command, how to verify CDN URLs, and how to introduce `inter-v2` without mutating `inter-v1`. Add a shorter committed pointer in `config/map_styles/README.md` covering the self-hosted Inter glyph path, approved font stacks, and the fact that fonts are not uploaded by normal PMTiles releases. Avoid noisy inline comments in JSON templates; tests should document most invariants.

## Acceptance criteria
- [ ] `config/map_styles/austrian_rocks_light.json` and `config/map_styles/austrian_rocks_dark.json` both use `https://tiles.austrian.rocks/map_styles/fonts/inter-v1/{fontstack}/{range}.pbf` for `glyphs`.
- [ ] No committed or materialized shared style contains `basemap.bergwerk-gis.at/basemap-download/webapp/fonts`, `mapbox://fonts`, or `Roboto` in any `text-font` stack.
- [ ] All shared style `text-font` stacks are one of the approved Inter stacks: `Inter Light`, `Inter Regular`, `Inter Medium`, `Inter Bold`, `Inter Medium Italic`, or `Inter Bold Italic`.
- [ ] Austrian Rocks overlay symbol labels and the dynamic contribution text layer render with Inter font stacks.
- [ ] `config/map_styles/fonts/inter-v1/` contains the required committed Inter glyph PBF folders plus license/provenance documentation, and this work commits no Inter `.ttf`, `.otf`, `.woff`, or `.woff2` files.
- [ ] `config/map_tiles.yml` exposes the glyph subpath/version, and code derives the public glyph URL from configuration instead of duplicating the path in multiple logic locations.
- [ ] A dedicated idempotent command/task uploads the committed glyph PBF tree to Bunny under `map_styles/fonts/inter-v1/` without being invoked by the normal map release publish flow or exposed on the admin exports page.
- [ ] Automated tests cover style glyph/font invariants and static font publishing behaviour, including safe object keys, cache/content headers, idempotency, and credential-safe failures.
- [ ] `docs/map_tiles.md` concisely documents the font publish/update workflow, and `config/map_styles/README.md` contains a committed summary/pointer for maintainers.
- [ ] The first production rollout can be verified by HEAD/GET checks on representative CDN URLs such as `https://tiles.austrian.rocks/map_styles/fonts/inter-v1/Inter%20Regular/0-255.pbf` before clients load the updated styles.

## Risks & open questions
- Inter glyph PBF generation happens outside the normal app pipeline, so future Inter upgrades need a documented regeneration step before committing a new versioned PBF tree.
- PBF font-stack directory names may require URL escaping for spaces in manual checks, while MapLibre will substitute `{fontstack}` in the runtime URL; tests should verify the exact style template string and publisher object keys.
- The actual Inter glyph ranges must cover every character used by basemap labels and Austrian Rocks labels; committing the full generated range set for each approved stack reduces the risk of missing glyphs.
