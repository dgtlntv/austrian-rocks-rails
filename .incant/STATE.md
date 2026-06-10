# State
- Updated: 2026-06-10 (0006-P5 complete — search/deep links select cards; gate green)
- Current focus: 0006 — Polish web map interactions on MapLibre

## Active
- [0006] review (plan approved 2026-06-10) — P1 DB/admin, P2 exporter/tile contract, P3 sprite/pins/crossfade done and reviewed clean. P4 selection runtime + info card done and re-reviewed with no open blocker/major findings after the docked-panel padding fix. P5 done (gate green: 8 runs/163 assertions, rubocop clean): search `gotoproblem`/`gotoarea` and `?pid=`/`?slug=` deep links now call `selectFeatureWhenIdle` to select tile features and open cards; legacy problem popup/deferred replay code removed; `flyToBounds` no longer clamps to zoom 15. Next: `/incant:review 0006` (P5 review), then P6 docs/release/smoke. Branch `incant/0006-maplibre-web-interactions`. Inter font self-hosting split to inbox.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
