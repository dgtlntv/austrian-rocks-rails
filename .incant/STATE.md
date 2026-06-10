# State
- Updated: 2026-06-10 (0006-P4 selection runtime + info card done; gate green)
- Current focus: 0006 — Polish web map interactions on MapLibre

## Active
- [0006] implementing (plan approved 2026-06-10) — P1 DB/admin, P2 exporter/tile contract, P3 sprite/pins/crossfade done and reviewed clean. P4 done (gate green: 9 runs/171 assertions, importmap audit clean, rubocop clean): `map/selection.js` (single-selection invariant, sentinel filters, base-layer exclusion incl. the P3 note, grow tween), `map/info_card.js` (safe-DOM responsive card), controller select wiring + background deselect + bottom-sheet padding, `map_card_strings` + de/en `views.map.card.*` locales, view card target/data attributes. Next: `/incant:review 0006` (P4 gate), then P5 search/deep-link integration + popup removal + zoom-clamp fix. Remaining after that: P6 docs/release/smoke. Branch `incant/0006-maplibre-web-interactions`. Inter font self-hosting split to inbox.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
