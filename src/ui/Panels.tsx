import {
  ArrowLeftRight,
  Check,
  Crop,
  Eye,
  EyeOff,
  FlipHorizontal2,
  Film,
  ImagePlus,
  LayoutGrid,
  Music2,
  Palette,
  Plus,
  Repeat,
  RotateCcw,
  RotateCw,
  Shuffle,
  SlidersHorizontal,
  Trash2,
  Volume2,
  VolumeX,
  X,
} from 'lucide-react'
import { FORMATS } from '../geometry'
import { MAX_CELLS, MAX_VIDEOS, layoutsFor } from '../layouts'
import { BACKGROUNDS, useStore, type Tab } from '../store'
import { formatTime } from '../timeline'
import type { FormatId, Layout } from '../types'

export const TABS: { id: Tab; label: string; icon: typeof ImagePlus }[] = [
  { id: 'media', label: 'Media', icon: ImagePlus },
  { id: 'layout', label: 'Layout', icon: LayoutGrid },
  { id: 'style', label: 'Style', icon: Palette },
  { id: 'audio', label: 'Audio', icon: Volume2 },
  { id: 'picture', label: 'Picture', icon: SlidersHorizontal },
]

export function TabBar() {
  const tab = useStore((s) => s.tab)
  const setTab = useStore((s) => s.setTab)
  return (
    <nav className="tabbar" aria-label="Editor sections">
      {TABS.map(({ id, label, icon: Icon }) => (
        <button key={id} className={tab === id ? 'on' : ''} onClick={() => setTab(id)} aria-current={tab === id}>
          <Icon size={20} />
          <span>{label}</span>
        </button>
      ))}
    </nav>
  )
}

function LayoutThumb({ layout, on, onClick }: { layout: Layout; on: boolean; onClick: () => void }) {
  return (
    <button className={`lay ${on ? 'on' : ''}`} onClick={onClick} aria-label={layout.name} aria-pressed={on}>
      <span className="mini">
        {layout.rects.map(([x, y, w, h], i) => (
          <i
            key={i}
            style={{
              left: `${x * 100 + 2}%`,
              top: `${y * 100 + 1.5}%`,
              width: `${w * 100 - 4}%`,
              height: `${h * 100 - 3}%`,
            }}
          />
        ))}
      </span>
      <span className="lay-name">{layout.name}</span>
    </button>
  )
}

function MediaPanel({ onAdd }: { onAdd: () => void }) {
  const items = useStore((s) => s.items)
  const project = useStore((s) => s.project)
  const importing = useStore((s) => s.importing)
  const st = useStore.getState
  const placed = new Set(project.cells.map((c) => c.mediaId))
  const videoCount = items.filter((i) => i.kind === 'video').length
  return (
    <div className="panel-body">
      <p className="cap">
        {items.length} of {MAX_CELLS} · {videoCount} of {MAX_VIDEOS} videos
      </p>
      <div className="strip">
        {items.map((m) => (
          <div className="thumb" key={m.id}>
            <button
              className={placed.has(m.id) ? 'in-use' : ''}
              onClick={() => st().placeMedia(m.id, st().selectedCell ?? undefined)}
              aria-label={`${m.kind === 'video' ? 'Video' : 'Photo'} ${m.name}. ${placed.has(m.id) ? 'In the collage' : 'Tap to add to the selected cell'}`}
            >
              <img src={m.thumb} alt="" />
              {m.kind === 'video' && (
                <span className="badge">
                  <Film size={11} /> {formatTime(m.duration)}
                </span>
              )}
              {!placed.has(m.id) && <span className="badge dim">Not used</span>}
            </button>
            <button className="x" onClick={() => st().removeMedia(m.id)} aria-label={`Remove ${m.name}`}>
              <Trash2 size={12} />
            </button>
          </div>
        ))}
        <button className="thumb add" onClick={onAdd} disabled={importing} aria-label="Add photos or videos">
          <Plus size={22} />
          <span>{importing ? 'Adding…' : 'Add'}</span>
        </button>
      </div>
    </div>
  )
}

