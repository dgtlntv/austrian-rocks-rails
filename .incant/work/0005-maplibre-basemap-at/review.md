---
id: "0005"
slug: maplibre-basemap-at
stage: review
reviewed: 2026-06-09
commit: d9ef5b62c61ead0485be0d20ce94d06d7fdb3fe4
---

# Migrate Rails web maps from Mapbox to MapLibre with basemap.at — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

### Strengths
- `lib/map_tiles/bunny_publisher.rb:49` — the publish flow now explicitly separates versioned PMTiles/light/dark style artifacts from the mutable manifest, matching the immutable-release contract in the spec and plan.
- `lib/map_tiles/bunny_publisher.rb:50` and `lib/map_tiles/bunny_publisher.rb:52` — the non-cached manifest upload is now sequenced after all versioned asset uploads and their public HEAD checks, so a broken versioned asset no longer advances the client pointer.
- `test/lib/map_tiles/bunny_publisher_test.rb:123` — the regression test covers the release-integrity failure mode directly by asserting that a dark-style HEAD failure leaves `maps/current.json` unpublished.
- `lib/map_tiles/configuration.rb:127` and `lib/map_tiles/configuration.rb:194` — the earlier URL/key sanitization work still rejects malformed object keys and CDN hosts with query/fragment components, preserving the path-traversal and invalid-public-URL protections required by the spec.
- Fresh P2 re-review quality gate passed this session: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test -e BUNNY_STORAGE_ENDPOINT=http://example.invalid -e BUNNY_STORAGE_ACCESS_KEY_ID=dummy -e BUNNY_STORAGE_SECRET_ACCESS_KEY=dummy -e BUNNY_STORAGE_REGION=dummy -e BUNNY_STORAGE_BUCKET=dummy web bash -lc 'bin/rails test test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/style_materializer_test.rb test/lib/map_tiles/release_manifest_test.rb test/lib/map_tiles/bunny_publisher_test.rb test/lib/map_tiles/cli_test.rb test/lib/map_tiles/local_artifact_cleaner_test.rb && if command -v rg >/dev/null 2>&1; then ! rg -n "latest_object_key|austrian-rocks-latest|latest\\.pmtiles" lib test config README.md docs/map_tiles.md; else ! grep -R -n -E "latest_object_key|austrian-rocks-latest|latest\\.pmtiles" lib test config README.md docs/map_tiles.md; fi'` → `33 runs, 242 assertions, 0 failures, 0 errors, 0 skips` and no stale latest PMTiles references found.

### Blocker
- None.

### Major
- `lib/map_tiles/bunny_publisher.rb:49`, `lib/map_tiles/bunny_publisher.rb:50`, `lib/map_tiles/bunny_publisher.rb:52`, and `test/lib/map_tiles/bunny_publisher_test.rb:123` — previous finding: the publisher uploaded the non-cached current manifest before public HEAD verification of all versioned assets, risking a manifest that points clients at a broken release. The implementation now uploads and verifies the versioned PMTiles/light/dark styles first, uploads/verifies the manifest last, and asserts that `maps/current.json` is not uploaded when a versioned style HEAD check fails. status: addressed
- `lib/map_tiles/configuration.rb:127`, `lib/map_tiles/configuration.rb:202`, and `test/lib/map_tiles/configuration_test.rb:108` — previous finding: `public_url_for_object_key`/`public_cdn_base` allowed malformed blank/trailing-slash object keys and CDN host query/fragment components. The implementation rejects those cases and the regression assertions pass in the fresh Docker/PostGIS gate. status: addressed

### Minor
- None.

### Nit
- None.

### Verdict
Ready to release? **Yes** — for the completed `0005-P2` phase/re-review, with no open blocker or major findings in the immutable publish contract. This is not a final item release review yet: `plan.md` still has P3/P4 unchecked, so continue implementation before `/incant:finalize 0005`.
