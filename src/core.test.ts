import { describe, expect, it } from 'vitest'
import { LAYOUTS, MAX_CELLS, layoutsFor } from './layouts'
import { cellPixelRects, coverRect, neededPhotoSize, panAfterDrag } from './geometry'
import {
  MAX_DURATION,
  musicAt,
  musicEnd,
  musicSegments,
  moveClip,
  newLane,
  resolveLane,
  splitClip,
  totalDuration,
  trimLeft,
  trimRight,
} from './timeline'
import type { Lane, MusicTrack, Project } from './types'

describe('layouts', () => {
  it('has several layouts for every count from 2 to 9', () => {
    for (let n = 2; n <= MAX_CELLS; n++) expect(layoutsFor(n).length).toBeGreaterThanOrEqual(2)
    expect(LAYOUTS.length).toBeGreaterThanOrEqual(30)
  })

  it('uses unique ids and keeps every cell inside the collage', () => {
    expect(new Set(LAYOUTS.map((l) => l.id)).size).toBe(LAYOUTS.length)
    for (const l of LAYOUTS) {
      expect(l.rects.length).toBe(l.count)
      for (const [x, y, w, h] of l.rects) {
        expect(x).toBeGreaterThanOrEqual(-1e-9)
        expect(y).toBeGreaterThanOrEqual(-1e-9)
        expect(x + w).toBeLessThanOrEqual(1 + 1e-9)
        expect(y + h).toBeLessThanOrEqual(1 + 1e-9)
      }
    }
  })

  it('tiles the whole area without overlaps (except the centred single layout)', () => {
    for (const l of LAYOUTS.filter((x) => x.id !== '1-centre')) {
      const area = l.rects.reduce((s, [, , w, h]) => s + w * h, 0)
      expect(area).toBeCloseTo(1, 6)
    }
  })
})

describe('geometry', () => {
  it('leaves a margin equal to the gap around the collage and between cells', () => {
    const [a, b] = cellPixelRects(
      [
        [0, 0, 0.5, 1],
        [0.5, 0, 0.5, 1],
      ],
      1080,
      1920,
      20,
    )
    expect(a.x).toBeCloseTo(20)
    expect(a.y).toBeCloseTo(20)
    expect(b.x - (a.x + a.w)).toBeCloseTo(20)
    expect(1080 - (b.x + b.w)).toBeCloseTo(20)
  })

  it('covers the cell and centres the media at zoom 1', () => {
    const cell = { x: 0, y: 0, w: 100, h: 100 }
    const d = coverRect(400, 200, cell, 1, 0, 0)
    expect(d.dh).toBeCloseTo(100)
    expect(d.dw).toBeCloseTo(200)
    expect(d.dx).toBeCloseTo(-50)
    expect(d.overflowY).toBe(0)
  })

  it('pans to the edges and clamps', () => {
    const cell = { x: 0, y: 0, w: 100, h: 100 }
    expect(coverRect(400, 200, cell, 1, 1, 0).dx).toBeCloseTo(0)
    expect(coverRect(400, 200, cell, 1, -1, 0).dx).toBeCloseTo(-100)
    expect(coverRect(400, 200, cell, 1, 5, 0).dx).toBeCloseTo(0)
    expect(panAfterDrag(0, 25, 100)).toBeCloseTo(0.5)
    expect(panAfterDrag(0, 25, 0)).toBe(0)
  })

  it('never asks for more pixels than the photo has', () => {
    const cell = { x: 0, y: 0, w: 1000, h: 1000 }
    expect(neededPhotoSize(500, 500, cell, 1).scale).toBe(1)
    const big = neededPhotoSize(4000, 3000, cell, 1)
    expect(big.h).toBe(1000)
    expect(big.w).toBe(1333)
  })
})

const lane = (loop = false): Lane => ({
  mediaId: 'v',
  loop,
  volume: 1,
  clips: [
    { id: 'a', start: 2, in: 10, out: 14 },
    { id: 'b', start: 8, in: 0, out: 2 },
  ],
})

