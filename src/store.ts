import { create } from 'zustand'
import type { CellState, Clip, FormatId, Lane, MediaItem, MusicTrack, Project } from './types'
import { MAX_CELLS, MAX_VIDEOS, defaultLayoutFor, layoutById, layoutsFor } from './layouts'
import { clamp } from './geometry'
import { MAX_DURATION, MUSIC_CLIP_ID, clipEnd, newLane, splitClip, totalDuration } from './timeline'
import { ImportError, kindOf, loadMedia, loadMusic } from './media/import'
import { disposeMedia, disposeMusic } from './media/registry'

export type Tab = 'media' | 'layout' | 'style' | 'audio' | 'picture'

export const BACKGROUNDS = ['#101016', '#ffffff', '#f4e9d8', '#ffd6e7', '#c9e4ff', '#d4f5dc', '#ff5fa2', '#6c4dff']

const emptyCell = (): CellState => ({ mediaId: null, zoom: 1, panX: 0, panY: 0, rotation: 0, flip: false, angle: 0 })

const initialProject = (): Project => ({
  format: 'story',
  cellCount: 4,
  layoutId: defaultLayoutFor(4).id,
  cells: Array.from({ length: 4 }, emptyCell),
  gap: 12,
  radius: 16,
  bg: BACKGROUNDS[0],
  safeZone: false,
  lanes: [],
  music: null,
})

interface State {
  items: MediaItem[]
  project: Project
  selectedCell: number | null
  selectedClip: string | null
  swapFrom: number | null
  playhead: number
  playing: boolean
  tab: Tab
  /** The tab to go back to when the Picture tab is closed. */
  returnTab: Tab
  importing: boolean
  toast: { id: number; text: string } | null
  exportOpen: boolean

  notify: (text: string) => void
  addFiles: (files: File[], targetCell?: number) => Promise<void>
  placeMedia: (mediaId: string, cell?: number) => void
  removeMedia: (mediaId: string) => void
  clearCell: (cell: number) => void
  swapCells: (a: number, b: number) => void
  setCellView: (cell: number, patch: Partial<Pick<CellState, 'zoom' | 'panX' | 'panY' | 'rotation' | 'flip' | 'angle'>>) => void
  /** Turn a picture a quarter turn clockwise (or counter-clockwise with dir -1). Resets its position. */
  rotateCell: (cell: number, dir?: 1 | -1) => void
  flipCell: (cell: number) => void
  cropCell: number | null
  setCropCell: (cell: number | null) => void
  resetCell: (cell: number) => void
  setCellCount: (n: number) => void
  setLayout: (id: string) => void
  shuffleLayout: () => void
  setStyle: (patch: Partial<Pick<Project, 'gap' | 'radius' | 'bg' | 'safeZone'>>) => void
  setFormat: (f: FormatId) => void
  selectCell: (i: number | null) => void
  /** Show the Picture tab (options for the selected picture). */
  openPicture: () => void
  setSwapFrom: (i: number | null) => void
  selectClip: (id: string | null) => void
  setTab: (t: Tab) => void
  setPlayhead: (t: number) => void
  setPlaying: (p: boolean) => void
  setLane: (mediaId: string, patch: Partial<Pick<Lane, 'loop' | 'volume'>>) => void
  updateClip: (mediaId: string, clipId: string, fn: (c: Clip) => Clip) => void
  splitAtPlayhead: () => void
  deleteSelectedClip: () => void
  setExportOpen: (o: boolean) => void
  setMusic: (file: File) => Promise<void>
  updateMusic: (patch: Partial<Pick<MusicTrack, 'volume' | 'loop' | 'fadeOut'>>) => void
  setMusicClip: (clip: Clip) => void
  removeMusic: () => void
}

let toastSeq = 0

