import { useEffect, useRef } from 'react'
import { FORMATS, clamp, hitCell, panAfterDrag, placeMedia, type PxRect } from '../geometry'
import { layoutById } from '../layouts'
import { drawCollage, type Source } from '../render'
import { syncMusic, syncVideos } from '../media/sync'
import { photos, videos } from '../media/registry'
import { useStore } from '../store'
import { totalDuration } from '../timeline'

const MAX_PREVIEW_W_PHONE = 720
const MAX_PREVIEW_W_DESKTOP = 1080
/** Hold a picture this long (without moving) to pick it up and drag it onto another cell. */
const HOLD_MS = 380
const MOVE_SLOP = 6

function sourceFor(mediaId: string): Source | null {
  const p = photos.get(mediaId)
  if (p) return { img: p, w: p.width, h: p.height }
  const v = videos.get(mediaId)
  if (v && v.readyState >= 2 && v.videoWidth > 0) return { img: v, w: v.videoWidth, h: v.videoHeight }
  return null
}

interface Gesture {
  kind: 'pan' | 'pinch' | 'lift'
  cell: number
  moved: boolean
  lastX: number
  lastY: number
  startX: number
  startY: number
  startDist: number
  startZoom: number
}

interface Lift {
  from: number
  x: number
  y: number
  over: number
}

