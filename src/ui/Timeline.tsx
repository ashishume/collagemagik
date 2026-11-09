import { useRef } from 'react'
import { Music2, Pause, Play, Plus, Repeat, Scissors, Trash2, Volume2, VolumeX } from 'lucide-react'
import { clamp } from '../geometry'
import { primeVideos } from '../media/sync'
import { useStore } from '../store'
import {
  MUSIC_CLIP_ID,
  clipEnd,
  clipLength,
  formatTime,
  moveClip,
  musicAsClip,
  musicEnd,
  placedLanes,
  totalDuration,
  trimLeft,
  trimRight,
} from '../timeline'
import type { Clip } from '../types'

const LANE_COLORS = ['var(--video-a)', 'var(--video-b)']
const MUSIC_LANE = '__music__'

type Drag =
  | { kind: 'scrub' }
  | { kind: 'left' | 'right' | 'move'; mediaId: string; clip: Clip; x0: number; pxPerSec: number }

export function Timeline() {
  const project = useStore((s) => s.project)
  const items = useStore((s) => s.items)
  const playhead = useStore((s) => s.playhead)
  const playing = useStore((s) => s.playing)
  const selectedClip = useStore((s) => s.selectedClip)
  const store = useStore.getState

  const areaRef = useRef<HTMLDivElement>(null)
  const drag = useRef<Drag | null>(null)
  const viewRef = useRef(10)
  const musicFile = useRef<HTMLInputElement>(null)
  const music = project.music

  const lanes = placedLanes(project)
  const dur = totalDuration(project)

  if (!drag.current) viewRef.current = clamp(Math.ceil((dur * 1.4) / 5) * 5, 10, 60)
  const view = viewRef.current

  if (lanes.length === 0) {
    return (
      <section className="timeline empty" aria-label="Timeline">
        <p>Add a video to cut it on the timeline. Photos stay on screen for the whole video.</p>
      </section>
    )
  }

  const timeFromEvent = (clientX: number) => {
    const b = areaRef.current!.getBoundingClientRect()
    return clamp(((clientX - b.left) / b.width) * view, 0, dur)
  }

  const togglePlay = () => {
    const s = store()
    if (s.playing) {
      s.setPlaying(false)
      return
    }
    primeVideos()
    if (s.playhead >= dur - 0.05) s.setPlayhead(0)
    s.setPlaying(true)
  }

  const onAreaDown = (e: React.PointerEvent) => {
    areaRef.current!.setPointerCapture(e.pointerId)
    drag.current = { kind: 'scrub' }
    store().setPlaying(false)
    store().setPlayhead(timeFromEvent(e.clientX))
    store().selectClip(null)
  }

  const onClipDown = (e: React.PointerEvent, kind: 'left' | 'right' | 'move', mediaId: string, clip: Clip) => {
    e.stopPropagation()
    areaRef.current!.setPointerCapture(e.pointerId)
    const b = areaRef.current!.getBoundingClientRect()
    drag.current = { kind, mediaId, clip, x0: e.clientX, pxPerSec: b.width / view }
    store().selectClip(clip.id)
    store().setPlaying(false)
  }

  const onMove = (e: React.PointerEvent) => {
    const d = drag.current
    if (!d) return
    if (d.kind === 'scrub') {
      store().setPlayhead(timeFromEvent(e.clientX))
      return
    }
    const dt = (e.clientX - d.x0) / d.pxPerSec
    const isMusic = d.mediaId === MUSIC_LANE
    const sourceLen = isMusic ? (music?.duration ?? d.clip.out) : (items.find((m) => m.id === d.mediaId)?.duration ?? d.clip.out)
    const next =
      d.kind === 'left'
        ? trimLeft(d.clip, dt)
        : d.kind === 'right'
          ? trimRight(d.clip, dt, sourceLen)
          : moveClip(d.clip, dt)
    if (isMusic) {
      store().setMusicClip(next)
      return
    }
    store().updateClip(d.mediaId, d.clip.id, () => next)
    // keep the picture on the clip being edited
    if (d.kind === 'left') store().setPlayhead(next.start)
    else if (d.kind === 'right') store().setPlayhead(Math.max(next.start, clipEnd(next) - 0.05))
  }

  const onUp = () => {
    drag.current = null
  }

  const phLeft = `${(clamp(playhead, 0, view) / view) * 100}%`
  const ticks: number[] = []
  const step = view <= 15 ? 2 : view <= 30 ? 5 : 10
  for (let t = 0; t <= view; t += step) ticks.push(t)

  return (
    <section className="timeline" aria-label="Timeline">
      <div className="tl-bar">
        <button className="icon-btn round" onClick={togglePlay} aria-label={playing ? 'Pause' : 'Play'}>
          {playing ? <Pause size={18} /> : <Play size={18} />}
        </button>
        <span className="time">
          {formatTime(playhead)} / {formatTime(dur)}
        </span>
        <span className="spacer" />
        <button className="chip-btn" onClick={() => store().splitAtPlayhead()}>
          <Scissors size={16} /> Split
        </button>
        <button className="chip-btn" onClick={() => store().deleteSelectedClip()}>
          <Trash2 size={16} /> Delete
        </button>
      </div>

      <div className="tl-grid">
        <div className="tl-labels">
          <div className="tl-ruler-label" />
          {lanes.map((lane, i) => (
            <div className="tl-label" key={lane.mediaId} style={{ ['--lane' as string]: LANE_COLORS[i % 2] }}>
              <span className="lane-chip">{i === 0 ? 'A' : 'B'}</span>
              <button
                className={`mini-btn ${lane.volume === 0 ? 'off' : ''}`}
                onClick={() => store().setLane(lane.mediaId, { volume: lane.volume === 0 ? 1 : 0 })}
                aria-label={lane.volume === 0 ? `Unmute video ${i === 0 ? 'A' : 'B'}` : `Mute video ${i === 0 ? 'A' : 'B'}`}
                aria-pressed={lane.volume === 0}
              >
                {lane.volume === 0 ? <VolumeX size={15} /> : <Volume2 size={15} />}
              </button>
              <button
                className={`mini-btn ${lane.loop ? 'on' : ''}`}
                onClick={() => store().setLane(lane.mediaId, { loop: !lane.loop })}
                aria-label={`Loop video ${i === 0 ? 'A' : 'B'} when it ends`}
                aria-pressed={lane.loop}
              >
                <Repeat size={15} />
              </button>
            </div>
          ))}
          <div className="tl-label music">
            <span className="lane-chip" style={{ background: 'var(--music)' }} aria-hidden>
              <Music2 size={13} />
            </span>
            {music && (
              <>
                <button
                  className={`mini-btn ${music.volume === 0 ? 'off' : ''}`}
                  onClick={() => store().updateMusic({ volume: music.volume === 0 ? 0.7 : 0 })}
                  aria-label={music.volume === 0 ? 'Unmute music' : 'Mute music'}
                  aria-pressed={music.volume === 0}
                >
                  {music.volume === 0 ? <VolumeX size={15} /> : <Volume2 size={15} />}
                </button>
                <button
                  className={`mini-btn ${music.loop ? 'on' : ''}`}
                  onClick={() => store().updateMusic({ loop: !music.loop })}
                  aria-label="Repeat the music until the collage ends"
                  aria-pressed={music.loop}
                >
                  <Repeat size={15} />
                </button>
              </>
            )}
          </div>
        </div>

        <div
          className="tl-area"
          ref={areaRef}
          onPointerDown={onAreaDown}
          onPointerMove={onMove}
          onPointerUp={onUp}
          onPointerCancel={onUp}
        >
          <div className="tl-ruler">
            {ticks.map((t) => (
              <span key={t} style={{ left: `${(t / view) * 100}%` }}>
                {t}s
              </span>
            ))}
          </div>
          {lanes.map((lane, i) => {
            const media = items.find((m) => m.id === lane.mediaId)
            return (
              <div className="tl-lane" key={lane.mediaId} style={{ ['--lane' as string]: LANE_COLORS[i % 2] }}>
                {lane.clips.map((clip) => (
                  <div
                    key={clip.id}
                    className={`clip ${selectedClip === clip.id ? 'sel' : ''}`}
                    style={{
                      left: `${(clip.start / view) * 100}%`,
                      width: `${(clipLength(clip) / view) * 100}%`,
                      backgroundImage: media ? `url(${media.thumb})` : undefined,
                    }}
                    onPointerDown={(e) => onClipDown(e, 'move', lane.mediaId, clip)}
                  >
                    <span
                      className="handle l"
                      onPointerDown={(e) => onClipDown(e, 'left', lane.mediaId, clip)}
                      aria-label="Trim start"
                    />
                    <span className="clip-label">{formatTime(clipLength(clip))}</span>
                    <span
                      className="handle r"
                      onPointerDown={(e) => onClipDown(e, 'right', lane.mediaId, clip)}
                      aria-label="Trim end"
                    />
                  </div>
                ))}
              </div>
            )
          })}
          <div className="tl-lane music" style={{ ['--lane' as string]: 'var(--music)' }}>
            {!music ? (
              <button
                className="add-ribbon"
                onPointerDown={(e) => e.stopPropagation()}
                onClick={() => musicFile.current?.click()}
              >
                <Plus size={16} /> Add music
              </button>
            ) : (
              <>
                {music.loop && musicEnd(music, dur) > music.start + (music.out - music.in) && (
                  <div
                    className="ghost"
                    style={{
                      left: `${((music.start + (music.out - music.in)) / view) * 100}%`,
                      width: `${((musicEnd(music, dur) - (music.start + (music.out - music.in))) / view) * 100}%`,
                    }}
                  />
                )}
                <div
                  className={`clip music ${selectedClip === MUSIC_CLIP_ID ? 'sel' : ''}`}
                  style={{
                    left: `${(music.start / view) * 100}%`,
                    width: `${((music.out - music.in) / view) * 100}%`,
                  }}
                  onPointerDown={(e) => onClipDown(e, 'move', MUSIC_LANE, musicAsClip(music))}
                >
                  <span
                    className="handle l"
                    onPointerDown={(e) => onClipDown(e, 'left', MUSIC_LANE, musicAsClip(music))}
                    aria-label="Trim music start"
                  />
                  <span className="clip-label music-label">{music.name}</span>
                  <span
                    className="handle r"
                    onPointerDown={(e) => onClipDown(e, 'right', MUSIC_LANE, musicAsClip(music))}
                    aria-label="Trim music end"
                  />
                </div>
              </>
            )}
          </div>
          <div className="playhead" style={{ left: phLeft }} />
        </div>
      </div>
      <input
        ref={musicFile}
        type="file"
        accept="audio/*,.mp3,.m4a,.aac,.wav"
        hidden
        onChange={(e) => {
          const f = e.target.files?.[0]
          e.target.value = ''
          if (f) void store().setMusic(f)
        }}
      />
    </section>
  )
}
