---
id: "0011"
slug: self-host-inter-glyphs-for-shared-map-styles
stage: review
reviewed: 2026-06-11
commit: 6bb6c82a
---

# Self Host Inter Glyphs For Shared Map Styles — review

### Strengths
- lib/map_tiles/font_publisher.rb:14 — the static font publisher uses the requested `application/x-protobuf` content type and immutable cache-control constant for PBF glyph objects.
- lib/map_tiles/font_publisher.rb:16 — it reuses the same five Bunny storage environment variable names as map release publishing, keeping the deployment contract consistent.
- lib/map_tiles/font_publisher.rb:43 — configuration validation checks Bunny env, public CDN host, style prefix, and the configured glyph root before any upload work begins.
- lib/map_tiles/font_publisher.rb:57 — upload planning walks only sorted `*.pbf` files below `configuration.font_glyph_root`, rejects an empty runtime glyph tree, and builds stable keys under `configuration.font_glyph_object_prefix`.
- lib/map_tiles/font_publisher.rb:75 — each upload candidate is resolved with `realpath`, checked against the configured root, and limited to safe object-key segments, addressing the path traversal risk called out in the spec.
- lib/map_tiles/font_publisher.rb:101 — upload failures are wrapped as `UploadError` with the object key and exception class only, avoiding raw Bunny/AWS error text or credential leakage.
- lib/map_tiles/font_publisher.rb:125 — public reporting URLs URL-escape stack names with spaces while preserving Bunny object keys with the literal stack names MapLibre expects.
- lib/map_tiles/cli.rb:9 and lib/map_tiles/cli.rb:58 — the CLI wires a dedicated `publish-fonts` command through `MapTiles::FontPublisher` without touching the normal `publish` branch.
- lib/map_tiles/cli.rb:114 — `publish-fonts` rejects all extra options and runs without requiring `--version`, smoke checks, map release publishing, or cleanup.
- lib/tasks/map_tiles.rake:33 — operators also get the requested `map_tiles:publish_fonts` Rails task for the same dedicated publish path.
- test/lib/map_tiles/font_publisher_test.rb:23 — tests cover deterministic sorted keys, repeat publish behaviour, bodies, content type, immutable cache-control, and public URL escaping for stack names with spaces.
- test/lib/map_tiles/font_publisher_test.rb:50 — tests cover missing Bunny env, blank style prefix, missing glyph root, and empty glyph root failures.
- test/lib/map_tiles/font_publisher_test.rb:79 — tests cover escaped symlink/path traversal and unsafe object-key segment rejection.
- test/lib/map_tiles/font_publisher_test.rb:97 — tests cover credential-safe upload failures when a service error contains a secret.
- test/lib/map_tiles/cli_test.rb:94 — CLI tests prove `publish-fonts` is separate from normal versioned map publish, smoke, and cleanup paths.
- Commit history follows incant conventions through the completed phase: `incant 0011-P1: derive Inter map glyph styles`, `incant 0011-P2: add Inter glyph assets`, and `incant 0011-P3: add font glyph publisher`.
- Fresh P3 quality gate passed this review session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test web bash -lc 'bin/rails test test/lib/map_tiles/font_publisher_test.rb test/lib/map_tiles/cli_test.rb'` → 15 runs, 103 assertions, 0 failures, 0 errors, 0 skips.

### Blocker
None.

### Major
None.

### Minor
None.

### Nit
None.

### Verdict
Ready to release? **No** — Phase 0011-P3 clears review with no open findings, but the work item is not item-release-ready yet because planned Phase 0011-P4 remains unchecked/unimplemented. Continue with `/incant:implement 0011` for the documentation and normal-release separation proof phase.
