# State
- Updated: 2026-06-09 (0005 P4 review recorded; two open major findings)
- Current focus: 0005 — MapLibre/basemap.at P4 reviewed after commit; automated gate/stale search are green, but release is blocked by two open major review findings: testing-only Bergwerk basemap dependency and incomplete concrete manual smoke evidence

## Active
- 0005 — review stage on branch `incant/0005-maplibre-basemap-at`; work dir `.incant/work/0005-maplibre-basemap-at/`; P4 commit `a1469a7b` is reviewed and final full Docker automated release gate plus stale-reference search are green. Review has two open major findings: replace/revise the Bergwerk testing-only basemap dependency before release, and provide concrete manual smoke evidence with environment/browser/route/network observations. Next step is `/incant:implement 0005` to address the open majors, then re-review.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
- For 0005, remove stale `latest.pmtiles` behaviour and use immutable versioned PMTiles/style JSON releases plus a non-cached manifest pointer.
- For 0005 basemap attribution, use linked `Grundkarte: basemap.at`/`Datenquelle: basemap.at` and do not add OpenStreetMap attribution unless a future displayed source requires it.
