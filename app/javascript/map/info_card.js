/**
 * Info card renderer for the Austrian Rocks map. Builds the card DOM
 * exclusively with createElement/textContent — tile feature properties are
 * untrusted input, so no HTML interpolation — and lays out responsively via
 * Tailwind classes: bottom sheet below the lg breakpoint, docked floating
 * panel at and above it. All static strings arrive localized from Rails via
 * the data-map-card-strings-value JSON blob.
 */

const CONTAINER_CLASSES = "fixed inset-x-0 bottom-0 z-20 max-h-[60vh] overflow-y-auto rounded-t-xl bg-white shadow-2xl lg:inset-x-auto lg:bottom-auto lg:left-4 lg:top-4 lg:w-96 lg:max-h-[calc(100vh-2rem)] lg:rounded-xl"

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
            const cover = document.createElement("img")
            cover.src = coverUrl.toString()
            cover.alt = ""
            cover.className = "h-40 w-full object-cover rounded-t-xl"
            cover.onerror = () => cover.remove()
            body.appendChild(cover)
        }

        const content = document.createElement("div")
        content.className = "p-4 space-y-3"
        content.appendChild(this.headerRow(this.localizedText(properties.name, properties.nameEn), callbacks))

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
        const content = document.createElement("div")
        content.className = "p-4 space-y-3"
        content.appendChild(this.headerRow(this.localizedText(properties.name, properties.nameEn), callbacks))

        const details = []
        if (properties.grade) details.push(properties.grade)
        const steepness = this.strings.steepness?.[properties.steepness]
        if (steepness) details.push(steepness)
        if (properties.height) details.push(this.strings.height_meters.replace("%{height}", properties.height))
        if (details.length > 0) {
            const line = document.createElement("p")
            line.className = "text-sm text-gray-500"
            line.textContent = details.join(" · ")
            content.appendChild(line)
        }

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

        return content
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
    headerRow(title, callbacks) {
        const row = document.createElement("div")
        row.className = "flex items-start justify-between gap-2"

        const heading = document.createElement("h2")
        heading.className = "text-lg font-semibold text-gray-900"
        heading.textContent = title
        row.appendChild(heading)

        const close = document.createElement("button")
        close.type = "button"
        close.className = "shrink-0 rounded-full p-1 text-gray-400 hover:bg-gray-100 hover:text-gray-600"
        close.setAttribute("aria-label", this.strings.close)
        close.textContent = "✕"
        close.addEventListener("click", () => callbacks.close())
        row.appendChild(close)
        return row
    }

    /**
     * Builds the problem-count and grade-range line when data is present.
     * @param {Object} properties Tile feature properties.
     * @returns {HTMLElement|null} Stats line element or null.
     */
    statsLine(properties) {
        const parts = []
        if (properties.problemCount !== undefined && properties.problemCount !== null) {
            parts.push(`${properties.problemCount} ${this.strings.problems}`)
        }
        if (properties.gradeMin && properties.gradeMax) {
            parts.push(`${properties.gradeMin} – ${properties.gradeMax}`)
        }
        if (parts.length === 0) return null

        const line = document.createElement("p")
        line.className = "text-sm text-gray-500"
        line.textContent = parts.join(" · ")
        return line
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
