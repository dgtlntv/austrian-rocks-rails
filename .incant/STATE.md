# State
- Updated: 2026-06-09 (0005 P3 re-review passed; P4 next)
- Current focus: 0005 — MapLibre/basemap.at Rails runtime ready for P4 implementation

## Active
- 0005 — implement stage on branch `incant/0005-maplibre-basemap-at`; work dir `.incant/work/0005-maplibre-basemap-at/`; phase `0005-P3` re-review recorded the PMTiles `problemId` popup-link blocker as addressed with no open blocker/major findings for P3. Next gate: `/incant:implement 0005` for P4 documentation, full release gates, and manual smoke evidence.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
- For 0005, remove stale `latest.pmtiles` behaviour and use immutable versioned PMTiles/style JSON releases plus a non-cached manifest pointer.
- For 0005 basemap attribution, use linked `Grundkarte: basemap.at`/`Datenquelle: basemap.at` and do not add OpenStreetMap attribution unless a future displayed source requires it.
