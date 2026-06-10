---
id: "0006"
slug: maplibre-web-interactions
stage: review
reviewed: 2026-06-10
commit: 15879a50
---

# Maplibre Web Interactions — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

> Scope of this pass: **phase gate for 0006-P4** through commit `15879a50`.
> Prior P1/P2/P3 findings remain addressed/wontfix/clean as previously recorded; P5–P6 and the remaining search/deep-link/release acceptance criteria are reviewed at later gates / before release.

### Strengths
- app/javascript/map/selection.js:1-12,49-72 — the selection state machine documents the no-`feature-state` contract, enforces a single current selection, clears to the `-1` sentinel, and restores mutated state on deselect.
- app/javascript/map/selection.js:82-102 — selected region/cluster/area/POI ids are excluded from the resting symbol layer, addressing the P3 follow-up so the base pin does not render under the selected balloon while leaving problem grade filters untouched.
- app/javascript/map/selection.js:110-150 — the grow tween is isolated from the controller and handles both symbol `icon-size` and problem `circle-radius` with cancellation/reset paths.
- app/javascript/map/info_card.js:59-149,158-181,234-280 — card DOM is built with `createElement`/`textContent`, cover/guidebook/parking/POI URLs pass an HTTP(S) allowlist, stale cover images remove themselves, and outbound links use `noopener noreferrer`.
- app/javascript/controllers/map_controller.js:271-340,365-402 — the controller now routes problem/POI/pin/hull clicks through selection + card rendering, clears on real background clicks, and gives region cards the planned main-cluster-bounds CTA fallback path.
- app/helpers/map_helper.rb:12-26, config/locales/en.yml:184-193, config/locales/de.yml:193-202, app/views/map/index.html.erb:20-43 — localized card strings and the area-id/card targets are wired from Rails markup without introducing runtime string literals.
- test/controllers/map_controller_test.rb:36-55 — server-side coverage verifies the card target, localized string payload, and `data-map-area-id-value` needed by the P4/P5 controller work.
- Commit history follows incant conventions (`incant 0006-P4: selection runtime + info card`). Fresh P4 gate run in this session passed in Docker/PostGIS: `bin/rails db:prepare && bin/rails test test/controllers/map_controller_test.rb test/controllers/mapping/contribution_requests_controller_test.rb && bin/importmap audit && bin/rubocop -f github` → 9 runs, 171 assertions, 0 failures/errors; importmap audit found no vulnerable packages; rubocop exited clean.

### Blocker
- app/javascript/controllers/map_controller.js:411-421 and app/javascript/map/info_card.js:10 — desktop card placement can cover the selected pin with no corrective padding or camera adjustment. `adjustSheetPadding` returns immediately at `lg` and up, while the card is fixed at `lg:left-4 lg:top-4 lg:w-96`; selecting any feature under that docked panel area at ≥1280px will hide the selected pin, failing the spec acceptance criterion that the selected pin remains visible in both bottom-sheet and docked-panel layouts. Fix: for desktop, either reserve left/top padding while the docked panel is open or detect overlap between `map.project(lngLat)` and the card bounding rect and `easeTo`/offset the camera until the selected coordinate is outside the panel. status: open

### Major
(none)

### Minor
(none)

### Nit
(none)

### Verdict
Ready to release? **No** — one open blocker. P4 is otherwise well-structured and its automated gate is green, but the docked-card visibility acceptance criterion needs a revise loop before moving on.
