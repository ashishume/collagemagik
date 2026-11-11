import { useCallback, useEffect, useRef, useState } from 'react'
import { Download, Upload } from 'lucide-react'
import { FORMATS } from './geometry'
import { useStore } from './store'
import { Stage } from './ui/Stage'
import { Timeline } from './ui/Timeline'
import { Panel, TabBar } from './ui/Panels'
import { ExportDialog } from './ui/ExportDialog'
import { CropEditor } from './ui/CropEditor'

/** Safari picks HEIC photos for "image/*" itself, and listing .heic there can make it re-encode. Other browsers need it listed. */
const isAppleBrowser = /iPhone|iPad|iPod/.test(navigator.userAgent) || /^((?!chrome|chromium|android|edg|firefox).)*safari/i.test(navigator.userAgent)
const ACCEPT = isAppleBrowser ? 'image/*,video/*' : 'image/*,video/*,.heic,.heif,.mov'

export default function App() {
  const fileRef = useRef<HTMLInputElement>(null)
  const targetCell = useRef<number | undefined>(undefined)
  const [dragOver, setDragOver] = useState(false)

  const itemsCount = useStore((s) => s.items.length)
  const format = useStore((s) => s.project.format)
  const toast = useStore((s) => s.toast)
  const importing = useStore((s) => s.importing)
  const exportOpen = useStore((s) => s.exportOpen)
  const cropOpen = useStore((s) => s.cropCell !== null)

  const pick = useCallback((cell?: number) => {
    targetCell.current = cell
    fileRef.current?.click()
  }, [])

  const onFiles = (files: FileList | File[] | null) => {
    if (!files || files.length === 0) return
    const list = Array.from(files)
    const cell = targetCell.current
    targetCell.current = undefined
    void useStore.getState().addFiles(list, cell)
  }

  // Drag and drop (desktop).
  useEffect(() => {
    const over = (e: DragEvent) => {
      if (e.dataTransfer?.types.includes('Files')) {
        e.preventDefault()
        setDragOver(true)
      }
    }
    const leave = (e: DragEvent) => {
      if (e.relatedTarget === null) setDragOver(false)
    }
    const drop = (e: DragEvent) => {
      e.preventDefault()
      setDragOver(false)
      onFiles(e.dataTransfer?.files ?? null)
    }
    window.addEventListener('dragover', over)
    window.addEventListener('dragleave', leave)
    window.addEventListener('drop', drop)
    return () => {
      window.removeEventListener('dragover', over)
      window.removeEventListener('dragleave', leave)
      window.removeEventListener('drop', drop)
    }
  }, [])

  return (
    <div className="app">
      <header className="topbar">
        <img src="/icon-192.png" alt="" width={26} height={26} className="logo" />
        <h1>CollageMagik</h1>
        <span className="fmt">{FORMATS[format].short}</span>
        <button className="btn primary small" onClick={() => useStore.getState().setExportOpen(true)}>
          <Download size={16} /> Export
        </button>
      </header>

      <main className="stage-area">
        <Stage onPickForCell={pick} />
        {itemsCount === 0 && !importing && (
          <div className="empty-cta">
            <div>
              <h2>Make a collage that moves</h2>
              <p>Mix photos with up to 2 videos in one Story.</p>
              <button className="btn primary" onClick={() => pick()}>
                <Upload size={18} /> Add photos or videos
              </button>
            </div>
          </div>
        )}
        {importing && <div className="busy">Adding…</div>}
      </main>

      <Timeline />

      <div className="side">
        <Panel onAdd={() => pick()} onPickCell={(c) => pick(c)} />
        <TabBar />
      </div>

      <input
        ref={fileRef}
        type="file"
        accept={ACCEPT}
        multiple
        hidden
        onChange={(e) => {
          onFiles(e.target.files)
          e.target.value = ''
        }}
      />

      {dragOver && <div className="drop">Drop to add</div>}
      {toast && (
        <div className="toast" role="status" key={toast.id}>
          {toast.text}
        </div>
      )}
      {exportOpen && <ExportDialog />}
      {cropOpen && <CropEditor />}
    </div>
  )
}
