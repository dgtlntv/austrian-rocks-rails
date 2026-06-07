# Austrian Rocks PMTiles Overlay Contract

This is the committed consumer and maintainer contract for the Austrian Rocks PMTiles overlay artifact. It is intentionally kept under `.incant/work/0004-pmtiles-overlay-contract/` for this item; `/docs/` remains gitignored and `docs/map_tiles.md` must not be committed here.

## Artifact and delivery rules

- Artifact basename: `austrian-rocks`.
- File type: PMTiles built with Tippecanoe from deterministic per-layer GeoJSON exports.
- native max zoom: `16` for every source layer. MapLibre, web, and iOS clients may overzoom above `16`.
- Generated files are build artifacts only and must stay under ignored output such as `tmp/map_tiles/`; production must not depend on Rails serving `public/maps/austrian-rocks.pmtiles`.
- Bunny/CDN publication writes both:
  - Immutable version: `<prefix>/austrian-rocks-<version>.pmtiles`
  - Stable latest: `<prefix>/austrian-rocks-latest.pmtiles`
- Public URLs are built from map-specific CDN configuration plus the object key, for example `https://<MAP_TILES_PUBLIC_CDN_HOST>/<prefix>/austrian-rocks-<version>.pmtiles`.
- Bunny storage credentials may reuse the existing Bunny S3-compatible environment variables, but map tile CDN host, object prefix, and version are map-specific configuration.

## Naming and data rules

- Source layer names are snake_case and stable.
- Feature properties are camelCase, scalar vector-tile values. If relationship metadata needs structure, encode it as a documented JSON string.
- Feature IDs are stable scalar model identifiers exposed as explicit properties such as `problemId`, `areaId`, or `walkingPathId`.
- Consumers must build app navigation from IDs and slugs. PMTiles features must not contain app-local canonical URL properties.
- Localized labels use required `name` plus optional `nameEn` only when an English value exists and differs from `name`. If a model has no English source field, omit `nameEn`.
- POIs may include external `googleUrl`; this is not an app-local canonical URL.
- Circuit layers and circuit properties are intentionally excluded and must not be introduced.
- `problems.boulderId` is optional and comes from the database relationship cleanup delivered by completed item `0007`.
- `walking_paths` reads published line geometry from the `WalkingPath` source delivered by completed item `0007`; `0004` must not add or recreate walking-path schema/admin foundations.

## PMTiles source layers vs MapLibre style layers

The layers below are PMTiles source layers. Later MapLibre styles can derive many visual style layers from the same source layer:

- Region, cluster, area, and boulder text labels can render from `regions`, `clusters`, `areas`, and `boulders`.
- Polygon fills and outline line styles can render from `region_hulls`, `cluster_hulls`, `area_hulls`, and `boulders`.
- `walking_paths` renders as one or more line style layers.
- Problem symbols, boulder labels, POI symbols, and POI labels can be separate style layers without changing this source contract.

## Source layer contract

### `problems`

- Geometry: `Point`
- Stable identifier: `problemId`
- Required properties: `problemId`, `areaId`, `areaSlug`, `name`, `grade`, `steepness`, `featured`
- Optional properties: `boulderId`, `nameEn`, `popularity`, `landing`, `height`, `parentProblemId`
- Source notes: export only problems with locations in published areas. `boulderId` is present only when the `0007` relationship assignment knows the containing boulder.
- Navigation: open a problem by `problemId`, optionally scoped by `areaSlug`.

### `boulders`

- Geometry: `Polygon`
- Stable identifier: `boulderId`
- Required properties: `boulderId`, `areaId`, `areaSlug`
- Optional properties: `name`
- Source notes: export boulder polygons from published areas. `ignore_for_area_hull` affects hull derivation only; it does not exclude the boulder polygon from this layer.
- Navigation: select the boulder by `boulderId` and use `areaSlug` for area context.

### `areas`

- Geometry: `Point`
- Stable identifier: `areaId`
- Required properties: `areaId`, `areaSlug`, `name`, `priority`, `southWestLat`, `southWestLon`, `northEastLat`, `northEastLon`
- Optional properties: `nameEn`, `shortName`, `clusterId`, `clusterSlug`
- Source notes: point geometry is the label/selection point for a published area; bounds describe the area extent.
- Navigation: open an area by `areaSlug` or `areaId`.

