import type { Clip, Lane, MusicTrack, Project } from './types'
import { clamp } from './geometry'

/** Instagram Stories play up to 60 seconds per clip. */
export const MAX_DURATION = 60
export const MIN_CLIP = 0.2
/** Length of a collage that has no video (used for the preview clock only). */
export const STILL_DURATION = 6

let seq = 0
export const newId = () => `${Date.now().toString(36)}${(seq++).toString(36)}${Math.random().toString(36).slice(2, 6)}`

export const clipLength = (c: Clip) => c.out - c.in
export const clipEnd = (c: Clip) => c.start + clipLength(c)

export const sortedClips = (lane: Lane) => [...lane.clips].sort((a, b) => a.start - b.start)

export interface Resolved {
  clip: Clip
  /** Second to show from the source file. */
  time: number
  /** True when the playhead is inside a clip (as opposed to holding the first or last frame). */
  active: boolean
}

/** What a lane shows at timeline time `t`. */
export function resolveLane(lane: Lane, t: number): Resolved | null {
  const clips = sortedClips(lane)
  if (clips.length === 0) return null
  const seqStart = clips[0].start
  const seqEnd = Math.max(...clips.map(clipEnd))
  let tt = t
  if (lane.loop && seqEnd > seqStart && t >= seqEnd) {
    tt = seqStart + ((t - seqStart) % (seqEnd - seqStart))
  }
  for (const clip of clips) {
    if (tt >= clip.start && tt < clipEnd(clip)) {
      return { clip, time: clip.in + (tt - clip.start), active: true }
    }
  }
  if (tt < seqStart) return { clip: clips[0], time: clips[0].in, active: false }
  let prev = clips[0]
  for (const c of clips) if (clipEnd(c) <= tt) prev = c
  return { clip: prev, time: Math.max(prev.in, prev.out - 0.04), active: false }
}

/** Lanes whose video is shown in a cell. */
export function placedLanes(project: Project): Lane[] {
  const placed = new Set(project.cells.slice(0, project.cellCount).map((c) => c.mediaId))
  return project.lanes.filter((l) => placed.has(l.mediaId))
}

/** Length of the collage: the end of its latest clip, up to 60 seconds. */
export function totalDuration(project: Project): number {
  const lanes = placedLanes(project)
  if (lanes.length === 0) return STILL_DURATION
  const end = Math.max(...lanes.flatMap((l) => l.clips.map(clipEnd)))
  return clamp(end, MIN_CLIP, MAX_DURATION)
}

/** A new lane for a video: whole file (or its first 60 s), starting at 0. */
export function newLane(mediaId: string, duration: number, volume: number): Lane {
  return {
    mediaId,
    clips: [{ id: newId(), start: 0, in: 0, out: Math.min(duration, MAX_DURATION) }],
    loop: false,
    volume,
  }
}

/** Drag the left handle by dt seconds. The picture stays where it is on the timeline. */
export function trimLeft(clip: Clip, dt: number): Clip {
  const minDt = Math.max(-clip.in, -clip.start)
  const maxDt = clipLength(clip) - MIN_CLIP
  const d = clamp(dt, minDt, maxDt)
  return { ...clip, in: clip.in + d, start: clip.start + d }
}

export function trimRight(clip: Clip, dt: number, mediaDuration: number): Clip {
  const maxOut = Math.min(mediaDuration, clip.in + (MAX_DURATION - clip.start))
  return { ...clip, out: clamp(clip.out + dt, clip.in + MIN_CLIP, maxOut) }
}

export function moveClip(clip: Clip, dt: number): Clip {
  const start = clamp(clip.start + dt, 0, Math.max(0, MAX_DURATION - clipLength(clip)))
  return { ...clip, start }
}

/** Cut a clip at timeline time t. Returns null if t is not inside the clip (with some room on both sides). */
export function splitClip(clip: Clip, t: number): [Clip, Clip] | null {
  if (t <= clip.start + MIN_CLIP || t >= clipEnd(clip) - MIN_CLIP) return null
  const cut = clip.in + (t - clip.start)
  return [
    { ...clip, out: cut },
    { id: newId(), start: t, in: cut, out: clip.out },
  ]
}

export const formatTime = (s: number) => {
  const t = Math.max(0, s)
  const m = Math.floor(t / 60)
  const sec = Math.floor(t % 60)
  return `${m}:${sec.toString().padStart(2, '0')}`
}

// ---------- background music ribbon ----------

/** Id used for the music clip when it is selected on the timeline. */
export const MUSIC_CLIP_ID = 'music'
export const FADE_SECONDS = 1.5

/** The music as a clip, so it can be trimmed and moved with the same functions as a video clip. */
export const musicAsClip = (m: MusicTrack): Clip => ({ id: MUSIC_CLIP_ID, start: m.start, in: m.in, out: m.out })

/** When the music stops: at the end of the collage if it loops, otherwise at the end of its clip. */
export const musicEnd = (m: MusicTrack, total: number) => (m.loop ? total : Math.min(total, m.start + (m.out - m.in)))

/** The pieces of the song to play, with the timeline time each one starts at. */
export function musicSegments(m: MusicTrack, total: number): { at: number; from: number; to: number }[] {
  const len = m.out - m.in
  const segs: { at: number; from: number; to: number }[] = []
  if (len <= 0) return segs
  let at = m.start
  do {
    const l = Math.min(len, total - at)
    if (l <= 0) break
    segs.push({ at, from: m.in, to: m.in + l })
    at += len
  } while (m.loop && at < total)
  return segs
}

/** Which second of the song to hear at timeline time t, and how loud (fade) it should be. */
export function musicAt(m: MusicTrack, t: number, total: number): { want: number; audible: boolean; fade: number } {
  const len = m.out - m.in
  if (len <= 0 || t < m.start) return { want: m.in, audible: false, fade: 0 }
  const rel = t - m.start
  if (!m.loop && rel >= len) return { want: m.out, audible: false, fade: 0 }
  const end = musicEnd(m, total)
  return {
    want: m.in + (m.loop ? rel % len : rel),
    audible: t < end,
    fade: m.fadeOut ? clamp((end - t) / FADE_SECONDS, 0, 1) : 1,
  }
}
