# State
- Updated: 2026-06-09 (0005 P4 paused for main merge/admin PMTiles reconciliation)
- Current focus: 0005 — MapLibre/basemap.at P4 merging current main and reconciling PMTiles admin workflow

## Active
- 0005 — implement stage on branch `incant/0005-maplibre-basemap-at`; work dir `.incant/work/0005-maplibre-basemap-at/`; P4 is paused while current `main` is merged. The 0009 admin/background PMTiles publishing workflow from main must be adapted to 0005's versioned PMTiles/style JSON plus non-cached `current.json` manifest contract before automated gates and human browser smoke resume.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
- For 0005, remove stale `latest.pmtiles` behaviour and use immutable versioned PMTiles/style JSON releases plus a non-cached manifest pointer.
- For 0005 basemap attribution, use linked `Grundkarte: basemap.at`/`Datenquelle: basemap.at` and do not add OpenStreetMap attribution unless a future displayed source requires it.
