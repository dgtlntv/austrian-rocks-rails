# State
- Updated: 2026-06-10 (0006-P3 sprite+styles+crossfade done; gate green)
- Current focus: 0006 — Polish web map interactions on MapLibre

## Active
- [0006] implementing (plan approved 2026-06-10) — P1 DB/admin and P2 exporter/tile contract done and reviewed. P3 done (gate green: 76 runs/2531 assertions, rubocop clean): sprite pipeline + Apple-Maps-style pins (resting disc / selected balloon+dot, human-approved design), selected layers with `-1` sentinels, z14→15 crossfade, Bergwerk sprite dependency removed. Next: `/incant:review 0006` (P3 gate), then P4 selection/card runtime (note: P4 must also exclude the selected id from base layers — see plan Status). Remaining: P5 entry points+popup removal, P6 docs/release/smoke. Branch `incant/0006-maplibre-web-interactions`. Inter font self-hosting split to inbox.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
