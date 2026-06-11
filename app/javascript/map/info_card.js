/**
 * Info card renderer for the Austrian Rocks map. Builds the card DOM
 * exclusively with createElement/textContent — tile feature properties are
 * untrusted input, so no HTML interpolation — and lays out responsively via
 * Tailwind classes inside the map container: bottom sheet below the lg
 * breakpoint, docked panel at and above it. All static strings arrive localized from Rails via
 * the data-map-card-strings-value JSON blob.
 */

const CONTAINER_CLASSES = "absolute inset-x-0 bottom-0 z-20 max-h-[60vh] overflow-y-auto rounded-t-xl bg-white shadow-2xl lg:inset-x-auto lg:bottom-auto lg:left-4 lg:top-4 lg:w-96 lg:max-h-[calc(100%_-_2rem)] lg:rounded-xl"

export default class InfoCard {
    /**
     * @param {HTMLElement} container Stimulus card target element.
     * @param {Object} strings Parsed data-map-card-strings-value JSON.
     * @param {string} locale Active locale ("de" or "en").
     */
    constructor(container, strings, locale) {
        this.container = container
        this.strings = strings
        this.locale = locale
    }

    /**
     * Renders and shows the card for one selected feature.
     * @param {string} kind One of region/cluster/area/poi/problem.
     * @param {Object} properties Tile feature properties (untrusted).
     * @param {Object} callbacks { showOnMap, close } handlers.
     * @returns {void}
     */
    show(kind, properties, callbacks) {
        this.container.replaceChildren()
        this.container.className = CONTAINER_CLASSES

        if (kind === "problem") {
            this.container.appendChild(this.problemContent(properties, callbacks))
        } else if (kind === "poi") {
            this.container.appendChild(this.poiContent(properties, callbacks))
        } else {
            this.container.appendChild(this.entityContent(properties, callbacks))
        }
    }

    /**
     * Hides the card and drops its content.
     * @returns {void}
     */
    hide() {
        this.container.replaceChildren()
        this.container.className = "hidden"
    }

    /**
     * Builds the region/cluster/area card body.
     * @param {Object} properties Tile feature properties.
     * @param {Object} callbacks { showOnMap, close } handlers.
     * @returns {HTMLElement} Card body element.
     */
    entityContent(properties, callbacks) {
        const body = document.createElement("div")

        const coverUrl = this.safeHttpUrl(properties.coverPhotoUrl)
        if (coverUrl) {
            const media = document.createElement("div")
            media.className = "relative h-40 bg-gray-100"
            const cover = document.createElement("img")
            cover.src = coverUrl.toString()
            cover.alt = ""
            cover.className = "h-full w-full object-cover rounded-t-xl"
            cover.onerror = () => cover.remove()
            media.appendChild(cover)
            media.appendChild(this.mediaCloseButton(callbacks))
            body.appendChild(media)
        }

        const content = document.createElement("div")
        content.className = "p-4 space-y-3"
        content.appendChild(this.headerRow(this.localizedText(properties.name, properties.nameEn), callbacks, { showClose: !coverUrl }))

        const stats = this.statsLine(properties)
        if (stats) content.appendChild(stats)

        const warning = this.localizedText(properties.warning, properties.warningEn)
        if (warning) {
            const block = document.createElement("p")
            block.className = "rounded-lg bg-amber-50 p-3 text-sm text-amber-800"
            const label = document.createElement("span")
            label.className = "font-semibold"
            label.textContent = `${this.strings.warning}: `
            block.appendChild(label)
            block.appendChild(document.createTextNode(warning))
            content.appendChild(block)
        }

        const guidebookUrl = this.safeHttpUrl(properties.guidebookUrl)
        if (guidebookUrl && properties.guidebookTitle) {
            const title = properties.guidebookAuthor
                ? `${properties.guidebookTitle} — ${properties.guidebookAuthor}`
                : properties.guidebookTitle
            content.appendChild(this.labelledLinkRow(this.strings.guidebook, title, guidebookUrl))
        }

        const parkingUrl = this.safeHttpUrl(properties.parkingGoogleUrl)
        if (parkingUrl) {
            content.appendChild(this.labelledLinkRow(properties.parkingName || "", this.strings.directions, parkingUrl))
        }

        const button = document.createElement("button")
        button.type = "button"
        button.className = "w-full rounded-lg bg-brand-500 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-600"
        button.textContent = this.strings.show_on_map
        button.addEventListener("click", () => callbacks.showOnMap())
        content.appendChild(button)

        body.appendChild(content)
        return body
    }

