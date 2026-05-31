import { Controller } from "@hotwired/stimulus"

const DEFAULT_BOUNDS = [
    [9.430320338084726, 46.28576190178245],
    [17.230613306834925, 49.18126637161225],
]

const VIENNA_BASEMAP_VECTOR_URL = "https://mapsneu.wien.gv.at/basemapv/bmapv/3857/"
const BERGWERK_BASEMAP_TILE_URL = "https://basemap.bergwerk-gis.at/basemap-download/webapp/api/tiles/basemap-at-vector/{z}/{x}/{y}.pbf"
const TILE_CACHE_BUSTER = "bergwerk-basemap-z17-contours-top-v4"
const VIENNA_BASEMAP_TILE_URL = `${VIENNA_BASEMAP_VECTOR_URL}tile/{z}/{y}/{x}.pbf?v=${TILE_CACHE_BUSTER}`
const BERGWERK_BASEMAP_TILE_URL_WITH_CACHE_BUSTER = `${BERGWERK_BASEMAP_TILE_URL}?v=${TILE_CACHE_BUSTER}`
const BASEMAP_MAX_NATIVE_ZOOM = 17
const CONTOUR_STYLE_URL = "https://mapsneu.wien.gv.at/basemapv/bmapvhl/3857/resources/styles/root.json"
const CONTOUR_TILE_URL = `https://mapsneu.wien.gv.at/basemapv/bmapvhl/3857/tile/{z}/{y}/{x}.pbf?v=${TILE_CACHE_BUSTER}`
const CONTOUR_MAX_NATIVE_ZOOM = 16
const SCHUMMERUNG_TILE_URL = `https://mapsneu.wien.gv.at/basemap/bmapgelaende/grau/google3857/{z}/{y}/{x}.jpeg?v=${TILE_CACHE_BUSTER}`
const SCHUMMERUNG_MAX_NATIVE_ZOOM = 17
const AUSTRIA_BOUNDS = [8.8587, 45.7823, 17.1608, 49.5752]
const AUSTRIAN_ROCKS_PMTILES_PATH = "/maps/austrian-rocks.pmtiles"

export default class extends Controller {
    static targets = ["map"]

    static values = {
        bounds: Object,
        problem: Object,
        locale: { type: String, default: "en" },
        styleUrl: {
            type: String,
            default: "/map_styles/basemap-at-farbe.json",
        },
    }

    async connect() {
        this.registerPmtilesProtocol()

        const style = await this.loadBaseStyle()

        if (!this.element.isConnected) return

        this.map = new maplibregl.Map({
            container: this.mapTarget,
            style,
            hash: true,
            bounds: DEFAULT_BOUNDS,
            fitBoundsOptions: { padding: 5 },
            locale: this.localeValue == "de" ? this.getDeLocale() : undefined,
        })

        this.map.addControl(
            new maplibregl.ScaleControl({ maxWidth: 80, unit: "metric" }),
            "bottom-left",
        )
        this.map.addControl(new maplibregl.NavigationControl(), "top-right")
        this.map.addControl(
            new maplibregl.GeolocateControl({
                positionOptions: { enableHighAccuracy: true },
                trackUserLocation: true,
                showUserHeading: true,
            }),
            "top-right",
        )

        this.map.on("load", () => {
            this.addSchummerung()
            this.addContourLines()
            this.addAustrianRocksTiles()
            this.centerMap()
        })
    }

    disconnect() {
        this.map?.remove()
    }

    registerPmtilesProtocol() {
        if (!window.pmtiles || window.__austrianRocksPmtilesProtocol) return

        const protocol = new window.pmtiles.Protocol()
        maplibregl.addProtocol("pmtiles", protocol.tile)
        window.__austrianRocksPmtilesProtocol = protocol
    }

