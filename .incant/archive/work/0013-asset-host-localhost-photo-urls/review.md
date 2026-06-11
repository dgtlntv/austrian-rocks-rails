---
id: "0013"
slug: asset-host-localhost-photo-urls
stage: review
reviewed: 2026-06-11
commit: e64cf0ac94cf072a407989bcc672d82042fa3bb0
---

# Asset Host Localhost Photo Urls — review

### Strengths
- lib/map_tiles/geojson_exporter.rb:10-17 — The exporter now centralizes the missing-host failure mode with `MissingAssetHostError` and a clear operator-facing message, satisfying the spec without adding a second configuration source.
- lib/map_tiles/geojson_exporter.rb:408-417 — `cdn_image_url` still receives `expires_in: nil`, but the host now comes from `required_asset_host`; the removed localhost fallback means configured Active Storage proxy URLs remain deterministic without publishing local-network hosts.
- test/lib/map_tiles/geojson_exporter_test.rb:17-29 — Tests explicitly set and restore `Rails.application.config.asset_host`, so existing exporter coverage no longer depends on ambient Rails defaults.
- test/lib/map_tiles/geojson_exporter_test.rb:213-224 and test/lib/map_tiles/geojson_exporter_test.rb:250-256 — Cover and topo success paths assert the configured HTTPS host, proxy representation route, deterministic fallback behavior, and absence of localhost.
- test/lib/map_tiles/geojson_exporter_test.rb:264-309 — Blank-host behavior is covered for no-photo exports and for both cover-photo and topo-photo failure paths.

### Blocker
- None.

### Major
- None.

### Minor
- None.

### Nit
- None.

### Verdict
Ready to release? **Yes** — the implementation meets the acceptance criteria and the fresh quality gate passed: `! rg -n "localhost|http://localhost:3000" lib/map_tiles/geojson_exporter.rb` plus the Docker-backed `bin/rails test test/lib/map_tiles/geojson_exporter_test.rb` completed with 13 runs, 208 assertions, 0 failures, and 0 errors.