    /**
     * Builds the problem card body.
     * @param {Object} properties Tile feature properties.
     * @param {Object} callbacks { showOnMap, close } handlers.
     * @returns {HTMLElement} Card body element.
     */
    problemContent(properties, callbacks) {
        const body = document.createElement("div")
        const preview = this.problemTopoPreview(properties, callbacks)
        if (preview) body.appendChild(preview)

        const content = document.createElement("div")
        content.className = "p-4 space-y-3"
        content.appendChild(this.headerRow(this.localizedText(properties.name, properties.nameEn), callbacks, { showClose: !preview }))

        const details = this.problemDetails(properties)
        if (details) content.appendChild(details)

        const problemId = properties.problemId
        if (problemId !== undefined && problemId !== null && problemId !== "") {
            const cta = document.createElement("a")
            cta.href = `/${this.locale}/redirects/new?problem_id=${encodeURIComponent(problemId)}`
            cta.target = "_blank"
            cta.rel = "noopener noreferrer"
            cta.className = "block w-full rounded-lg bg-brand-500 px-4 py-2 text-center text-sm font-semibold text-white hover:bg-brand-600"
            cta.textContent = this.strings.details
            content.appendChild(cta)
        }

        body.appendChild(content)
        return body
    }

    /**
     * Builds a topo photo preview with the problem line overlay when tile data
     * carries both a safe photo URL and normalized line coordinates.
     * @param {Object} properties Tile feature properties.
     * @param {Object} callbacks { close } handler.
     * @returns {HTMLElement|null} Preview element or null.
     */
    problemTopoPreview(properties, callbacks) {
        const photoUrl = this.safeHttpUrl(properties.topoPhotoUrl)
        const coordinates = this.lineCoordinates(properties.lineCoordinatesJson)
        if (!photoUrl || coordinates.length < 2) return null

        const frame = document.createElement("div")
        frame.className = "relative overflow-hidden bg-gray-100 lg:rounded-t-xl"
        frame.style.aspectRatio = "4 / 3"

        const image = document.createElement("img")
        image.src = photoUrl.toString()
        image.alt = ""
        image.className = "h-full w-full object-cover"
        image.onerror = () => frame.remove()
        frame.appendChild(image)

        const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
        svg.setAttribute("viewBox", "0 0 400 300")
        svg.setAttribute("preserveAspectRatio", "none")
        svg.setAttribute("class", "absolute inset-0 h-full w-full")

        const shadow = document.createElementNS("http://www.w3.org/2000/svg", "polyline")
        shadow.setAttribute("points", this.svgPoints(coordinates))
        shadow.setAttribute("fill", "none")
        shadow.setAttribute("stroke", "rgba(0,0,0,0.55)")
        shadow.setAttribute("stroke-width", "4")
        shadow.setAttribute("stroke-linecap", "round")
        shadow.setAttribute("stroke-linejoin", "round")
        svg.appendChild(shadow)

        const line = document.createElementNS("http://www.w3.org/2000/svg", "polyline")
        line.setAttribute("points", this.svgPoints(coordinates))
        line.setAttribute("fill", "none")
        line.setAttribute("stroke", "#ef3340")
        line.setAttribute("stroke-width", "2.4")
        line.setAttribute("stroke-linecap", "round")
        line.setAttribute("stroke-linejoin", "round")
        svg.appendChild(line)

        const start = coordinates[0]
        const dot = document.createElementNS("http://www.w3.org/2000/svg", "circle")
        dot.setAttribute("cx", String(start.x * 400))
        dot.setAttribute("cy", String(start.y * 300))
        dot.setAttribute("r", "7.5")
        dot.setAttribute("fill", "#ef3340")
        dot.setAttribute("stroke", "#ffffff")
        dot.setAttribute("stroke-width", "1")
        svg.appendChild(dot)

        frame.appendChild(svg)
        frame.appendChild(this.mediaCloseButton(callbacks))
        return frame
    }

