# State
- Updated: 2026-06-10 (P5 re-reviewed; P7 added for human-smoke UX polish)
- Current focus: 0006 — Polish web map interactions on MapLibre

## Active
- [0006] implement (plan approved 2026-06-10) — P1 DB/admin, P2 exporter/tile contract, P3 sprite/pins/crossfade done and reviewed clean. P4 selection runtime + info card done and re-reviewed with no open blocker/major findings after the docked-panel padding fix. P5 done and re-reviewed after the `?problem=` alias blocker fix. Next: P6 docs/release/smoke, then newly added P7 human-smoke interaction polish (pin label sizing/spacing, selected animation, card CTA/close/placement, smoother conditional map padding, card stats, region pin sizing) before final release review. Branch `incant/0006-maplibre-web-interactions`. Inter font self-hosting split to inbox.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
