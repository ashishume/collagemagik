# GPU video export — implementation plan (handover)

Audience: an AI coding agent working in this repo. Read `CLAUDE.md` (repo root) and `ios/README.md` first; their
rules apply (work only in `ios/`, no test target, preview and export must look identical, keep README/CLAUDE.md
current, never add SDKs).

## 1. Goal

Make **video export** (MP4, HD and 4K, 30/60 fps, SDR and HDR) several times faster and lighter on memory by
composing each frame on the **GPU with Core Image (Metal)** instead of drawing it on the CPU with Core Graphics —
**without changing how exports look**.

Non-goals: the live preview (SwiftUI, already GPU), PNG export, carousel JPEG slides, draft thumbnails and template
cards (single images: keep the CPU renderer), audio, encoder settings, the export UI.

Success criteria (all required):

| # | Criterion |
|---|---|
| S1 | Every test case in §7 exports with the GPU engine, SSIM vs the CPU engine **≥ 0.985 overall and ≥ 0.96 on every frame** |
| S2 | 4K 60 fps export time of the 3-video Neon nights case is **≤ 40 %** of the CPU engine's (simulator numbers are fine for the ratio) |
| S3 | Peak memory during that export is **≤ 60 %** of the CPU engine's |
| S4 | HDR export (10-bit HEVC HLG) still works and stays HDR |
| S5 | If Metal/Core Image setup fails, export silently falls back to the CPU engine |
| S6 | `xcodebuild … build` succeeds with no new warnings in touched files |

## 2. How export works today (read these files)

- `ios/CollageMagik/CollageMagik/Export/Exporter.swift` — `CollageExporter.exportVideo(quality:hdr:fps:progress:)`.
  Per frame: allocates a `CVPixelBuffer` from the `AVAssetWriterInputPixelBufferAdaptor` pool, wraps it in a CG
  context (`CollageRenderer.makeContext`), calls `CollageRenderer.draw(ctx:W:H:snapshot:t:captionLayers:image:)`,
  appends. HDR: draws into a half-float canvas then `HDR.ci.render(…)` into a 10-bit HLG buffer.
  Also builds audio (`buildAudio`) — leave untouched.
- `Export/CollageRenderer.swift`
  - `CollageRenderer.draw` — the one renderer: `project.posed(at: t)` (motion designs), backdrop
    (`BackdropRenderer.draw`), cells in `project.cellDrawOrder` with `cellAlpha` (transparency layer when < 1),
    each cell via `drawPrint` (shadow, frame edge `frameOutline`, `FrameDecor.drawUnder`, clip `pictureClipPath`,
    fit bars `BackdropRenderer.drawFitBars`, photo look `PhotoLookRenderer.apply`, `drawMedia` placement,
    `FrameDecor.drawOver`), then photos on top (`project.overlays`, `overlayGeometry`), stickers
    (`StickerRenderer.drawAll`), captions (`CaptionLayers` stamped with per-scene alpha).
  - `drawMedia` uses `placeMedia(srcW:srcH:cell:view:)` from `Model/Geometry.swift` (cover/fit, zoom, pan, quarter
    rotation, flip, straighten). **Reuse this math exactly.**
  - `decodePhotos` — photos decoded once at the largest size any moment needs (`motionSamples`).
  - `LaneFrameFeeder` — reads one video lane in timeline order: `frame(at:) -> CGImage?` handles clips, trims, speed,
    loop, held first/last frames (`resolveLane` in `Model/Timeline.swift`). It currently converts every decoded
    `CVPixelBuffer` to a `CGImage` with `VTCreateCGImageFromCVPixelBuffer` (a full-size CPU copy).
  - `HDR` — colour spaces and the shared half-float `CIContext`.
- `Model/Motion.swift` — `Project.posed(at:)`, `cellAlpha(_:)`, `cellDrawOrder`, `captionAlpha(_:)`, `MotionPose`.
  Motion designs move/resize/fade cells and zoom/drift photos every frame.
- `Model/Frames.swift`, `Model/Backdrop.swift`, `Model/Stickers.swift`, `Model/Captions.swift`,
  `Model/Overlays.swift`, `Model/PhotoLook.swift` — the drawing code for the parts that do **not** change per frame.

Where the time goes now: per frame, the CPU copies every video frame into a `CGImage` and Core Graphics redraws the
whole canvas (backdrop, shadows with blur, frames, every photo resampled, captions stamp) — millions of pixels per
frame, 60×/s at 4K60.

## 3. Design (approach A: GPU composition, keep today's readers)

