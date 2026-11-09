import { SAFE_BOTTOM, SAFE_TOP, cellPixelRects, placeMedia, type MediaView, type PxRect } from './geometry'
import type { CellState, Rect } from './types'

export interface Source {
  img: CanvasImageSource
  w: number
  h: number
}

export interface DrawOptions {
  rects: Rect[]
  cells: CellState[]
  gap: number
  radius: number
  bg: string
  getSource: (mediaId: string) => Source | null
  /** Preview-only extras. */
  overlay?: {
    selected: number | null
    swapFrom: number | null
    safeZone: boolean
    /** A picture picked up with press-and-hold, being dragged to another cell. x, y are canvas pixels. */
    lift?: { from: number; x: number; y: number; over: number } | null
  }
}

/** Draws a source into a cell with its zoom, pan, rotation, flip and straighten. Used for preview, export and the crop screen. */
export function drawMedia(ctx: CanvasRenderingContext2D, src: Source, rect: PxRect, view: MediaView) {
  const p = placeMedia(src.w, src.h, rect, view)
  const w = src.w * p.scale
  const h = src.h * p.scale
  ctx.save()
  ctx.translate(p.cx, p.cy)
  ctx.rotate(p.angleRad)
  if (p.flip) ctx.scale(-1, 1)
  ctx.rotate(p.rotationRad)
  try {
    ctx.drawImage(src.img, -w / 2, -h / 2, w, h)
  } catch {
    // frame not ready yet
  }
  ctx.restore()
}

export function roundRectPath(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) {
  const rr = Math.max(0, Math.min(r, w / 2, h / 2))
  ctx.beginPath()
  ctx.moveTo(x + rr, y)
  ctx.arcTo(x + w, y, x + w, y + h, rr)
  ctx.arcTo(x + w, y + h, x, y + h, rr)
  ctx.arcTo(x, y + h, x, y, rr)
  ctx.arcTo(x, y, x + w, y, rr)
  ctx.closePath()
}

/** Draws the whole collage. Used by both the live preview and the export, so they always match. */
export function drawCollage(ctx: CanvasRenderingContext2D, W: number, H: number, o: DrawOptions): PxRect[] {
  const scale = W / 1080
  ctx.save()
  ctx.imageSmoothingEnabled = true
  ctx.imageSmoothingQuality = 'high'
  ctx.fillStyle = o.bg
  ctx.fillRect(0, 0, W, H)

  const px = cellPixelRects(o.rects, W, H, o.gap)
  const radius = o.radius * scale

  px.forEach((r, i) => {
    const cell = o.cells[i]
    const src = cell?.mediaId ? o.getSource(cell.mediaId) : null
    ctx.save()
    roundRectPath(ctx, r.x, r.y, r.w, r.h, radius)
    ctx.clip()
    if (src && src.w > 0 && src.h > 0) {
      drawMedia(ctx, src, r, cell)
    } else if (o.overlay) {
      ctx.fillStyle = 'rgba(255,255,255,0.08)'
      ctx.fillRect(r.x, r.y, r.w, r.h)
    }
    ctx.restore()
  })

  const ov = o.overlay
  if (ov) {
    px.forEach((r, i) => {
      const cell = o.cells[i]
      if (!cell?.mediaId) {
        // "+" mark on empty cells
        const s = Math.min(r.w, r.h) * 0.16
        ctx.save()
        ctx.strokeStyle = 'rgba(255,255,255,0.55)'
        ctx.lineWidth = Math.max(2, 3 * scale)
        ctx.lineCap = 'round'
        const cx = r.x + r.w / 2
        const cy = r.y + r.h / 2
        ctx.beginPath()
        ctx.moveTo(cx - s, cy)
        ctx.lineTo(cx + s, cy)
        ctx.moveTo(cx, cy - s)
        ctx.lineTo(cx, cy + s)
        ctx.stroke()
        ctx.restore()
      }
    })
    const mark = (i: number | null, color: string) => {
      if (i === null || !px[i]) return
      const r = px[i]
      ctx.save()
      ctx.strokeStyle = color
      ctx.lineWidth = Math.max(3, 5 * scale)
      roundRectPath(ctx, r.x + 1.5 * scale, r.y + 1.5 * scale, r.w - 3 * scale, r.h - 3 * scale, radius)
      ctx.stroke()
      ctx.restore()
    }
    mark(ov.swapFrom, '#ffb84a')
    mark(ov.selected, '#8b6cff')
    if (ov.lift) {
      const L = ov.lift
      const from = px[L.from]
      if (from) {
        ctx.save()
        ctx.fillStyle = 'rgba(0,0,0,0.5)'
        roundRectPath(ctx, from.x, from.y, from.w, from.h, radius)
        ctx.fill()
        ctx.restore()
        if (L.over >= 0 && L.over !== L.from) mark(L.over, '#ff5fa2')
        const media = o.cells[L.from]?.mediaId
        const src = media ? o.getSource(media) : null
        const gw = Math.min(W, H) * 0.3
        const gh = Math.min(H * 0.3, gw * (from.h / from.w))
        const g = { x: L.x - gw / 2, y: L.y - gh / 2, w: gw, h: gh }
        ctx.save()
        ctx.globalAlpha = 0.92
        roundRectPath(ctx, g.x, g.y, g.w, g.h, Math.min(radius, 24 * scale))
        ctx.clip()
        if (src) {
          const c0 = o.cells[L.from]
          drawMedia(ctx, src, g, { zoom: 1, panX: 0, panY: 0, rotation: c0.rotation, flip: c0.flip, angle: c0.angle })
        } else {
          ctx.fillStyle = '#8b6cff'
          ctx.fillRect(g.x, g.y, g.w, g.h)
        }
        ctx.restore()
        ctx.save()
        ctx.strokeStyle = '#fff'
        ctx.lineWidth = Math.max(2, 4 * scale)
        roundRectPath(ctx, g.x, g.y, g.w, g.h, Math.min(radius, 24 * scale))
        ctx.stroke()
        ctx.restore()
      }
    }
    if (ov.safeZone) {
      ctx.save()
      ctx.fillStyle = 'rgba(255,80,80,0.14)'
      ctx.fillRect(0, 0, W, H * SAFE_TOP)
      ctx.fillRect(0, H * (1 - SAFE_BOTTOM), W, H * SAFE_BOTTOM)
      ctx.strokeStyle = 'rgba(255,110,110,0.9)'
      ctx.lineWidth = Math.max(1, 2 * scale)
      ctx.setLineDash([10 * scale, 8 * scale])
      ctx.beginPath()
      ctx.moveTo(0, H * SAFE_TOP)
      ctx.lineTo(W, H * SAFE_TOP)
      ctx.moveTo(0, H * (1 - SAFE_BOTTOM))
      ctx.lineTo(W, H * (1 - SAFE_BOTTOM))
      ctx.stroke()
      ctx.restore()
    }
  }
  ctx.restore()
  return px
}