    /**
     * Builds a more prominent problem grade row with secondary details beside it.
     * @param {Object} properties Tile feature properties.
     * @returns {HTMLElement|null} Details row or null.
     */
    problemDetails(properties) {
        const details = []
        const steepness = this.strings.steepness?.[properties.steepness]
        if (steepness) details.push(steepness)
        if (properties.height) details.push(this.strings.height_meters.replace("%{height}", properties.height))
        if (!properties.grade && details.length === 0) return null

        const row = document.createElement("div")
        row.className = "flex items-center gap-3"

        if (properties.grade) {
            const grade = document.createElement("span")
            grade.className = "text-3xl font-bold leading-none text-gray-700"
            grade.textContent = properties.grade
            row.appendChild(grade)
        }

        if (details.length > 0) {
            const meta = document.createElement("p")
            meta.className = "text-sm text-gray-500"
            meta.textContent = details.join(" · ")
            row.appendChild(meta)
        }

        return row
    }

    /**
     * Parses normalized line coordinates from a tile scalar JSON string.
     * @param {string} value JSON-encoded [{x, y}, ...] coordinates.
     * @returns {Object[]} Safe normalized coordinates.
     */
    lineCoordinates(value) {
        try {
            const coordinates = JSON.parse(value)
            if (!Array.isArray(coordinates)) return []

            return coordinates.filter((point) => {
                const x = Number(point?.x)
                const y = Number(point?.y)
                return Number.isFinite(x) && Number.isFinite(y) && x >= 0 && x <= 1 && y >= 0 && y <= 1
            }).map((point) => ({ x: Number(point.x), y: Number(point.y) }))
        } catch (_error) {
            return []
        }
    }

    /**
     * Converts normalized coordinates to SVG polyline points.
     * @param {Object[]} coordinates Safe normalized coordinates.
     * @returns {string} SVG points value.
     */
    svgPoints(coordinates) {
        return coordinates.map((point) => `${point.x * 400},${point.y * 300}`).join(" ")
    }

    /**
     * Builds the POI card body.
     * @param {Object} properties Tile feature properties.
     * @param {Object} callbacks { showOnMap, close } handlers.
     * @returns {HTMLElement} Card body element.
     */
    poiContent(properties, callbacks) {
        const content = document.createElement("div")
        content.className = "p-4 space-y-3"
        content.appendChild(this.headerRow(properties.name || "", callbacks))

        const poiType = this.strings.poi_types?.[properties.poiType]
        if (poiType) {
            const line = document.createElement("p")
            line.className = "text-sm text-gray-500"
            line.textContent = poiType
            content.appendChild(line)
        }

        const googleUrl = this.safeHttpUrl(properties.googleUrl)
        if (googleUrl) {
            content.appendChild(this.outboundLink(this.strings.directions, googleUrl, "block w-full rounded-lg bg-brand-500 px-4 py-2 text-center text-sm font-semibold text-white hover:bg-brand-600"))
        }

        return content
    }

    /**
     * Builds the title row with the close button.
     * @param {string} title Localized display name.
     * @param {Object} callbacks { showOnMap, close } handlers.
     * @returns {HTMLElement} Header row element.
     */
    headerRow(title, callbacks, { showClose = true } = {}) {
        const row = document.createElement("div")
        row.className = "flex items-start justify-between gap-2"

        const heading = document.createElement("h2")
        heading.className = "text-lg font-semibold text-gray-900"
        heading.textContent = title
        row.appendChild(heading)

        if (showClose) row.appendChild(this.headerCloseButton(callbacks))
        return row
    }