Keep the existing pipeline shape (readers → compose → `AVAssetWriter`). Replace only the per-frame compose step.

### 3.1 Principle: CPU draws pieces once, GPU places them every frame

Everything with detailed drawing (frame edges, torn/stamp outlines, tape, film holes, neon, date stamp, shadows,
fit bars, stickers, captions, backdrop) is drawn **by the existing Core Graphics code** into small images
("pieces"), cached, and reused. The GPU only transforms, clips, fades and stacks pieces and media each frame.
This is what keeps the output identical to the CPU engine.

### 3.2 Pieces per frame (bottom → top)

1. **Backdrop**: one canvas-size image from `BackdropRenderer.draw` (static for the whole export).
2. **Each cell**, in `cellDrawOrder`, skipped when `cellAlpha == 0`:
   - **under piece**: shadow + frame edge (`frameOutline` fill) + `FrameDecor.drawUnder` + fit bars, drawn with the
     existing code into a transparent image covering the print's bounding box **plus shadow margin**
     (shadow is offset `7*unit`, blur `22*unit` in `drawPrint` — pad ≥ `40*unit` on every side). Exclude tilt here.
   - **media**: video frame (`CIImage(cvPixelBuffer:)`) or photo (`CIImage(cgImage:)` of the look-applied image),
     transformed with the matrix equivalent to `drawMedia` (use `placeMedia`), then masked by the picture clip.
   - **clip mask**: `pictureClipPath(frame, rect:, radius:)` rendered once as an alpha mask image (or, for plain
     rectangles/rounded rectangles, crop + rounded mask) — cache by (size, frame, radius).
   - **over piece**: `FrameDecor.drawOver` (tape, mat line, date, neon) into the same bounding box.
   - Combine under → masked media → over into one cell image, then apply **tilt** (rotate about the print centre,
     `outer.tilt`) and **cell alpha** (`CIColorMatrix` alpha scale, or `CIImage.applyingFilter("CIColorMatrix",
     …inputAVector…)`), then composite over the canvas.
3. **Photos on top** (`project.overlays`): same as a cell but static → render each print once **fully on the CPU**
   with `drawPrint` into its bbox and place it (they never change during an export).
4. **Stickers**: one canvas-size static image via `StickerRenderer.drawAll`.
5. **Captions**: reuse `CaptionRenderer.layers(project:W:H:)` (`always` + per-scene layers); per frame composite the
   scene layers with their alpha exactly as `CollageRenderer.draw` does today.

### 3.3 Caching (what makes it fast)

- Cache key for a cell's under/over pieces: `(cellIndex, outer rect & picture rect rounded to 0.5 px, frame style,
  frame colour, frame width, radius, fit/fitBars, mediaId for fit-bar blur)`. **Exclude** zoom/pan (photo moves) and
  alpha — those are applied on the GPU.
- Still designs: every key is constant → each piece is drawn once per export.
- Motion designs: keys are constant while a scene is settled (cache hits); during a transition the cells that glide
  or resize get new keys every frame → their pieces are redrawn on the CPU **at their own bbox size only** (small),
  which is acceptable. Use an LRU of ~64 entries / ≤ 150 MB at 4K; evict on memory warning.
- Clip masks: cache by `(w, h, frame, radius)`.

### 3.4 Video frames without CPU copies

In `LaneFrameFeeder` add a parallel API `pixelBuffer(at t: Double) -> CVPixelBuffer?` with identical timing
semantics to `frame(at:)` (same restart/seek rules, holds, loops, speed). Keep the `CMSampleBuffer`/`CVPixelBuffer`
instead of converting. Reader output settings: add `kCVPixelBufferIOSurfacePropertiesKey: [:]` and
`kCVPixelBufferMetalCompatibilityKey: true`; keep the existing BT.709 conversion for SDR and the 10-bit format for
HDR. Held frames (`hold(at:)`) may stay `CGImage` (rare) — wrap with `CIImage(cgImage:)`.
Keep `frame(at:)` working: the CPU engine and PNG export still use it.

### 3.5 Rendering

- One `CIContext(mtlDevice: MTLCreateSystemDefaultDevice()!, options: …)` per export.
- **SDR**: to match Core Graphics blending (gamma-space, premultiplied sRGB), set
  `.workingColorSpace = CGColorSpace(name: CGColorSpace.sRGB)` and `.workingFormat = .RGBA8` (try `.RGBAh` if banding
  shows in gradients). Render into the writer pool's `CVPixelBuffer` with
  `context.render(image, to: pixelBuffer, bounds: canvasRect, colorSpace: sRGB)`.
- **HDR**: reuse `HDR.linearSpace` working space, `.RGBAh`, and render straight into the 10-bit pool buffer with
  colour space `HDR.hlgSpace`, then set the same three `CVBufferSetAttachment` tags as today. No half-float CPU canvas.
- **Coordinates**: the renderer and all geometry are top-left origin; Core Image is bottom-left. Build every piece
  with a single helper that converts a top-left `PxRect`/transform to CI space (`y' = H - y - h`, and flip the
  rotation sign). Get this right once; most bugs will be here.
