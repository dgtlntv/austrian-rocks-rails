# Austrian Rocks map sprite icons

Source icons for the self-hosted MapLibre sprite. `MapTiles::SpriteBuilder` packs the
committed PNGs into `sprite.png`/`sprite.json` (and `@2x`) at publish time; the SVGs are
the editable sources and are **not** read by the pipeline.

## Icon inventory

| Icon | Resting (1x) | Selected (1x) | Used by layer |
|---|---|---|---|
| `ar-pin-region` / `ar-pin-region-selected` | 20×20 | 34×45 | `regions` / `regions-selected` |
| `ar-pin-cluster` / `ar-pin-cluster-selected` | 20×20 | 34×45 | `clusters` / `clusters-selected` |
| `ar-pin-area` / `ar-pin-area-selected` | 20×20 | 34×45 | `areas` / `areas-selected` |
| `ar-pin-parking` / `ar-pin-parking-selected` | 20×20 | 34×45 | `pois` / `pois-selected` (`poiType` ≠ `train_station`) |
| `ar-pin-train` / `ar-pin-train-selected` | 20×20 | 34×45 | `pois` / `pois-selected` (`poiType` = `train_station`) |

Every icon ships at 1x and 2x (`@2x` suffix, exactly double the 1x pixel size). The
builder fails if either variant of a name is missing.

## Design

- **Resting**: colored disc (9px radius) with a white glyph and a 1.5px white ring,
  centered on the feature (`icon-anchor: center`). The name label renders beside the
  disc (`text-anchor: left`).
- **Selected**: Apple-Maps-style balloon — a 15px-radius bubble with a short tail that
  blends smoothly into the circle and points at a small anchor dot marking the feature
  location. The dot center sits 4px above the canvas bottom (1x), so selected layers use
  `icon-anchor: "bottom"` with `icon-offset: [0, 4]` to land the dot exactly on the
  feature coordinate; the offset scales with `icon-size`, so the grow animation keeps
  the dot anchored.
- Colors: climbing entities use brand red `#ef3340`; parking uses `#3173de`; train
  stations use `#5a6b7a`. Glyphs are white.

## Regenerating the PNGs

Edit the SVGs, then rasterize them with librsvg-backed libvips inside the dev container
(host ImageMagick mangles SVG strokes — don't use it):

```sh
docker compose run --rm --no-deps web bash -lc 'bundle exec ruby -e "
require \"vips\"
Dir.glob(\"config/map_styles/sprite/*.svg\").sort.each do |svg|
  base = svg.sub(/\.svg\z/, \"\")
  Vips::Image.new_from_file(svg).write_to_file(\"#{base}.png\")
  Vips::Image.new_from_file(svg, scale: 2).write_to_file(\"#{base}@2x.png\")
end
"'
```
