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

/** Size to decode a photo at so a cell shows it at full sharpness without ever upscaling. */
export function neededPhotoSize(
  srcW: number,
  srcH: number,
  cell: PxRect,
  zoom: number,
): { w: number; h: number; scale: number } {
  const scale = Math.min(1, Math.max(cell.w / srcW, cell.h / srcH) * Math.max(1, zoom))
  return { w: Math.max(1, Math.round(srcW * scale)), h: Math.max(1, Math.round(srcH * scale)), scale }
}

export function hitCell(rects: PxRect[], x: number, y: number): number {
  for (let i = rects.length - 1; i >= 0; i--) {
    const r = rects[i]
    if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) return i
  }
  return -1
}
