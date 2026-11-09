import { ALL_FORMATS, AudioBufferSink, BlobSource, Input } from 'mediabunny'
import { FADE_SECONDS, clipEnd, musicEnd, musicSegments, placedLanes, sortedClips } from '../timeline'
import type { MediaItem, Project } from '../types'

export const SAMPLE_RATE = 48000
/** Without WebCodecs audio, the whole file has to be read into memory to decode its sound. */
const MAX_WHOLE_FILE_DECODE = 250 * 1024 * 1024

/** True if the export would contain any sound: a placed video that is not muted, or background music. */
export function hasAudibleSound(project: Project, items: MediaItem[]): boolean {
  if (project.music && project.music.volume > 0) return true
  return placedLanes(project).some((l) => l.volume > 0 && items.find((m) => m.id === l.mediaId)?.hasAudio)
}

interface Piece {
  buffer: AudioBuffer
  /** Where in the file this buffer starts, in seconds. */
  timestamp: number
  duration: number
}

interface AudioSource {
  buffers(from: number, to: number): AsyncIterable<Piece>
  dispose(): void
}

/**
 * Opens the sound of a file for mixing. Preferred: WebCodecs through Mediabunny (streams only the part needed).
 * Fallback for browsers without a WebCodecs audio decoder (Safari before iOS 26): the browser's Web Audio decoder,
 * which reads the whole file. Returns null if neither works.
 */
async function openAudio(file: File, ctx: OfflineAudioContext): Promise<AudioSource | null> {
  if (typeof AudioDecoder !== 'undefined') {
    const input = new Input({ source: new BlobSource(file), formats: ALL_FORMATS })
    try {
      const track = await input.getPrimaryAudioTrack()
      if (track && (await track.canDecode())) {
        const sink = new AudioBufferSink(track)
        return { buffers: (from, to) => sink.buffers(from, to), dispose: () => input.dispose() }
      }
    } catch {
      // try the next way
    }
    input.dispose()
  }
  if (file.size > MAX_WHOLE_FILE_DECODE) return null
  try {
    const buffer = await ctx.decodeAudioData(await file.arrayBuffer())
    return {
      async *buffers() {
        yield { buffer, timestamp: 0, duration: buffer.duration }
      },
      dispose() {},
    }
  } catch {
    return null
  }
}

export interface MixResult {
  buffer: AudioBuffer | null
  /** Names of files whose sound could not be added. */
  skipped: string[]
}

/**
 * Mixes the sound of the placed videos and the music ribbon into one stereo buffer, following the timeline: trims,
 * start offsets, looping, volume and fade. `buffer` is null if nothing is audible.
 */
export async function mixAudio(
  project: Project,
  items: MediaItem[],
  duration: number,
  signal?: AbortSignal,
): Promise<MixResult> {
  const lanes = placedLanes(project).filter((l) => l.volume > 0 && items.find((m) => m.id === l.mediaId)?.hasAudio)
  const mu = project.music && project.music.volume > 0 ? project.music : null
  const skipped: string[] = []
  if (lanes.length === 0 && !mu) return { buffer: null, skipped }

  const ctx = new OfflineAudioContext(2, Math.ceil(duration * SAMPLE_RATE), SAMPLE_RATE)
  let scheduled = 0

  const schedule = (piece: Piece, gain: GainNode, from: number, to: number, at: number) => {
    const a = Math.max(piece.timestamp, from)
    const b = Math.min(piece.timestamp + piece.duration, to)
    if (b - a <= 0) return
    const src = ctx.createBufferSource()
    src.buffer = piece.buffer
    src.connect(gain)
    src.start(at + (a - from), a - piece.timestamp, b - a)
    scheduled++
  }

  for (const lane of lanes) {
    const item = items.find((m) => m.id === lane.mediaId)!
    const audio = await openAudio(item.file, ctx)
    if (!audio) {
      skipped.push(item.name)
      continue
    }
    try {
      const gain = ctx.createGain()
      gain.gain.value = lane.volume
      gain.connect(ctx.destination)

      const clips = sortedClips(lane)
      const seqStart = clips[0].start
      const seqEnd = Math.max(...clips.map(clipEnd))
      const span = seqEnd - seqStart
      const repeats = lane.loop && span > 0 ? Math.ceil((duration - seqStart) / span) : 1

      for (let k = 0; k < repeats; k++) {
        for (const clip of clips) {
          const base = clip.start + k * span
          if (base >= duration) continue
          const limit = Math.min(clip.out, clip.in + (duration - base))
          for await (const piece of audio.buffers(clip.in, limit)) {
            if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError')
            schedule(piece, gain, clip.in, limit, base)
          }
        }
      }
    } finally {
      audio.dispose()
    }
  }

  if (mu) {
    const audio = await openAudio(mu.file, ctx)
    if (!audio) skipped.push(mu.name)
    else {
      try {
        const gain = ctx.createGain()
        gain.gain.setValueAtTime(mu.volume, 0)
        if (mu.fadeOut) {
          const end = musicEnd(mu, duration)
          const f = Math.min(FADE_SECONDS, Math.max(0.01, end - mu.start))
          gain.gain.setValueAtTime(mu.volume, Math.max(0, end - f))
          gain.gain.linearRampToValueAtTime(0, end)
        }
        gain.connect(ctx.destination)
        for (const seg of musicSegments(mu, duration)) {
          for await (const piece of audio.buffers(seg.from, seg.to)) {
            if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError')
            schedule(piece, gain, seg.from, seg.to, seg.at)
          }
        }
      } finally {
        audio.dispose()
      }
    }
  }

  if (scheduled === 0) return { buffer: null, skipped }
  return { buffer: await ctx.startRendering(), skipped }
}
