# State
- Updated: 2026-06-09 (0005 P4 review accepted; ready to finalize)
- Current focus: 0005 — MapLibre/basemap.at P4 reviewed after commit; automated gate/stale search are green, and the two remaining P4 concerns were explicitly accepted as wontfix by the human

## Active
- 0005 — review stage on branch `incant/0005-maplibre-basemap-at`; work dir `.incant/work/0005-maplibre-basemap-at/`; P4 commit `a1469a7b` is reviewed and final full Docker automated release gate plus stale-reference search are green. The Bergwerk testing-only basemap dependency concern and concrete manual smoke evidence concern are marked `wontfix` per human acceptance. Next step is `/incant:finalize 0005`.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
- For 0005, remove stale `latest.pmtiles` behaviour and use immutable versioned PMTiles/style JSON releases plus a non-cached manifest pointer.
- For 0005 basemap attribution, use linked `Grundkarte: basemap.at`/`Datenquelle: basemap.at` and do not add OpenStreetMap attribution unless a future displayed source requires it.
