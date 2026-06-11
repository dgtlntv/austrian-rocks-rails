---
id: "0012"
slug: remove-legacy-mapbox-references
stage: archived
completed: 2026-06-11
commit: d9c43975
---

# Remove Legacy Mapbox References — summary

## What was built
- Removed the obsolete `lib/tasks/mapbox.rake` task file and its legacy `mapbox:*` GeoJSON export surface.
- Removed the stale `austrian_rocks_mapbox:/austrian-rocks-maps/mapbox` deploy volume while preserving `austrian_rocks_export:/rails/export`.
- Reworded incidental non-test Mapbox comments in admin map/routes code without changing GeoJSON endpoints, redirects, or `marker-color` behaviour.
- Preserved intentional tests that assert Mapbox runtime/style/Tippecanoe regressions stay absent.

## Deviations from spec
- None. The implementation followed the removal-only spec and kept intentional Mapbox-negative tests readable.

## Key decisions
- Deleted rather than renamed the obsolete rake namespace because `map_tiles:*` and `bin/build_pmtiles` are the maintained PMTiles flow.
- Removed the old deploy mount without replacement because current durable map artifacts are published through Bunny/CDN and generated files remain transient.
- Accepted the review verdict as releasable: no blocker, major, minor, or nit findings remain open.

## Links
- Final feature commit: `d9c43975` (`incant 0012-P1: remove legacy Mapbox references`).
- Review verdict: ready to release.

## Sessions
- `019eb5ff-34f7-7e82-8c4a-8e85481c2756`
- `019eb60f-7b51-70cc-8af4-0aa807168f3e`
- `019eb61d-f0d4-7777-9d82-4df423429f88`
- `019eb63c-92ff-7f20-bbf5-074bb95154f5`
- `019eb644-a314-7cd1-a447-93db71eb7eed`

## Follow-ups
- None.
