import { ALL_FORMATS, BlobSource, CanvasSink, Input, type WrappedCanvas } from 'mediabunny'
import type { Source } from '../render'
import type { MediaItem } from '../types'

/** Test hook: pretend WebCodecs cannot decode video so the compatibility path runs. */
export const decodeFlags = { forceElement: false }

/** Reads frames from one video in order, restarting the decoder only when the timeline jumps. */
class SequentialReader {
  private it: AsyncGenerator<WrappedCanvas, void, unknown> | null = null
  private cur: WrappedCanvas | null = null
  private next: WrappedCanvas | null = null
  private done = false

  constructor(private sink: CanvasSink) {}

  private async restart(t: number) {
    await this.it?.return(undefined)
    this.it = this.sink.canvases(t)
    this.cur = null
    this.next = null
    this.done = false
    const first = await this.it.next()
    if (first.done) this.done = true
    else this.cur = first.value
    await this.pull()
  }

  private async pull() {
    if (this.done || !this.it) return
    const n = await this.it.next()
    if (n.done) {
      this.done = true
      this.next = null
    } else this.next = n.value
  }

  async get(t: number): Promise<WrappedCanvas | null> {
    const jumpedBack = this.cur !== null && t < this.cur.timestamp - 1e-3
    const jumpedFar = this.next !== null && t > this.next.timestamp + 2
    if (!this.it || jumpedBack || jumpedFar) await this.restart(t)
    while (this.next && this.next.timestamp <= t + 1e-6) {
      this.cur = this.next
      await this.pull()
    }
    return this.cur
  }

  async close() {
    await this.it?.return(undefined)
    this.it = null
  }
}

function once(el: HTMLMediaElement, event: string, ms: number): Promise<void> {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => {
      cleanup()
      reject(new Error(`${event} timed out`))
    }, ms)
    const ok = () => {
      cleanup()
      resolve()
    }
    const bad = () => {
      cleanup()
      reject(new Error('video error'))
    }
    const cleanup = () => {
      clearTimeout(t)
      el.removeEventListener(event, ok)
      el.removeEventListener('error', bad)
    }
    el.addEventListener(event, ok)
    el.addEventListener('error', bad)
  })
}

/**
 * Frames of one video for the export. Fast path: WebCodecs through Mediabunny. If the browser cannot decode the file
 * that way (for example some iPhone HEVC clips), or it fails part-way, frames are read through a hidden <video>
 * element instead: slower, but it works for anything the browser can play.
 */
export class VideoFrames {
  usingElement = false
  private input: Input | null = null
  private reader: SequentialReader | null = null
  private el: HTMLVideoElement | null = null
  private url: string | null = null

  constructor(private item: MediaItem) {}

  async open() {
    if (this.item.decoder !== 'element' && !decodeFlags.forceElement) {
      const input = new Input({ source: new BlobSource(this.item.file), formats: ALL_FORMATS })
      try {
        const track = await input.getPrimaryVideoTrack()
        if (track && (await track.canDecode())) {
          this.input = input
          this.reader = new SequentialReader(new CanvasSink(track, { poolSize: 4 }))
          return
        }
      } catch {
        // use the player instead
      }
      input.dispose()
    }
    await this.openElement()
  }

  private async openElement() {
    this.usingElement = true
    const url = URL.createObjectURL(this.item.file)
    const el = document.createElement('video')
    el.muted = true
    el.playsInline = true
    el.setAttribute('playsinline', '')
    el.preload = 'auto'
    el.style.cssText = 'position:fixed;left:-9999px;top:0;width:2px;height:2px;opacity:0;pointer-events:none'
    el.src = url
    document.body.appendChild(el)
    try {
      if (el.readyState < 2) await once(el, 'loadeddata', 15000)
    } catch (e) {
      el.remove()
      URL.revokeObjectURL(url)
      throw e
    }
    this.el = el
    this.url = url
  }

  async get(t: number): Promise<Source | null> {
    if (this.reader) {
      try {
        const f = await this.reader.get(t)
        return f ? { img: f.canvas as CanvasImageSource, w: f.canvas.width, h: f.canvas.height } : null
      } catch (e) {
        console.warn('WebCodecs video decoding failed, switching to the compatibility path', e)
        await this.closeWebCodecs()
        await this.openElement()
      }
    }
    const el = this.el
    if (!el) return null
    if (Math.abs(el.currentTime - t) > 0.0005) {
      const seeked = once(el, 'seeked', 10000)
      el.currentTime = t
      await seeked
      // give the picture a tick to be ready to draw (Safari)
      await new Promise((r) => setTimeout(r, 0))
    }
    return { img: el, w: el.videoWidth, h: el.videoHeight }
  }

  private async closeWebCodecs() {
    await this.reader?.close()
    this.reader = null
    this.input?.dispose()
    this.input = null
  }

  async close() {
    await this.closeWebCodecs()
    if (this.el) {
      this.el.pause()
      this.el.removeAttribute('src')
      this.el.load()
      this.el.remove()
      this.el = null
    }
    if (this.url) URL.revokeObjectURL(this.url)
    this.url = null
  }
}
