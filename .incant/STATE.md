# State
- Updated: 2026-06-09 (0005 plan written)
- Current focus: 0005 — MapLibre/basemap.at Rails web map migration plan awaiting human approval

## Active
- 0005 — plan stage on branch `incant/0005-maplibre-basemap-at`; work dir `.incant/work/0005-maplibre-basemap-at/`; spec approval supplied in the 2026-06-09 planning request; next gate is human plan approval before implementation/code changes.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
- For 0005, remove stale `latest.pmtiles` behaviour and use immutable versioned PMTiles/style JSON releases plus a non-cached manifest pointer.
