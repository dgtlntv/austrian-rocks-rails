/**
 * Selection state machine for the Austrian Rocks map: at most one feature is
 * selected at any time, ever — selecting while something else is selected
 * clears the previous selection first.
 *
 * Selection is rendered through dedicated single-feature `-selected` style
 * layers filtered by entity id (sentinel -1 when cleared) instead of MapLibre
 * `feature-state`, because the same filter mechanism works identically in
 * MapLibre GL JS and MapLibre Native, keeping web and the future mobile apps
 * on one shared style/tile contract. The selected id is also excluded from
 * the base symbol layer's filter so the resting pin does not render
 * underneath the selected balloon.
 */

const CLEARED_SENTINEL = -1
const GROW_DURATION_MS = 520
const CLEAR_DURATION_MS = 220
const ICON_GROW_SCALE = 1.25
const ICON_CLEAR_SCALE = 0.72
const CIRCLE_GROW_SCALE = 1.4
const CIRCLE_CLEAR_SCALE = 1
const ICON_SETTLE_OVERSHOOT = 0.1
const CIRCLE_SETTLE_OVERSHOOT = 0.08
const ICON_WIGGLE_DEGREES = 5

const SELECTABLE_KINDS = {
    region: { selectedLayerId: "regions-selected", baseLayerId: "regions", idProperty: "regionId" },
    cluster: { selectedLayerId: "clusters-selected", baseLayerId: "clusters", idProperty: "clusterId" },
    area: { selectedLayerId: "areas-selected", baseLayerId: "areas", idProperty: "areaId" },
    poi: { selectedLayerId: "pois-selected", baseLayerId: "pois", idProperty: "poiId" },
    // The base problems layer keeps its grade filter (owned by the map
    // controller's filter UI) and the bigger stroked selected circle fully
    // covers the base circle, so problems skip the base-layer exclusion.
    problem: { selectedLayerId: "problems-selected", baseLayerId: null, idProperty: "problemId", circle: true },
}

export default class MapSelection {
    /**
     * @param {maplibregl.Map} map Loaded MapLibre map with the shared style.
     */
    constructor(map) {
        this.map = map
        this.current = null
        this.growFrame = null
        this.originalBaseFilters = new Map()
        this.originalGrowValues = new Map()
        this.originalIconRotations = new Map()
    }

    /**
     * Selects one feature by entity kind and id, replacing any prior selection.
     * @param {string} kind One of region/cluster/area/poi/problem.
     * @param {number} id Entity id baked into the tile properties.
     * @returns {void}
     */
    select(kind, id) {
        const config = SELECTABLE_KINDS[kind]
        if (!config || !this.map.getLayer(config.selectedLayerId)) return
        if (this.current) this.clear({ animated: false })

        this.map.setFilter(config.selectedLayerId, ["==", ["get", config.idProperty], id])
        this.excludeFromBaseLayer(config, id)
        this.current = { kind, id, layerId: config.selectedLayerId }
        this.startGrowTween(config)
    }

    /**
     * Clears the current selection and restores all touched layer state.
     * @param {Object} options Clear options.
     * @param {boolean} options.animated Whether to play the selected→resting shrink.
     * @returns {void}
     */
    clear({ animated = true } = {}) {
        if (!this.current) return

        const current = this.current
        const config = SELECTABLE_KINDS[current.kind]
        this.cancelGrowTween()

        if (animated) {
            this.startClearTween(config, () => this.finishClear(config, current))
        } else {
            this.finishClear(config, current)
        }
    }

    /**
     * Finalizes clearing after the optional shrink animation.
     * @param {Object} config Selectable kind configuration.
     * @param {Object} current Selection being cleared.
     * @returns {void}
     */
    finishClear(config, current) {
        if (this.current !== current) return

        this.applyGrowScale(config, 1)
        this.restoreIconRotation(config)
        this.map.setFilter(config.selectedLayerId, ["==", ["get", config.idProperty], CLEARED_SENTINEL])
        this.restoreBaseLayer(config)
        this.current = null
    }

