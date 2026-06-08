# State
- Updated: 2026-06-08 (0008 post-review E2E fixes implemented; awaiting re-review)
- Current focus: 0008 — PMTiles E2E publish readiness with Dockerized Felt Tippecanoe and Rails config

## Active
- 0008 review — work/0008-pmtiles-e2e-docker-config (post-review E2E fixes committed; run `/incant:review 0008`)

## Cross-cutting notes / blockers
- Database commands/tests for map-data work should run against Docker-hosted PostgreSQL/PostGIS, not a host-created database.