    async loadBaseStyle() {
        const response = await fetch(this.styleUrlValue, { cache: "reload" })
        const style = await response.json()

        if (style.sources["basemap-vector-source"]) {
            style.sources["basemap-vector-source"] = {
                type: "vector",
                tiles: [BERGWERK_BASEMAP_TILE_URL_WITH_CACHE_BUSTER],
                minzoom: 0,
                maxzoom: BASEMAP_MAX_NATIVE_ZOOM,
                bounds: AUSTRIA_BOUNDS,
            }
        } else if (style.sources.esri) {
            style.sources.esri = {
                type: "vector",
                tiles: [VIENNA_BASEMAP_TILE_URL],
                minzoom: 0,
                maxzoom: BASEMAP_MAX_NATIVE_ZOOM,
                bounds: AUSTRIA_BOUNDS,
            }
        }

        // Tell MapLibre the native max zoom so it overzooms instead of
        // requesting non-existent higher zoom vector tiles.
        // Also keep the highest-detail style layers visible past their z19 cutoff.
        style.layers = style.layers.map((layer) => {
            if ((layer.maxzoom || 0) >= 19) {
                const { maxzoom: _maxzoom, ...layerWithoutMaxzoom } = layer
                return layerWithoutMaxzoom
            }

            return layer
        })

        return style
    }

    addSchummerung() {
        if (this.map.getSource("schummerung")) return

        this.map.addSource("schummerung", {
            type: "raster",
            tiles: [SCHUMMERUNG_TILE_URL],
            tileSize: 256,
            minzoom: 0,
            maxzoom: SCHUMMERUNG_MAX_NATIVE_ZOOM,
            bounds: AUSTRIA_BOUNDS,
        })

        this.map.addLayer(
            {
                id: "schummerung",
                type: "raster",
                source: "schummerung",
                paint: {
                    "raster-opacity": 0.35,
                },
            },
            this.firstSymbolLayerId(),
        )
    }

    async addContourLines() {
        if (this.map.getSource("contours")) return

        this.map.addSource("contours", {
            type: "vector",
            tiles: [CONTOUR_TILE_URL],
            minzoom: 0,
            maxzoom: CONTOUR_MAX_NATIVE_ZOOM,
            bounds: AUSTRIA_BOUNDS,
        })

        const response = await fetch(CONTOUR_STYLE_URL, { cache: "reload" })
        const contourStyle = await response.json()

        contourStyle.layers.forEach((layer) => {
            const { maxzoom: _maxzoom, ...overzoomableLayer } = layer
            const contourLayer = {
                ...overzoomableLayer,
                id: `contours-${layer.id}`,
                source: "contours",
            }

            // The Bergwerk basemap style uses Bergwerk's glyph endpoint globally.
            // The Wien contour style asks for "Corbel Bold Italic", which does not
            // exist there, so remap contour labels to a font Bergwerk provides.
            if (contourLayer.type === "symbol" && contourLayer.layout?.["text-font"]) {
                contourLayer.layout = {
                    ...contourLayer.layout,
                    "text-font": ["Roboto-MediumItalic"],
                }
            }

            // Add contours on top for now to rule out layer ordering issues.
            this.map.addLayer(contourLayer)
        })
    }