    /**
     * Hides the selected feature's resting pin by excluding its id from the
     * base symbol layer's filter.
     * @param {Object} config Selectable kind configuration.
     * @param {number} id Selected entity id.
     * @returns {void}
     */
    excludeFromBaseLayer(config, id) {
        if (!config.baseLayerId || !this.map.getLayer(config.baseLayerId)) return

        if (!this.originalBaseFilters.has(config.baseLayerId)) {
            this.originalBaseFilters.set(config.baseLayerId, this.map.getFilter(config.baseLayerId))
        }

        const exclusion = ["!=", ["get", config.idProperty], id]
        const original = this.originalBaseFilters.get(config.baseLayerId)
        this.map.setFilter(config.baseLayerId, original ? ["all", original, exclusion] : exclusion)
    }

    /**
     * Restores the base symbol layer's original filter after deselection.
     * @param {Object} config Selectable kind configuration.
     * @returns {void}
     */
    restoreBaseLayer(config) {
        if (!config.baseLayerId || !this.originalBaseFilters.has(config.baseLayerId)) return

        this.map.setFilter(config.baseLayerId, this.originalBaseFilters.get(config.baseLayerId))
    }

    /**
     * Runs a quick grow + settle tween on the selected layer.
     * @param {Object} config Selectable kind configuration.
     * @returns {void}
     */
    startGrowTween(config) {
        this.cancelGrowTween()

        const targetScale = config.circle ? CIRCLE_GROW_SCALE : ICON_GROW_SCALE
        const overshoot = config.circle ? CIRCLE_SETTLE_OVERSHOOT : ICON_SETTLE_OVERSHOOT
        const start = performance.now()
        const step = (now) => {
            const progress = Math.min((now - start) / GROW_DURATION_MS, 1)
            this.applySelectionFrame(config, this.settleScale(progress, targetScale, overshoot), progress)
            this.growFrame = progress < 1 ? requestAnimationFrame(step) : null
        }
        this.growFrame = requestAnimationFrame(step)
    }

    /**
     * Runs the selected→resting shrink before the selected layer is hidden.
     * @param {Object} config Selectable kind configuration.
     * @param {Function} finish Called after the animation completes.
     * @returns {void}
     */
    startClearTween(config, finish) {
        const startScale = config.circle ? CIRCLE_GROW_SCALE : ICON_GROW_SCALE
        const endScale = config.circle ? CIRCLE_CLEAR_SCALE : ICON_CLEAR_SCALE
        const start = performance.now()
        const step = (now) => {
            const progress = Math.min((now - start) / CLEAR_DURATION_MS, 1)
            const eased = 1 - Math.pow(1 - progress, 3)
            this.applySelectionFrame(config, startScale + (endScale - startScale) * eased, 1)
            if (progress < 1) {
                this.growFrame = requestAnimationFrame(step)
            } else {
                this.growFrame = null
                finish()
            }
        }
        this.growFrame = requestAnimationFrame(step)
    }

    /**
     * Eases past the final grow size, then gently settles back for a
     * lightweight Apple-Maps-like selection pop without a distracting bounce.
     * @param {number} progress Tween progress, clamped 0..1.
     * @param {number} targetScale Final scale factor.
     * @param {number} overshoot Extra scale at the peak.
     * @returns {number} Current scale factor.
     */
    settleScale(progress, targetScale, overshoot) {
        if (progress < 0.55) {
            const eased = 1 - Math.pow(1 - (progress / 0.55), 3)
            return 1 + ((targetScale + overshoot) - 1) * eased
        }

        const settle = (progress - 0.55) / 0.45
        const wave = Math.sin(settle * Math.PI * 2) * (1 - settle) * (overshoot * 0.55)
        return targetScale + wave
    }

    /**
     * Cancels a running grow tween frame, if any.
     * @returns {void}
     */
    cancelGrowTween() {
        if (this.growFrame == null) return

        cancelAnimationFrame(this.growFrame)
        this.growFrame = null
    }

