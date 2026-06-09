# State
- Updated: 2026-06-09 (0005 spec drafted)
- Current focus: 0005 — MapLibre/basemap.at Rails web map migration spec awaiting human approval

## Active
- 0005 — spec stage on branch `incant/0005-maplibre-basemap-at`; work dir `.incant/work/0005-maplibre-basemap-at/`; next gate is human spec approval before planning.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
- For 0005, remove stale `latest.pmtiles` behaviour and use immutable versioned PMTiles/style JSON releases plus a non-cached manifest pointer.
