/**
 * Stimulus controller for the Rails map pages. It wires MapLibre GL JS, the
 * PMTiles protocol, release-manifest style loading, web-only interactions,
 * pin selection with the responsive info card, grade filters, search events,
 * and the dynamic contribution-request overlay; shared basemap/source/layer
 * styling lives in the published style JSONs.
 */
import { Controller } from "@hotwired/stimulus"
import maplibregl from "maplibre-gl"
import { Protocol } from "pmtiles"
import MapSelection from "map/selection"
import InfoCard from "map/info_card"

const AUSTRIA_BOUNDS = [
    [9.430320338084726, 46.28576190178245],
    [17.230613306834925, 49.18126637161225],
]
const GRADE_FILTER_LAYERS = ["problems"]
const ALL_GRADES = [
    "1a", "1a/+", "1a+", "1b", "1b/+", "1b+", "1c", "1c/+", "1c+",
    "2a", "2a/+", "2a+", "2b", "2b/+", "2b+", "2c", "2c/+", "2c+",
    "3a", "3a/+", "3a+", "3b", "3b/+", "3b+", "3c", "3c/+", "3c+",
    "4a", "4a/+", "4a+", "4b", "4b/+", "4b+", "4c", "4c/+", "4c+",
    "5a", "5a/+", "5a+", "5b", "5b/+", "5b+", "5c", "5c/+", "5c+",
    "6a", "6a/+", "6a+", "6b", "6b/+", "6b+", "6c", "6c/+", "6c+",
    "7a", "7a/+", "7a+", "7b", "7b/+", "7b+", "7c", "7c/+", "7c+",
    "8a", "8a/+", "8a+", "8b", "8b/+", "8b+", "8c", "8c/+", "8c+",
    "9a", "9a/+", "9a+", "9b", "9b/+", "9b+", "9c", "9c/+", "9c+",
]

export default class extends Controller {
    static targets = [
        "map",
        "card",
        "gradeRadioButton",
        "gradeMin",
        "gradeMax",
        "customGradePicker",
        "filterCounter",
        "filterIcon",
    ]

    static values = {
        bounds: Object,
        problem: Object,
        cardStrings: Object,
        areaId: Number,
        locale: { type: String, default: "en" },
        manifestUrl: String,
        style: { type: String, default: "light" },
        contribute: { type: Boolean, default: false },
        contributeSource: String,
    }

    /**
     * Registers the PMTiles protocol, loads the release manifest, and creates
     * the MapLibre map once Stimulus connects the controller.
     * @returns {Promise<void>}
     */
    async connect() {
        this.allGrades = ALL_GRADES
        this.popup = null
        this.protocol = new Protocol()
        maplibregl.addProtocol("pmtiles", this.protocol.tile)

        try {
            const styleUrl = await this.loadStyleUrl()
            this.initializeMap(styleUrl)
        } catch (error) {
            console.error("Could not initialize Austrian Rocks map", error)
        }
    }

    /**
     * Removes the map and unregisters PMTiles when Turbo disconnects the page.
     * @returns {void}
     */
    disconnect() {
        if (this.map) {
            this.map.remove()
            this.map = null
        }

        if (maplibregl.removeProtocol) {
            maplibregl.removeProtocol("pmtiles")
        }
    }

    /**
     * Fetches the non-cached release manifest and selects the configured style.
     * @returns {Promise<string>} Versioned MapLibre style URL.
     */
    async loadStyleUrl() {
        const response = await fetch(this.manifestUrlValue, {
            cache: "no-store",
            credentials: "same-origin",
        })
        if (!response.ok) {
            throw new Error(`Map release manifest failed with ${response.status}`)
        }

        const manifest = await response.json()
        const styles = manifest.styles || {}
        const styleName = this.styleValue || "light"
        const styleUrl = styles[styleName]
        if (!styleUrl) {
            throw new Error(`Map release manifest is missing the ${styleName} style`)
        }

        return styleUrl
    }