- Premultiplied alpha everywhere (CG contexts from `makeContext` are premultiplied; `CIImage(cgImage:)` handles it).

### 3.6 Engine switch and fallback

- `enum ExportEngine { case cpu, gpu }`. `exportVideo` uses `.gpu` by default; Debug env `CM_EXPORT_ENGINE=cpu|gpu`
  overrides (add the row to the debug table in `CLAUDE.md`).
- If Metal device or `CIContext` creation fails, or the GPU composer throws before the first frame, fall back to the
  CPU path for the whole export (log `CM_EXPORT engine=cpu (fallback: …)`).
- Log at the end of every export (Debug): `CM_EXPORT engine=gpu w×h fps frames seconds peakMB` — peak memory via
  `task_vm_info.phys_footprint` sampled every 30 frames.

## 4. Files

| File | Change |
|---|---|
| `Export/GPUFrameComposer.swift` (new) | Pieces, caches, CI composition, render into pixel buffer (SDR + HDR) |
| `Export/CollageRenderer.swift` | `LaneFrameFeeder.pixelBuffer(at:)`; small refactor so `drawPrint`'s parts (under / clip / over) can be called separately **without changing CPU output** |
| `Export/Exporter.swift` | Engine switch, fallback, GPU frame loop, timing/memory log |
| `DebugHarness.swift` | Read `CM_EXPORT_ENGINE` (or read it in `Exporter`) |
| `ios/scripts/compare_export_engines.sh` (new) | The verification script in §7 |
| `CLAUDE.md`, `ios/README.md` | Document the GPU engine, the debug flag, the script |

Do not touch the preview, `Model/Motion.swift` semantics, templates, or the audio path.

## 5. Phases (commit at the end of each, on branch `gpu-export`)

0. **Baseline.** Before any change, write `compare_export_engines.sh` (§7) in "baseline only" mode and record CPU
   timings + peak memory for the matrix. Save results to `ios/docs/gpu-export-results.md`.
1. **Feeder pixel buffers** (§3.4). Prove timing parity: for a 3-video design, the timestamps chosen by
   `pixelBuffer(at:)` and `frame(at:)` must match for every frame (debug assert in a harness run).
2. **Still designs** (§3.2–3.3, §3.5 SDR): backdrop, cells (rect + rounded + circle/heart/arch clips, all frame
   styles, tilt, fit bars, filters, rotation/flip/straighten), overlays, stickers, captions. Pass S1 for the still
   cases.
3. **Motion designs**: per-frame `posed(at:)`, alpha, draw order, photo zoom/drift, piece cache during transitions,
   per-scene caption alpha. Pass S1 for all 12 motion templates.
4. **HDR** (§3.5 HDR). Pass S4 + S1 against the CPU HDR export.
5. **Optional speed-ups, only if S2 is not met**: (a) prefetch the next frame's video buffers on a second queue
   while the GPU composes the current one; (b) decode at drawn size (scale in the reader's video composition
   `renderSize`) for 4K sources shown small.
6. **Switch & docs**: default to GPU, fallback, logs, `CLAUDE.md`/README updates.
7. **Final report** (§8).

## 6. Pitfalls to check explicitly

- CI bottom-left vs top-left coordinates and rotation direction (tilt, straighten, quarter turns, flip).
- Shadow bleed: pad pieces enough or shadows get clipped at piece edges.
- Fit bars blur (`BackdropRenderer.blurredImage`) and "blur that follows the pictures" backdrop must come from the
  same cached functions as the CPU path.
- `PhotoLookRenderer.apply` caches full-size results with only a count limit — don't make memory worse; apply looks
  once per photo per export and keep the result in the composer, not in that cache.