    /**
     * Builds a normal close button for non-media card headers.
     * @param {Object} callbacks { close } handler.
     * @returns {HTMLElement} Close button.
     */
    headerCloseButton(callbacks) {
        const close = document.createElement("button")
        close.type = "button"
        close.className = "inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-gray-400 hover:bg-gray-100 hover:text-gray-600"
        close.setAttribute("aria-label", this.strings.close)
        close.textContent = "✕"
        close.addEventListener("click", () => callbacks.close())
        return close
    }

    /**
     * Builds a high-contrast close button over photo/topo media.
     * @param {Object} callbacks { close } handler.
     * @returns {HTMLElement} Close button.
     */
    mediaCloseButton(callbacks) {
        const close = document.createElement("button")
        close.type = "button"
        close.className = "absolute right-3 top-3 z-10 inline-flex h-8 w-8 items-center justify-center rounded-full bg-black/55 font-semibold leading-none text-white shadow-lg ring-1 ring-white/40 backdrop-blur-sm hover:bg-black/70 focus:outline-none focus:ring-2 focus:ring-white"
        close.setAttribute("aria-label", this.strings.close)
        close.textContent = "✕"
        close.addEventListener("click", () => callbacks.close())
        return close
    }

    /**
     * Builds the problem-count line and grade-distribution histogram when data
     * is present. Tiles published before the histogram property exist fall back
     * to the textual grade range.
     * @param {Object} properties Tile feature properties.
     * @returns {HTMLElement|null} Stats block element or null.
     */
    statsLine(properties) {
        const histogram = this.gradeHistogram(properties.gradeHistogramJson)

        const parts = []
        if (properties.problemCount !== undefined && properties.problemCount !== null) {
            parts.push(`${properties.problemCount} ${this.strings.problems}`)
        }
        if (!histogram && properties.gradeMin && properties.gradeMax) {
            parts.push(`${properties.gradeMin} – ${properties.gradeMax}`)
        }
        if (parts.length === 0 && !histogram) return null

        const block = document.createElement("div")
        block.className = "space-y-4"
        if (parts.length > 0) {
            const line = document.createElement("p")
            line.className = "text-sm text-gray-500"
            line.textContent = parts.join(" · ")
            block.appendChild(line)
        }
        if (histogram) block.appendChild(histogram)
        return block
    }

    /**
     * Builds the grade-distribution bar chart from the tile histogram property.
     * One column per letter grade ("6a", "6b", …), trimmed to the populated
     * range (padded to at least five columns so bars keep a consistent width);
     * bar heights scale to the most common grade. Hovering a column shows its
     * problem count in a small bubble.
     * @param {string} value JSON-encoded per-letter-grade problem counts.
     * @returns {HTMLElement|null} Histogram element or null.
     */
    gradeHistogram(value) {
        const entries = this.histogramEntries(value)
        if (!entries) return null

        const max = Math.max(...entries.map(({ count }) => count))

        const chart = document.createElement("div")
        chart.className = "pt-4 pb-3"
        chart.setAttribute("role", "img")
        chart.setAttribute(
            "aria-label",
            `${this.strings.grade_distribution}: ${entries.map(({ grade, count }) => `${grade}: ${count}`).join(", ")}`,
        )

        const bars = document.createElement("div")
        bars.className = "flex h-12 items-stretch gap-px border-b border-gray-200"
        const labels = document.createElement("div")
        labels.className = "mt-2 flex gap-px"

        for (const { grade, count } of entries) {
            const column = document.createElement("div")
            column.className = "group relative flex flex-1 items-end"
            column.title = `${grade}: ${count} ${this.strings.problems}`

            const bar = document.createElement("div")
            bar.className = `w-full rounded-t-sm ${this.histogramBarColor(count, max)}`
            bar.style.height = count > 0 ? `${Math.max(4, Math.round((count / max) * 48))}px` : "2px"
            column.appendChild(bar)

            if (count > 0) {
                const bubble = document.createElement("span")
                bubble.className = "pointer-events-none absolute left-1/2 hidden -translate-x-1/2 whitespace-nowrap rounded bg-gray-900/80 px-1 py-0.5 text-[10px] font-medium leading-none text-white group-hover:block"
                bubble.style.bottom = `${Math.max(4, Math.round((count / max) * 48)) + 3}px`
                bubble.textContent = String(count)
                column.appendChild(bubble)
            }
            bars.appendChild(column)

            const label = document.createElement("span")
            label.className = "flex-1 text-center text-[10px] font-medium leading-none text-gray-400"
            label.textContent = grade
            labels.appendChild(label)
        }

        chart.appendChild(bars)
        chart.appendChild(labels)
        return chart
    }

