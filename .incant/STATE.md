# State
- Updated: 2026-06-09 (0005 P1 review fix complete)
- Current focus: 0005 — MapLibre/basemap.at Rails web map migration P1 review fix awaiting re-review

## Active
- 0005 — review stage on branch `incant/0005-maplibre-basemap-at`; work dir `.incant/work/0005-maplibre-basemap-at/`; phase `0005-P1` review fix tightened public URL/object-key sanitization and passed the P1 gate. Next gate: `/incant:review 0005`.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
- For 0005, remove stale `latest.pmtiles` behaviour and use immutable versioned PMTiles/style JSON releases plus a non-cached manifest pointer.
- For 0005 basemap attribution, use linked `Grundkarte: basemap.at`/`Datenquelle: basemap.at` and do not add OpenStreetMap attribution unless a future displayed source requires it.
