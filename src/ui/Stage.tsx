import { useEffect, useRef } from 'react'
import { FORMATS, clamp, coverRect, hitCell, panAfterDrag, type PxRect } from '../geometry'
import { layoutById } from '../layouts'
import { drawCollage, type Source } from '../render'
import { syncMusic, syncVideos } from '../media/sync'
import { photos, videos } from '../media/registry'
import { useStore } from '../store'
import { totalDuration } from '../timeline'

const MAX_PREVIEW_W = 720

function sourceFor(mediaId: string): Source | null {
  const p = photos.get(mediaId)
  if (p) return { img: p, w: p.width, h: p.height }
  const v = videos.get(mediaId)
  if (v && v.readyState >= 2 && v.videoWidth > 0) return { img: v, w: v.videoWidth, h: v.videoHeight }
  return null
}

interface Gesture {
  kind: 'pan' | 'pinch'
  cell: number
  moved: boolean
  lastX: number
  lastY: number
  startX: number
  startY: number
  startDist: number
  startZoom: number
}

export function Stage({ onPickForCell }: { onPickForCell: (cell: number) => void }) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const rectsRef = useRef<PxRect[]>([])
  const pointers = useRef(new Map<number, { x: number; y: number }>())
  const gesture = useRef<Gesture | null>(null)
  const format = useStore((s) => s.project.format)
  const f = FORMATS[format]

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
      const w = Math.max(2, Math.min(MAX_PREVIEW_W, Math.round(cssW * dpr)))
      const h = Math.round((w * FORMATS[s.project.format].h) / FORMATS[s.project.format].w)
      let vkey = ''
      for (const v of videos.values()) vkey += `${v.currentTime.toFixed(2)}${v.readyState}${v.seeking ? 's' : ''}`
      const key = [w, h, s.selectedCell, s.swapFrom, t.toFixed(3), vkey].map(String).join('|')
      const idle = !useStore.getState().playing
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
          overlay: { selected: s.selectedCell, swapFrom: s.swapFrom, safeZone: s.project.safeZone && s.project.format === 'story' },
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
    c.setPointerCapture(e.pointerId)
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
      }
    } else if (pointers.current.size === 2) {
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
    if (g.kind === 'pinch' && pointers.current.size >= 2) {
      const [a, b] = [...pointers.current.values()]
      const dist = Math.hypot(a.x - b.x, a.y - b.y)
      if (g.cell >= 0 && s.project.cells[g.cell]?.mediaId) {
        s.setCellView(g.cell, { zoom: clamp((g.startZoom * dist) / g.startDist, 1, 4) })
      }
      return
    }
    if (g.kind === 'pan') {
      if (!g.moved && Math.hypot(e.clientX - g.startX, e.clientY - g.startY) > 6) g.moved = true
      if (!g.moved) return
      const cellIdx = g.cell
      const cell = s.project.cells[cellIdx]
      const rect = rectsRef.current[cellIdx]
      const src = cell?.mediaId ? sourceFor(cell.mediaId) : null
      if (cell && rect && src && s.swapFrom === null) {
        const c = canvasRef.current!
        const k = c.width / c.getBoundingClientRect().width
        const d = coverRect(src.w, src.h, rect, cell.zoom, cell.panX, cell.panY)
        s.setCellView(cellIdx, {
          panX: panAfterDrag(cell.panX, (e.clientX - g.lastX) * k, d.overflowX),
          panY: panAfterDrag(cell.panY, (e.clientY - g.lastY) * k, d.overflowY),
        })
      }
      g.lastX = e.clientX
      g.lastY = e.clientY
    }
  }

  const onUp = (e: React.PointerEvent) => {
    pointers.current.delete(e.pointerId)
    const g = gesture.current
    if (pointers.current.size === 0) gesture.current = null
    if (!g || g.kind !== 'pan' || g.moved) return
    const s = useStore.getState()
    const cell = g.cell
    if (s.swapFrom !== null) {
      if (cell >= 0 && cell !== s.swapFrom) s.swapCells(s.swapFrom, cell)
      else s.setSwapFrom(null)
      return
    }
    if (cell < 0) s.selectCell(null)
    else if (!s.project.cells[cell]?.mediaId) {
      s.selectCell(cell)
      onPickForCell(cell)
    } else s.selectCell(cell)
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
    <div className="stage-wrap">
      <canvas
        ref={canvasRef}
        className="stage"
        style={{ aspectRatio: `${f.w} / ${f.h}` }}
        onPointerDown={onDown}
        onPointerMove={onMove}
        onPointerUp={onUp}
        onPointerCancel={onUp}
        aria-label="Collage preview. Tap a cell to select it, drag to move the picture, pinch to zoom."
      />
    </div>
  )
}