function LayoutPanel() {
  const project = useStore((s) => s.project)
  const st = useStore.getState
  const options = layoutsFor(project.cellCount)
  return (
    <div className="panel-body">
      <div className="count-row" role="group" aria-label="Number of cells">
        <span className="cap">Cells</span>
        {Array.from({ length: MAX_CELLS }, (_, i) => i + 1).map((n) => (
          <button
            key={n}
            className={`num ${project.cellCount === n ? 'on' : ''}`}
            onClick={() => st().setCellCount(n)}
            aria-pressed={project.cellCount === n}
          >
            {n}
          </button>
        ))}
        <button className="chip-btn" onClick={() => st().shuffleLayout()} aria-label="Try another layout">
          <Shuffle size={16} />
        </button>
      </div>
      <div className="strip">
        {options.map((l) => (
          <LayoutThumb key={l.id} layout={l} on={l.id === project.layoutId} onClick={() => st().setLayout(l.id)} />
        ))}
      </div>
    </div>
  )
}

function StylePanel() {
  const project = useStore((s) => s.project)
  const st = useStore.getState
  return (
    <div className="panel-body rows">
      <div className="seg" role="group" aria-label="Format">
        {(Object.keys(FORMATS) as FormatId[]).map((f) => (
          <button key={f} className={project.format === f ? 'on' : ''} onClick={() => st().setFormat(f)} aria-pressed={project.format === f}>
            {FORMATS[f].label}
          </button>
        ))}
      </div>
      <label className="row">
        <span>Gap</span>
        <input type="range" min={0} max={48} value={project.gap} onChange={(e) => st().setStyle({ gap: +e.target.value })} />
      </label>
      <label className="row">
        <span>Corners</span>
        <input type="range" min={0} max={80} value={project.radius} onChange={(e) => st().setStyle({ radius: +e.target.value })} />
      </label>
      <div className="row">
        <span>Colour</span>
        <div className="swatches">
          {BACKGROUNDS.map((c) => (
            <button
              key={c}
              className={project.bg === c ? 'on' : ''}
              style={{ background: c }}
              onClick={() => st().setStyle({ bg: c })}
              aria-label={`Background ${c}`}
              aria-pressed={project.bg === c}
            />
          ))}
        </div>
      </div>
      {project.format === 'story' && (
        <button className="chip-btn wide" onClick={() => st().setStyle({ safeZone: !project.safeZone })} aria-pressed={project.safeZone}>
          {project.safeZone ? <EyeOff size={16} /> : <Eye size={16} />}
          {project.safeZone ? 'Hide' : 'Show'} the area Instagram covers
        </button>
      )}
    </div>
  )
}

function AudioPanel() {
  const project = useStore((s) => s.project)
  const items = useStore((s) => s.items)
  const st = useStore.getState
  const placed = new Set(project.cells.slice(0, project.cellCount).map((c) => c.mediaId))
  const lanes = project.lanes.filter((l) => placed.has(l.mediaId))
  const music = project.music
  if (lanes.length === 0) {
    return (
      <div className="panel-body">
        <p className="cap">Add a video to control its sound and add background music on the timeline.</p>
      </div>
    )
  }
  return (
    <div className="panel-body rows">
      {lanes.map((l, i) => {
        const m = items.find((x) => x.id === l.mediaId)
        return (
          <div className="row" key={l.mediaId}>
            <span className="lane-chip" style={{ ['--lane' as string]: i === 0 ? 'var(--video-a)' : 'var(--video-b)' }}>
              {i === 0 ? 'A' : 'B'}
            </span>
            {m?.hasAudio ? (
              <>
                {l.volume === 0 ? <VolumeX size={16} /> : <Volume2 size={16} />}
                <input
                  type="range"
                  min={0}
                  max={100}
                  value={Math.round(l.volume * 100)}
                  onChange={(e) => st().setLane(l.mediaId, { volume: +e.target.value / 100 })}
                  aria-label={`Volume of video ${i === 0 ? 'A' : 'B'}`}
                />
              </>
            ) : (
              <span className="cap grow">No sound in this video</span>
            )}
            <button
              className={`chip-btn ${l.loop ? 'on' : ''}`}
              onClick={() => st().setLane(l.mediaId, { loop: !l.loop })}
              aria-pressed={l.loop}
            >
              <Repeat size={15} /> Loop
            </button>
          </div>
        )
      })}

      {music && (
        <>
          <div className="row">
            <Music2 size={18} className="music-ic" />
            <span className="music-name" title={music.name}>
              {music.name}
            </span>
          </div>
          <div className="row">
            <span>Volume</span>
            <input
              type="range"
              min={0}
              max={100}
              value={Math.round(music.volume * 100)}
              onChange={(e) => st().updateMusic({ volume: +e.target.value / 100 })}
              aria-label="Music volume"
            />
          </div>
          <button
            className={`chip-btn wide ${music.fadeOut ? 'on' : ''}`}
            onClick={() => st().updateMusic({ fadeOut: !music.fadeOut })}
            aria-pressed={music.fadeOut}
          >
            Fade out at the end
          </button>
        </>
      )}
      {!music && <p className="cap">Add background music from the Music row on the timeline.</p>}
    </div>
  )
}

