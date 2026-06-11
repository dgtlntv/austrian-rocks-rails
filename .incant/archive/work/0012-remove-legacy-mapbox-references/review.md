---
id: "0012"
slug: remove-legacy-mapbox-references
stage: review
reviewed: 2026-06-11
commit: d9c43975
---

# Remove Legacy Mapbox References — review

### Strengths
- `lib/tasks/mapbox.rake` — the obsolete `mapbox:*` namespace and all legacy `../#{BRAND_CONFIG[:slug]}-maps/mapbox/*.geojson` outputs were removed completely, matching the delete-not-rename requirement.
- `config/deploy.yml:92` — the deploy volumes now retain only `austrian_rocks_export:/rails/export`; the stale `austrian_rocks_mapbox` mount/path is gone without introducing a replacement persistent legacy export path.
- `app/controllers/admin/maps_controller.rb:17` and `config/routes.rb:108` — incidental Mapbox wording was replaced with neutral current-behaviour comments while preserving `marker-color`, GeoJSON rendering, downloads, and redirect route behaviour.
- Acceptance and active principles are covered: the change is removal-only with no new config or secrets, preserves intentional Mapbox-negative tests, and the fresh Docker-backed gate passed (`23 runs, 1176 assertions, 0 failures, 0 errors, 0 skips`; Rails task discovery had no `mapbox` matches).

### Blocker
None.

### Major
None.

### Minor
None.

### Nit
None.

### Verdict
Ready to release? **Yes** — the implementation satisfies the spec and plan, the targeted Docker-backed quality gate passes, and there are no open blocker or major findings.