    /**
     * Creates the MapLibre map and wires load/move/click behaviour.
     * @param {string} styleUrl Versioned style JSON URL from the manifest.
     * @returns {void}
     */
    initializeMap(styleUrl) {
        this.map = new maplibregl.Map({
            container: this.mapTarget,
            locale: this.localeValue == "de" ? this.getDeLocale() : undefined,
            hash: true,
            style: styleUrl,
            bounds: AUSTRIA_BOUNDS,
            padding: 5,
        })

        this.addControls()

        this.map.on("load", () => {
            this.selection = new MapSelection(this.map)
            if (this.hasCardTarget) {
                this.infoCard = new InfoCard(this.cardTarget, this.cardStringsValue, this.localeValue)
            }
            this.addContributionLayers()
            this.centerMap()
            this.cleanHistory()
            this.setupClickEvents()
        })

        this.map.on("moveend", () => {
            if (this.popup != null) {
                this.popup.addTo(this.map)
                this.popup = null
            }
        })
    }

    /**
     * Adds scale, navigation, and geolocation controls.
     * @returns {void}
     */
    addControls() {
        this.map.addControl(new maplibregl.ScaleControl({ maxWidth: 100, unit: "metric" }))
        this.map.addControl(new maplibregl.NavigationControl())
        this.map.addControl(new maplibregl.GeolocateControl({
            positionOptions: { enableHighAccuracy: true },
            trackUserLocation: true,
            showUserHeading: true,
        }))
    }

    /**
     * Adds the web-only dynamic contribution-request GeoJSON source and layers.
     * @returns {void}
     */
    addContributionLayers() {
        if (!this.contributeValue || !this.hasContributeSourceValue) return

        this.map.addSource("contribute", {
            type: "geojson",
            data: this.contributeSourceValue,
        })

        this.map.addLayer({
            id: "contribute-problems",
            type: "circle",
            source: "contribute",
            layout: { visibility: "visible" },
            paint: {
                "circle-radius": [
                    "interpolate", ["linear"], ["zoom"],
                    12, 6,
                    17, 20,
                    18, 25,
                    19, 50,
                    20, 50,
                    21, 50,
                    22, 20,
                ],
                "circle-color": "#FFCC02",
                "circle-opacity": 0.25,
                "circle-stroke-width": 2,
                "circle-stroke-color": "white",
            },
            filter: ["match", ["geometry-type"], ["Point"], true, false],
        }, this.layerBefore("areas"))

        this.map.addLayer({
            id: "contribute-problems-texts",
            type: "symbol",
            source: "contribute",
            minzoom: 16,
            layout: {
                visibility: "visible",
                "text-allow-overlap": true,
                "text-field": ["to-string", ["get", "name"]],
                "text-font": ["Roboto-Regular"],
                "text-size": ["interpolate", ["linear"], ["zoom"], 19, 10, 22, 20],
            },
            paint: {
                "text-color": "#333",
                "text-halo-color": "hsl(0, 0%, 100%)",
                "text-halo-width": 1,
            },
            filter: ["match", ["geometry-type"], ["Point"], true, false],
        })
    }

    /**
     * Returns a layer insertion ID only when that style layer exists.
     * @param {string} layerId Candidate style layer ID.
     * @returns {string|undefined} Existing layer ID or undefined.
     */
    layerBefore(layerId) {
        return this.map.getLayer(layerId) ? layerId : undefined
    }

    /**
     * Centers the map on area bounds or a problem deep link supplied by Rails.
     * @returns {void}
     */
    centerMap() {
        if (this.hasBoundsValue) {
            const bounds = this.boundsValue
            this.flyToBounds([
                [bounds.southWestLon, bounds.southWestLat],
                [bounds.northEastLon, bounds.northEastLat],
            ])
        }

        if (this.hasProblemValue) {
            const problem = this.problemValue
            this.map.flyTo({ center: [problem.lon, problem.lat], zoom: 20, speed: 2 })

            if (!this.contributeValue) {
                this.popup = this.createPopup()
                    .setLngLat([problem.lon, problem.lat])
                    .setDOMContent(this.problemPopupContent(problem))
            }
        }
    }

    /**
     * Removes deep-link query parameters when the user starts moving the map.
     * @returns {void}
     */
    cleanHistory() {
        this.map.on("movestart", () => {
            const url = this.contributeValue ? `/${this.localeValue}/mapping/map` : `/${this.localeValue}/map`
            history.replaceState({}, "", url)
        })
    }

