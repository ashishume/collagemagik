/**
 * Photo decoding that works on every browser: the browser's own decoder first (Safari reads HEIC natively), then
 * an <img> element, and for HEIC on browsers that cannot read it (Chrome, Firefox) a WebAssembly converter that is
 * only downloaded when needed.
 */

const HEIC_BRANDS = new Set(['heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'hevm', 'hevs', 'mif1', 'msf1'])

export async function looksLikeHeic(file: File): Promise<boolean> {
  if (/image\/hei[cf]/i.test(file.type) || /\.hei[cf]$/i.test(file.name)) return true
  try {
    const b = new Uint8Array(await file.slice(0, 16).arrayBuffer())
    const box = String.fromCharCode(...b.slice(4, 8))
    const brand = String.fromCharCode(...b.slice(8, 12))
    return box === 'ftyp' && HEIC_BRANDS.has(brand)
  } catch {
    return false
  }
}

/** Decodes a photo. With `size`, asks the decoder for exactly that many pixels (never more than the original). */
export async function decodePhoto(file: File, size?: { w: number; h: number }): Promise<ImageBitmap> {
  const opts: ImageBitmapOptions | undefined = size
    ? { resizeWidth: size.w, resizeHeight: size.h, resizeQuality: 'high' }
    : undefined
  try {
    return await createImageBitmap(file, opts)
  } catch {
    // fall through to the <img> decoder
  }
  const url = URL.createObjectURL(file)
  try {
    const img = new Image()
    img.decoding = 'async'
    img.src = url
    await img.decode()
    return await createImageBitmap(img, opts)
  } finally {
    URL.revokeObjectURL(url)
  }
}

/** HEIC to a very high quality JPEG (q 0.95). Loads the converter on first use (about 3 MB, cached afterwards). */
export async function convertHeicToJpeg(file: File): Promise<File> {
  const { heicTo } = await import('heic-to')
  const blob = await heicTo({ blob: file, type: 'image/jpeg', quality: 0.95 })
  return new File([blob], file.name.replace(/\.[^.]+$/, '') + '.jpg', { type: 'image/jpeg' })
}
