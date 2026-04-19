import { Controller } from '@hotwired/stimulus'

const POINT_RADIUS_SCREEN_PX = 8
const HIT_RADIUS_SCREEN_PX = 14
const MIN_SCALE = 0.1
const MAX_SCALE = 20

export default class extends Controller {
  static targets = ["textarea", "canvas", "container", "image", "viewport", "wrapper", "zoomLabel"]

  connect() {
    this.points = []
    this.history = []
    this.scale = 1
    this.tx = 0
    this.ty = 0
    this.dragging = null // { type: 'pan'|'point', ... }
    this.activePointers = new Map()

    this.imageTarget.addEventListener('load', () => this.onImageLoad(), { once: true })
    if (this.imageTarget.complete && this.imageTarget.naturalWidth) {
      this.onImageLoad()
    } else {
      this.imageTarget.src = this.imageTarget.src
    }

    this._onKeyDown = (e) => this.handleKeyDown(e)
    window.addEventListener('keydown', this._onKeyDown)
    this._onResize = () => this.fit()
    window.addEventListener('resize', this._onResize)
  }

  disconnect() {
    window.removeEventListener('keydown', this._onKeyDown)
    window.removeEventListener('resize', this._onResize)
  }

  onImageLoad() {
    const img = this.imageTarget
    const w = img.naturalWidth
    const h = img.naturalHeight

    this.wrapperTarget.style.width = w + 'px'
    this.wrapperTarget.style.height = h + 'px'
    img.width = w
    img.height = h
    this.canvasTarget.width = w
    this.canvasTarget.height = h

    try {
      this.points = JSON.parse(this.textareaTarget.value) || []
    } catch (e) {
      this.points = []
    }

    this.fit()
  }

  // -------- Transform helpers --------

  applyTransform() {
    this.wrapperTarget.style.transform =
      `translate(${this.tx}px, ${this.ty}px) scale(${this.scale})`
    if (this.hasZoomLabelTarget) {
      this.zoomLabelTarget.textContent = Math.round(this.scale * 100) + '%'
    }
    this.redraw()
  }

  fit() {
    if (!this.imageTarget.naturalWidth) return
    const vpRect = this.viewportTarget.getBoundingClientRect()
    const iw = this.imageTarget.naturalWidth
    const ih = this.imageTarget.naturalHeight
    const scale = Math.min(vpRect.width / iw, vpRect.height / ih)
    this.scale = scale
    this.tx = (vpRect.width - iw * scale) / 2
    this.ty = (vpRect.height - ih * scale) / 2
    this.applyTransform()
  }

  reset() { this.fit() }

  zoomBy(factor, centerClient) {
    const vpRect = this.viewportTarget.getBoundingClientRect()
    const cx = (centerClient ? centerClient.x : vpRect.left + vpRect.width / 2) - vpRect.left
    const cy = (centerClient ? centerClient.y : vpRect.top + vpRect.height / 2) - vpRect.top

    const newScale = Math.max(MIN_SCALE, Math.min(MAX_SCALE, this.scale * factor))
    const ratio = newScale / this.scale
    this.tx = cx - (cx - this.tx) * ratio
    this.ty = cy - (cy - this.ty) * ratio
    this.scale = newScale
    this.applyTransform()
  }

  zoomIn() { this.zoomBy(1.25) }
  zoomOut() { this.zoomBy(1 / 1.25) }

  // -------- Coordinate conversion --------

  // Client (page) coords -> image pixel coords
  clientToImage(clientX, clientY) {
    const vpRect = this.viewportTarget.getBoundingClientRect()
    const x = (clientX - vpRect.left - this.tx) / this.scale
    const y = (clientY - vpRect.top - this.ty) / this.scale
    return { x, y }
  }

  // -------- Drawing --------

  redraw() {
    const canvas = this.canvasTarget
    const ctx = canvas.getContext('2d')
    ctx.clearRect(0, 0, canvas.width, canvas.height)

    const r = POINT_RADIUS_SCREEN_PX / this.scale
    const lineW = 2 / this.scale

    // connecting polyline
    if (this.points.length > 1) {
      ctx.strokeStyle = 'rgba(255, 38, 38, 0.85)'
      ctx.lineWidth = lineW * 1.5
      ctx.beginPath()
      this.points.forEach((p, i) => {
        const x = p.x * canvas.width
        const y = p.y * canvas.height
        if (i === 0) ctx.moveTo(x, y)
        else ctx.lineTo(x, y)
      })
      ctx.stroke()
    }

    this.points.forEach((p, i) => {
      const x = p.x * canvas.width
      const y = p.y * canvas.height
      ctx.beginPath()
      ctx.arc(x, y, r, 0, Math.PI * 2)
      ctx.fillStyle = '#ff2626'
      ctx.fill()
      ctx.lineWidth = lineW
      ctx.strokeStyle = '#fff'
      ctx.stroke()
    })
  }

  // -------- Point operations --------

  pushHistory() {
    this.history.push(JSON.stringify(this.points))
    if (this.history.length > 50) this.history.shift()
  }

  syncTextarea() {
    this.textareaTarget.value = JSON.stringify(this.points)
  }

  limitPrecision(v) { return parseFloat(v.toFixed(4)) }

