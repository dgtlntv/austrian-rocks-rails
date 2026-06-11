---
id: "0012"
slug: remove-legacy-mapbox-references
branch: incant/0012-remove-legacy-mapbox-references
title: Remove Legacy Mapbox References
stage: spec
status: in-progress
created: 2026-06-11
commit: e98ebb9d
updated: 2026-06-11
---

# Remove Legacy Mapbox References

## Goal

Remove obsolete Mapbox-named maintenance, deploy, and inline-code/comment surfaces from the Rails app now that runtime maps and tile publication are MapLibre/PMTiles based, while preserving intentional tests that assert legacy Mapbox runtime assets stay absent.

## Context & codebase fit

- `lib/tasks/mapbox.rake` defines old `mapbox:*` GeoJSON export tasks (`areas`, `regions`, `clusters`, `problems`, and a commented `pois` task). These write files under `../#{BRAND_CONFIG[:slug]}-maps/mapbox/`, duplicate data now produced by `lib/map_tiles/geojson_exporter.rb`, and are no longer exposed through admin export controls.
- `lib/tasks/map_tiles.rake`, `bin/build_pmtiles`, `lib/map_tiles/cli.rb`, and `config/map_tiles.yml` are the current map export/build/publish path. They export deterministic layer GeoJSON under `tmp/map_tiles/geojson`, build PMTiles with Tippecanoe, publish immutable PMTiles/styles/sprites through Bunny/CDN, and expose the mutable manifest at `/map_tiles/current.json`.
- `config/deploy.yml` still mounts `austrian_rocks_mapbox:/austrian-rocks-maps/mapbox` even though the current PMTiles pipeline writes transient local artifacts under `tmp/map_tiles` and publishes to Bunny/CDN. The existing `austrian_rocks_export:/rails/export` volume is unrelated and still supports SQLite app export.
- `app/controllers/admin/maps_controller.rb` has an incidental comment/link to Mapbox's simple-style spec for `marker-color`, and `config/routes.rb` mentions Mapbox in a redirect-route comment. The admin GeoJSON endpoints themselves remain useful for editing/debugging in `geojson.io`; only stale wording should go.
- Existing tests intentionally contain Mapbox strings to guard against regressions: `test/controllers/map_controller_test.rb` asserts public maps do not render Mapbox runtime assets/tokens, `test/lib/map_tiles/style_materializer_test.rb` asserts styles do not contain `mapbox://` URLs, and `test/lib/map_tiles/tippecanoe_builder_test.rb` asserts install guidance does not point at the historical Mapbox Tippecanoe repository. The human decision for this item is to keep these tests plainly named rather than rename or string-split them.
- `test/controllers/admin/exports_controller_test.rb` already verifies legacy GeoJSON export controls/routes are absent, which supports deleting the remaining old rake task instead of renaming it.

## Requirements

1. Delete the obsolete `lib/tasks/mapbox.rake` task file entirely; no replacement `mapbox:*` rake namespace or renamed legacy GeoJSON task namespace is introduced.
2. After implementation, Rails task discovery exposes no `mapbox` tasks (`bin/rails -T` has no case-insensitive `mapbox` matches).
3. Remove the `austrian_rocks_mapbox:/austrian-rocks-maps/mapbox` deploy volume mount from `config/deploy.yml`; do not add a replacement persistent volume/path for the obsolete legacy GeoJSON exports. Preserve unrelated deploy volumes such as `/rails/export`.
4. Clean incidental non-test comments/references in admin map and route code so they no longer describe current behaviour as Mapbox-related. Preserve the admin GeoJSON endpoints and `marker-color` simple-style property behaviour.
5. Keep the existing intentional test assertions that mention Mapbox runtime assets/URLs/tokens and historical Tippecanoe guidance; do not rename the tests or hide the word with string concatenation solely to make search output empty.
6. Outside `.incant/` artifacts and intentional tests, committed app/deploy/task/docs code has no remaining plain `mapbox`, `Mapbox`, or `MAPBOX` references.
7. The current MapLibre public map, PMTiles export/build/publish rake tasks, admin SQLite export, and admin GeoJSON editing/debug endpoints continue to work as before.

## In scope / Out of scope

