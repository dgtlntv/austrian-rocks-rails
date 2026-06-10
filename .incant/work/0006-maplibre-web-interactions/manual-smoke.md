# Manual smoke checklist — 0006 P6

Use this file to record the human-run browser smoke for the MapLibre interaction contract.

## Run details

| Field | Value |
|---|---|
| Date/time |  |
| Tester |  |
| Environment | Docker dev / other:  |
| Release version |  |
| Manifest URL | `https://tiles.austrian.rocks/map_tiles/current.json` |
| Light style URL |  |
| Dark style URL |  |
| PMTiles URL |  |
| Browser + version |  |
| Data set notes |  |

## Checklist

| Area | Check | Result / observations |
|---|---|---|
| Release | Publish/load an e2e release built from this branch; confirm manifest includes `pmtilesUrl`, `styles.light`, `styles.dark`, and `spriteUrl`. |  |
| Light pins | On `/en/map`, verify region pins render as sprite icons with labels at low zoom. |  |
| Light pins | Zoom into cluster level; verify cluster pins render as sprite icons with labels. |  |
| Light pins | Zoom into area level; verify area pins render as sprite icons with labels. |  |
| Light pins | If POI data exists, verify parking/train POI pins render with the right icon and label. |  |
| Dark style | Load the published dark style JSON directly (or via a temporary style override) and verify the same region/cluster/area/POI pins render. |  |
| Selection | Select a region pin; selected balloon grows, resting pin disappears underneath, info card opens. |  |
| Selection | Select a cluster pin; previous selection clears, selected balloon/card updates. |  |
| Selection | Select an area pin; previous selection clears, selected balloon/card updates. |  |
| Selection | Select a POI pin; selected balloon/card opens with type and Directions CTA when `googleUrl` exists. |  |
| Selection | Select a problem; selected circle grows and problem card opens with grade/details CTA. |  |
| Selection | Tap empty map and use the card close button; selection clears, card hides, map padding resets. |  |
| Responsive | At about 375px width, card appears as a bottom sheet; selected pin remains visible above/after padding adjustment. |  |
| Responsive | At 1280px+ width, card appears as a docked side panel; selected pin remains visible beside/after padding adjustment. |  |
| Card content | Region/cluster/area cards show expected title, cover if present, problem count, grade range, warning if present, guidebook if present, parking/Directions if present. |  |
| CTAs | Area/cluster “Show on map” fits entity bounds and closes the card. |  |
| CTAs | Maltatal region “Show on map” lands on main-cluster bounds/boulders, not empty region center. |  |
| CTAs | A region without main-cluster bounds falls back to full region bounds. |  |
| Crossfade | Around z14→z15, area hull opacity fades down while boulders fade up. |  |
| Crossfade | Below z14, boulders are not visible. |  |
| Crossfade | Above z15, hulls are gone and boulders are fully visible; no simultaneous full-opacity hull+boulder outside the crossfade. |  |
| Search | Search result → problem opens the selected problem/card flow, not a legacy popup. |  |
| Search | Search result → area opens the selected area/card flow. |  |
| Deep links | `/en/map?pid=<problem-id>` opens the selected problem/card flow. |  |
| Deep links | `/en/map?problem=<problem-id>` opens the selected problem/card flow. |  |
| Deep links | Area slug route / `?slug=` flow opens the selected area/card flow. |  |
| History/hash | Existing map hash/history behavior still works; query parameters are cleaned when moving the map. |  |
| Contribution overlay | `/en/mapping/map` contribution popups still open and are not replaced by the new card flow. |  |
| Localization | Repeat representative card checks in `/de/map`; static card strings are German and tile-provided localized fields prefer `*En` only on English. |  |
| Security sanity | Card text from tile properties is displayed as text, not interpreted as HTML; external links open with expected HTTP(S) destinations. |  |
| Console/network | No new application JS errors during the checks; expected third-party tile 410s, if any, are noted separately. |  |

## Notes / issues found

- 
