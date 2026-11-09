import { useEffect, useRef, useState } from 'react'
import { CircleCheck, Download, Image as ImageIcon, Share2, Smartphone, X } from 'lucide-react'
import { useStore } from '../store'
import { totalDuration, formatTime, placedLanes } from '../timeline'
import {
  ExportError,
  canExportHighQuality,
  exportMp4,
  exportPng,
  exportSize,
  type ExportInfo,
  type Quality,
} from '../export/exportVideo'
import { canShareFile, downloadBlob, filenameFor, shareFile } from '../export/share'

type Phase =
  | { name: 'idle' }
  | { name: 'running'; progress: number; label: string }
  | { name: 'done'; blob: Blob; url: string; info: ExportInfo }
  | { name: 'error'; message: string }

const mb = (bytes: number) => `${(bytes / 1_000_000).toFixed(bytes < 10_000_000 ? 1 : 0)} MB`

export function ExportDialog() {
  const project = useStore((s) => s.project)
  const items = useStore((s) => s.items)
  const playhead = useStore((s) => s.playhead)
  const close = useStore((s) => s.setExportOpen)
  const notify = useStore((s) => s.notify)

  const [phase, setPhase] = useState<Phase>({ name: 'idle' })
  const [quality, setQuality] = useState<Quality>('standard')
  const [highOk, setHighOk] = useState(false)
  const abort = useRef<AbortController | null>(null)
  const wake = useRef<WakeLockSentinel | null>(null)

  const hasVideo = placedLanes(project).length > 0
  const dur = totalDuration(project)
  const size = exportSize(project, quality)

  useEffect(() => {
    void canExportHighQuality(project).then(setHighOk)
  }, [project.format]) // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(
    () => () => {
      abort.current?.abort()
      void wake.current?.release().catch(() => {})
    },
    [],
  )

  useEffect(() => {
    if (phase.name === 'done') return () => URL.revokeObjectURL(phase.url)
  }, [phase])

  const keepAwake = async () => {
    try {
      wake.current = (await navigator.wakeLock?.request('screen')) ?? null
    } catch {
      // not available: the screen may dim, the export keeps going while the page is visible
    }
  }

  const runVideo = async () => {
    const ctl = new AbortController()
    abort.current = ctl
    setPhase({ name: 'running', progress: 0, label: 'Preparing' })
    await keepAwake()
    try {
      const { blob, info } = await exportMp4(project, items, {
        quality,
        signal: ctl.signal,
        onProgress: (progress, label) => setPhase({ name: 'running', progress, label }),
      })
      setPhase({ name: 'done', blob, info, url: URL.createObjectURL(blob) })
    } catch (e) {
      if (e instanceof DOMException && e.name === 'AbortError') setPhase({ name: 'idle' })
      else {
        console.error(e)
        setPhase({
          name: 'error',
          message: e instanceof ExportError ? e.message : "Something went wrong while exporting. Try again, or try Standard quality.",
        })
      }
    } finally {
      await wake.current?.release().catch(() => {})
      wake.current = null
    }
  }

  const runPng = async () => {
    try {
      const blob = await exportPng(project, items, hasVideo ? playhead : 0, quality)
      const name = filenameFor('png')
      const file = new File([blob], name, { type: 'image/png' })
      if (canShareFile(file)) {
        const shared = await shareFile(file)
        if (!shared) return
      } else downloadBlob(blob, name)
    } catch (e) {
      console.error(e)
      notify("Couldn't create the image. Try Standard quality.")
    }
  }

  const done = phase.name === 'done' ? phase : null
  const file = done ? new File([done.blob], filenameFor('mp4'), { type: 'video/mp4' }) : null

  return (
    <div className="modal-back" role="dialog" aria-modal="true" aria-label="Export">
      <div className="modal">
        <header>
          <h2>Export</h2>
          <button
            className="icon-btn"
            onClick={() => {
              abort.current?.abort()
              close(false)
            }}
            aria-label="Close"
          >
            <X size={20} />
          </button>
        </header>

        {phase.name === 'idle' && (
          <>
            <div className="seg" role="group" aria-label="Quality">
              <button className={quality === 'standard' ? 'on' : ''} onClick={() => setQuality('standard')}>
                Standard
                <small>{exportSize(project, 'standard').width}×{exportSize(project, 'standard').height}</small>
              </button>
              <button className={quality === 'high' ? 'on' : ''} onClick={() => (highOk ? setQuality('high') : notify("This device can't encode the high-resolution size."))} aria-disabled={!highOk}>
                High-res
                <small>{highOk ? `${exportSize(project, 'high').width}×${exportSize(project, 'high').height}` : 'Not on this device'}</small>
              </button>
            </div>
            <p className="note">
              Photos and videos are read from your original files, never from a shrunk copy. Standard is the size Instagram
              plays at, at a high bitrate so it stays sharp after upload.
            </p>
            <ul className="facts">
              <li>
                {size.width}×{size.height} · {hasVideo ? `${formatTime(dur)} long` : 'still image'}
              </li>
              {hasVideo && <li>MP4 (H.264 + AAC), up to 30 fps</li>}
            </ul>
            {hasVideo && (
              <button className="btn primary" onClick={() => void runVideo()}>
                <Download size={18} /> Export video
              </button>
            )}
            <button className={`btn ${hasVideo ? '' : 'primary'}`} onClick={() => void runPng()}>
              <ImageIcon size={18} /> {hasVideo ? 'Save this frame as PNG' : 'Save image (PNG)'}
            </button>
          </>
        )}

        {phase.name === 'running' && (
          <>
            <div className="progress-head">
              <strong>{phase.label}</strong>
              <span>{Math.round(phase.progress * 100)}%</span>
            </div>
            <div className="bar" role="progressbar" aria-valuenow={Math.round(phase.progress * 100)} aria-valuemin={0} aria-valuemax={100}>
              <div style={{ width: `${phase.progress * 100}%` }} />
            </div>
            <p className="note">
              <Smartphone size={14} /> Keep this screen open until it's done. Your phone stays awake while it renders.
            </p>
            <button className="btn" onClick={() => abort.current?.abort()}>
              Cancel
            </button>
          </>
        )}

        {done && file && (
          <>
            <p className="ok">
              <CircleCheck size={20} /> Your video is ready
            </p>
            <video className="result" src={done.url} controls playsInline />
            <p className="note">
              {done.info.width}×{done.info.height} · {done.info.fps} fps · {(done.info.videoBitrate / 1_000_000).toFixed(0)} Mbps ·{' '}
              {formatTime(done.info.duration)} · {mb(done.info.bytes)}
              {done.info.audio === 'none' ? ' · no sound' : ''}
            </p>
            {done.info.warnings.map((w) => (
              <p className="note warn" key={w}>
                {w}
              </p>
            ))}
            {canShareFile(file) && (
              <button
                className="btn primary"
                onClick={() => void shareFile(file).catch(() => notify("Couldn't open the share sheet. Use Save video."))}
              >
                <Share2 size={18} /> Share to Instagram
              </button>
            )}
            <button className={`btn ${canShareFile(file) ? '' : 'primary'}`} onClick={() => downloadBlob(done.blob, file.name)}>
              <Download size={18} /> Save video
            </button>
            {canShareFile(file) && (
              <p className="note small">Share opens your phone's share sheet, where you can pick Instagram or save to Photos.</p>
            )}
          </>
        )}

        {phase.name === 'error' && (
          <>
            <p className="err">{phase.message}</p>
            <button className="btn" onClick={() => setPhase({ name: 'idle' })}>
              Back
            </button>
          </>
        )}
      </div>
    </div>
  )
}