    /**
     * Picks the bar color tier from the count relative to the most common
     * grade: the busiest third renders most intense, quieter grades fade.
     * @param {number} count Problems at this grade.
     * @param {number} max Problems at the most common grade.
     * @returns {string} Tailwind background class.
     */
    histogramBarColor(count, max) {
        if (count <= 0) return "bg-gray-200"
        const ratio = count / max
        if (ratio > 2 / 3) return "bg-brand-500"
        if (ratio > 1 / 3) return "bg-brand-400"
        return "bg-brand-300"
    }

    /**
     * Parses the per-letter-grade histogram from a tile scalar JSON string into
     * an ordered, gap-filled list of {grade, count} entries trimmed to the
     * populated range (padded to at least five columns).
     * @param {string} value JSON-encoded {"6a": 12, ...} object.
     * @returns {Object[]|null} Safe ordered entries or null.
     */
    histogramEntries(value) {
        let counts
        try {
            counts = JSON.parse(value)
        } catch (_error) {
            return null
        }
        if (typeof counts !== "object" || counts === null || Array.isArray(counts)) return null

        const scale = []
        for (let level = 1; level <= 9; level += 1) {
            for (const letter of ["a", "b", "c"]) scale.push(`${level}${letter}`)
        }
        const valid = Object.entries(counts).every(([grade, count]) =>
            scale.includes(grade) && Number.isInteger(count) && count > 0)
        if (!valid || Object.keys(counts).length === 0) return null

        let first = scale.findIndex((grade) => counts[grade])
        let last = scale.length - 1 - [...scale].reverse().findIndex((grade) => counts[grade])
        const MIN_COLUMNS = 5
        while (last - first + 1 < MIN_COLUMNS && (first > 0 || last < scale.length - 1)) {
            if (last < scale.length - 1) last += 1
            else first -= 1
        }

        return scale.slice(first, last + 1).map((grade) => ({ grade, count: counts[grade] || 0 }))
    }

    /**
     * Builds a label + outbound-link row.
     * @param {string} label Row label text.
     * @param {string} linkText Link text.
     * @param {URL} url Verified HTTP(S) URL.
     * @returns {HTMLElement} Row element.
     */
    labelledLinkRow(label, linkText, url) {
        const row = document.createElement("p")
        row.className = "text-sm text-gray-700"
        if (label) row.appendChild(document.createTextNode(`${label}: `))
        row.appendChild(this.outboundLink(linkText, url, "font-medium text-brand-500 hover:underline"))
        return row
    }

    /**
     * Builds a safe outbound link.
     * @param {string} text Link text.
     * @param {URL} url Verified HTTP(S) URL.
     * @param {string} className Tailwind classes for the link.
     * @returns {HTMLElement} Anchor element.
     */
    outboundLink(text, url, className) {
        const link = document.createElement("a")
        link.href = url.toString()
        link.target = "_blank"
        link.rel = "noopener noreferrer"
        link.className = className
        link.textContent = text
        return link
    }

    /**
     * Selects the localized value following the tile contract (base value is
     * German, the En variant is present only when different).
     * @param {string} value German/base value.
     * @param {string} valueEn English variant or undefined.
     * @returns {string} Localized text.
     */
    localizedText(value, valueEn) {
        if (this.locale === "en" && valueEn) return valueEn
        return value || ""
    }

    /**
     * Accepts only HTTP(S) URLs for card links.
     * @param {string} value Raw URL value from tile properties.
     * @returns {URL|null} Parsed safe URL or null.
     */
    safeHttpUrl(value) {
        try {
            const url = new URL(value)
            return ["http:", "https:"].includes(url.protocol) ? url : null
        } catch (_error) {
            return null
        }
    }
}
