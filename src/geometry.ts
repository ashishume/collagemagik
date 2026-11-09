import type { FormatId, Rect } from './types'

export interface FormatInfo {
  w: number
  h: number
  label: string
  short: string
}

export const FORMATS: Record<FormatId, FormatInfo> = {
  story: { w: 1080, h: 1920, label: 'Story 9:16', short: '9:16' },
  post: { w: 1080, h: 1350, label: 'Post 4:5', short: '4:5' },
  square: { w: 1080, h: 1080, label: 'Square 1:1', short: '1:1' },
}

/** Instagram covers roughly the top 14% and bottom 18% of a Story with its own buttons. */
export const SAFE_TOP = 0.14
export const SAFE_BOTTOM = 0.18

export interface PxRect {
  x: number
  y: number
  w: number
  h: number
}

/**
 * Cell rectangles in pixels. `gap` (in pixels at 1080 wide) is both the space between cells and the margin around
 * the whole collage.
 */
export function cellPixelRects(rects: Rect[], W: number, H: number, gap: number): PxRect[] {
  const g = gap * (W / 1080)
  const half = g / 2
  const areaX = half
  const areaY = half
  const areaW = W - g
  const areaH = H - g
  return rects.map(([rx, ry, rw, rh]) => ({
    x: areaX + rx * areaW + half,
    y: areaY + ry * areaH + half,
    w: Math.max(1, rw * areaW - g),
    h: Math.max(1, rh * areaH - g),
  }))
}

export interface DrawRect {
  dx: number
  dy: number
  dw: number
  dh: number
  /** How far the drawn media overflows the cell on each axis (px, >= 0). */
  overflowX: number
  overflowY: number
}

export const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v))

/** Where to draw a source of srcW×srcH so it covers the cell, scaled by zoom and shifted by pan. */
export function coverRect(
  srcW: number,
  srcH: number,
  cell: PxRect,
  zoom: number,
  panX: number,
  panY: number,
): DrawRect {
  const scale = Math.max(cell.w / srcW, cell.h / srcH) * Math.max(1, zoom)
  const dw = srcW * scale
  const dh = srcH * scale
  const overflowX = Math.max(0, dw - cell.w)
  const overflowY = Math.max(0, dh - cell.h)
  const px = clamp(panX, -1, 1)
  const py = clamp(panY, -1, 1)
  return {
    dx: cell.x - overflowX / 2 + (px * overflowX) / 2,
    dy: cell.y - overflowY / 2 + (py * overflowY) / 2,
    dw,
    dh,
    overflowX,
    overflowY,
  }
}

/** New pan value after dragging the media by `deltaPx` along an axis. */
export function panAfterDrag(pan: number, deltaPx: number, overflowPx: number): number {
  if (overflowPx < 0.5) return 0
  return clamp(pan + deltaPx / (overflowPx / 2), -1, 1)
}

export const RAD = Math.PI / 180

/** Width and height of a source after quarter turns. */
export function quarterDims(w: number, h: number, rotation: number) {
  const odd = (((Math.round(rotation / 90) % 2) + 2) % 2) === 1
  return odd ? { w: h, h: w } : { w, h }
}

export interface MediaView {
  zoom: number
  panX: number
  panY: number
  rotation: number
  flip: boolean
  angle: number
}

/** Scale at which a (rotated, straightened) source just covers the cell. With no rotation this is the usual "cover". */
export function coverScale(srcW: number, srcH: number, cell: { w: number; h: number }, rotation = 0, angle = 0): number {
  const q = quarterDims(srcW, srcH, rotation)
  const t = angle * RAD
  const c = Math.abs(Math.cos(t))
  const s = Math.abs(Math.sin(t))
  return Math.max((cell.w * c + cell.h * s) / q.w, (cell.w * s + cell.h * c) / q.h)
}

/**
 * How far (0..1) a requested shift (ox, oy) of a tilted picture can go before an empty corner would show.
 * The picture is a dw×dh rectangle tilted by `angle`; the cell must stay inside it.
 */
function maxShiftFraction(dw: number, dh: number, cell: { w: number; h: number }, angle: number, ox: number, oy: number) {
  const t = angle * RAD
  const c = Math.cos(t)
  const s = Math.sin(t)
  let hi = 1
  for (const [sx, sy] of [
    [-1, -1],
    [1, -1],
    [-1, 1],
    [1, 1],
  ]) {
    const qx = (sx * cell.w) / 2
    const qy = (sy * cell.h) / 2
    const ax = c * qx + s * qy
    const ay = -s * qx + c * qy
    const bx = c * ox + s * oy
    const by = -s * ox + c * oy
    for (const [a, b, half] of [
      [ax, bx, dw / 2],
      [ay, by, dh / 2],
    ]) {
      if (Math.abs(b) < 1e-9) continue
      hi = Math.min(hi, Math.max((a - half) / b, (a + half) / b))
    }
  }
  return Math.max(0, hi)
}

export interface Placement {
  /** Centre of the picture in pixels. */
  cx: number
  cy: number
  /** Source pixels to canvas pixels. */
  scale: number
  rotationRad: number
  angleRad: number
  flip: boolean
  /** Room to move the picture on each axis, as used for panning (px, >= 0). */
  overflowX: number
  overflowY: number
  /** 1 unless a tilted picture had to be pulled back so no empty corner shows. */
  fit: number
}

/** Where and how to draw a source in a cell: covers the cell, then zoom, rotation, flip, straighten and pan. */
export function placeMedia(srcW: number, srcH: number, cell: PxRect, v: MediaView): Placement {
  const scale = coverScale(srcW, srcH, cell, v.rotation, v.angle) * Math.max(1, v.zoom)
  const q = quarterDims(srcW, srcH, v.rotation)
  const dw = q.w * scale
  const dh = q.h * scale
  const t = v.angle * RAD
  const c = Math.abs(Math.cos(t))
  const s = Math.abs(Math.sin(t))
  const bw = dw * c + dh * s
  const bh = dw * s + dh * c
  const overflowX = Math.max(0, bw - cell.w)
  const overflowY = Math.max(0, bh - cell.h)
  let ox = (clamp(v.panX, -1, 1) * overflowX) / 2
  let oy = (clamp(v.panY, -1, 1) * overflowY) / 2
  let fit = 1
  if (v.angle !== 0 && (ox !== 0 || oy !== 0)) {
    fit = Math.min(1, maxShiftFraction(dw, dh, cell, v.angle, ox, oy))
    ox *= fit
    oy *= fit
  }
  return {
    cx: cell.x + cell.w / 2 + ox,
    cy: cell.y + cell.h / 2 + oy,
    scale,
    rotationRad: v.rotation * RAD,
    angleRad: v.angle * RAD,
    flip: v.flip,
    overflowX,
    overflowY,
    fit,
  }
}

/** Size to decode a photo at so a cell shows it at full sharpness without ever upscaling. */
export function neededPhotoSize(
  srcW: number,
  srcH: number,
  cell: PxRect,
  zoom: number,
  rotation = 0,
  angle = 0,
): { w: number; h: number; scale: number } {
  const scale = Math.min(1, coverScale(srcW, srcH, cell, rotation, angle) * Math.max(1, zoom))
  return { w: Math.max(1, Math.round(srcW * scale)), h: Math.max(1, Math.round(srcH * scale)), scale }
}

export function hitCell(rects: PxRect[], x: number, y: number): number {
  for (let i = rects.length - 1; i >= 0; i--) {
    const r = rects[i]
    if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) return i
  }
  return -1
}
