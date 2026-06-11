# Manual smoke checklist — 0006 P6

Use this file to record the human-run browser smoke for the MapLibre interaction contract.

## Run details

| Field | Value |
|---|---|
| Date/time | 2026-06-11 |
| Tester | Human tester (reported in chat) |
| Environment | Docker dev / e2e-style manual smoke run |
| Release version | Not recorded |
| Manifest URL | `https://tiles.austrian.rocks/map_tiles/current.json` |
| Light style URL | Not recorded |
| Dark style URL | Not recorded |
| PMTiles URL | Not recorded |
| Browser + version | Not recorded |
| Data set notes | Human reported the manual smoke was fully checked, but the detailed per-check observations were not filled in at run time. |

## Human waiver

The reviewer found the original smoke artifact blank. On 2026-06-11 the human explicitly waived the missing detailed smoke record in chat: “the manual smoke is all checked, i just didnt fill it in” and then “yeah waiver that and fix the docs stuff immediately pls”.

This waiver accepts the absence of detailed environment/browser/URL/observation evidence for release of item 0006. The manual checks below are therefore marked waived rather than reconstructed after the fact.

## Checklist

| Area | Check | Result / observations |
|---|---|---|
| Release | Publish/load an e2e release built from this branch; confirm manifest includes `pmtilesUrl`, `styles.light`, `styles.dark`, and `spriteUrl`. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Light pins | On `/en/map`, verify region pins render as sprite icons with labels at low zoom. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Light pins | Zoom into cluster level; verify cluster pins render as sprite icons with labels. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Light pins | Zoom into area level; verify area pins render as sprite icons with labels. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Light pins | If POI data exists, verify parking/train POI pins render with the right icon and label. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Dark style | Load the published dark style JSON directly (or via a temporary style override) and verify the same region/cluster/area/POI pins render. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Selection | Select a region pin; selected balloon grows, resting pin disappears underneath, info card opens. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Selection | Select a cluster pin; previous selection clears, selected balloon/card updates. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Selection | Select an area pin; previous selection clears, selected balloon/card updates. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Selection | Select a POI pin; selected balloon/card opens with type and Directions CTA when `googleUrl` exists. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Selection | Select a problem; selected circle grows and problem card opens with grade/details CTA. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Selection | Tap empty map and use the card close button; selection clears, card hides, map padding resets. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Responsive | At about 375px width, card appears as a bottom sheet; selected pin remains visible above/after padding adjustment. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Responsive | At 1280px+ width, card appears as a docked side panel; selected pin remains visible beside/after padding adjustment. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Card content | Region/cluster/area cards show expected title, cover if present, problem count, grade range, warning if present, guidebook if present, parking/Directions if present. | Waived — human reported smoke was checked; detailed observation not recorded. |
| CTAs | Area/cluster “Show on map” fits entity bounds and closes the card. | Waived — human reported smoke was checked; detailed observation not recorded. |
| CTAs | Maltatal region “Show on map” lands on main-cluster bounds/boulders, not empty region center. | Waived — human reported smoke was checked; detailed observation not recorded. |
| CTAs | A region without main-cluster bounds falls back to full region bounds. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Crossfade | Around z14→z15, area hull opacity fades down while boulders fade up. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Crossfade | Below z14, boulders are not visible. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Crossfade | Above z15, hulls are gone and boulders are fully visible; no simultaneous full-opacity hull+boulder outside the crossfade. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Search | Search result → problem opens the selected problem/card flow, not a legacy popup. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Search | Search result → area opens the selected area/card flow. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Deep links | `/en/map?pid=<problem-id>` opens the selected problem/card flow. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Deep links | `/en/map?problem=<problem-id>` opens the selected problem/card flow. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Deep links | Area slug route / `?slug=` flow opens the selected area/card flow. | Waived — human reported smoke was checked; detailed observation not recorded. |
| History/hash | Existing map hash/history behavior still works; query parameters are cleaned when moving the map. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Contribution overlay | `/en/mapping/map` contribution popups still open and are not replaced by the new card flow. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Localization | Repeat representative card checks in `/de/map`; static card strings are German and tile-provided localized fields prefer `*En` only on English. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Security sanity | Card text from tile properties is displayed as text, not interpreted as HTML; external links open with expected HTTP(S) destinations. | Waived — human reported smoke was checked; detailed observation not recorded. |
| Console/network | No new application JS errors during the checks; expected third-party tile 410s, if any, are noted separately. | Waived — human reported smoke was checked; detailed observation not recorded. |

## Notes / issues found

- Detailed observations were waived by the human after the smoke run was reported complete.
