# Austrian Rocks MapLibre styles

`austrian_rocks_light.json` and `austrian_rocks_dark.json` are committed MapLibre style version 8 templates for web, iOS, and Android clients. They are derived from the basemap.at vector root style at `https://mapsneu.wien.gv.at/basemapvectorneu/root.json` and add Austrian Rocks PMTiles overlay styling.

The displayed basemap is basemap.at. The required attribution is therefore `Grundkarte: basemap.at`, with `basemap.at` linking to `https://basemap.at/`, following the Open Government Data Österreich CC-BY 4.0 naming guidance. These templates intentionally do not add OpenStreetMap attribution because no OSM basemap is displayed by these styles. If a future style adds another displayed source, that source must carry its own attribution without misleading users about the basemap.

Both styles include:

- the basemap.at vector source and layers;
- a lower-opacity basemap.at `gelände` raster-shading layer controlled by `config/map_tiles.yml` (`terrain_opacity`, currently `0.35`);
- one Austrian Rocks vector source named `austrian-rocks` using a development-safe PMTiles URL in the committed template;
- style layers for every source layer in `MapTiles::LayerContract.layer_names`.

During publication, `MapTiles::StyleMaterializer` writes immutable versioned light/dark style JSON artifacts and rewrites the `austrian-rocks` source URL to the exact versioned PMTiles URL for that release. Clients should fetch the non-cached release manifest, then load the versioned style URL from `styles.light` or `styles.dark`.
