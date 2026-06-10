# State
- Updated: 2026-06-10 (0006-P2 reviewed; review-fix gate green)
- Current focus: 0006 — Polish web map interactions on MapLibre

## Active
- [0006] implementing (plan approved 2026-06-10) — P1 DB/admin done and reviewed; P2 exporter cascade/card tile contract reviewed with major wontfix and minor addressed (gate green: 66 runs/1947 assertions, rubocop clean). Next: `/incant:implement 0006` for P3 sprite+styles+crossfade. Remaining: P4 selection/card runtime, P5 entry points+popup removal, P6 docs/release/smoke. Branch `incant/0006-maplibre-web-interactions`. Inter font self-hosting split to inbox.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