    async addAustrianRocksTiles() {
        if (this.map.getSource("austrian-rocks")) return
        if (!window.pmtiles) {
            console.info("PMTiles library is not loaded; skipping Austrian Rocks overlays")
            return
        }

        const response = await fetch(AUSTRIAN_ROCKS_PMTILES_PATH, { method: "HEAD" })
        if (!response.ok) {
            console.info(`${AUSTRIAN_ROCKS_PMTILES_PATH} not found; run bin/build_pmtiles to generate local overlays`)
            return
        }

        this.map.addSource("austrian-rocks", {
            type: "vector",
            url: `pmtiles://${window.location.origin}${AUSTRIAN_ROCKS_PMTILES_PATH}`,
        })

        this.map.addLayer({
            id: "austrian-rocks-region-hulls",
            type: "fill",
            source: "austrian-rocks",
            "source-layer": "region_hulls",
            minzoom: 5,
            paint: {
                "fill-color": "#047857",
                "fill-opacity": 0.06,
            },
        })

        this.map.addLayer({
            id: "austrian-rocks-cluster-hulls",
            type: "fill",
            source: "austrian-rocks",
            "source-layer": "cluster_hulls",
            minzoom: 7,
            paint: {
                "fill-color": "#059669",
                "fill-opacity": 0.08,
            },
        })

        this.map.addLayer({
            id: "austrian-rocks-area-hulls",
            type: "fill",
            source: "austrian-rocks",
            "source-layer": "area_hulls",
            minzoom: 10,
            paint: {
                "fill-color": "#10b981",
                "fill-opacity": 0.12,
            },
        })

        this.map.addLayer({
            id: "austrian-rocks-boulders",
            type: "fill",
            source: "austrian-rocks",
            "source-layer": "boulders",
            minzoom: 14,
            paint: {
                "fill-color": "#334155",
                "fill-opacity": 0.35,
            },
        })

        this.map.addLayer({
            id: "austrian-rocks-boulder-outlines",
            type: "line",
            source: "austrian-rocks",
            "source-layer": "boulders",
            minzoom: 14,
            paint: {
                "line-color": "#0f172a",
                "line-width": 1,
            },
        })

        this.map.addLayer({
            id: "austrian-rocks-problems",
            type: "circle",
            source: "austrian-rocks",
            "source-layer": "problems",
            minzoom: 12,
            paint: {
                "circle-color": ["case", ["==", ["get", "featured"], true], "#f59e0b", "#10b981"],
                "circle-radius": ["interpolate", ["linear"], ["zoom"], 12, 3, 16, 6],
                "circle-stroke-color": "#ffffff",
                "circle-stroke-width": 1,
            },
        })

        this.map.addLayer({
            id: "austrian-rocks-area-labels",
            type: "symbol",
            source: "austrian-rocks",
            "source-layer": "areas",
            minzoom: 10,
            layout: {
                "text-field": ["get", "name"],
                "text-font": ["Roboto-Bold"],
                "text-size": ["interpolate", ["linear"], ["zoom"], 10, 12, 14, 16],
                "text-anchor": "top",
                "text-offset": [0, 0.6],
            },
            paint: {
                "text-color": "#065f46",
                "text-halo-color": "#ffffff",
                "text-halo-width": 1.5,
            },
        })
    }

    firstSymbolLayerId() {
        return this.map.getStyle().layers.find((layer) => layer.type === "symbol")?.id
    }

    centerMap() {
        if (this.hasProblemValue) {
            this.gotoProblemCoordinates(this.problemValue)
        } else if (this.hasBoundsValue) {
            this.fitBoundsValue(this.boundsValue)
        }
    }

    gotoproblem(event) {
        if (event.detail) this.gotoProblemCoordinates(event.detail)
    }

    gotoarea(event) {
        if (event.detail) this.fitBoundsValue(event.detail)
    }

    gotoProblemCoordinates(problem) {
        if (!problem?.lon || !problem?.lat) return

        this.map.flyTo({
            center: [problem.lon, problem.lat],
            zoom: 15,
            essential: true,
        })
    }

    fitBoundsValue(bounds) {
        const sw = [bounds.southWestLon, bounds.southWestLat]
        const ne = [bounds.northEastLon, bounds.northEastLat]

        if (sw.some((value) => value == null) || ne.some((value) => value == null)) return

        this.map.fitBounds([sw, ne], { padding: 40, maxZoom: 15 })
    }

    getDeLocale() {
        return {
            "AttributionControl.ToggleAttribution": "Quellen anzeigen/verbergen",
            "FullscreenControl.Enter": "Vollbildansicht aktivieren",
            "FullscreenControl.Exit": "Vollbildansicht beenden",
            "GeolocateControl.FindMyLocation": "Meinen Standort anzeigen",
            "GeolocateControl.LocationNotAvailable": "Standort nicht verfügbar",
            "LogoControl.Title": "MapLibre Logo",
            "NavigationControl.ResetBearing": "Ausrichtung zurücksetzen",
            "NavigationControl.ZoomIn": "Vergrößern",
            "NavigationControl.ZoomOut": "Verkleinern",
            "ScaleControl.Feet": "ft",
            "ScaleControl.Meters": "m",
            "ScaleControl.Kilometers": "km",
            "ScaleControl.Miles": "mi",
        }
    }
}
