---
id: "0011"
slug: self-host-inter-glyphs-for-shared-map-styles
stage: review
reviewed: 2026-06-11
commit: 59fa681a
---

# Self Host Inter Glyphs For Shared Map Styles — review

### Strengths
- config/map_tiles.yml:7 and lib/map_tiles/configuration.rb:54 — the glyph version is exposed as `font_glyph_subpath` and then derived into root, object-prefix, and public template helpers instead of scattering the CDN path through code.
- lib/map_tiles/configuration.rb:232 — `font_glyph_subpath` is validated as safe slash-separated segments, covering the config-vs-code and security requirements for the new path surface.
- config/map_styles/austrian_rocks_light.json:5 and config/map_styles/austrian_rocks_dark.json:5 — both committed templates point at the self-hosted Inter glyph URL required by Phase 0011-P1.
- lib/map_tiles/style_materializer.rb:38 and lib/map_tiles/style_materializer.rb:85 — materialized styles derive glyphs from configuration and enforce the forbidden Bergwerk/Mapbox/Roboto plus approved-Inter text-font contract before writing artifacts.
- app/javascript/controllers/map_controller.js:216 — the dynamic contribution text layer uses `Inter Regular`, aligning web-only map labels with the shared style contract.
- config/map_styles/fonts/inter-v1/README.md:9 and config/map_styles/fonts/inter-v1/LICENSE.md:7 — Phase 0011-P2 adds clear committed provenance for the approved Inter v1 runtime glyph tree, including the source generation directory and CDN object shape.
- config/map_styles/fonts/inter-v1/README.md:18 and config/map_styles/fonts/inter-v1/LICENSE.md:9 — documentation explicitly keeps source font binaries out of this tree and records the immutable `inter-v2` update rule.
- test/lib/map_tiles/font_assets_test.rb:21 and test/lib/map_tiles/font_assets_test.rb:33 — the new asset test locks the directory to approved stacks plus docs, requires runtime PBFs, and rejects `.ttf`, `.otf`, `.woff`, and `.woff2` files.
- test/lib/map_tiles/style_materializer_test.rb:38, test/lib/map_tiles/style_materializer_test.rb:69, and test/lib/map_tiles/style_materializer_test.rb:219 — tests cover committed/materialized glyph URLs and reject forbidden glyph/font references or unapproved text-font stacks.
- Manual asset comparison during review confirmed each approved stack was copied from `tmp/font-maker-2026-06-11T14_25_38.391Z/` with 256 PBF files and no `diff -qr` mismatches.
- Fresh gate passed this review session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test web bash -lc 'bin/rails test test/lib/map_tiles/font_assets_test.rb test/lib/map_tiles/style_materializer_test.rb'` → 7 runs, 963 assertions, 0 failures, 0 errors, 0 skips.
- Final scan passed this review session: `! rg -n 'basemap\.bergwerk-gis\.at/basemap-download/webapp/fonts|mapbox://fonts|Roboto' config/map_styles/austrian_rocks_*.json app/javascript/controllers/map_controller.js && test -z "$(find config/map_styles/fonts/inter-v1 -type f \( -name '*.ttf' -o -name '*.otf' -o -name '*.woff' -o -name '*.woff2' \) -print -quit)"`.
- Commit history follows incant conventions for completed work so far: `incant 0011-P1: derive Inter map glyph styles` and `incant 0011-P2: add Inter glyph assets`.

### Blocker
None.

### Major
None.

### Minor
None.

### Nit
None.

### Verdict
Ready to release? **No** — Phase 0011-P2 clears review with no open findings, but the work item is intentionally not item-release-ready yet because planned Phases 0011-P3 and 0011-P4 remain unimplemented. Continue with `/incant:implement 0011` for the next phase.
