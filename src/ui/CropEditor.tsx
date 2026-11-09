import { useEffect, useRef, useState } from 'react'
import { FlipHorizontal2, RotateCcw, RotateCw } from 'lucide-react'
import { FORMATS, cellPixelRects, clamp, panAfterDrag, placeMedia, type MediaView, type PxRect } from '../geometry'
import { layoutById } from '../layouts'
import { drawMedia, roundRectPath, type Source } from '../render'
import { photos, videos } from '../media/registry'
import { useStore } from '../store'

function sourceFor(mediaId: string): Source | null {
  const p = photos.get(mediaId)
  if (p) return { img: p, w: p.width, h: p.height }
  const v = videos.get(mediaId)
  if (v && v.readyState >= 2 && v.videoWidth > 0) return { img: v, w: v.videoWidth, h: v.videoHeight }
  return null
}

/**
 * Crop screen for one picture or video: the whole picture is shown with the cell's frame over it, so you can see
 * what is cut off. Drag to move, pinch / wheel / slider to zoom, rotate, flip, straighten. Apply keeps the changes.
 */
export function CropEditor() {
  const cellIndex = useStore((s) => s.cropCell)
  const project = useStore((s) => s.project)
  const setCropCell = useStore((s) => s.setCropCell)
  const cell = cellIndex !== null ? project.cells[cellIndex] : null

  const [draft, setDraft] = useState<MediaView>(() => ({
    zoom: cell?.zoom ?? 1,
    panX: cell?.panX ?? 0,
    panY: cell?.panY ?? 0,
    rotation: cell?.rotation ?? 0,
    flip: cell?.flip ?? false,
    angle: cell?.angle ?? 0,
  }))
  const draftRef = useRef(draft)
  draftRef.current = draft

  const canvasRef = useRef<HTMLCanvasElement>(null)
  const frameRef = useRef<PxRect>({ x: 0, y: 0, w: 1, h: 1 })
  const pointers = useRef(new Map<number, { x: number; y: number }>())
  const pinch = useRef<{ dist: number; zoom: number } | null>(null)
  const dragging = useRef(false)

  const mediaId = cell?.mediaId ?? null

  // Aspect ratio of the cell this picture sits in, so the frame matches what will be used.
  const aspect = (() => {
    if (cellIndex === null) return 1
    const f = FORMATS[project.format]
    const px = cellPixelRects(layoutById(project.layoutId).rects, f.w, f.h, project.gap)[cellIndex]
    return px ? px.w / px.h : 1
  })()

  // Draw loop (cheap): keeps the picture fresh, including a video frame that arrives a moment later.
  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas || !mediaId) return
    const ctx = canvas.getContext('2d')!
    let raf = 0
    const tick = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2)
      const cw = canvas.clientWidth
      const ch = canvas.clientHeight
      const w = Math.round(cw * dpr)
      const h = Math.round(ch * dpr)
      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w
        canvas.height = h
      }
      // frame: the cell's shape, as large as fits with a margin
      const margin = 0.88
      const fw = Math.min(w * margin, h * margin * aspect)
      const fh = fw / aspect
      const frame: PxRect = { x: (w - fw) / 2, y: (h - fh) / 2, w: fw, h: fh }
      frameRef.current = frame

      ctx.fillStyle = '#0a0a0e'
      ctx.fillRect(0, 0, w, h)
      const src = sourceFor(mediaId)
      if (src) {
        ctx.imageSmoothingQuality = 'high'
        // everything, dimmed: this is what is being cut off
        ctx.save()
        ctx.globalAlpha = 0.35
        drawMedia(ctx, src, frame, draftRef.current)
        ctx.restore()
        // inside the frame, at full strength
        ctx.save()
        roundRectPath(ctx, frame.x, frame.y, frame.w, frame.h, Math.min(8 * dpr, frame.w / 2))
        ctx.clip()
        drawMedia(ctx, src, frame, draftRef.current)
        if (dragging.current) {
          ctx.strokeStyle = 'rgba(255,255,255,0.35)'
          ctx.lineWidth = Math.max(1, dpr)
          ctx.beginPath()
          for (const k of [1 / 3, 2 / 3]) {
            ctx.moveTo(frame.x + frame.w * k, frame.y)
            ctx.lineTo(frame.x + frame.w * k, frame.y + frame.h)
            ctx.moveTo(frame.x, frame.y + frame.h * k)
            ctx.lineTo(frame.x + frame.w, frame.y + frame.h * k)
          }
          ctx.stroke()
        }
        ctx.restore()
      }
      ctx.strokeStyle = '#fff'
      ctx.lineWidth = Math.max(2, 2 * dpr)
      roundRectPath(ctx, frame.x, frame.y, frame.w, frame.h, Math.min(8 * dpr, frame.w / 2))
      ctx.stroke()
      raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [mediaId, aspect])

  // wheel / trackpad pinch zooms on desktop
  useEffect(() => {
    const c = canvasRef.current
    if (!c) return
    const onWheel = (e: WheelEvent) => {
      e.preventDefault()
      setDraft((d) => ({ ...d, zoom: clamp(d.zoom * Math.exp(-e.deltaY * 0.0025), 1, 4) }))
    }
    c.addEventListener('wheel', onWheel, { passive: false })
    return () => c.removeEventListener('wheel', onWheel)
  }, [mediaId])

  if (cellIndex === null || !cell || !mediaId) return null

  const patch = (p: Partial<MediaView>) => setDraft((d) => ({ ...d, ...p }))

  const onDown = (e: React.PointerEvent) => {
    try {
      canvasRef.current!.setPointerCapture(e.pointerId)
    } catch {
      // ignore
    }
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY })
    dragging.current = true
    if (pointers.current.size === 2) {
      const [a, b] = [...pointers.current.values()]
      pinch.current = { dist: Math.hypot(a.x - b.x, a.y - b.y) || 1, zoom: draftRef.current.zoom }
    }
  }

  const onMove = (e: React.PointerEvent) => {
    const prev = pointers.current.get(e.pointerId)
    if (!prev) return
    pointers.current.set(e.pointerId, { x: e.clientX, y: e.clientY })
    if (pointers.current.size >= 2 && pinch.current) {
      const [a, b] = [...pointers.current.values()]
      const d = Math.hypot(a.x - b.x, a.y - b.y)
      patch({ zoom: clamp((pinch.current.zoom * d) / pinch.current.dist, 1, 4) })
      return
    }
    const src = sourceFor(mediaId)
    const c = canvasRef.current!
    if (!src) return
    const k = c.width / c.getBoundingClientRect().width
    const cur = draftRef.current
    const frame = frameRef.current
    const p = placeMedia(src.w, src.h, frame, cur)
    const panX = panAfterDrag(cur.panX, (e.clientX - prev.x) * k, p.overflowX)
    const panY = panAfterDrag(cur.panY, (e.clientY - prev.y) * k, p.overflowY)
    const fit = placeMedia(src.w, src.h, frame, { ...cur, panX, panY }).fit
    patch({ panX: panX * fit, panY: panY * fit })
  }

  const onUp = (e: React.PointerEvent) => {
    pointers.current.delete(e.pointerId)
    if (pointers.current.size < 2) pinch.current = null
    if (pointers.current.size === 0) dragging.current = false
  }

  const turn = (dir: 1 | -1) => patch({ rotation: (draft.rotation + 90 * dir + 360) % 360, panX: 0, panY: 0 })
  const reset = () => setDraft({ zoom: 1, panX: 0, panY: 0, rotation: 0, flip: false, angle: 0 })
  const apply = () => {
    useStore.getState().setCellView(cellIndex, draft)
    setCropCell(null)
  }

  return (
    <div className="modal-back" role="dialog" aria-modal="true" aria-label="Crop and rotate">
      <div className="modal crop-modal">
        <header>
          <h2>Crop and rotate</h2>
        </header>
        <canvas
          ref={canvasRef}
          className="crop-canvas"
          onPointerDown={onDown}
          onPointerMove={onMove}
          onPointerUp={onUp}
          onPointerCancel={onUp}
          aria-label="Drag to move the picture, pinch to zoom. The bright area is what is used."
        />
        <p className="note small">The bright area is what's used. Drag to move, pinch or use the slider to zoom.</p>
        <div className="crop-tools">
          <button className="chip-btn" onClick={() => turn(-1)} aria-label="Rotate left">
            <RotateCcw size={16} /> Left
          </button>
          <button className="chip-btn" onClick={() => turn(1)} aria-label="Rotate right">
            <RotateCw size={16} /> Right
          </button>
          <button className={`chip-btn ${draft.flip ? 'on' : ''}`} onClick={() => patch({ flip: !draft.flip, panX: -draft.panX })} aria-pressed={draft.flip}>
            <FlipHorizontal2 size={16} /> Flip
          </button>
          <button className="chip-btn" onClick={reset}>
            Reset
          </button>
        </div>
        <label className="row">
          <span>Zoom</span>
          <input type="range" min={1} max={4} step={0.01} value={draft.zoom} onChange={(e) => patch({ zoom: +e.target.value })} />
          <span className="val">{Math.round(draft.zoom * 100)}%</span>
        </label>
        <label className="row">
          <span>Straighten</span>
          <input
            type="range"
            min={-45}
            max={45}
            step={0.5}
            value={draft.angle}
            onChange={(e) => patch({ angle: +e.target.value })}
            onDoubleClick={() => patch({ angle: 0 })}
          />
          <span className="val">{draft.angle > 0 ? '+' : ''}{draft.angle.toFixed(1).replace('.0', '')}°</span>
        </label>
        <div className="crop-actions">
          <button className="btn" onClick={() => setCropCell(null)}>
            Cancel
          </button>
          <button className="btn primary" onClick={apply}>
            Apply
          </button>
        </div>
      </div>
    </div>
  )
}
