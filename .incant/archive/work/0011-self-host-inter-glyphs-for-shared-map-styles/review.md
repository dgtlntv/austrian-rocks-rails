---
id: "0011"
slug: self-host-inter-glyphs-for-shared-map-styles
stage: review
reviewed: 2026-06-11
commit: 30edca3a
---

# Self Host Inter Glyphs For Shared Map Styles — review

### Strengths
- config/map_tiles.yml:7 and lib/map_tiles/configuration.rb:54 — the glyph version is a configuration value (`fonts/inter-v1`), with helpers deriving the local root, Bunny object prefix, and public MapLibre glyph template instead of scattering the CDN URL through publisher logic.
- config/map_styles/austrian_rocks_light.json:5 and config/map_styles/austrian_rocks_dark.json:5 — both committed shared styles now point `glyphs` at the requested self-hosted Inter CDN template.
- lib/map_tiles/style_materializer.rb:14 — materialization has an explicit forbidden-reference allow/deny contract for Bergwerk glyph URLs, Mapbox glyph URLs, and Roboto; lib/map_tiles/style_materializer.rb:38 rewrites materialized artifacts from configuration before validation.
- app/javascript/controllers/map_controller.js:216 — the web-only dynamic contribution text layer uses `Inter Regular`, matching the shared-style font-stack contract.
- config/map_styles/fonts/inter-v1/README.md:9 — the committed runtime glyph tree documents the six approved Inter stacks, provenance, OFL licensing, separate publish path, and immutable `inter-v2` upgrade rule.
- test/lib/map_tiles/font_assets_test.rb:17 — the asset test locks the committed glyph tree to the approved stack directories, requires PBF files, and rejects Inter source font binaries.
- lib/map_tiles/font_publisher.rb:43 — the dedicated font publisher validates Bunny env, CDN host, style prefix, and glyph root before upload; lib/map_tiles/font_publisher.rb:57 builds sorted stable keys with `application/x-protobuf` and immutable cache-control metadata.
- lib/map_tiles/font_publisher.rb:75 — upload candidates are realpath-normalized, kept under the configured glyph root, and constrained to safe object-key segments; lib/map_tiles/font_publisher.rb:111 wraps service/system failures without leaking raw credential-bearing messages.
- lib/map_tiles/font_publisher.rb:125 — public reporting URLs escape font-stack spaces as `%20` while preserving literal-space Bunny object keys for MapLibre stack names.
- lib/map_tiles/cli.rb:58 and lib/map_tiles/cli.rb:114 — `publish-fonts` is a separate command path that rejects extra options and does not require a map artifact version, smoke check, map-release publish, or cleanup.
- test/lib/map_tiles/bunny_publisher_test.rb:104 — the normal PMTiles/style/sprite/manifest publisher is explicitly tested not to upload `/fonts/` keys, preserving release-flow separation.
- config/map_styles/README.md:9 — committed maintainer documentation now points to the self-hosted Inter glyph URL, approved stacks, glyph-tree README, and separate font publish workflow.
- Commit history follows incant conventions for spec, plan, and every implementation phase through `incant 0011-P4: document font publish separation`.
- Fresh final-review gate passed this session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test web bash -lc 'bin/rails test test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/style_materializer_test.rb test/lib/map_tiles/font_assets_test.rb test/lib/map_tiles/font_publisher_test.rb test/lib/map_tiles/cli_test.rb test/lib/map_tiles/bunny_publisher_test.rb'` → 48 runs, 1234 assertions, 0 failures, 0 errors, 0 skips.
- Fresh final-review scan passed this session: `! rg -n 'basemap\.bergwerk-gis\.at/basemap-download/webapp/fonts|mapbox://fonts|Roboto' config/map_styles/austrian_rocks_*.json app/javascript/controllers/map_controller.js && test -z "$(find config/map_styles/fonts/inter-v1 -type f \( -name '*.ttf' -o -name '*.otf' -o -name '*.woff' -o -name '*.woff2' \) -print -quit)"` → no output, exit 0.

### Blocker
None.

### Major
None.

### Minor
None.

### Nit
None.

### Verdict
Ready to release? **Yes** — all acceptance criteria are covered by the implementation, documentation, and fresh gate evidence, with no open blocker or major findings.
