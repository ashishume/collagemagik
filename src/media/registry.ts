/**
 * Live, non-React objects for imported media. Everything stays in memory in this tab: nothing is uploaded or saved.
 * Photos keep a preview-sized copy here; the export decodes the original file again at full quality.
 */
export const videos = new Map<string, HTMLVideoElement>()
export const photos = new Map<string, ImageBitmap>()
/** The single background-music element (hidden, not in the page) for the preview. */
export const music: { el: HTMLAudioElement | null; url: string | null } = { el: null, url: null }

export function disposeMusic() {
  if (music.el) {
    music.el.pause()
    music.el.removeAttribute('src')
    music.el.load()
  }
  if (music.url) URL.revokeObjectURL(music.url)
  music.el = null
  music.url = null
}

const urls = new Map<string, string[]>()

export function remember(id: string, url: string) {
  urls.set(id, [...(urls.get(id) ?? []), url])
}

export function disposeMedia(id: string) {
  const v = videos.get(id)
  if (v) {
    v.pause()
    v.removeAttribute('src')
    v.load()
    v.remove()
    videos.delete(id)
  }
  photos.get(id)?.close()
  photos.delete(id)
  for (const u of urls.get(id) ?? []) URL.revokeObjectURL(u)
  urls.delete(id)
}
