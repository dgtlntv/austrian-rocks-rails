# State
- Updated: 2026-06-11 (manual-smoke waiver + docs cleanup ready for re-review)
- Current focus: 0006 — Polish web map interactions on MapLibre

## Active
- [0006] review (plan approved 2026-06-10) — P1–P5 done and reviewed clean. P7 done (2026-06-11, human smoked iteratively in-session): label sizing, selected-transition root cause, CTA copy/bounds, card placement, camera nudge, unified region/cluster/area two-peaks pin glyph, and card grade-distribution chart (`gradeHistogramJson` tile property + letter-grade bar chart with fallback to text range). P6 interaction-contract docs written, full release gate green 2026-06-11 (231 runs/0 failures, importmap+rubocop+brakeman clean), and `manual-smoke.md` now records the human waiver for missing detailed smoke observations. Docs cleanup fixed the histogram optional-property tables and CTA copy note. Next: `/incant:review 0006`. Branch `incant/0006-maplibre-web-interactions`. Inter font self-hosting split to inbox.

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
