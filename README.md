# CollageMagik

Make Instagram Story collages that mix photos and **videos that play inside the collage**. Runs entirely in the
browser: there is no backend, nothing is uploaded, and nothing is saved. A refresh clears the project.

Built mobile-first (phone layout, installable as a home-screen app, share sheet on export). The same page works on
desktop with a side panel.

## Run it

```bash
npm install
npm run dev        # http://localhost:5173 (also on your phone via the Network URL)
npm test           # layout, geometry and timeline maths
npm run build      # static site in dist/
npm run lan        # build + serve over HTTPS for phones on the same Wi-Fi (see below)
```

### Try it on your phone (same Wi-Fi)

`npm run lan` prints a `Network: https://192.168.x.x:5180/` address. Open it on the phone. The certificate is
self-signed, so the browser shows a warning once: tap Advanced, then continue (Safari: Show Details, then visit
this website). HTTPS is required because video encoding, the share sheet and wake lock only work on secure pages.

Deploy `dist/` to any static host (Vercel, Netlify, Cloudflare Pages, GitHub Pages). Serve over HTTPS: phones only
allow the share sheet, wake lock and install prompt on secure origins. No special headers are needed.

## What it does

- Up to **9 cells**: any mix of photos plus at most **2 videos**.
- **35 basic layouts** for 1 to 9 cells, plus gap, corner radius, background colour and Story / Post (4:5) / Square.
- Tap a cell to select it; drag to move the picture, pinch (or scroll wheel) to zoom; Replace, Swap, Remove, Reset.
- **Timeline** with one lane per video: drag the ends to trim, drag a clip to delay its start, Split at the playhead,
  Delete, Loop, mute. The collage lasts as long as the longest clip, up to 60 s (Instagram's Story limit).
- **Background music** on its own ribbon under the videos on the timeline: tap *Add music*, pick your own audio file
  (MP3, M4A, WAV), then drag the ribbon to move it, drag its ends to trim the song, toggle repeat and mute on the
  ribbon, and set volume and fade out in the Audio tab. Needs at least one video in the collage.
- **Export** MP4 (H.264 + AAC, 30 fps max) at 1080×1920, or 2160×3840 where the device can encode it; PNG still.
  Share button opens the phone's share sheet.

## Export quality

The preview uses light copies so phones stay smooth. The **export re-reads your original files**: photos are decoded
straight to the size each cell needs (never upscaled), video frames are decoded at full size, and the result is
encoded at about 16 Mbps for 1080×1920. A cell can't be sharper than its own pixels, and Instagram plays Stories at
1080 px wide, so standard export is as sharp as Instagram can show it.

## How it's built

| Folder | What |
|---|---|
| `src/layouts.ts` | Layout data (cell rectangles as fractions) |
| `src/geometry.ts` | Cell pixel rectangles, cover / zoom / pan maths, formats |
| `src/timeline.ts` | Clips, lanes, trim / split / move, what each video shows at time *t* |
| `src/render.ts` | One `drawCollage` function used by both preview and export |
| `src/store.ts` | In-memory state (Zustand) |
| `src/media/` | Import and probing, preview copies, keeping hidden `<video>` elements in step with the timeline |
| `src/export/` | Full-quality frame renderer, audio mix, MP4 writer ([Mediabunny](https://mediabunny.dev), MPL-2.0, WebCodecs) |
| `src/ui/` | Stage (gestures), Timeline, panels, export dialog |

## Browser support

iOS Safari 16.4+ and Chrome on Android (WebCodecs is required for export). Desktop Chrome, Edge and Safari work too.

## iPhone files (HEIC, HEVC .mov, MP3 / AAC)

- **HEIC photos**: read by the browser when it can (Safari does). Otherwise the app converts them to a very
  high quality JPEG (q 0.95) with a WebAssembly converter ([heic-to](https://github.com/hoppergee/heic-to),
  LGPL-3.0, libheif) that is only downloaded the first time a HEIC photo needs it.
- **iPhone .mov (HEVC / H.264)**: preview always works through the browser's player. For export, if WebCodecs
  can't decode the video (or fails part-way) the app reads frames through the browser's player instead
  ("compatibility mode": slower, same picture).
- **Sound on Safari before iOS 26** (no WebCodecs audio): video and MP3/M4A sound is decoded with Web Audio
  (whole file read into memory, files over 250 MB are skipped with a message) and AAC is encoded with a bundled
  WebAssembly encoder ([@mediabunny/aac-encoder](https://www.npmjs.com/package/@mediabunny/aac-encoder), MPL-2.0),
  loaded only when the browser has none.
- **MPEG-1/2 (.mpg / .mpeg) video** can't be played by phone browsers. The app says so and asks for MP4 (H.264).

## Known limits

- iPhone: Safari's photo picker can convert or shrink videos when you choose them; the volume slider only mutes
  (iOS keeps media volume at full).
- iPhone HEVC / HDR clips can fail to decode in some desktop browsers; the app names the file that failed.
- Export runs in the foreground: keep the screen open until it finishes (the app asks the phone to stay awake).
- There is no real-time `MediaRecorder` fallback for browsers without WebCodecs yet; they get a clear message.
- Music is your own file only (no built-in library, so there are no copyright issues to manage), and it needs a
  video in the collage. Instagram's own music library can't be used from a web page.
- Not built yet: text and stickers, entrance animations, filters, undo, drag-to-swap by long-press.
