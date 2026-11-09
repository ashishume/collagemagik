import { FORMATS, cellPixelRects, neededPhotoSize } from '../geometry'
import { layoutById } from '../layouts'
import { drawCollage, type Source } from '../render'
import { placedLanes, resolveLane } from '../timeline'
import { decodePhoto } from '../media/photo'
import type { MediaItem, Project } from '../types'
import { VideoFrames } from './videoFrames'

/**
 * Renders collage frames from the ORIGINAL files at export resolution: photos are decoded straight to the size the
 * cell needs (never upscaled), and video frames are decoded at their full size.
 */
export class CollageRenderer {
  readonly canvas: HTMLCanvasElement
  private ctx: CanvasRenderingContext2D
  private photos = new Map<string, ImageBitmap>()
  private videos = new Map<string, VideoFrames>()
  private frames = new Map<string, Source | null>()

  private constructor(
    private project: Project,
    readonly W: number,
    readonly H: number,
  ) {
    this.canvas = document.createElement('canvas')
    this.canvas.width = W
    this.canvas.height = H
    this.ctx = this.canvas.getContext('2d', { alpha: false })!
  }

  static async create(project: Project, items: MediaItem[], W: number, H: number): Promise<CollageRenderer> {
    const r = new CollageRenderer(project, W, H)
    try {
      await r.load(items)
    } catch (e) {
      await r.dispose()
      throw e
    }
    return r
  }

  private async load(items: MediaItem[]) {
    const { project, W, H } = this
    const layout = layoutById(project.layoutId)
    const px = cellPixelRects(layout.rects, W, H, project.gap)
    for (let i = 0; i < project.cellCount; i++) {
      const cell = project.cells[i]
      const item = items.find((m) => m.id === cell?.mediaId)
      if (!item) continue
      if (item.kind === 'photo') {
        const need = neededPhotoSize(item.width, item.height, px[i], cell.zoom, cell.rotation, cell.angle)
        this.photos.set(item.id, await decodePhoto(item.file, need.scale >= 1 ? undefined : { w: need.w, h: need.h }))
      } else {
        const frames = new VideoFrames(item)
        await frames.open()
        this.videos.set(item.id, frames)
      }
    }
  }

  /** True if any video is being read through the browser's player (slower than the fast path). */
  get compat(): boolean {
    return [...this.videos.values()].some((v) => v.usingElement)
  }

  /** Draws the collage at timeline time t onto `canvas`. */
  async renderAt(t: number) {
    const { project } = this
    const lanes = placedLanes(project)
    for (const lane of lanes) {
      const v = this.videos.get(lane.mediaId)
      const r = resolveLane(lane, t)
      if (!v || !r) continue
      this.frames.set(lane.mediaId, await v.get(r.time))
    }
    const layout = layoutById(project.layoutId)
    drawCollage(this.ctx, this.W, this.H, {
      rects: layout.rects,
      cells: project.cells,
      gap: project.gap,
      radius: project.radius,
      bg: project.bg,
      getSource: (id): Source | null => {
        const p = this.photos.get(id)
        if (p) return { img: p, w: p.width, h: p.height }
        return this.frames.get(id) ?? null
      },
    })
  }

  async dispose() {
    for (const b of this.photos.values()) b.close()
    this.photos.clear()
    for (const v of this.videos.values()) await v.close()
    this.videos.clear()
    this.frames.clear()
  }
}

export const sizeFor = (project: Project, scale: 1 | 2 = 1) => {
  const f = FORMATS[project.format]
  return { W: f.w * scale, H: f.h * scale }
}
