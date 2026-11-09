import { ALL_FORMATS, AudioBufferSink, BlobSource, Input } from 'mediabunny'
import { FADE_SECONDS, clipEnd, musicEnd, musicSegments, placedLanes, sortedClips } from '../timeline'
import type { MediaItem, Project } from '../types'

export const SAMPLE_RATE = 48000

/** True if the export would contain any sound: a placed video that is not muted, or background music. */
export function hasAudibleSound(project: Project, items: MediaItem[]): boolean {
  if (project.music && project.music.volume > 0) return true
  return placedLanes(project).some((l) => l.volume > 0 && items.find((m) => m.id === l.mediaId)?.hasAudio)
}

/**
 * Mixes the sound of the placed videos into one stereo buffer, following the timeline: trims, start offsets,
 * looping and volume. Returns null if nothing is audible.
 */
export async function mixAudio(
  project: Project,
  items: MediaItem[],
  duration: number,
  signal?: AbortSignal,
): Promise<AudioBuffer | null> {
  const lanes = placedLanes(project).filter(
    (l) => l.volume > 0 && items.find((m) => m.id === l.mediaId)?.hasAudio,
  )
  const mu = project.music && project.music.volume > 0 ? project.music : null
  if (lanes.length === 0 && !mu) return null

  const ctx = new OfflineAudioContext(2, Math.ceil(duration * SAMPLE_RATE), SAMPLE_RATE)
  let scheduled = 0

  for (const lane of lanes) {
    const item = items.find((m) => m.id === lane.mediaId)!
    const input = new Input({ source: new BlobSource(item.file), formats: ALL_FORMATS })
    try {
      const track = await input.getPrimaryAudioTrack()
      if (!track) continue
      const sink = new AudioBufferSink(track)
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
          for await (const wb of sink.buffers(clip.in, limit)) {
            if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError')
            const bufStart = wb.timestamp
            const a = Math.max(bufStart, clip.in)
            const b = Math.min(bufStart + wb.duration, limit)
            if (b - a <= 0) continue
            const src = ctx.createBufferSource()
            src.buffer = wb.buffer
            src.connect(gain)
            src.start(base + (a - clip.in), a - bufStart, b - a)
            scheduled++
          }
        }
      }
    } finally {
      input.dispose()
    }
  }

  if (mu) {
    const input = new Input({ source: new BlobSource(mu.file), formats: ALL_FORMATS })
    try {
      const track = await input.getPrimaryAudioTrack()
      if (track) {
        const sink = new AudioBufferSink(track)
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
          for await (const wb of sink.buffers(seg.from, seg.to)) {
            if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError')
            const a = Math.max(wb.timestamp, seg.from)
            const b = Math.min(wb.timestamp + wb.duration, seg.to)
            if (b - a <= 0) continue
            const src = ctx.createBufferSource()
            src.buffer = wb.buffer
            src.connect(gain)
            src.start(seg.at + (a - seg.from), a - wb.timestamp, b - a)
            scheduled++
          }
        }
      }
    } finally {
      input.dispose()
    }
  }
  if (scheduled === 0) return null
  return ctx.startRendering()
}