  findPointAt(imgX, imgY) {
    const canvas = this.canvasTarget
    const rImg = HIT_RADIUS_SCREEN_PX / this.scale
    for (let i = this.points.length - 1; i >= 0; i--) {
      const p = this.points[i]
      const dx = p.x * canvas.width - imgX
      const dy = p.y * canvas.height - imgY
      if (dx * dx + dy * dy <= rImg * rImg) return i
    }
    return -1
  }

  addPointAtImage(imgX, imgY) {
    const canvas = this.canvasTarget
    this.pushHistory()
    this.points.push({
      x: this.limitPrecision(imgX / canvas.width),
      y: this.limitPrecision(imgY / canvas.height)
    })
    this.syncTextarea()
    this.redraw()
  }

  removePoint(index) {
    this.pushHistory()
    this.points.splice(index, 1)
    this.syncTextarea()
    this.redraw()
  }

  undo() {
    if (!this.history.length) return
    this.points = JSON.parse(this.history.pop())
    this.syncTextarea()
    this.redraw()
  }

  clearAll() {
    if (!this.points.length) return
    if (!confirm('Remove all points?')) return
    this.pushHistory()
    this.points = []
    this.syncTextarea()
    this.redraw()
  }

  // -------- Pointer interaction --------

  onPointerDown(event) {
    event.preventDefault()
    this.viewportTarget.setPointerCapture(event.pointerId)
    this.activePointers.set(event.pointerId, { x: event.clientX, y: event.clientY })

    // pinch start
    if (this.activePointers.size === 2) {
      this.dragging = null
      const pts = [...this.activePointers.values()]
      this.pinchStartDist = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y)
      this.pinchStartScale = this.scale
      return
    }

    const img = this.clientToImage(event.clientX, event.clientY)
    const idx = this.findPointAt(img.x, img.y)

    // right-click or shift-click on a point => delete
    if (idx >= 0 && (event.button === 2 || event.shiftKey)) {
      this.removePoint(idx)
      this.dragging = { type: 'consume' }
      return
    }

    if (idx >= 0 && event.button === 0) {
      this.pushHistory()
      this.dragging = { type: 'point', index: idx, moved: false }
      return
    }

    // pan: middle button, alt/space, or no hit + drag
    this.dragging = {
      type: 'pan-or-click',
      startClient: { x: event.clientX, y: event.clientY },
      startTx: this.tx,
      startTy: this.ty,
      button: event.button,
      moved: false,
    }
  }

  onPointerMove(event) {
    if (this.activePointers.has(event.pointerId)) {
      this.activePointers.set(event.pointerId, { x: event.clientX, y: event.clientY })
    }

    // pinch
    if (this.activePointers.size === 2 && this.pinchStartDist) {
      const pts = [...this.activePointers.values()]
      const dist = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y)
      const center = { x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2 }
      const targetScale = Math.max(MIN_SCALE, Math.min(MAX_SCALE, this.pinchStartScale * (dist / this.pinchStartDist)))
      this.zoomBy(targetScale / this.scale, center)
      return
    }

    if (!this.dragging) return

    const d = this.dragging
    if (d.type === 'point') {
      const img = this.clientToImage(event.clientX, event.clientY)
      const canvas = this.canvasTarget
      const p = this.points[d.index]
      p.x = this.limitPrecision(Math.max(0, Math.min(1, img.x / canvas.width)))
      p.y = this.limitPrecision(Math.max(0, Math.min(1, img.y / canvas.height)))
      d.moved = true
      this.redraw()
    } else if (d.type === 'pan-or-click') {
      const dx = event.clientX - d.startClient.x
      const dy = event.clientY - d.startClient.y
      if (!d.moved && Math.hypot(dx, dy) > 4) d.moved = true
      if (d.moved) {
        this.tx = d.startTx + dx
        this.ty = d.startTy + dy
        this.applyTransform()
      }
    }
  }

  onPointerUp(event) {
    this.activePointers.delete(event.pointerId)
    if (this.activePointers.size < 2) this.pinchStartDist = null
    try { this.viewportTarget.releasePointerCapture(event.pointerId) } catch (_) {}

    const d = this.dragging
    this.dragging = null
    if (!d) return

    if (d.type === 'pan-or-click' && !d.moved && d.button === 0) {
      const img = this.clientToImage(event.clientX, event.clientY)
      if (img.x >= 0 && img.y >= 0 && img.x <= this.canvasTarget.width && img.y <= this.canvasTarget.height) {
        this.addPointAtImage(img.x, img.y)
      }
    }
    if (d.type === 'point' && !d.moved) {
      // click on point without moving: no-op (history already pushed); roll it back
      this.history.pop()
    } else if (d.type === 'point' && d.moved) {
      this.syncTextarea()
    }
  }

  onWheel(event) {
    event.preventDefault()
    const factor = event.deltaY < 0 ? 1.15 : 1 / 1.15
    this.zoomBy(factor, { x: event.clientX, y: event.clientY })
  }

  onContextMenu(event) {
    event.preventDefault()
  }

  handleKeyDown(event) {
    const meta = event.ctrlKey || event.metaKey
    if (meta && event.key.toLowerCase() === 'z') {
      event.preventDefault()
      this.undo()
    }
  }
}