    /**
     * Wires cursor and click handlers for shared style layers and contribution layers.
     * @returns {void}
     */
    setupClickEvents() {
        this.registerPointerLayer("problems")
        this.registerPointerLayer("pois", (zoom) => zoom >= 12)
        this.registerPointerLayer("areas", (zoom) => zoom < 15)
        this.registerPointerLayer("areas-hulls", (zoom) => zoom < 15)
        this.registerPointerLayer("clusters", (zoom) => zoom <= 12)
        this.registerPointerLayer("cluster-hulls", (zoom) => zoom <= 12)
        this.registerPointerLayer("regions", (zoom) => zoom <= 10)
        this.registerPointerLayer("region-hulls", (zoom) => zoom <= 10)
        this.registerContributionClicks()
        this.registerSelectClicks("problems", "problem")
        this.registerSelectClicks("pois", "poi", (zoom) => zoom >= 12)
        this.registerSelectClicks("areas", "area", (zoom) => zoom < 15)
        this.registerSelectClicks("areas-hulls", "area", (zoom) => zoom < 15)
        this.registerSelectClicks("clusters", "cluster", (zoom) => zoom <= 12)
        this.registerSelectClicks("cluster-hulls", "cluster", (zoom) => zoom <= 12)
        this.registerSelectClicks("regions", "region", (zoom) => zoom <= 10)
        this.registerSelectClicks("region-hulls", "region", (zoom) => zoom <= 10)
        this.registerBackgroundClicks()
    }

    /**
     * Sets a pointer cursor for an interactive layer when its zoom predicate passes.
     * @param {string} layerId Layer ID to handle.
     * @param {Function} zoomPredicate Returns true when the cursor should be a pointer.
     * @returns {void}
     */
    registerPointerLayer(layerId, zoomPredicate = () => true) {
        if (!this.map.getLayer(layerId)) return

        this.map.on("mouseenter", layerId, () => {
            if (zoomPredicate(this.map.getZoom())) this.map.getCanvas().style.cursor = "pointer"
        })
        this.map.on("mouseleave", layerId, () => { this.map.getCanvas().style.cursor = "" })
    }

    /**
     * Selects the clicked feature and opens its info card.
     * @param {string} layerId Layer ID to handle (hulls select their pin's entity).
     * @param {string} kind Entity kind: region/cluster/area/poi/problem.
     * @param {Function} zoomPredicate Returns true when click should select.
     * @returns {void}
     */
    registerSelectClicks(layerId, kind, zoomPredicate = () => true) {
        if (!this.map.getLayer(layerId)) return

        this.map.on("click", layerId, (event) => {
            if (!zoomPredicate(this.map.getZoom())) return

            const feature = event.features[0]
            const id = feature.properties[`${kind}Id`]
            if (id === undefined || id === null) return
            if (this.selection.current?.kind === kind && this.selection.current?.id === id) return

            this.selectFeature(kind, id, feature.properties, event.lngLat)
        })
    }

    /**
     * Clears the selection when a click hits no interactive feature.
     * @returns {void}
     */
    registerBackgroundClicks() {
        this.map.on("click", (event) => {
            if (!this.selection.current) return

            const features = this.map.queryRenderedFeatures(event.point, {
                layers: this.interactiveLayerIds(),
            })
            if (features.length === 0) this.clearSelection()
        })
    }

    /**
     * Returns the existing layer IDs a click may interact with.
     * @returns {string[]} Existing interactive layer IDs.
     */
    interactiveLayerIds() {
        return [
            "problems", "problems-selected",
            "pois", "pois-selected",
            "areas", "areas-selected", "areas-hulls",
            "clusters", "clusters-selected", "cluster-hulls",
            "regions", "regions-selected", "region-hulls",
            "contribute-problems", "contribute-problems-texts",
        ].filter((layerId) => this.map.getLayer(layerId))
    }