describe('timeline', () => {
  it('holds the first frame before the lane starts', () => {
    const r = resolveLane(lane(), 0)!
    expect(r.active).toBe(false)
    expect(r.time).toBe(10)
  })

  it('maps timeline time to source time inside a clip', () => {
    const r = resolveLane(lane(), 3)!
    expect(r.active).toBe(true)
    expect(r.clip.id).toBe('a')
    expect(r.time).toBeCloseTo(11)
    expect(resolveLane(lane(), 9)!.time).toBeCloseTo(1)
  })

  it('holds the last frame of the previous clip in a gap and after the end', () => {
    const gap = resolveLane(lane(), 7)!
    expect(gap.active).toBe(false)
    expect(gap.clip.id).toBe('a')
    expect(gap.time).toBeLessThan(14)
    const after = resolveLane(lane(), 50)!
    expect(after.clip.id).toBe('b')
    expect(after.active).toBe(false)
  })

  it('loops the whole lane when asked to', () => {
    const r = resolveLane(lane(true), 10 + 1)! // span is 2..10 (8 s); 11 -> 2 + 1 = 3
    expect(r.active).toBe(true)
    expect(r.clip.id).toBe('a')
    expect(r.time).toBeCloseTo(11)
  })

  it('caps the collage at 60 seconds and defaults a long video to its first 60 s', () => {
    const l = newLane('v', 300, 1)
    expect(l.clips[0].out).toBe(MAX_DURATION)
    const project = {
      cellCount: 2,
      cells: [
        { mediaId: 'v', zoom: 1, panX: 0, panY: 0 },
        { mediaId: null, zoom: 1, panX: 0, panY: 0 },
      ],
      lanes: [{ ...l, clips: [{ id: 'x', start: 30, in: 0, out: 90 }] }],
    } as unknown as Project
    expect(totalDuration(project)).toBe(MAX_DURATION)
  })

  it('trims from the left without moving the picture on the timeline', () => {
    const c = trimLeft({ id: 'a', start: 3, in: 5, out: 15 }, 2)
    expect(c.in).toBe(7)
    expect(c.start).toBe(5)
    expect(c.out).toBe(15)
    // cannot trim past the start of the timeline
    expect(trimLeft({ id: 'a', start: 1, in: 5, out: 15 }, -4).start).toBe(0)
    // cannot shrink below the minimum length
    const tiny = trimLeft({ id: 'a', start: 0, in: 0, out: 1 }, 5)
    expect(tiny.out - tiny.in).toBeGreaterThan(0)
  })

  it('trims on the right within the file and the 60 s cap', () => {
    expect(trimRight({ id: 'a', start: 0, in: 0, out: 5 }, 100, 20).out).toBe(20)
    expect(trimRight({ id: 'a', start: 55, in: 0, out: 3 }, 100, 200).out).toBe(5)
  })

  it('moves a clip but keeps it on the timeline', () => {
    expect(moveClip({ id: 'a', start: 1, in: 0, out: 4 }, -5).start).toBe(0)
    expect(moveClip({ id: 'a', start: 1, in: 0, out: 4 }, 100).start).toBe(56)
  })

  it('splits a clip in two that together cover the same footage', () => {
    const parts = splitClip({ id: 'a', start: 2, in: 10, out: 20 }, 6)!
    expect(parts[0]).toMatchObject({ start: 2, in: 10, out: 14 })
    expect(parts[1]).toMatchObject({ start: 6, in: 14, out: 20 })
    expect(splitClip({ id: 'a', start: 2, in: 10, out: 20 }, 2.1)).toBeNull()
  })
})

const song = (over: Partial<MusicTrack> = {}): MusicTrack => ({
  file: null as unknown as File,
  name: 'song',
  duration: 30,
  volume: 0.7,
  start: 0,
  in: 5,
  out: 8,
  loop: false,
  fadeOut: true,
  ...over,
})

describe('background music ribbon', () => {
  it('plays a trimmed clip once, from where the clip starts on the timeline', () => {
    const m = song({ start: 2 })
    expect(musicSegments(m, 10)).toEqual([{ at: 2, from: 5, to: 8 }])
    expect(musicAt(m, 1, 10).audible).toBe(false)
    expect(musicAt(m, 3, 10)).toMatchObject({ want: 6, audible: true })
    expect(musicAt(m, 6, 10).audible).toBe(false)
    expect(musicEnd(m, 10)).toBe(5)
  })

  it('repeats the clip until the collage ends and cuts the last repeat', () => {
    const m = song({ loop: true })
    expect(musicSegments(m, 8)).toEqual([
      { at: 0, from: 5, to: 8 },
      { at: 3, from: 5, to: 8 },
      { at: 6, from: 5, to: 7 },
    ])
    expect(musicAt(m, 4, 8).want).toBeCloseTo(6)
    expect(musicEnd(m, 8)).toBe(8)
  })

  it('fades out over the last 1.5 s of the music', () => {
    const m = song({ loop: true })
    expect(musicAt(m, 4, 8).fade).toBe(1)
    expect(musicAt(m, 7.25, 8).fade).toBeCloseTo(0.5)
    expect(musicAt(m, 4, 8).audible).toBe(true)
    expect(musicAt(song({ loop: true, fadeOut: false }), 7.9, 8).fade).toBe(1)
  })

  it('never plays past the end of the collage', () => {
    expect(musicSegments(song({ start: 9, loop: true }), 10)).toEqual([{ at: 9, from: 5, to: 6 }])
    expect(musicSegments(song({ start: 12 }), 10)).toEqual([])
  })
})