**In scope:**
- Delete `lib/tasks/mapbox.rake` and its legacy `../#{BRAND_CONFIG[:slug]}-maps/mapbox/*.geojson` output paths.
- Remove the Mapbox-named Kamal deploy volume/path from `config/deploy.yml`.
- Edit stale comments in `app/controllers/admin/maps_controller.rb` and `config/routes.rb` without changing endpoint behaviour.
- Keep and run relevant tests that protect MapLibre runtime output, map style materialization, Tippecanoe guidance, and admin export cleanup.
- Static verification that only `.incant/` artifacts and intentional tests still mention Mapbox.

**Out of scope:**
- Host-level cleanup or migration of any already-created Docker volume on production servers — reason: operational cleanup is separate from the committed deploy specification.
- Renaming or obfuscating existing test names/helpers/literals that intentionally assert Mapbox absence — reason: the human explicitly preferred keeping them.
- Changing MapLibre runtime interactions, style JSON design, tile schemas, PMTiles publishing semantics, Bunny/CDN object names, or the SQLite app export — reason: this item removes stale legacy surfaces only.
- Removing `geojson.io` admin editing/debug flows — reason: those flows are independent of Mapbox and still useful.

## Approach

Delete rather than rename the old Mapbox rake file because the maintained `map_tiles` pipeline already owns map data export and publication, admin legacy export routes are gone, and keeping a renamed task/volume would preserve an unused maintenance surface. Remove the deploy volume mount with no replacement because the current PMTiles path stores generated artifacts in ignored local output (`tmp/map_tiles`) and publishes the durable artifacts to Bunny/CDN. Update only comments where the code behaviour is still valid but the Mapbox framing is stale.

Rejected alternatives: renaming `mapbox:*` to a generic GeoJSON namespace would make an obsolete exporter look supported; moving the old output to a new persistent deploy path would keep unused infrastructure alive; renaming/splitting intentional tests would reduce readability and was rejected by the human.

## Considerations

### Config vs code
No new configuration is needed. The obsolete deploy configuration is removed rather than replaced. Current configurable map tile values remain in `config/map_tiles.yml` and continue to be consumed by `MapTiles::Configuration`; this item does not add new constants or environment knobs.

### Security
This is a removal-only maintenance change. It reduces deploy blast radius by eliminating an unused persistent mount and removes an obsolete export task surface. No secrets are introduced or moved, and no credential names or values are written into `.incant/`. Existing tests that check Mapbox access-token/runtime strings stay in place to prevent accidental reintroduction of a legacy third-party runtime dependency.

### Testability
Verification is primarily static plus targeted Rails tests. Static checks confirm the old task file is absent, Rails task discovery has no `mapbox` namespace, the deploy volume is gone, and non-test app/deploy/task/docs code no longer contains plain Mapbox references. Automated tests should run against the Docker-hosted PostgreSQL/PostGIS database for map-data coverage, using a command shaped like:

```bash
docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test web bash -lc 'bin/rails test test/controllers/map_controller_test.rb test/controllers/admin/exports_controller_test.rb test/lib/map_tiles/style_materializer_test.rb test/lib/map_tiles/tippecanoe_builder_test.rb'
```

### Code documentation
No new modules or public APIs are expected. Documentation work is limited to removing stale comments or replacing them with concise wording that explains current behaviour, such as why the admin GeoJSON output uses the standard `marker-color` simple-style property. Avoid adding noisy comments around self-explanatory deletions.

## Acceptance criteria

- [ ] `lib/tasks/mapbox.rake` is deleted and no new legacy GeoJSON rake task file/namespace replaces it.
- [ ] `bin/rails -T | rg -i "mapbox"` produces no output.
- [ ] `config/deploy.yml` no longer contains `austrian_rocks_mapbox` or `/austrian-rocks-maps/mapbox`, while the unrelated `/rails/export` volume remains.
- [ ] `rg -n -i "mapbox" app config lib bin README.md Dockerfile Dockerfile.dev` produces no output outside files intentionally excluded from the check.
- [ ] Existing tests that explicitly assert no Mapbox runtime/style assets remain present and readable.
- [ ] The targeted Docker-backed Rails test command from the Testability section passes.

## Risks & open questions

- Risk: an operator might still have an old host Docker volume after deploy. This spec intentionally removes the committed mount only; host cleanup can be handled manually if desired.
- Risk: deleting the rake task could surprise someone who still runs `mapbox:*` commands manually. The maintained replacement is the documented `map_tiles:*`/`bin/build_pmtiles` flow, and `bin/rails -T` should no longer advertise the old commands.
- Open questions: none; the human confirmed deleting the obsolete task/volume and keeping the intentional Mapbox-negative tests.
