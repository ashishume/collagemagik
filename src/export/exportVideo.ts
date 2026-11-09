import {
  ALL_FORMATS,
  AudioBufferSource,
  BlobSource,
  BufferTarget,
  CanvasSource,
  Input,
  Mp4OutputFormat,
  Output,
  canEncodeAudio,
  canEncodeVideo,
} from 'mediabunny'
import { FORMATS } from '../geometry'
import { MAX_DURATION, placedLanes, totalDuration } from '../timeline'
import type { MediaItem, Project } from '../types'
import { CollageRenderer } from './renderer'
import { hasAudibleSound, mixAudio } from './mixAudio'

export type Quality = 'standard' | 'high'

export interface ExportInfo {
  width: number
  height: number
  fps: number
  videoBitrate: number
  audio: 'aac' | 'none'
  duration: number
  bytes: number
  /** Things the person should know, such as sound that could not be added. */
  warnings: string[]
  /** Frames were read through the browser's player (slower) because WebCodecs could not decode a video. */
  compat: boolean
}

export class ExportError extends Error {}

/** Pixel size for each quality: standard is Instagram's own size; high doubles it (when the device can encode it). */
export function exportSize(project: Project, quality: Quality) {
  const f = FORMATS[project.format]
  const k = quality === 'high' ? 2 : 1
  return { width: f.w * k, height: f.h * k }
}

/** About 16 Mbps for a 1080×1920 30 fps Story: above what Instagram needs, so the upload stays as sharp as possible. */
export function targetBitrate(width: number, height: number, fps: number): number {
  const rate = 16_000_000 * ((width * height) / (1080 * 1920)) * (fps / 30)
  return Math.round(Math.min(60_000_000, Math.max(8_000_000, rate)))
}

/** AAC encoding: native if the browser has it, otherwise a small WebAssembly encoder that is loaded on demand. */
async function ensureAacEncoder(): Promise<boolean> {
  const opts = { numberOfChannels: 2, sampleRate: 48000, bitrate: 256_000 }
  try {
    if (await canEncodeAudio('aac', opts)) return true
    const { registerAacEncoder } = await import('@mediabunny/aac-encoder')
    registerAacEncoder()
    return await canEncodeAudio('aac', opts)
  } catch {
    return false
  }
}

export async function canExportHighQuality(project: Project): Promise<boolean> {
  const { width, height } = exportSize(project, 'high')
  try {
    return await canEncodeVideo('avc', { width, height, bitrate: targetBitrate(width, height, 30) })
  } catch {
    return false
  }
}

/** Frame rate of the placed videos, kept as close as possible to the originals but never above 30. */
async function pickFps(project: Project, items: MediaItem[]): Promise<number> {
  let best = 0
  for (const lane of placedLanes(project)) {
    const item = items.find((m) => m.id === lane.mediaId)
    if (!item) continue
    const input = new Input({ source: new BlobSource(item.file), formats: ALL_FORMATS })
    try {
      const track = await input.getPrimaryVideoTrack()
      if (track) {
        const stats = await track.computePacketStats(120)
        best = Math.max(best, stats.averagePacketRate)
      }
    } catch {
      // fall through to the default
    } finally {
      input.dispose()
    }
  }
  if (best <= 0) return 30
  return Math.min(30, Math.max(24, Math.round(best)))
}

export async function exportMp4(
  project: Project,
  items: MediaItem[],
  opts: { quality: Quality; signal?: AbortSignal; onProgress: (p: number, label: string) => void },
): Promise<{ blob: Blob; info: ExportInfo }> {
  const { quality, signal, onProgress } = opts
  const { width, height } = exportSize(project, quality)
  const duration = Math.min(MAX_DURATION, totalDuration(project))
  const fps = await pickFps(project, items)
  const bitrate = targetBitrate(width, height, fps)

  if (!(await canEncodeVideo('avc', { width, height, bitrate }))) {
    throw new ExportError(
      quality === 'high'
        ? "This device can't encode the high-resolution size. Use Standard instead."
        : "This browser can't create MP4 video. Try Safari on iOS 16.4 or later, or Chrome.",
    )
  }

  const warnings: string[] = []
  const wantAudio = hasAudibleSound(project, items)
  let audioCodec: 'aac' | null = null
  if (wantAudio) {
    if (await ensureAacEncoder()) audioCodec = 'aac'
    else warnings.push("This browser can't encode sound, so the video has no sound.")
  }

  onProgress(0, 'Preparing')
  let mixed: AudioBuffer | null = null
  if (audioCodec) {
    onProgress(0, 'Mixing sound')
    const mix = await mixAudio(project, items, duration, signal)
    mixed = mix.buffer
    for (const name of mix.skipped) warnings.push(`Couldn't read the sound of ${name}, so it's left out.`)
  }
  if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError')

  onProgress(0.04, 'Loading your files')
  const renderer = await CollageRenderer.create(project, items, width, height)
  const target = new BufferTarget()
  const output = new Output({ format: new Mp4OutputFormat({ fastStart: 'in-memory' }), target })

  try {
    const videoSource = new CanvasSource(renderer.canvas, { codec: 'avc', bitrate, keyFrameInterval: 2 })
    output.addVideoTrack(videoSource, { frameRate: fps })
    let audioSource: AudioBufferSource | null = null
    if (mixed && audioCodec) {
      audioSource = new AudioBufferSource({ codec: audioCodec, bitrate: 256_000 })
      output.addAudioTrack(audioSource)
    }
    await output.start()
    if (audioSource && mixed) await audioSource.add(mixed)

    const frames = Math.max(1, Math.round(duration * fps))
    for (let i = 0; i < frames; i++) {
      if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError')
      const t = i / fps
      await renderer.renderAt(t)
      await videoSource.add(t, 1 / fps)
      if (i % 3 === 0 || i === frames - 1) {
        onProgress(0.05 + 0.93 * ((i + 1) / frames), renderer.compat ? 'Rendering (compatibility mode, slower)' : 'Rendering')
      }
    }
    onProgress(0.99, 'Finishing')
    await output.finalize()
  } catch (e) {
    await output.cancel().catch(() => {})
    throw e
  } finally {
    await renderer.dispose()
  }

  const compat = renderer.compat
  const buffer = target.buffer
  if (!buffer) throw new ExportError('The export finished without any data.')
  const blob = new Blob([buffer], { type: 'video/mp4' })
  onProgress(1, 'Done')
  return {
    blob,
    info: {
      width,
      height,
      fps,
      videoBitrate: bitrate,
      audio: mixed ? 'aac' : 'none',
      duration,
      bytes: blob.size,
      warnings,
      compat,
    },
  }
}

/** A still image of the collage at timeline time t (full export resolution, lossless PNG). */
export async function exportPng(project: Project, items: MediaItem[], t: number, quality: Quality): Promise<Blob> {
  const { width, height } = exportSize(project, quality)
  const renderer = await CollageRenderer.create(project, items, width, height)
  try {
    await renderer.renderAt(t)
    return await new Promise<Blob>((resolve, reject) =>
      renderer.canvas.toBlob((b) => (b ? resolve(b) : reject(new ExportError("Couldn't create the image."))), 'image/png'),
    )
  } finally {
    await renderer.dispose()
  }
}
