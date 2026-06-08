---
id: "0008"
slug: pmtiles-e2e-docker-config
stage: archived
completed: 2026-06-08
commit: 4f41dc0c
---

# PMTiles E2E Publish-Ready With Dockerized Felt Tippecanoe And Rails Config — summary

## What was built
Moved PMTiles pipeline from env-only configuration to a tracked `config/map_tiles.yml` with env-specific settings (artifact basename `austrian-rocks`, output dir `tmp/map_tiles`, CDN host `tiles.austrian.rocks`, development prefix `map_tiles/e2e`, production prefix `map_tiles`, optional production layer `pois`). `MapTiles::Configuration` now loads from Rails config, accepts an explicit per-run version argument, and no longer supports legacy `MAP_TILES_*` non-secret env overrides; Bunny S3 credentials remain env-provided secrets.

CLI commands `build`, `smoke`, and `publish` require `--version=<safe-segment>`; `export` runs without a version. `publish` runs production smoke by default; `--skip-smoke` is the only bypass. Duplicate `--version` is rejected, and space-form arguments are safely parsed. Rails tasks mirror the CLI with explicit task arguments.

Production smoke now permits zero-feature `pois` (the only optional production layer) while keeping `walking_paths`, `problems`, `boulders`, `areas`, `area_hulls`, `clusters`, `cluster_hulls`, `regions`, and `region_hulls` strictly required. PMTiles metadata comparison derives expected layers from actual GeoJSON counts. Dataful `pois` still receives full geometry/property/forbidden-field validation.

Felt Tippecanoe `2.79.0` is built from `https://github.com/felt/tippecanoe` in both `Dockerfile.dev` (direct install) and `Dockerfile` (throw-away build stage, only `tippecanoe`/`tippecanoe-decode`/`tile-join` binaries land in the runtime image). Missing-binary guidance references Felt Tippecanoe and Dockerized availability.

`LocalArtifactCleaner` prunes old local PMTiles artifacts and metadata older than 14 days from `tmp/map_tiles/` after successful publish, keeping the current artifact and never touching remote Bunny objects or GeoJSON files.

A latent `area_hulls` contract violation was fixed: `shortName` is no longer exported in `area_hulls` properties (not in the layer contract) and remains only in the `areas` point layer where the contract allows it. Path-segment sanitization was hardened to reject `.` and `..` traversal values beyond the spec.

## Deviations from spec
None — all 17 acceptance criteria met as specified.

## Key decisions
- Stable non-secret values in `config/map_tiles.yml`, secrets in env, version as a command argument.
- `pois` is the only optional production layer; `walking_paths` and all core layers remain required.
- Felt Tippecanoe `2.79.0` pinned; Mapbox repository never used.
- Production Docker uses multi-stage build to keep compiler deps out of the runtime image.
- Local cleanup uses 14-day conservative retention window.

## Links
- Branch: `incant/0008-pmtiles-e2e-docker-config`
- Commits: `incant 0008: spec` → `incant 0008: plan` → `incant 0008-P1: config-backed PMTiles commands` → `incant 0008-P2: allow empty production POIs` → `incant 0008-P2: address POI E2E review` → `incant 0008-P3: dockerize Felt Tippecanoe` → `incant 0008-P3: address PMTiles E2E publish findings`

## Sessions
- `019ea3cf-3200-7774-8fd3-f663e42a3507`
- `019ea69a-f626-7da5-87bd-8b4cbcdb8c53`
- `019ea6a3-467f-72f0-8fe8-368ecfd26bd3`
- `019ea6ab-e8d7-7b79-a950-092b3588dcfe`
- `019ea6ae-bc93-7e20-9483-16887f394c2c`
- `019ea6b3-d6df-77f6-a99b-76aabba440d9`
- `019ea6b7-4a6c-7c14-89db-6112a3ce9a0b`
- `019ea6bc-0b43-7763-87ac-0ad46863b6dc`
- `019ea6bf-b974-70ae-ac01-f1bec73c8dc8`
- `019ea6df-1c98-743c-a471-45c21afb2b95`
- `019ea751-025f-7b75-b6a8-ff2158f41779`
- `019ea76c-6829-7810-91d0-f559323c21ea`

## Follow-ups
None — the operator-triggered publish UI/background job was already captured as a separate inbox item during spec.
