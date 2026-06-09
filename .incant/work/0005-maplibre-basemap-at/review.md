---
id: "0005"
slug: maplibre-basemap-at
stage: review
reviewed: 2026-06-09
commit: f3f049d43f4f189c36cfaf41068bb2fd03bd3bb5
---

# Migrate Rails web maps from Mapbox to MapLibre with basemap.at — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

### Strengths
- `lib/map_tiles/release_manifest.rb:10` — the new manifest object documents and implements the intended invariant clearly: the manifest is the only mutable pointer while PMTiles/style JSON URLs remain immutable versioned release objects.
- `lib/map_tiles/bunny_publisher.rb:83` — the publication plan now covers exactly the required four artifacts with the right split between immutable PMTiles/style cache headers and non-cached manifest headers.
- `lib/map_tiles/local_artifact_cleaner.rb:35` — local cleanup now understands generated style JSONs and the current manifest in addition to PMTiles/metadata, reducing stale local release artifacts without touching the current release.
- Fresh P2 quality gate passed this session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.invalid -e BUNNY_STORAGE_ACCESS_KEY_ID=dummy -e BUNNY_STORAGE_SECRET_ACCESS_KEY=dummy -e BUNNY_STORAGE_REGION=dummy -e BUNNY_STORAGE_BUCKET=dummy web bash -lc 'bin/rails test test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/style_materializer_test.rb test/lib/map_tiles/release_manifest_test.rb test/lib/map_tiles/bunny_publisher_test.rb test/lib/map_tiles/cli_test.rb test/lib/map_tiles/local_artifact_cleaner_test.rb && if command -v rg >/dev/null 2>&1; then ! rg -n "latest_object_key|austrian-rocks-latest|latest\\.pmtiles" lib test config README.md docs/map_tiles.md; else ! grep -R -n -E "latest_object_key|austrian-rocks-latest|latest\\.pmtiles" lib test config README.md docs/map_tiles.md; fi'` → `33 runs, 242 assertions, 0 failures, 0 errors, 0 skips` and no stale latest PMTiles references found.

### Blocker
- None.

### Major
- `lib/map_tiles/bunny_publisher.rb:48` and `lib/map_tiles/bunny_publisher.rb:109` — the publisher uploads every artifact, including the non-cached current manifest, before any public HEAD verification runs. If the PMTiles/light/dark style upload is not publicly reachable (the test at `test/lib/map_tiles/bunny_publisher_test.rb:123` models a dark-style HEAD failure), `maps/current.json` has already been updated to point clients at that broken release. That violates the immutable-release/manifest safety contract because the only moving pointer can expose an inaccessible style or PMTiles URL. Fix: split the publish flow so versioned PMTiles and both style JSONs are uploaded and HEAD-verified first, then upload and verify the manifest last; add a regression assertion that the manifest is not uploaded when a versioned asset HEAD check fails. status: open
- `lib/map_tiles/configuration.rb:127`, `lib/map_tiles/configuration.rb:202`, and `test/lib/map_tiles/configuration_test.rb:109` — previous finding: `public_url_for_object_key`/`public_cdn_base` allowed malformed blank/trailing-slash object keys and CDN host query/fragment components. The implementation now raises for those cases and the regression assertions pass in the fresh Docker/PostGIS gate. status: addressed

### Minor
- None.

### Nit
- None.

### Verdict
Ready to release? **No** — P2 has one open major release-integrity finding. Return to implementation to make the manifest update the final step after versioned assets are verified.