export function Stage({ onPickForCell }: { onPickForCell: (cell: number) => void }) {
  const wrapRef = useRef<HTMLDivElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const rectsRef = useRef<PxRect[]>([])
  const pointers = useRef(new Map<number, { x: number; y: number }>())
  const gesture = useRef<Gesture | null>(null)
  const lift = useRef<Lift | null>(null)
  const holdTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const format = useStore((s) => s.project.format)
  const f = FORMATS[format]

  const clearHold = () => {
    if (holdTimer.current) clearTimeout(holdTimer.current)
    holdTimer.current = null
  }

  // Draw loop: advances the clock, keeps videos in sync, repaints when something changed.
  useEffect(() => {
    const canvas = canvasRef.current!
    const ctx = canvas.getContext('2d')!
    let raf = 0
    let last = performance.now()
    let lastKey = ''
    let lastProject: unknown = null

    const tick = (now: number) => {
      const dt = Math.min(0.1, (now - last) / 1000)
      last = now
      const s = useStore.getState()
      let t = s.playhead
      if (s.playing) {
        t += dt
        const dur = totalDuration(s.project)
        if (t >= dur) {
          useStore.setState({ playing: false, playhead: 0 })
          t = 0
        } else {
          s.setPlayhead(t)
        }
      }
      const isPlaying = useStore.getState().playing
      syncVideos(s.project, t, isPlaying)
      syncMusic(s.project, t, isPlaying, totalDuration(s.project))

      const dpr = Math.min(window.devicePixelRatio || 1, 2)
      const cssW = canvas.clientWidth
      const maxW = window.innerWidth >= 900 ? MAX_PREVIEW_W_DESKTOP : MAX_PREVIEW_W_PHONE
      const w = Math.max(2, Math.min(maxW, Math.round(cssW * dpr)))
      const h = Math.round((w * FORMATS[s.project.format].h) / FORMATS[s.project.format].w)
      let vkey = ''
      for (const v of videos.values()) vkey += `${v.currentTime.toFixed(2)}${v.readyState}${v.seeking ? 's' : ''}`
      const L = lift.current
      const key = [w, h, s.selectedCell, s.swapFrom, t.toFixed(3), vkey, L ? `${L.x | 0},${L.y | 0},${L.over}` : ''].map(String).join('|')
      const idle = !isPlaying
      if (!(idle && key === lastKey && s.project === lastProject)) {
        lastKey = key
        lastProject = s.project
        if (canvas.width !== w || canvas.height !== h) {
          canvas.width = w
          canvas.height = h
        }
        const layout = layoutById(s.project.layoutId)
        rectsRef.current = drawCollage(ctx, w, h, {
          rects: layout.rects,
          cells: s.project.cells,
          gap: s.project.gap,
          radius: s.project.radius,
          bg: s.project.bg,
          getSource: sourceFor,
          overlay: {
            selected: s.selectedCell,
            swapFrom: s.swapFrom,
            safeZone: s.project.safeZone && s.project.format === 'story',
            lift: L,
          },
        })
      }

      raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [])

  const toCanvas = (e: { clientX: number; clientY: number }) => {
    const c = canvasRef.current!
    const b = c.getBoundingClientRect()
    return { x: ((e.clientX - b.left) * c.width) / b.width, y: ((e.clientY - b.top) * c.height) / b.height }
  }

  const onDown = (e: React.PointerEvent) => {
    const c = canvasRef.current!
    try {
      c.setPointerCapture(e.pointerId)
    } catch {
      // some synthetic or stale pointers cannot be captured; the gesture still works while the pointer is over the canvas
    }
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY })
    const s = useStore.getState()
    if (pointers.current.size === 1) {
      const p = toCanvas(e)
      const cell = hitCell(rectsRef.current, p.x, p.y)
      gesture.current = {
        kind: 'pan',
        cell,
        moved: false,
        lastX: e.clientX,
        lastY: e.clientY,
        startX: e.clientX,
        startY: e.clientY,
        startDist: 0,
        startZoom: 1,
      }
      if (cell >= 0 && s.swapFrom === null && cell !== s.selectedCell && s.project.cells[cell]?.mediaId) {
        s.selectCell(cell)
        s.openPicture()
      }
      // Press and hold on a picture to pick it up, then drop it on another cell to swap.
      clearHold()
      if (cell >= 0 && s.swapFrom === null && s.project.cells[cell]?.mediaId) {
        holdTimer.current = setTimeout(() => {
          const g = gesture.current
          if (!g || g.kind !== 'pan' || g.moved || pointers.current.size !== 1) return
          g.kind = 'lift'
          g.moved = true
          const now = useStore.getState()
          now.selectCell(cell)
          now.openPicture()
          const pt = toCanvas({ clientX: g.lastX, clientY: g.lastY })
          lift.current = { from: cell, x: pt.x, y: pt.y, over: -1 }
          navigator.vibrate?.(15)
        }, HOLD_MS)
      }
    } else if (pointers.current.size === 2) {
      clearHold()
      const [a, b] = [...pointers.current.values()]
      const cell = s.selectedCell ?? gesture.current?.cell ?? -1
      gesture.current = {
        kind: 'pinch',
        cell,
        moved: true,
        lastX: 0,
        lastY: 0,
        startX: 0,
        startY: 0,
        startDist: Math.hypot(a.x - b.x, a.y - b.y) || 1,
        startZoom: s.project.cells[cell]?.zoom ?? 1,
      }
    }
  }

  const onMove = (e: React.PointerEvent) => {
    if (!pointers.current.has(e.pointerId)) return
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY })
    const g = gesture.current
    if (!g) return
    const s = useStore.getState()

    if (g.kind === 'lift' && lift.current) {
      const p = toCanvas(e)
      const over = hitCell(rectsRef.current, p.x, p.y)
      lift.current = { ...lift.current, x: p.x, y: p.y, over }
      g.lastX = e.clientX
      g.lastY = e.clientY
      return
    }

    if (g.kind === 'pinch' && pointers.current.size >= 2) {
      const [a, b] = [...pointers.current.values()]
      const dist = Math.hypot(a.x - b.x, a.y - b.y)
      if (g.cell >= 0 && s.project.cells[g.cell]?.mediaId) {
        s.setCellView(g.cell, { zoom: clamp((g.startZoom * dist) / g.startDist, 1, 4) })
      }
      return
    }

    if (g.kind === 'pan') {
      const dx = e.clientX - g.lastX
      const dy = e.clientY - g.lastY
      g.lastX = e.clientX
      g.lastY = e.clientY
      if (!g.moved && Math.hypot(e.clientX - g.startX, e.clientY - g.startY) > MOVE_SLOP) {
        g.moved = true
        clearHold()
      }
      if (!g.moved) return
      const cellIdx = g.cell
      const cell = s.project.cells[cellIdx]
      const rect = rectsRef.current[cellIdx]
      const src = cell?.mediaId ? sourceFor(cell.mediaId) : null
      if (cell && rect && src && s.swapFrom === null) {
        const c = canvasRef.current!
        const k = c.width / c.getBoundingClientRect().width
        const d = placeMedia(src.w, src.h, rect, cell)
        const panX = panAfterDrag(cell.panX, dx * k, d.overflowX)
        const panY = panAfterDrag(cell.panY, dy * k, d.overflowY)
        // a tilted picture can't move as far: pull the stored position back so dragging never has a dead zone
        const fit = placeMedia(src.w, src.h, rect, { ...cell, panX, panY }).fit
        s.setCellView(cellIdx, { panX: panX * fit, panY: panY * fit })
      }
    }
  }

  const onUp = (e: React.PointerEvent) => {
    clearHold()
    pointers.current.delete(e.pointerId)
    const g = gesture.current
    if (pointers.current.size === 0) gesture.current = null
    if (!g) return
    const s = useStore.getState()

    if (g.kind === 'lift') {
      const L = lift.current
      lift.current = null
      if (L && L.over >= 0 && L.over !== L.from) {
        s.swapCells(L.from, L.over)
        navigator.vibrate?.(10)
      }
      return
    }
    if (g.kind !== 'pan' || g.moved) return

    // a tap
    const cell = g.cell
    if (s.swapFrom !== null) {
      if (cell >= 0 && cell !== s.swapFrom) s.swapCells(s.swapFrom, cell)
      else s.setSwapFrom(null)
      return
    }
    if (cell < 0) s.selectCell(null)
    else if (!s.project.cells[cell]?.mediaId) {
      s.selectCell(cell)
      s.openPicture()
      onPickForCell(cell)
    } else {
      s.selectCell(cell)
      s.openPicture()
    }
  }

  const onCancel = (e: React.PointerEvent) => {
    clearHold()
    lift.current = null
    pointers.current.delete(e.pointerId)
    if (pointers.current.size === 0) gesture.current = null
  }

  // Mouse wheel / trackpad pinch zooms the selected cell on desktop.
  useEffect(() => {
    const c = canvasRef.current!
    const onWheel = (e: WheelEvent) => {
      const s = useStore.getState()
      const idx = s.selectedCell
      if (idx === null || !s.project.cells[idx]?.mediaId) return
      e.preventDefault()
      s.setCellView(idx, { zoom: s.project.cells[idx].zoom * Math.exp(-e.deltaY * 0.0025) })
    }
    c.addEventListener('wheel', onWheel, { passive: false })
    return () => c.removeEventListener('wheel', onWheel)
  }, [])

  return (
    <div className="stage-wrap" ref={wrapRef}>
      <canvas
        ref={canvasRef}
        className="stage"
        style={{ aspectRatio: `${f.w} / ${f.h}` }}
        onPointerDown={onDown}
        onPointerMove={onMove}
        onPointerUp={onUp}
        onPointerCancel={onCancel}
        onContextMenu={(e) => e.preventDefault()}
        aria-label="Collage preview. Tap a picture for options, drag to move it, pinch to zoom, press and hold then drag to swap."
      />
    </div>
  )
}
