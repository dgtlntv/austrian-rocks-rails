# State
- Updated: 2026-06-10 (0006-P1 phase review passed; all findings addressed, gate green after fixes)
- Current focus: 0006 — Polish web map interactions on MapLibre

## Active
- [0006] implementing (plan approved 2026-06-10) — P1 DB/admin done, phase-reviewed, all review findings addressed (gate re-run green: 112 runs/415 assertions, rubocop clean). Next: P2 exporter cascade. Remaining: P3 sprite+styles+crossfade, P4 selection/card runtime, P5 entry points+popup removal, P6 docs/release/smoke. Branch `incant/0006-maplibre-web-interactions`. Inter font self-hosting split to inbox.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
