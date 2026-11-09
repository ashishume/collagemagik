export type MediaKind = 'photo' | 'video'

export interface MediaItem {
  id: string
  kind: MediaKind
  file: File
  name: string
  /** Display size in pixels, with rotation / EXIF orientation applied. */
  width: number
  height: number
  /** Seconds. 0 for photos. */
  duration: number
  hasAudio: boolean
  /** Videos: how frames are read for export. 'element' is the slower compatibility path through the browser's player. */
  decoder?: 'webcodecs' | 'element'
  /** Photos: the original was HEIC and has been converted to JPEG. */
  converted?: boolean
  /** Object URL of a small thumbnail. */
  thumb: string
}

/** x, y, width, height as fractions (0..1) of the collage area. */
export type Rect = [number, number, number, number]

export interface Layout {
  id: string
  name: string
  count: number
  rects: Rect[]
}

export interface CellState {
  mediaId: string | null
  /** 1 = the photo or video just covers the cell. */
  zoom: number
  /** -1..1, 0 = centred. Only matters when the media overflows the cell. */
  panX: number
  panY: number
  /** Quarter turns clockwise, in degrees: 0, 90, 180 or 270. */
  rotation: number
  /** Mirror left to right (after rotating). */
  flip: boolean
  /** Straighten: extra tilt in degrees, -45..45 (positive = clockwise). */
  angle: number
}

/** A piece of a video placed on the timeline. All values are seconds. */
export interface Clip {
  id: string
  /** Where the clip begins on the timeline. */
  start: number
  /** Trim: first and last second used from the source file. */
  in: number
  out: number
}

export interface Lane {
  mediaId: string
  clips: Clip[]
  /** Repeat the lane's clips when they end (otherwise the last frame is held). */
  loop: boolean
  /** 0 = muted, 1 = full volume. */
  volume: number
}

/** Background music (the user's own audio file), shown as its own ribbon on the timeline. Seconds throughout. */
export interface MusicTrack {
  file: File
  name: string
  /** Length of the whole file. */
  duration: number
  /** 0..1, 0 = muted. */
  volume: number
  /** Where the clip begins on the timeline. */
  start: number
  /** Trim: first and last second used from the song. */
  in: number
  out: number
  /** Repeat the clip until the collage ends. */
  loop: boolean
  /** Fade out over the last seconds of the music. */
  fadeOut: boolean
}

export type FormatId = 'story' | 'post' | 'square'

export interface Project {
  format: FormatId
  cellCount: number
  layoutId: string
  cells: CellState[]
  /** Pixels at 1080 px wide; scaled for other sizes. */
  gap: number
  radius: number
  bg: string
  safeZone: boolean
  lanes: Lane[]
  music: MusicTrack | null
}