### `area_hulls`

- Geometry: `Polygon`
- Stable identifier: `areaId`
- Required properties: `areaId`, `areaSlug`, `southWestLat`, `southWestLon`, `northEastLat`, `northEastLon`
- Optional properties: `name`, `nameEn`, `priority`
- Source notes: hull geometries are derived from non-ignored boulders in published areas.
- Navigation: treat taps as area selections by `areaSlug` or `areaId`.

### `clusters`

- Geometry: `Point`
- Stable identifier: `clusterId`
- Required properties: `clusterId`, `clusterSlug`, `name`, `southWestLat`, `southWestLon`, `northEastLat`, `northEastLon`
- Optional properties: `nameEn`, `regionId`, `regionSlug`, `mainAreaId`, `mainAreaSlug`
- Source notes: point geometry is the label/selection point for a published cluster.
- Navigation: open a cluster by `clusterSlug` or `clusterId`.

### `cluster_hulls`

- Geometry: `Polygon`
- Stable identifier: `clusterId`
- Required properties: `clusterId`, `clusterSlug`, `southWestLat`, `southWestLon`, `northEastLat`, `northEastLon`
- Optional properties: `name`, `nameEn`, `regionId`, `regionSlug`, `mainAreaId`, `mainAreaSlug`
- Source notes: hull geometries are derived from non-ignored boulders in published child areas.
- Navigation: treat taps as cluster selections by `clusterSlug` or `clusterId`.

### `regions`

- Geometry: `Point`
- Stable identifier: `regionId`
- Required properties: `regionId`, `regionSlug`, `name`, `southWestLat`, `southWestLon`, `northEastLat`, `northEastLon`
- Optional properties: `nameEn`, `mainClusterId`, `mainClusterSlug`
- Source notes: point geometry is the label/selection point for a published region.
- Navigation: open a region by `regionSlug` or `regionId`.

### `region_hulls`

- Geometry: `Polygon`
- Stable identifier: `regionId`
- Required properties: `regionId`, `regionSlug`, `southWestLat`, `southWestLon`, `northEastLat`, `northEastLon`
- Optional properties: `name`, `nameEn`, `mainClusterId`, `mainClusterSlug`
- Source notes: hull geometries are derived from non-ignored boulders in published descendant clusters/areas.
- Navigation: treat taps as region selections by `regionSlug` or `regionId`.

### `walking_paths`

- Geometry: `LineString` or `MultiLineString`
- Stable identifier: `walkingPathId`
- Required properties: `walkingPathId`, `slug`, `name`
- Optional properties: `nameEn`, `description`
- Source notes: export only `WalkingPath.published` records with valid SRID 4326 line geometry. `name` comes from the walking-path label/name source; omit `nameEn` unless an English source value exists later.
- Navigation: use `walkingPathId` or `slug` for path selection. Walking paths are general approach/connector overlays and are not POI route geometries.

### `pois`

- Geometry: `Point`
- Stable identifier: `poiId`
- Required properties: `poiId`, `poiType`, `name`, `accessAreasJson`
- Optional properties: `shortName`, `googleUrl`
- Source notes: export POIs with locations and public consumer-safe metadata. `googleUrl` is an external URL and is allowed.
- Navigation: select a POI by `poiId`; use `accessAreasJson` to present related area access metadata.

`accessAreasJson` is a JSON string, not an object-valued vector-tile property. It is derived from `poi_routes` and contains an array of entries with these scalar keys:

```json
[
  {
    "areaId": 123,
    "areaSlug": "zillertal",
    "transport": "walking",
    "distance": 1200,
    "minutes": 15
  }
]
```

The value documents access metadata only. It must not be interpreted as route geometry and must not replace `walking_paths`.

## Expected layer list

The PMTiles artifact exposes exactly these ten source layers:

1. `problems`
2. `boulders`
3. `areas`
4. `area_hulls`
5. `clusters`
6. `cluster_hulls`
7. `regions`
8. `region_hulls`
9. `walking_paths`
10. `pois`
