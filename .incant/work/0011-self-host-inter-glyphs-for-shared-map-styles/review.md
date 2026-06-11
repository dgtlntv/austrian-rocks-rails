---
id: "0011"
slug: self-host-inter-glyphs-for-shared-map-styles
stage: review
reviewed: 2026-06-11
commit: 7012d886
---

# Self Host Inter Glyphs For Shared Map Styles — review

### Strengths
- config/map_tiles.yml:7 and lib/map_tiles/configuration.rb:54 — the glyph version is exposed as `font_glyph_subpath` and then derived into root, object-prefix, and public template helpers instead of scattering the CDN path through code.
- lib/map_tiles/configuration.rb:232 — `font_glyph_subpath` is validated as safe slash-separated segments, covering the config-vs-code and security requirements for the new path surface.
- config/map_styles/austrian_rocks_light.json:5 and config/map_styles/austrian_rocks_dark.json:5 — both committed templates now point at the self-hosted Inter glyph URL required by Phase 0011-P1.
- lib/map_tiles/style_materializer.rb:38 and lib/map_tiles/style_materializer.rb:85 — materialized styles derive glyphs from configuration and enforce the forbidden Bergwerk/Mapbox/Roboto plus approved-Inter text-font contract before writing artifacts.
- app/javascript/controllers/map_controller.js:216 — the dynamic contribution text layer now uses `Inter Regular`, aligning web-only map labels with the shared style contract.
- test/lib/map_tiles/configuration_test.rb:21 and test/lib/map_tiles/style_materializer_test.rb:38 — tests cover the configured glyph helpers, committed style glyphs, materialized glyphs, approved Inter stacks, forbidden font references, and the dynamic contribution font.
- Fresh gate passed this review session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test web bash -lc 'bin/rails test test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/style_materializer_test.rb'` → 22 runs, 1022 assertions, 0 failures, 0 errors, 0 skips.
- Final scan passed this review session: `! rg -n 'basemap\.bergwerk-gis\.at/basemap-download/webapp/fonts|mapbox://fonts|Roboto' config/map_styles/austrian_rocks_*.json app/javascript/controllers/map_controller.js`.

### Blocker
None.

### Major
None.

### Minor
None.

### Nit
None.

### Verdict
Ready to release? **No** — Phase 0011-P1 clears review with no open findings, but the work item is intentionally not item-release-ready yet because planned Phases 0011-P2 through 0011-P4 remain unimplemented. Continue with `/incant:implement 0011` for the next phase.
