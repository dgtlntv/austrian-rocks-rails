# State
- Updated: 2026-06-10 (0006-P1 committed, ready for phase review)
- Current focus: 0006 — Polish web map interactions on MapLibre

## Active
- [0006] implementing (plan approved 2026-06-10) — P1 DB/admin done (warnings on clusters/regions, Guidebook model + admin CRUD, parking-POI links; gate green in Docker). Next: review P1, then P2 exporter cascade. Remaining: P3 sprite+styles+crossfade, P4 selection/card runtime, P5 entry points+popup removal, P6 docs/release/smoke. Branch `incant/0006-maplibre-web-interactions`. Inter font self-hosting split to inbox.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