    /**
     * Applies one animation frame: icon-size + a subtle rotation wiggle for
     * symbol layers, circle-radius for the selected problems circle layer.
     * @param {Object} config Selectable kind configuration.
     * @param {number} scale Current scale factor (1 = resting style value).
     * @param {number} progress Tween progress, clamped 0..1.
     * @returns {void}
     */
    applySelectionFrame(config, scale, progress) {
        this.applyGrowScale(config, scale)
        if (!config.circle) this.applyIconWiggle(config, progress)
    }

    /**
     * Applies one grow-tween scale step: icon-size for symbol layers,
     * circle-radius for the selected problems circle layer.
     * @param {Object} config Selectable kind configuration.
     * @param {number} scale Current scale factor (1 = resting style value).
     * @returns {void}
     */
    applyGrowScale(config, scale) {
        if (!this.map.getLayer(config.selectedLayerId)) return

        if (config.circle) {
            const base = this.originalGrowValue(config, () => this.map.getPaintProperty(config.selectedLayerId, "circle-radius"))
            this.map.setPaintProperty(config.selectedLayerId, "circle-radius", this.scaledValue(base, scale))
        } else {
            const base = this.originalGrowValue(config, () => this.map.getLayoutProperty(config.selectedLayerId, "icon-size") ?? 1)
            this.map.setLayoutProperty(config.selectedLayerId, "icon-size", this.scaledValue(base, scale))
        }
    }

    /**
     * Adds a tiny damped rotation wiggle to selected symbol layers. MapLibre
     * rotates the icon around its anchor, so the selected balloon pivots around
     * the pin's location dot instead of around the sprite center.
     * @param {Object} config Selectable kind configuration.
     * @param {number} progress Tween progress, clamped 0..1.
     * @returns {void}
     */
    applyIconWiggle(config, progress) {
        if (!this.map.getLayer(config.selectedLayerId)) return

        const base = this.originalIconRotation(config)
        const easedProgress = 1 - Math.pow(1 - progress, 2)
        const amplitude = ICON_WIGGLE_DEGREES * Math.max(0, 1 - easedProgress)
        const rotation = base + (Math.sin(easedProgress * Math.PI * 2.5) * amplitude)
        this.map.setLayoutProperty(config.selectedLayerId, "icon-rotate", rotation)
    }

    /**
     * Restores the selected symbol layer's style-declared icon rotation.
     * @param {Object} config Selectable kind configuration.
     * @returns {void}
     */
    restoreIconRotation(config) {
        if (config.circle || !this.originalIconRotations.has(config.selectedLayerId)) return

        this.map.setLayoutProperty(config.selectedLayerId, "icon-rotate", this.originalIconRotations.get(config.selectedLayerId))
    }

    /**
     * Returns the layer's style-declared grow-property value, captured once
     * before the first tween mutates it.
     * @param {Object} config Selectable kind configuration.
     * @param {Function} read Reads the current style value for the property.
     * @returns {number|Array} Original style value.
     */
    originalGrowValue(config, read) {
        if (!this.originalGrowValues.has(config.selectedLayerId)) {
            this.originalGrowValues.set(config.selectedLayerId, read())
        }
        return this.originalGrowValues.get(config.selectedLayerId)
    }

    /**
     * Returns the style-declared icon rotation for a selected symbol layer.
     * @param {Object} config Selectable kind configuration.
     * @returns {number} Original icon rotation.
     */
    originalIconRotation(config) {
        if (!this.originalIconRotations.has(config.selectedLayerId)) {
            this.originalIconRotations.set(config.selectedLayerId, this.map.getLayoutProperty(config.selectedLayerId, "icon-rotate") || 0)
        }
        return this.originalIconRotations.get(config.selectedLayerId)
    }

    /**
     * Scales a numeric style value directly or wraps an expression in "*".
     * @param {number|Array} value Original style value or expression.
     * @param {number} scale Scale factor.
     * @returns {number|Array} Scaled style value.
     */
    scaledValue(value, scale) {
        if (scale === 1) return value
        if (typeof value === "number") return value * scale
        return ["*", scale, value]
    }
}
