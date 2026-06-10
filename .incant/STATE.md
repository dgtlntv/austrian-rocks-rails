# State
- Updated: 2026-06-09 (0005 P4 committed-ready; final automated gate green)
- Current focus: 0005 — MapLibre/basemap.at P4 ready for final review after main merge reconciliation, Höhenlinien opacity update, custom overlay style tuning, terrain/glyph 404 fixes, manual smoke checklist completion, and full automated release gate

## Active
- 0005 — review stage on branch `incant/0005-maplibre-basemap-at`; work dir `.incant/work/0005-maplibre-basemap-at/`; current `main` was merged and the 0009 admin/background PMTiles workflow was adapted to 0005's versioned PMTiles/style JSON plus non-cached `current.json` manifest contract. P4 README/checklist/dev-Docker docs are reapplied; basemap.at Höhenlinien are now part of the shared light/dark style templates with configured lower contour opacity, and the custom Austrian Rocks PMTiles overlay styles now follow the old stack with corrected topmost label order, old runtime problem-dot styling, no problem text layer, and a later area-hull fade; terrain overzooms from z17 and custom symbols use Bergwerk-served fonts to avoid z18 terrain/glyph 404s; final full Docker automated release gate and stale-reference search are green. Next step is `/incant:review 0005`.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
- For 0005, remove stale `latest.pmtiles` behaviour and use immutable versioned PMTiles/style JSON releases plus a non-cached manifest pointer.
- For 0005 basemap attribution, use linked `Grundkarte: basemap.at`/`Datenquelle: basemap.at` and do not add OpenStreetMap attribution unless a future displayed source requires it.
