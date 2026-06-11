---
id: "0006"
slug: maplibre-web-interactions
stage: review
reviewed: 2026-06-11
commit: 10b3a734
---

# Maplibre Web Interactions — final re-review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

> Scope of this pass: **final re-review after the smoke-waiver/docs-cleanup commit** through `10b3a734` on branch `incant/0006-maplibre-web-interactions`, against spec base `caafed8c`.
>
> Fresh verification this pass: the smoke-waiver/docs content check passes on disk (`manual-smoke.md` has the waiver, no blank smoke table cells; `docs/map_tiles.md` has six `gradeHistogramJson` optional-property entries and the current “Zoom to place” / “Zum Ort zoomen” CTA copy) and `git diff --check` is clean. I did not re-run the full Rails gate because the post-`ecdbd687` product-code diff is review/artifact-only; the previous full release gate remains the latest code-path evidence (`231 runs, 3383 assertions, 0 failures/errors; importmap/rubocop/brakeman clean`). The human clarified that `docs/map_tiles.md` being under ignored `/docs/` is intentional for this repo, so that is not treated as a release blocker.

### Strengths
- .incant/work/0006-maplibre-web-interactions/manual-smoke.md:20-24 — the previously blank manual-smoke artifact now records the human's explicit waiver instead of inventing missing observations after the run.
- docs/map_tiles.md:155-170,226-271 — the contract text on disk now documents `gradeHistogramJson` in the card mapping and all six climbing-entity optional-property lists, and the CTA prose uses the current web copy.
- lib/map_tiles/geojson_exporter.rb:285-329,347-385 — exporter-side cascade semantics, aggregate problem stats, `gradeHistogramJson`, cover/guidebook/parking fields, and main-cluster bounds remain centralized in tile properties, keeping web/mobile clients on one contract.
- app/javascript/map/selection.js:1-35,56-84 — selection remains implemented with dedicated filtered `-selected` layers, a `-1` sentinel, base-symbol exclusion, and no `feature-state`, matching the approved MapLibre Native-compatible model.
- app/javascript/map/info_card.js:1-30,381-428 — card rendering keeps the untrusted tile-data boundary explicit and the grade-distribution chart has a clear fallback path for older tiles.
- app/javascript/controllers/map_controller.js:377-390,492-518,542-583,691-697,821-834 — search/deep-link selection, main-cluster-bounds CTA logic, removal of the old zoom-15 clamp, and conditional card-visibility nudges are still defensive and aligned with the spec.

### Blocker
- .incant/work/0006-maplibre-web-interactions/manual-smoke.md:20-24 — prior blocker addressed: the human explicitly waived the missing detailed smoke observations, and the artifact now records that waiver plus marks the checklist rows as waived. status: addressed

### Major
(none)

### Minor
- docs/map_tiles.md:155-170,226-271 — prior minor contract-content drift is addressed on disk: `gradeHistogramJson` is in the card mapping and all relevant optional-property lists, and the CTA note names the current copy. The file remaining ignored/untracked is intentional per human clarification, so there is no release finding for that repository policy. status: addressed

### Nit
(none)

### Verdict
Ready to release? **Yes** — no open blocker or major findings remain. The manual-smoke observation gap is explicitly waived by the human, the contract-content drift is corrected on disk, and the code-path release gate evidence remains green.