- Videos: `item.width/height` are display size after `preferredTransform`; the reader output is already upright.
- 60 fps from 30 fps sources repeats frames — same as today (`halfFrame` rule in the feeder).
- Cell alpha must fade the **whole print** (shadow + frame + media) as one group, like the CPU transparency layer.
- Empty cells: draw the under/over pieces (frame) but no media, exactly like the CPU path.
- Keep `CollageRenderer.draw` output byte-for-byte unchanged by the refactor in phase 2 (verify with a CPU-vs-CPU
  export before/after the refactor: SSIM must be 1.0).

## 7. Verification (script + matrix)

`ios/scripts/compare_export_engines.sh` must, for each case: launch the simulator app with the debug harness,
export with `CM_EXPORT_ENGINE=cpu` and `=gpu` to two files, read the `CM_EXPORT` log line for time/peak memory,
compute SSIM with
`ffmpeg -i cpu.mp4 -i gpu.mp4 -lavfi "ssim=stats_file=ssim.txt" -f null -` (overall `All:` and per-frame minimum),
and append a row to `ios/docs/gpu-export-results.md`. Media (absolute host paths; the simulator reads the Mac's
files): videos from `google-ads/output/v5/*.mp4`, photos from `google-ads/html5/v5/300x600/*.jpg`, an HDR clip made
with:

```bash
ffmpeg -y -ss 12 -i google-ads/output/v5/collagemagik-mix-ad-landscape-16x9-1920x1080.mp4 -t 5 -vf "scale=1920:1080,format=yuv420p10le,setparams=color_primaries=bt2020:color_trc=arib-std-b67:colorspace=bt2020nc" -c:v libx265 -preset ultrafast -crf 22 -tag:v hvc1 -x265-params "colorprim=bt2020:transfer=arib-std-b67:colormatrix=bt2020nc:log-level=error" -c:a aac /tmp/hdr.mov
```

Harness flags (see `CLAUDE.md`): `CM_PRO=1`, `CM_START_TEMPLATE=<id>` + `CM_BATCH=a,b,c`, or `CM_AUTOLOAD` +
`CM_LAYOUT_ID`/`CM_FRAME`/`CM_LOOK`/`CM_CAPTIONS=1`/`CM_STICKERS`/`CM_OVERLAYS`/`CM_BACKDROP`, then
`CM_EXPORT=video|ultra`, `CM_FPS=60`, `CM_HDR=1`, `CM_OUT=/abs/path`. Launch with
`SIMCTL_CHILD_<flag>=… xcrun simctl launch <udid> com.axpo.collagemagik` and poll for the output file (do **not**
keep `--console-pty` attached; it keeps the app alive until timeout).

Matrix (minimum):

| Case | Setup |
|---|---|
| Still, 3 videos, rounded | `CM_AUTOLOAD` 3 videos, `CM_LAYOUT_ID=3-big-top`, gap + radius via template `living-night` style |
| Frames | still 4 photos + 1 video with `CM_FRAME` = torn, tape, film, stamp, gallery, date, neon, instant, circle, heart, arch (one export each, HD 30 is enough) |
| Tilted prints + overlays | layout `4-tossed`, `CM_OVERLAYS=1`, `CM_STICKERS=😍,heart.fill`, `CM_CAPTIONS=1` |
| Fit + looks | a cell with fit + blur bars, `CM_LOOK=film`, a rotated/flipped/straightened cell (the harness has no flags for fit/rotation/flip/straighten yet: add Debug-only `CM_FIT=i`, `CM_ROTATE=i`, `CM_FLIP=i`, `CM_ANGLE=i:deg` in `DebugHarness.swift`) |
| Backdrops | `CM_BACKDROP=blur`, `gradient:3`, `pattern:1` |
| All 12 motion templates | `CM_START_TEMPLATE=` each id in `Model/Templates.swift` (category `.motion`), 2 videos + 4 photos |
| 4K 60 heavy | `living-night`, 3 videos (one 4K, one HDR, one small), `CM_EXPORT=ultra CM_FPS=60` → S2/S3 |
| HDR | `CM_HDR=1 CM_EXPORT=ultra` with the HLG clip → check output is HEVC 10-bit `arib-std-b67` (S4) |

## 8. Final report (for a cheap review)

Write `ios/docs/gpu-export-results.md` containing only:

1. The matrix table: case · engine · resolution/fps · seconds · peak MB · SSIM overall · SSIM min frame.
2. S1–S6: pass/fail each, one line.
3. Known differences (if any) with one cropped side-by-side PNG path per difference.
4. `git log --oneline` of the branch and the list of files changed.
5. Anything not done or not verified.

Keep the report under ~80 lines. Do not paste code into it.
