import { musicAt, placedLanes, resolveLane } from '../timeline'
import type { Project } from '../types'
import { clamp } from '../geometry'
import { music, videos } from './registry'

/**
 * Keeps each hidden <video> element in step with the timeline clock: plays it while the playhead is inside one of
 * its clips, holds a frame otherwise, and mutes it when it should not be heard.
 */
export function syncVideos(project: Project, t: number, playing: boolean) {
  const placed = new Set(placedLanes(project).map((l) => l.mediaId))
  for (const [id, v] of videos) {
    if (!placed.has(id)) {
      if (!v.paused) v.pause()
      continue
    }
    const lane = project.lanes.find((l) => l.mediaId === id)
    const r = lane ? resolveLane(lane, t) : null
    if (!lane || !r) continue
    const want = r.time
    const audible = playing && r.active && lane.volume > 0
    v.muted = !audible
    // Volume cannot be changed on iPhone (it is always full); there the slider only mutes.
    try {
      v.volume = lane.volume
    } catch {
      // ignore
    }
    if (playing && r.active) {
      if (v.paused) {
        if (Math.abs(v.currentTime - want) > 0.05) v.currentTime = want
        void v.play().catch(() => {})
      } else if (Math.abs(v.currentTime - want) > 0.3) {
        v.currentTime = want
      }
    } else {
      if (!v.paused) v.pause()
      if (!v.seeking && Math.abs(v.currentTime - want) > 0.02) v.currentTime = want
    }
  }
}

/** Plays the music ribbon in step with the timeline: its trim, start time, repeat and fade out. */
export function syncMusic(project: Project, t: number, playing: boolean, total: number) {
  const el = music.el
  if (!el) return
  const m = project.music
  if (!m || m.volume <= 0) {
    if (!el.paused) el.pause()
    return
  }
  const { want, audible, fade } = musicAt(m, t, total)
  el.muted = !(playing && audible)
  try {
    el.volume = clamp(m.volume * fade, 0, 1)
  } catch {
    // ignore
  }
  if (playing && audible) {
    if (el.paused) {
      if (Math.abs(el.currentTime - want) > 0.05) el.currentTime = want
      void el.play().catch(() => {})
    } else if (Math.abs(el.currentTime - want) > 0.3) {
      el.currentTime = want
    }
  } else if (!el.paused) {
    el.pause()
  }
}

/** Call inside a tap handler so phones allow the videos to play (and play sound) afterwards. */
export function primeVideos() {
  for (const v of [...videos.values(), ...(music.el ? [music.el] : [])]) {
    const wasMuted = v.muted
    v.muted = true
    void v
      .play()
      .then(() => {
        v.pause()
        v.muted = wasMuted
      })
      .catch(() => {})
  }
}