    /**
     * Applies a selection: grows the selected pin and opens the info card.
     * @param {string} kind Entity kind: region/cluster/area/poi/problem.
     * @param {number} id Entity id from the tile properties.
     * @param {Object} properties Tile feature properties for the card.
     * @param {maplibregl.LngLat} lngLat Selected coordinate for sheet handling.
     * @returns {void}
     */
    selectFeature(kind, id, properties, lngLat) {
        this.selection.select(kind, id)
        this.infoCard?.show(kind, properties, {
            showOnMap: () => this.showSelectionOnMap(kind, properties),
            close: () => this.clearSelection(),
        })
        this.adjustSheetPadding(lngLat)
    }

    /**
     * Clears the selection, hides the card, and resets the sheet padding.
     * @returns {void}
     */
    clearSelection() {
        this.selection.clear()
        this.infoCard?.hide()
        this.map.setPadding({ top: 0, bottom: 0, left: 0, right: 0 })
    }

    /**
     * Card "Show on map" CTA: flies to the entity bounds — for regions the
     * main-cluster bounds when baked, else the full bounds — then closes the card.
     * @param {string} kind Entity kind: region/cluster/area/poi/problem.
     * @param {Object} properties Tile feature properties with bounds.
     * @returns {void}
     */
    showSelectionOnMap(kind, properties) {
        const bounds = kind === "region" && properties.mainClusterSouthWestLat !== undefined
            ? [
                [properties.mainClusterSouthWestLon, properties.mainClusterSouthWestLat],
                [properties.mainClusterNorthEastLon, properties.mainClusterNorthEastLat],
            ]
            : [
                [properties.southWestLon, properties.southWestLat],
                [properties.northEastLon, properties.northEastLat],
            ]
        if (bounds[0][0] !== undefined) this.flyToBounds(bounds)
        this.clearSelection()
    }

    /**
     * Below the lg breakpoint the card is a bottom sheet: pads the map by the
     * sheet height and eases to the selected coordinate when it is covered.
     * @param {maplibregl.LngLat} lngLat Selected coordinate.
     * @returns {void}
     */
    adjustSheetPadding(lngLat) {
        if (!this.hasCardTarget || window.matchMedia("(min-width: 1024px)").matches) return

        const sheetHeight = this.cardTarget.offsetHeight
        this.map.setPadding({ top: 0, bottom: sheetHeight, left: 0, right: 0 })
        if (!lngLat) return

        const point = this.map.project(lngLat)
        if (point.y > this.map.getContainer().clientHeight - sheetHeight) {
            this.map.easeTo({ center: lngLat, duration: 300 })
        }
    }

    /**
     * Opens safe grouped contribution-request popups.
     * @returns {void}
     */
    registerContributionClicks() {
        ["contribute-problems", "contribute-problems-texts"].forEach((layerId) => {
            if (!this.map.getLayer(layerId)) return

            this.map.on("click", layerId, (event) => {
                const feature = event.features[0]
                this.createPopup()
                    .setLngLat(feature.geometry.coordinates.slice())
                    .setDOMContent(this.contributionPopupContent(feature.properties))
                    .addTo(this.map)
            })
        })
    }

    /**
     * Builds a localized problem-popup DOM tree without raw HTML interpolation.
     * @param {Object} problem Problem feature properties.
     * @returns {HTMLElement} Popup content element.
     */
    problemPopupContent(problem) {
        const container = document.createElement("div")
        const problemId = this.problemFeatureId(problem)

        if (problemId !== undefined && problemId !== null && problemId !== "") {
            const link = document.createElement("a")
            link.href = `/${this.localeValue}/redirects/new?problem_id=${encodeURIComponent(problemId)}`
            link.target = "_blank"
            link.rel = "noopener noreferrer"
            link.textContent = this.localizedName(problem)
            container.appendChild(link)
        } else {
            container.appendChild(document.createTextNode(this.localizedName(problem)))
        }

        const grade = document.createElement("span")
        grade.className = "text-gray-400 ml-1"
        grade.textContent = problem.grade || ""
        container.appendChild(grade)
        return container
    }

