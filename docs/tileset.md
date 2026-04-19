# Mapbox Tileset Management

## Overview

The map displays data from **Mapbox vector tilesets** — static, pre-processed datasets hosted on Mapbox's servers. This means changes to the database (e.g. updating problem locations) do **not** automatically appear on the map. You need to export the data and re-upload the tileset.

**Tileset ≠ Style**: A tileset is the raw data (coordinates, properties). A style (edited in the Style Editor) controls how that data looks (colors, sizes, labels). When updating data, you only touch tilesets.

Current tileset references in `app/javascript/controllers/mapbox_controller.js`:
- **Problems + Boulders**: `mapbox://dgtlntv.95ifk802` (source-layer: `problems_8-85f5eq`)

## Updating Problem Locations & Boulder Outlines

### Step 1: Import updated GeoJSON via Admin UI

Go to **Admin > Imports** and upload your GeoJSON file.

**Required properties for the importer to pick up features:**
- **Problems** (Point features): must have `problemId`
- **Boulders** (LineString/Polygon features): must have `boulderId` key

Features missing these property keys will be **silently ignored** by the importer.

**Updating vs. creating:**
- `"boulderId": 123` — updates existing boulder #123
- `"boulderId": ""` or `"boulderId": null` — creates a **new** boulder
- No `boulderId` key at all — feature is ignored

Same logic applies to `problemId`, `clusterId`, and `regionId`.

Example — update existing problem:
```json
{
  "type": "Feature",
  "properties": { "name": "Crimp Pimp", "problemId": 123 },
  "geometry": { "type": "Point", "coordinates": [13.446, 47.003] }
}
```

Example — update existing boulder:
```json
{
  "type": "Feature",
  "properties": { "name": "Ficki Ficki", "boulderId": 42 },
  "geometry": { "type": "LineString", "coordinates": [[13.446, 47.003], ...] }
}
```

Example — create new boulder:
```json
{
  "type": "Feature",
  "properties": { "name": "New Boulder", "boulderId": "" },
  "geometry": { "type": "LineString", "coordinates": [[13.446, 47.003], ...] }
}
```

**Note on conflicts**: The importer flags changes as "Conflict" when the feature includes an `updatedAt` property that doesn't match the database record's `updated_at`. If your GeoJSON doesn't include `updatedAt`, no conflicts will be flagged and you can apply freely.

### Step 2: Export problems.geojson

After the import is applied to the database, export the data for Mapbox:

**Option A — Admin UI**: Go to **Admin > Problems** and click **"Export problems.geojson (with boulders)"**.

**Option B — Rake task**:
```bash
rake mapbox:problems include_boulders=true
```

### Step 3: Upload tileset to Mapbox Studio

1. Go to https://studio.mapbox.com/tilesets/
2. Find the problems tileset (currently `dgtlntv.95ifk802`)
3. Click on it, then click **"Replace"**
4. Upload the exported `problems.geojson`
5. Wait for processing to complete

Replacing keeps the same tileset ID — no code changes needed.

**If you can't replace and have to create a new tileset**: upload via "New tileset", then update two values in `mapbox_controller.js`:
- The tileset URL: `url: "mapbox://dgtlntv.<new-id>"`
- The source-layer name (find it on the tileset details page under "Source layers")

### Step 4: Deploy

If you changed any code (tileset ID/source-layer), deploy for it to take effect.

## Other Tilesets

The same export → upload flow applies to other map layers:

| Layer | Admin Export | Rake Task | Notes |
|-------|-------------|-----------|-------|
| Problems + Boulders | Admin > Problems > Export (with boulders) | `rake mapbox:problems include_boulders=true` | Most common update |
| Areas | Admin > Areas > Export | `rake mapbox:areas` | |
| Clusters | Admin > Clusters > Export | `rake mapbox:clusters` | |
| Regions | Admin > Regions > Export | `rake mapbox:regions` | |

## Troubleshooting

### Problems don't appear on the map after import
- The import only updates the **database**. You still need to export and re-upload the tileset (Steps 2-3).

### Boulder outlines not updating via import
- Make sure each boulder LineString/Polygon feature has a `boulderId` property. Without it, the importer ignores the feature.

### Import shows all changes as "Conflict"
- This happens when `updatedAt` is missing from the GeoJSON features. Fixed as of April 2026 — conflicts are now only flagged when `updatedAt` is present and doesn't match.

### Tileset ID or source-layer changed
- If you had to create a new tileset instead of replacing, update both `url` and `source-layer` in `mapbox_controller.js`.
