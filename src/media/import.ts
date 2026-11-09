import { ALL_FORMATS, BlobSource, Input } from 'mediabunny'
import type { MediaItem } from '../types'
import { newId } from '../timeline'
import { convertHeicToJpeg, decodePhoto, looksLikeHeic } from './photo'
import { disposeMusic, music, photos, remember, videos } from './registry'

/** Preview copies of photos are capped at this size on the long side. The export always uses the original file. */
const PREVIEW_MAX = 1600
const THUMB = 192

export class ImportError extends Error {}

export function kindOf(file: File): 'photo' | 'video' | null {
  if (file.type.startsWith('image/')) return 'photo'
  if (file.type.startsWith('video/')) return 'video'
  const ext = file.name.split('.').pop()?.toLowerCase() ?? ''
  if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'avif', 'heic', 'heif'].includes(ext)) return 'photo'
  if (['mp4', 'mov', 'm4v', 'webm', 'mpg', 'mpeg', '3gp', 'mkv'].includes(ext)) return 'video'
  return null
}

function thumbFrom(src: CanvasImageSource, w: number, h: number): Promise<string> {
  const c = document.createElement('canvas')
  const s = Math.max(THUMB / w, THUMB / h)
  c.width = THUMB
  c.height = THUMB
  const ctx = c.getContext('2d')!
  ctx.imageSmoothingQuality = 'high'
  ctx.drawImage(src, (THUMB - w * s) / 2, (THUMB - h * s) / 2, w * s, h * s)
  return new Promise((resolve, reject) =>
    c.toBlob((b) => (b ? resolve(URL.createObjectURL(b)) : reject(new Error('thumbnail failed'))), 'image/jpeg', 0.8),
  )
}

async function loadPhoto(file: File, id: string): Promise<MediaItem> {
  let source = file
  let converted = false
  let full: ImageBitmap
  try {
    full = await decodePhoto(file)
  } catch {
    if (!(await looksLikeHeic(file))) {
      throw new ImportError(`${file.name}: this photo format can't be opened in your browser.`)
    }
    // HEIC on a browser that cannot read it: convert once, and use the converted copy everywhere (preview and export).
    try {
      source = await convertHeicToJpeg(file)
      full = await decodePhoto(source)
      converted = true
    } catch {
      throw new ImportError(`${file.name}: this HEIC photo couldn't be converted. Try sharing it as a JPEG.`)
    }
  }
  const { width, height } = full
  const scale = Math.min(1, PREVIEW_MAX / Math.max(width, height))
  let proxy = full
  if (scale < 1) {
    proxy = await createImageBitmap(full, {
      resizeWidth: Math.round(width * scale),
      resizeHeight: Math.round(height * scale),
      resizeQuality: 'high',
    })
    full.close()
  }
  photos.set(id, proxy)
  const thumb = await thumbFrom(proxy, proxy.width, proxy.height)
  remember(id, thumb)
  return {
    id,
    kind: 'photo',
    file: source,
    name: source.name,
    width,
    height,
    duration: 0,
    hasAudio: false,
    converted,
    thumb,
  }
}

function waitFor(el: HTMLMediaElement, event: string, ms = 12000): Promise<void> {
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('timeout')), ms)
    el.addEventListener(
      event,
      () => {
        clearTimeout(t)
        resolve()
      },
      { once: true },
    )
    el.addEventListener(
      'error',
      () => {
        clearTimeout(t)
        reject(new Error('error'))
      },
      { once: true },
    )
  })
}

async function loadVideo(file: File, id: string): Promise<MediaItem> {
  // What the file says it contains. Failing here is fine: the browser's own player is the second opinion.
  let width = 0
  let height = 0
  let duration = 0
  let hasAudio: boolean | null = null
  let webCodecs = false
  const input = new Input({ source: new BlobSource(file), formats: ALL_FORMATS })
  try {
    const track = await input.getPrimaryVideoTrack()
    if (track) {
      width = track.displayWidth
      height = track.displayHeight
      webCodecs = await track.canDecode().catch(() => false)
      duration = await input.computeDuration().catch(() => 0)
      hasAudio = (await input.getPrimaryAudioTrack()) !== null
    }
  } catch {
    // unreadable container: rely on the player below
  } finally {
    input.dispose()
  }

  const url = URL.createObjectURL(file)
  remember(id, url)
  const el = document.createElement('video')
  el.playsInline = true
  el.setAttribute('playsinline', '')
  el.setAttribute('webkit-playsinline', '')
  el.muted = true
  el.preload = 'auto'
  el.style.cssText = 'position:fixed;left:-9999px;top:0;width:2px;height:2px;opacity:0;pointer-events:none'
  el.src = url
  document.body.appendChild(el)
  try {
    await waitFor(el, 'loadeddata')
    if (!duration || !isFinite(duration)) duration = el.duration
    el.currentTime = Math.min(0.1, duration / 2)
    await waitFor(el, 'seeked')
  } catch {
    el.remove()
    const ext = file.name.split('.').pop()?.toLowerCase()
    throw new ImportError(
      ext === 'mpg' || ext === 'mpeg'
        ? `${file.name}: MPEG-1/2 video can't be played in a browser. Convert it to MP4 (H.264) first.`
        : `${file.name}: your browser can't play this video. Try an MP4 (H.264) or an iPhone .mov file.`,
    )
  }
  if (!duration || !isFinite(duration)) {
    el.remove()
    throw new ImportError(`${file.name}: couldn't read the length of this video.`)
  }
  if (hasAudio === null) {
    // Safari exposes audioTracks; elsewhere assume there is sound and let the export skip it if there is none.
    const tracks = (el as unknown as { audioTracks?: { length: number } }).audioTracks
    hasAudio = tracks ? tracks.length > 0 : true
  }
  videos.set(id, el)
  const thumb = await thumbFrom(el, el.videoWidth || width, el.videoHeight || height)
  remember(id, thumb)
  return {
    id,
    kind: 'video',
    file,
    name: file.name,
    width: el.videoWidth || width,
    height: el.videoHeight || height,
    duration,
    hasAudio,
    decoder: webCodecs ? 'webcodecs' : 'element',
    thumb,
  }
}

export async function loadMedia(file: File): Promise<MediaItem> {
  const kind = kindOf(file)
  if (!kind) throw new ImportError(`${file.name}: only photos and videos can be added.`)
  const id = newId()
  return kind === 'photo' ? loadPhoto(file, id) : loadVideo(file, id)
}

export interface LoadedMusic {
  duration: number
}

/** Checks an audio file can be used and prepares the hidden player for the preview. */
export async function loadMusic(file: File): Promise<LoadedMusic> {
  let duration = 0
  const input = new Input({ source: new BlobSource(file), formats: ALL_FORMATS })
  try {
    if (await input.getPrimaryAudioTrack()) duration = await input.computeDuration()
  } catch {
    // the player below decides
  } finally {
    input.dispose()
  }

  disposeMusic()
  const url = URL.createObjectURL(file)
  const el = new Audio()
  el.preload = 'auto'
  el.src = url
  try {
    await waitFor(el, 'loadedmetadata', 10000)
  } catch {
    URL.revokeObjectURL(url)
    throw new ImportError(`${file.name}: your browser can't play this audio file. Try an MP3 or M4A.`)
  }
  if (!duration || !isFinite(duration)) duration = el.duration
  if (!duration || !isFinite(duration) || duration < 1) {
    URL.revokeObjectURL(url)
    throw new ImportError(`${file.name}: this audio is too short or can't be read.`)
  }
  music.el = el
  music.url = url
  return { duration }
}