    /**
     * Builds a grouped contribution-request popup without raw HTML interpolation.
     * @param {Object} group Contribution GeoJSON properties.
     * @returns {HTMLElement} Popup content element.
     */
    contributionPopupContent(group) {
        const container = document.createElement("div")
        this.parseProblems(group.problems).forEach((problem) => {
            const row = document.createElement("div")
            const link = document.createElement("a")
            link.href = `/${this.localeValue}/mapping/problems/${encodeURIComponent(problem.id)}`
            link.target = "_blank"
            link.rel = "noopener noreferrer"
            link.textContent = problem.name || ""
            row.appendChild(link)

            const grade = document.createElement("span")
            grade.className = "text-gray-400 ml-1"
            grade.textContent = problem.grade || ""
            row.appendChild(grade)

            const ascents = document.createElement("span")
            ascents.className = "text-gray-400 ml-1 font-semibold"
            ascents.textContent = `(${problem.ascents || 0})`
            row.appendChild(ascents)
            container.appendChild(row)
        })
        return container
    }

    /**
     * Parses contribution problems from MapLibre feature properties.
     * @param {string|Object[]} problems JSON string or decoded array.
     * @returns {Object[]} Contribution problem rows.
     */
    parseProblems(problems) {
        if (Array.isArray(problems)) return problems
        if (!problems) return []

        try {
            const parsed = JSON.parse(problems)
            return Array.isArray(parsed) ? parsed : []
        } catch (_error) {
            return []
        }
    }

    /**
     * Selects the localized feature name.
     * @param {Object} properties Feature properties with name/nameEn values.
     * @returns {string} Localized display name.
     */
    localizedName(properties) {
        if (this.localeValue == "en" && properties.nameEn) return properties.nameEn
        return properties.name || ""
    }

    /**
     * Returns the problem ID from either Rails deep-link data or PMTiles feature properties.
     * @param {Object} problem Problem feature properties.
     * @returns {string|number|undefined|null} Problem identifier.
     */
    problemFeatureId(problem) {
        return problem.id ?? problem.problemId
    }

    /**
     * Creates a consistent MapLibre popup instance.
     * @returns {maplibregl.Popup} Configured popup.
     */
    createPopup() {
        return new maplibregl.Popup({ closeButton: false, focusAfterOpen: false, offset: [0, -8] })
    }

    /**
     * Flies the map to a bounding box while keeping the current minimum zoom behaviour.
     * @param {Array<Array<number>>} bounds Southwest and northeast coordinate pairs.
     * @returns {void}
     */
    flyToBounds(bounds) {
        const cameraOptions = this.map.cameraForBounds(bounds, {
            padding: { top: 20, bottom: 100, left: 20, right: 20 },
        })
        cameraOptions.zoom = Math.max(15, cameraOptions.zoom)
        cameraOptions.speed = 2
        this.map.flyTo(cameraOptions)
    }

    /**
     * Returns German MapLibre control labels.
     * @returns {Object} Locale override map.
     */
    getDeLocale() {
        return {
            "AttributionControl.ToggleAttribution": "Attribution umschalten",
            "AttributionControl.MapFeedback": "Karten-Feedback",
            "FullscreenControl.Enter": "Vollbildmodus",
            "FullscreenControl.Exit": "Vollbildmodus verlassen",
            "GeolocateControl.FindMyLocation": "Meinen Standort finden",
            "GeolocateControl.LocationNotAvailable": "Standort nicht verfügbar",
            "Map.Title": "Karte",
            "NavigationControl.ResetBearing": "Nach Norden ausrichten",
            "NavigationControl.ZoomIn": "Vergrößern",
            "NavigationControl.ZoomOut": "Verkleinern",
            "ScrollZoomBlocker.CtrlMessage": "Verwenden Sie Strg + Scrollen zum Zoomen",
            "ScrollZoomBlocker.CmdMessage": "Verwenden Sie ⌘ + Scrollen zum Zoomen",
            "TouchPanBlocker.Message": "Verwenden Sie zwei Finger, um die Karte zu bewegen",
        }
    }

    /**
     * Shows or hides the custom grade picker after a preset radio selection.
     * @param {Event} event Change event from a grade radio button.
     * @returns {void}
     */
    didSelectFilter(event) {
        this.gradeRadioButton = event.target.value
        if (this.gradeRadioButton == "custom") {
            this.customGradePickerTarget.classList.remove("hidden")
        } else {
            this.customGradePickerTarget.classList.add("hidden")
        }
    }