export const useStore = create<State>((set, get) => ({
  items: [],
  project: initialProject(),
  selectedCell: null,
  selectedClip: null,
  swapFrom: null,
  playhead: 0,
  playing: false,
  tab: 'media',
  returnTab: 'media',
  importing: false,
  toast: null,
  exportOpen: false,

  notify: (text) => {
    const id = ++toastSeq
    set({ toast: { id, text } })
    setTimeout(() => {
      if (get().toast?.id === id) set({ toast: null })
    }, 5000)
  },

  addFiles: async (files, targetCell) => {
    if (get().importing) return
    set({ importing: true })
    const fresh = get().items.length === 0
    let target = targetCell
    try {
      for (const file of files) {
        const s = get()
        if (!kindOf(file)) {
          s.notify(`${file.name}: only photos and videos can be added.`)
          continue
        }
        if (s.items.length >= MAX_CELLS) {
          s.notify(`A collage holds up to ${MAX_CELLS} photos and videos.`)
          break
        }
        if (kindOf(file) === 'video' && s.items.filter((i) => i.kind === 'video').length >= MAX_VIDEOS) {
          s.notify(`Only ${MAX_VIDEOS} videos per collage. Remove one to add another.`)
          continue
        }
        let item: MediaItem
        try {
          item = await loadMedia(file)
        } catch (e) {
          get().notify(e instanceof ImportError ? e.message : `${file.name}: couldn't be added.`)
          continue
        }
        if (item.converted) get().notify(`${file.name} was HEIC, so it was converted to a high-quality JPEG.`)
        set((st) => ({
          items: [...st.items, item],
          project:
            item.kind === 'video'
              ? {
                  ...st.project,
                  lanes: [
                    ...st.project.lanes,
                    newLane(item.id, item.duration, st.project.lanes.length === 0 ? 1 : 0),
                  ],
                }
              : st.project,
        }))
        get().placeMedia(item.id, target)
        target = undefined
      }
      if (fresh) {
        const n = get().items.length
        if (n > 0) get().setCellCount(clamp(n, 1, MAX_CELLS))
      }
    } finally {
      set({ importing: false })
    }
  },

  placeMedia: (mediaId, cell) => {
    const { project } = get()
    let cells = project.cells.map((c) => (c.mediaId === mediaId ? emptyCell() : c))
    let count = project.cellCount
    let idx = cell ?? cells.findIndex((c) => !c.mediaId)
    if (idx === -1) {
      if (count >= MAX_CELLS) {
        get().notify('All cells are full. Tap a cell to replace its media.')
        return
      }
      count += 1
      cells = [...cells, emptyCell()]
      idx = count - 1
    }
    cells[idx] = { ...emptyCell(), mediaId }
    const layoutId = count === project.cellCount ? project.layoutId : defaultLayoutFor(count).id
    set({ project: { ...project, cells, cellCount: count, layoutId }, selectedCell: idx })
  },

  removeMedia: (mediaId) => {
    disposeMedia(mediaId)
    set((s) => ({
      items: s.items.filter((i) => i.id !== mediaId),
      project: {
        ...s.project,
        cells: s.project.cells.map((c) => (c.mediaId === mediaId ? emptyCell() : c)),
        lanes: s.project.lanes.filter((l) => l.mediaId !== mediaId),
      },
      selectedClip: null,
    }))
  },

  clearCell: (cell) =>
    set((s) => ({
      project: { ...s.project, cells: s.project.cells.map((c, i) => (i === cell ? emptyCell() : c)) },
    })),

  swapCells: (a, b) =>
    set((s) => {
      const cells = [...s.project.cells]
      ;[cells[a], cells[b]] = [cells[b], cells[a]]
      // one swap, then back to normal
      return { project: { ...s.project, cells }, selectedCell: b, swapFrom: null }
    }),

  setCellView: (cell, patch) =>
    set((s) => ({
      project: {
        ...s.project,
        cells: s.project.cells.map((c, i) =>
          i === cell
            ? {
                ...c,
                ...patch,
                zoom: clamp(patch.zoom ?? c.zoom, 1, 4),
                panX: clamp(patch.panX ?? c.panX, -1, 1),
                panY: clamp(patch.panY ?? c.panY, -1, 1),
                rotation: (((Math.round((patch.rotation ?? c.rotation) / 90) * 90) % 360) + 360) % 360,
                flip: patch.flip ?? c.flip,
                angle: clamp(patch.angle ?? c.angle, -45, 45),
              }
            : c,
        ),
      },
    })),

  resetCell: (cell) =>
    get().setCellView(cell, { zoom: 1, panX: 0, panY: 0, rotation: 0, flip: false, angle: 0 }),

  rotateCell: (cell, dir = 1) => {
    const c = get().project.cells[cell]
    if (c) get().setCellView(cell, { rotation: c.rotation + 90 * dir, panX: 0, panY: 0 })
  },

  flipCell: (cell) => {
    const c = get().project.cells[cell]
    if (c) get().setCellView(cell, { flip: !c.flip, panX: -c.panX })
  },

  cropCell: null,
  setCropCell: (cropCell) => set({ cropCell, playing: cropCell !== null ? false : get().playing }),

  setCellCount: (n) => {
    const count = clamp(Math.round(n), 1, MAX_CELLS)
    set((s) => {
      const cells = Array.from({ length: count }, (_, i) => s.project.cells[i] ?? emptyCell())
      const keep = layoutById(s.project.layoutId).count === count
      return {
        project: {
          ...s.project,
          cellCount: count,
          cells,
          layoutId: keep ? s.project.layoutId : defaultLayoutFor(count).id,
        },
        selectedCell: s.selectedCell !== null && s.selectedCell < count ? s.selectedCell : null,
        swapFrom: null,
      }
    })
  },

  setLayout: (id) => set((s) => ({ project: { ...s.project, layoutId: id } })),

  shuffleLayout: () => {
    const { project } = get()
    const options = layoutsFor(project.cellCount).filter((l) => l.id !== project.layoutId)
    if (options.length) get().setLayout(options[Math.floor(Math.random() * options.length)].id)
  },

  setStyle: (patch) => set((s) => ({ project: { ...s.project, ...patch } })),
  setFormat: (format) => set((s) => ({ project: { ...s.project, format } })),
  selectCell: (i) =>
    set((s) => ({
      selectedCell: i,
      // nothing selected any more: leave the Picture tab and go back to where the person was
      ...(i === null && s.tab === 'picture' ? { tab: s.returnTab, swapFrom: null } : {}),
    })),
  openPicture: () => set((s) => ({ tab: 'picture', returnTab: s.tab === 'picture' ? s.returnTab : s.tab })),
  setSwapFrom: (i) => set({ swapFrom: i }),
  selectClip: (id) => set({ selectedClip: id }),
  setTab: (tab) => set({ tab }),
  setPlayhead: (t) => set({ playhead: Math.max(0, t) }),
  setPlaying: (playing) => set({ playing }),

  setLane: (mediaId, patch) =>
    set((s) => ({
      project: {
        ...s.project,
        lanes: s.project.lanes.map((l) => (l.mediaId === mediaId ? { ...l, ...patch } : l)),
      },
    })),

  updateClip: (mediaId, clipId, fn) =>
    set((s) => ({
      project: {
        ...s.project,
        lanes: s.project.lanes.map((l) =>
          l.mediaId === mediaId ? { ...l, clips: l.clips.map((c) => (c.id === clipId ? fn(c) : c)) } : l,
        ),
      },
    })),

  splitAtPlayhead: () => {
    const { project, selectedClip, playhead, notify } = get()
    const lanes = project.lanes
    if (selectedClip === MUSIC_CLIP_ID) {
      notify('Split works on video clips. Trim the music with its ends instead.')
      return
    }
    // Prefer the selected clip, otherwise the first clip under the playhead.
    let target: { lane: Lane; clip: Clip } | null = null
    for (const lane of lanes) {
      for (const clip of lane.clips) {
        const under = playhead > clip.start && playhead < clipEnd(clip)
        if (clip.id === selectedClip && under) target = { lane, clip }
        else if (!target && !selectedClip && under) target = { lane, clip }
      }
    }
    if (!target) {
      notify('Move the playhead over a clip to cut it there.')
      return
    }
    const parts = splitClip(target.clip, playhead)
    if (!parts) {
      notify('Move the playhead a little further from the clip edge.')
      return
    }
    const { lane, clip } = target
    set({
      project: {
        ...project,
        lanes: lanes.map((l) =>
          l.mediaId === lane.mediaId ? { ...l, clips: l.clips.flatMap((c) => (c.id === clip.id ? parts : [c])) } : l,
        ),
      },
      selectedClip: parts[1].id,
    })
  },

  deleteSelectedClip: () => {
    const { project, selectedClip, notify } = get()
    if (!selectedClip) {
      notify('Tap a clip on the timeline first.')
      return
    }
    if (selectedClip === MUSIC_CLIP_ID) {
      get().removeMusic()
      return
    }
    const lane = project.lanes.find((l) => l.clips.some((c) => c.id === selectedClip))
    if (!lane) return
    if (lane.clips.length <= 1) {
      notify('A video needs at least one clip. Use Remove on its cell to take it out.')
      return
    }
    set({
      project: {
        ...project,
        lanes: project.lanes.map((l) =>
          l.mediaId === lane.mediaId ? { ...l, clips: l.clips.filter((c) => c.id !== selectedClip) } : l,
        ),
      },
      selectedClip: null,
    })
  },

  setMusic: async (file) => {
    if (!file.type.startsWith('audio/') && !/\.(mp3|m4a|aac|wav|ogg|opus|flac)$/i.test(file.name)) {
      get().notify(`${file.name}: pick an audio file (MP3, M4A, WAV).`)
      return
    }
    try {
      const { duration } = await loadMusic(file)
      const total = totalDuration(get().project)
      const prev = get().project.music
      set((s) => ({
        project: {
          ...s.project,
          music: {
            file,
            name: file.name.replace(/\.[^.]+$/, ''),
            duration,
            volume: prev?.volume || 0.7,
            start: 0,
            in: 0,
            out: Math.min(duration, MAX_DURATION),
            // a song shorter than the collage repeats by default
            loop: duration < total,
            fadeOut: prev?.fadeOut ?? true,
          },
        },
        selectedClip: MUSIC_CLIP_ID,
      }))
    } catch (e) {
      get().notify(e instanceof ImportError ? e.message : `${file.name}: couldn't be added.`)
    }
  },

  updateMusic: (patch) =>
    set((s) => (s.project.music ? { project: { ...s.project, music: { ...s.project.music, ...patch } } } : s)),

  setMusicClip: (clip) =>
    set((s) =>
      s.project.music
        ? { project: { ...s.project, music: { ...s.project.music, start: clip.start, in: clip.in, out: clip.out } } }
        : s,
    ),

  removeMusic: () => {
    disposeMusic()
    set((s) => ({
      project: { ...s.project, music: null },
      selectedClip: s.selectedClip === MUSIC_CLIP_ID ? null : s.selectedClip,
    }))
  },

  setExportOpen: (exportOpen) => set({ exportOpen, playing: exportOpen ? false : get().playing }),
}))

export const duration = () => totalDuration(useStore.getState().project)

if (import.meta.env.DEV) {
  ;(window as unknown as Record<string, unknown>).__cm = { store: useStore }
}
