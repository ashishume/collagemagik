export const filenameFor = (ext: 'mp4' | 'png') => {
  const d = new Date()
  const p = (n: number) => n.toString().padStart(2, '0')
  return `collagemagik-${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}.${ext}`
}

export function canShareFile(file: File): boolean {
  try {
    return typeof navigator.canShare === 'function' && navigator.canShare({ files: [file] })
  } catch {
    return false
  }
}

/** Opens the phone's share sheet (Instagram, Photos, Messages, ...). Returns false if the user dismissed it. */
export async function shareFile(file: File): Promise<boolean> {
  try {
    await navigator.share({ files: [file] })
    return true
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') return false
    throw e
  }
}

export function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 60_000)
}