    /**
     * Applies the selected grade filter to problem symbol and circle layers.
     * @returns {void}
     */
    applyFilters() {
        this.filterCounterTarget.classList.remove("hidden")
        this.filterIconTarget.classList.add("hidden")

        let grades = []
        if (this.gradeRadioButton == "beginner") {
            grades = ["1a", "1a+", "1b", "1b+", "1c", "1c+", "2a", "2a+", "2b", "2b+", "2c", "2c+", "3a", "3a+", "3b", "3b+", "3c", "3c+"]
        } else if (this.gradeRadioButton == "level4") {
            grades = ["4a", "4a+", "4b", "4b+", "4c", "4c+"]
        } else if (this.gradeRadioButton == "level5") {
            grades = ["5a", "5a+", "5b", "5b+", "5c", "5c+"]
        } else if (this.gradeRadioButton == "level6") {
            grades = ["6a", "6a+", "6b", "6b+", "6c", "6c+"]
        } else if (this.gradeRadioButton == "level7") {
            grades = ["7a", "7a+", "7b", "7b+", "7c", "7c+"]
        } else if (this.gradeRadioButton == "level8") {
            grades = ["8a", "8a+", "8b", "8b+", "8c", "8c+"]
        } else if (this.gradeRadioButton == "custom") {
            const gradeMin = this.gradeMinTarget.value
            const gradeMax = this.gradeMaxTarget.value
            grades = this.allGrades.slice(
                this.allGrades.indexOf(gradeMin),
                this.allGrades.indexOf(gradeMax) + 2
            )
        } else {
            grades = this.allGrades
        }

        GRADE_FILTER_LAYERS.forEach((layer) => this.applyLayerFilter(layer, grades))
    }

    /**
     * Clears selected grade filters from problem symbol and circle layers.
     * @returns {void}
     */
    clearFilters() {
        this.gradeRadioButton = null
        this.filterCounterTarget.classList.add("hidden")
        this.filterIconTarget.classList.remove("hidden")
        this.gradeRadioButtonTargets.forEach((item) => { item.checked = false })
        GRADE_FILTER_LAYERS.forEach((layer) => this.applyLayerFilter(layer, this.allGrades))
    }

    /**
     * Applies a grade filter to an existing map layer.
     * @param {string} layer Layer ID.
     * @param {string[]} grades Allowed grades.
     * @returns {void}
     */
    applyLayerFilter(layer, grades) {
        if (!this.map.getLayer(layer)) return

        this.map.setFilter(layer, ["match", ["get", "grade"], grades, true, false])
    }

    /**
     * Keeps the maximum custom grade greater than or equal to the minimum.
     * @returns {void}
     */
    didSelectGradeMin() {
        const indexMin = this.allGrades.indexOf(this.gradeMinTarget.value)
        const indexMax = this.allGrades.indexOf(this.gradeMaxTarget.value)
        this.gradeMaxTarget.value = this.allGrades[Math.max(indexMin, indexMax)]
    }

    /**
     * Keeps the minimum custom grade less than or equal to the maximum.
     * @returns {void}
     */
    didSelectGradeMax() {
        const indexMin = this.allGrades.indexOf(this.gradeMinTarget.value)
        const indexMax = this.allGrades.indexOf(this.gradeMaxTarget.value)
        this.gradeMinTarget.value = this.allGrades[Math.min(indexMin, indexMax)]
    }

    /**
     * Handles problem navigation events dispatched by the search controller.
     * @param {CustomEvent} event Problem navigation event.
     * @returns {void}
     */
    gotoproblem(event) {
        this.map.flyTo({ center: [event.detail.lon, event.detail.lat], zoom: 20, speed: 2 })
        this.createPopup()
            .setLngLat([event.detail.lon, event.detail.lat])
            .setDOMContent(this.problemPopupContent(event.detail))
            .addTo(this.map)
    }

    /**
     * Handles area navigation events dispatched by the search controller.
     * @param {CustomEvent} event Area navigation event.
     * @returns {void}
     */
    gotoarea(event) {
        this.flyToBounds([
            [event.detail.south_west_lon, event.detail.south_west_lat],
            [event.detail.north_east_lon, event.detail.north_east_lat],
        ])
    }
}