/** Options for the picture or video selected in the preview: replace, swap, remove, rotate, flip, crop, zoom. */
function PicturePanel({ onPick }: { onPick: (cell: number) => void }) {
  const selected = useStore((s) => s.selectedCell)
  const swapFrom = useStore((s) => s.swapFrom)
  const cell = useStore((s) => (s.selectedCell !== null ? s.project.cells[s.selectedCell] : null))
  const st = useStore.getState

  if (selected === null || !cell) {
    return (
      <div className="panel-body">
        <p className="cap">Tap a picture in the preview to change it here: replace, swap, rotate, flip, crop and zoom.</p>
      </div>
    )
  }
  const filled = !!cell.mediaId

  if (swapFrom !== null) {
    return (
      <div className="panel-body picture">
        <div className="pic-row">
          <span className="swap-hint">Tap another cell in the preview to swap with it.</span>
          <button className="chip-btn" onClick={() => st().setSwapFrom(null)}>
            <X size={16} /> Cancel
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="panel-body picture">
      <div className="pic-row">
        <button className="chip-btn" onClick={() => onPick(selected)}>
          <ImagePlus size={16} /> {filled ? 'Replace' : 'Add photo or video'}
        </button>
        {filled && (
          <>
            <button className="chip-btn" onClick={() => st().setSwapFrom(selected)}>
              <ArrowLeftRight size={16} /> Swap
            </button>
            <button className="chip-btn" onClick={() => st().clearCell(selected)}>
              <X size={16} /> Remove
            </button>
          </>
        )}
      </div>
      {filled && (
        <>
          <div className="pic-row">
            <button className="chip-btn" onClick={() => st().rotateCell(selected)} aria-label="Rotate a quarter turn">
              <RotateCw size={16} /> Rotate
            </button>
            <button className="chip-btn" onClick={() => st().flipCell(selected)} aria-pressed={cell.flip}>
              <FlipHorizontal2 size={16} /> Flip
            </button>
            <button className="chip-btn" onClick={() => st().setCropCell(selected)}>
              <Crop size={16} /> Crop
            </button>
          </div>
          <div className="pic-row">
            <label className="zoom">
              <span>Zoom</span>
              <input
                type="range"
                min={1}
                max={4}
                step={0.01}
                value={cell.zoom}
                onChange={(e) => st().setCellView(selected, { zoom: +e.target.value })}
                aria-label="Zoom"
              />
            </label>
            <button
              className="chip-btn"
              onClick={() => st().resetCell(selected)}
              aria-label="Reset zoom, position, rotation and flip"
            >
              <RotateCcw size={16} />
            </button>
          </div>
        </>
      )}
      <button className="chip-btn wide done" onClick={() => st().selectCell(null)}>
        <Check size={16} /> Done
      </button>
    </div>
  )
}

export function Panel({ onAdd, onPickCell }: { onAdd: () => void; onPickCell: (cell: number) => void }) {
  const tab = useStore((s) => s.tab)
  return (
    <section className="panel" aria-label="Editor panel">
      {tab === 'media' && <MediaPanel onAdd={onAdd} />}
      {tab === 'layout' && <LayoutPanel />}
      {tab === 'style' && <StylePanel />}
      {tab === 'audio' && <AudioPanel />}
      {tab === 'picture' && <PicturePanel onPick={onPickCell} />}
    </section>
  )
}
