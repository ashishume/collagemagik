# 4K 60 fps video export: review and handover

Branch: `gpu-export`. Scope: the iOS app only (`ios/`). Read `CLAUDE.md` at the repo root first. It covers the
architecture, the build command and the debug harness (`CM_*` environment variables).

This is a code review. Nothing here has been changed or run yet. All performance numbers come from
`ios/docs/gpu-export-results.md`, which was measured **on the iOS Simulator**.

Paths below are relative to `ios/CollageMagik/CollageMagik/` unless they start with `ios/`.

---

## 1. How 4K 60 fps export works today

1. **Export sheet** (`UI/ExportSheet.swift`)
   - The user picks Quality (HD, or 4K = `ExportQuality.ultra`, scale 2) and a frame rate (30 or 60, saved in
     `@AppStorage("cm.export.fps")`).
   - 4K is offered when `CollageExporter.canEncode(format:quality:)` passes.
   - `ExportJob.start` calls `exporter.exportVideo(quality:hdr:fps:)` (line 36). It also turns off the screen
     idle timer (lines 31 and 33).
2. **`CollageExporter.exportVideo`** (`Export/Exporter.swift:439`)
   - Calls `writeVideo(engine: .requested, …)`. The default engine is `.gpu`.
   - If writing fails with `GPUExportFailed`, it starts the **whole** export again with the CPU engine
     (lines 442–449).
3. **`writeVideo`** (`Export/Exporter.swift:452`)
   - Size: `canvasWidth × 2` by `canvasHeight × 2`. A Story becomes 2160×3840.
   - Encoder settings come from `videoSettings(w,h,hdr:fps:)` (line 314):
     - SDR: H.264 High, bitrate `16 Mbps × 1.5 (60 fps) × pixels / (1080×1920)`, which is **96 Mbps** at 4K60.
     - HDR: HEVC Main10 HLG, bitrate `20 Mbps × 1.5 × pixel ratio`, which is **120 Mbps** at 4K60.
     - Keyframe every `fps × 2` frames.
   - `planarSDR = !hdr && w*h > 4_000_000` (line 523). At 4K the GPU writes NV12 buffers that go straight to the
     encoder.
   - Before writing starts, the first GPU frame is rendered into an NV12 buffer as a check (`prepareFirstFrame`,
     lines 539–553). If it fails, the export falls back to the CPU engine and BGRA buffers.
   - **The frame loop** (lines 575–617) runs on the serial queue `videoQueue`. For each frame it does these
     steps one after another:
     1. take a buffer from the pool
     2. `frames.render(at:)`
     3. `adaptor.append`
     4. report progress
   - Audio runs on its own queue (lines 619–633).
   - An async loop checks every 25 ms for cancel or failure (lines 638–651).
4. **`GPUFrameComposer.render`** (`Export/GPUFrameComposer.swift:92`)
   - Builds a Core Image graph: the background, then for each cell the print under-art, the placed media
     masked to the picture, and the over-art. Tilt and opacity follow, then the foreground layers and the scene
     captions.
   - Renders it with `CIRenderDestination` and **waits for it synchronously**: `task.waitUntilCompleted()`
     (line 154).
5. **Video frames**: `LaneFrameFeeder` (`Export/CollageRenderer.swift:254`)
   - Each placed video has one `AVAssetReaderVideoCompositionOutput` (line 384). It reads each source frame at
     the **source's full resolution**: NV12 for planar SDR, 10-bit for HDR, BGRA otherwise.
   - `pixelBuffer(at:)` picks the frame whose time is within `t + halfFrame`. A 30 fps source in a 60 fps
     export therefore shows each frame twice.

---

## 2. Measured results (simulator), from `ios/docs/gpu-export-results.md`

| Case | Engine | Size / fps | Seconds | Peak MB |
|---|---|---|---:|---:|
| 4k60-heavy | cpu | 2160×3840 / 60 | 981.8 | 2298.8 |
| 4k60-heavy | gpu | 2160×3840 / 60 | 661.6 | 2221.4 |

- The case is the `living-night` motion template: 4 scenes of 2.2 + 1.8 + 1.8 + 3.6 s, about 9.4 s in all, about
  565 frames. It uses three videos: one 4K (3840×2160 H.264), one HDR (HEVC), one 480×480.
  It is set up in `ios/scripts/compare_export_engines.sh:192`.
- **S2 fails**: GPU time is 67.4% of CPU time. The target is 40% or less.
- **S3 fails**: GPU peak memory is 96.6% of CPU peak memory. The target is 60% or less.
- The simulator encodes video in software and runs Metal through translation, so its times are not real device
  times. Peak memory is the most worrying number. iOS 26 runs on 4 GB devices (iPhone 11, iPhone SE 3), and an
  app can be killed by the system at roughly 2 GB there.

---

## 3. Issues, most important first

### Issue 0: no device measurements (do this first)

**What:** every result comes from the simulator. Nobody knows how long a 4K60 export takes or how much memory
it uses on a real iPhone.

**Why it matters:** a peak of 2.2 GB would likely get the app killed during export on 4 GB iPhones. The real
device numbers decide how urgent issues 1 to 3 are.

**What to do:**
1. Build Debug and install it on a 4 GB device (iPhone 11 or SE 3) and on a 6–8 GB device (iPhone 15 or 16).
2. Run the same case:
   `CM_EXPORT=ultra CM_FPS=60 CM_START_TEMPLATE=living-night CM_BATCH=<4k>,<hdr>,<small>`, once with
   `CM_EXPORT_ENGINE=gpu` and once with `=cpu`. Make the fixtures the way `compare_export_engines.sh` makes
   them.
3. Read the `CM_EXPORT engine=… seconds=… peakMB=…` log line.
4. Also export a **60 s** design. The test case is only 9.4 s, and a 60 s design is the real worst case:
   3600 frames.
5. Watch Xcode's memory gauge, and look for jetsam events in the device logs.
6. Record the results in `ios/docs/gpu-export-results.md`.

---

### Issue 1: frames are made one at a time, so decoding, GPU work and encoding never overlap

**Where:**
- `Export/Exporter.swift:575–617` (the frame loop)
- `Export/GPUFrameComposer.swift:153–154` (`startTask` followed by `waitUntilCompleted`)
- `Export/CollageRenderer.swift:406` (`readNext`, which calls `copyNextSampleBuffer` synchronously)

**What:** each frame runs these steps in order on one serial queue:
1. decode the next sample of every video (blocking `copyNextSampleBuffer`)
2. build the Core Image graph
3. render on the GPU and **block until it finishes**
4. `append`

While the GPU renders, nothing is decoding. While a video decodes, the GPU sits idle. At 60 fps this happens
twice as often as at 30 fps. The plan (`ios/docs/GPU_EXPORT_PLAN.md`, step 5a) says to add read-ahead if S2
fails. S2 failed, and read-ahead was never added.

**What to do:**
- Read video ahead: for each feeder, use a small queue (depth 2–3) that reads the next sample buffers while the
  current frame renders. `LaneFrameFeeder` currently keeps only `current` and `pending`. Read-ahead has to keep
  timestamp selection exactly the same. The debug check `CM_EXPORT_VERIFY_TIMESTAMPS=1` (Exporter.swift:153)
  already compares CPU and GPU timestamp choices, so use it to confirm.
- Overlap GPU work: allow 2 frames in flight. Start the Core Image task for frame N+1 before waiting on frame N,
  and append frame N only after its task finishes. Appends must stay in presentation order.
- Keep `pixelBufferPool` use bounded so in-flight buffers don't pile up and use memory.
- Don't break the `VideoExportFrames.close()` rule: it must still run on the video queue, never in the middle
  of a frame.

**Done when:** on a device, GPU time is clearly lower and peak memory does not go up. Timestamps still match
(`CM_EXPORT verified N matching CPU/GPU timestamps`).

---

### Issue 2: videos are decoded at full source size whatever size they're drawn at

**Where:**
- `Export/CollageRenderer.swift:350–404` (`startReader`): no `renderSize` or scaling in the video composition.
- `Export/CollageRenderer.swift:422` (`hdrImage`): the only place that uses `maxPixels`. It runs only on the
  CPU HDR path.
- `Export/Exporter.swift:358–378` (`makeFeeders`): `maxPixels` is only worked out when `hdr` is true
  (`let poses = hdr ? project.motionSamples() : []`).

**What:** a 4K source shown in a cell a third of the screen wide is still decoded, colour-converted and sent
through Core Image at 3840×2160 every frame. This costs decode time, memory bandwidth and Core Image
intermediates, and with three videos it adds up. The GPU path never scales the input down.

**What to do (plan step 5b):**
1. Always compute `maxPixels`, for SDR as well as HDR. Use the existing motion-pose sampling
   (`project.motionSamples()`, `neededPhotoSize(…)`) so the size covers the largest size the video is drawn at
   in any scene.
2. In `startReader`, set `comp.renderSize` to the source size scaled down to `maxPixels` (keep the aspect
   ratio, round to even numbers). Scale the composition's transform to match, or use a custom
   instruction/layer instruction.
   - Check carefully that rotated clips (portrait iPhone video with a preferred transform) still come out the
     right way up. `AVMutableVideoComposition(propertiesOf:)` currently handles that rotation.
3. `GPUFrameComposer.place` (`Export/GPUFrameComposer.swift:270`) already scales by
   `item.width * p.scale / source.width`, so it should cope with a smaller input. Verify this.
4. Keep a little extra resolution, about 1.1×, so zoom moves (`move: .zoomIn`) don't look soft.
5. Compare SSIM against the CPU engine with `ios/scripts/compare_export_engines.sh`. The thresholds are in
   `GPU_EXPORT_PLAN.md`.

**Done when:** a smaller video is decoded when the cell is small, peak memory at 4K60 drops clearly, and SSIM
still passes.

---

### Issue 3: a GPU failure after writing has started redoes the whole export on the CPU

**Where:** `Export/Exporter.swift:439–450` (`exportVideo`), 653–656 (`failed(_:)` wraps every GPU-engine error
in `GPUExportFailed`), and 447 (`progress(0)`).

**What:**
- Any failure partway through a GPU export, for any reason, throws away all the frames made so far and starts
  again at frame 0 on the CPU engine.
- At 4K60 that can be many minutes of lost work. The CPU engine is also slower (982 s against 662 s in the
  simulator).
- The CPU engine uses **at least as much memory**. If the GPU export failed because of memory pressure (for
  example a `rasterAllocationFailed` error, or the writer failing under memory pressure), the CPU retry is likely
  to fail too, or get the app killed.
- The progress bar jumps back to 0 with no explanation to the user.

**What to do:**
- Only retry on the CPU when the error is a GPU-specific problem (a Metal or Core Image render error). Don't
  retry when:
  - the error is an allocation or memory failure (`GPUFrameComposer.SetupError.rasterAllocationFailed`, "Couldn't
    allocate video memory", or an `AVAssetWriter` error that comes from memory),
  - or the export is 4K and a memory warning arrived during it.
  In those cases show a clear error and suggest HD (`ExportQuality.standard`) or 30 fps.
- If a retry does happen, tell the UI. Add a state or callback so `ExportJob` can show something like "Trying
  again with a slower method…" instead of a bare reset to 0.
- Think about listening for `UIApplication.didReceiveMemoryWarningNotification` during a 4K export and noting it,
  so the retry decision can use it.

**Done when:** a failure caused by memory doesn't start a CPU re-run at 4K, and the user can see a retry when one
happens.

---

### Issue 4: moving the app to the background during an export probably makes the GPU export fail and restart

**Where:**
- `UI/ExportSheet.swift:31–33`: only the idle timer is turned off. There is no `beginBackgroundTask`.
- No code handles `didEnterBackground` or `scenePhase` during an export. `UI/RootView.swift:155` uses
  `scenePhase`, but not for exports.

**What:**
- iOS doesn't let apps send GPU work in the background. The Metal command buffer fails with "background execution
  not permitted".
- If the user switches apps during a long 4K60 export, the next `context.startTask` or `waitUntilCompleted` most
  likely throws. That becomes `GPUExportFailed`, which leads to the full CPU re-run in Issue 3.
- Without a background task the app is then suspended within a few seconds anyway.
- **I haven't confirmed this on a device.** Reproduce it first: start a 4K60 export, swipe to the Home Screen
  for 5 s, come back, and check the `CM_EXPORT` logs.

**What to do (pick one, then verify):**
- Option A (simplest): watch for the app going into the background during an export and pause the frame loop
  before the next GPU submission. Resume when the app becomes active again. The `AVAssetWriter` can stay open
  while paused because `expectsMediaDataInRealTime = false`.
- Option B: cancel cleanly with a message like "Export stopped because the app was closed. Keep Collage Magic
  open while exporting." Never turn it into a CPU retry.
- Either way, also call `UIApplication.shared.beginBackgroundTask` so the queues get time to stop cleanly
  without the writer being cut off mid-write.
- iOS 26 also has `BGContinuedProcessingTask`, which lets work continue in the background with a system progress
  UI, and it can allow GPU use on supported devices. It's worth looking at for long 4K exports, but check that the
  device supports it and that the API behaves as expected before relying on it.

**Done when:** backgrounding during an export never produces a silent restart on the CPU engine.

---

### Issue 5: the device check for 4K never checks 60 fps

**Where:**
- `Export/Exporter.swift:306–312`: `canEncode` calls `videoSettings(w, h, hdr: hdr)`, so `fps` is left at its
  default of 30.
- `UI/ExportSheet.swift:168–173`: the checks run once, with no frame rate.
- `UI/ExportSheet.swift:110`: the frame rate is saved in `@AppStorage`, so a user returns to 60 fps
  automatically.
- `Export/Exporter.swift:465–469`: if `canApply` fails at 60 fps, the error says "Try Standard quality" and never
  mentions the frame rate.

**What:**
- The 4K + 60 fps pair is never checked before the user taps Export.
- `canApply` also only checks the settings dictionary. It doesn't check whether the hardware can keep up or
  whether memory is enough.

**What to do:**
1. Add an `fps` parameter to `canEncode` and check 4K at 60 fps. Hide or disable "60 fps" when 4K is selected and
   the check fails, or the other way round.
2. Decide whether devices with 4 GB or less (`ProcessInfo.processInfo.physicalMemory`) should get 4K60 at all.
   The decision depends on the device results from Issue 0.
3. Make the error message name the real cause: "Try 30 fps or HD".

---

### Issue 6: the bitrate is much higher than needed, and free space is never checked

**Where:** `Export/Exporter.swift:314–355`, and `writeVideo`, which checks no disk space.

**What:**
- **Numbers:** H.264 4K60 at 96 Mbps and HEVC HDR 4K60 at 120 Mbps. A 60 s export is about **720 MB (SDR) or
  900 MB (HDR)**.
- **Free space:** the file is written to `tmp/`. It is then copied into `Documents/MyLibrary/` by
  `LibraryStore` and also saved to Photos, so the space is needed up to about 3 times.
- **No user gain:** Instagram Reels and Stories re-encode uploads to 1080×1920, and TikTok does much the same.
  Very high 4K bitrates give no visible improvement after upload.

**What to do:**
- Cap the SDR H.264 bitrate at 4K, at about 45–60 Mbps for 60 fps and 35–45 Mbps for 30 fps. Alternatively use
  HEVC (8-bit Main) for SDR 4K, which gives about the same quality at roughly half the bitrate. Check that HEVC SDR
  exports still play and upload fine; all iOS 26 devices support it.
- Before `startWriting`, estimate the size: `bitrate × duration / 8 × ~3`. Compare it with
  `volumeAvailableCapacityForImportantUsage` and fail early with a clear message if there isn't enough space.
- Mention the expected size in the export sheet's `qualityNote` (`UI/ExportSheet.swift:355–361`) for 4K/60.

---

### Issue 7: background, sticker and caption layers are full-size 4K images

**Where:**
- `Export/GPUFrameComposer.swift:47–51`: the background is drawn as one full-canvas image.
- `Export/GPUFrameComposer.swift:74–78`: all stickers go into one full-canvas image.
- `Export/GPUFrameComposer.swift:79–82`: the always-visible caption layer and **every** per-scene caption layer
  are full-canvas `CGImage`s. They're made in `CaptionRenderer.layers` (`Model/Captions.swift:840–853`).

**What:** at 2160×3840 each of these is about 33 MB in SDR (BGRA) or about 66 MB in HDR (RGBAh). A motion design
with captions in several scenes keeps all of them in memory for the whole export, and Core Image composites each
one over the whole canvas every frame.

**What to do:**
- Crop each sticker and caption layer to the box around its visible content, and keep the offset (place it with
  `CIImage.transformed(by:)`). This needs `CaptionRenderer.layers` to return a box and an image instead of a
  full-canvas image. The CPU path (`CollageRenderer.draw`) uses the same layers, so either update both engines or
  keep a full-size form for the CPU.
- A plain-colour or gradient background can be made directly in Core Image (`CIImage(color:)` cropped, or
  `CILinearGradient`) instead of a 33 MB image. Only do this if the output matches `BackdropRenderer` pixel for
  pixel within the SSIM thresholds. Otherwise leave it.
- Lower priority than issues 1 to 3. Measure first.

---

### Issue 8: HDR motion designs at 4K don't reuse print artwork

**Where:** `Export/GPUFrameComposer.swift:40`:
`useLocalPrintCoordinates = !hdr && snapshot.project.isMotion && width * height > 4_000_000`

**What:**
- In HDR, a print sliding across the canvas edge (for example the `.slideUp` transition) gets a new visible box
  every frame.
- So the cache key changes every frame, and the print is drawn again in RGBAh at 4K for every frame of the
  transition.
- That makes HDR 4K60 motion exports noticeably slower during transitions, and it fills the 140 MB cache and
  empties it again over and over (`consumeEvictions` then `context.clearCaches()`).

**What to do:**
1. Find out why HDR was left out (check `git log -S useLocalPrintCoordinates` on this branch).
2. If there's no real reason, turn it on for HDR too.
3. Check against the CPU HDR export (`run hdr` in `compare_export_engines.sh`, plus an HDR motion-template case)
   and the S4 colour-tag check.

---

### Issue 9: smaller points to check while working on this

- **The held-frame cache grows without limit.** `LaneFrameFeeder.holdCache` (`Export/CollageRenderer.swift:450–455`)
  is keyed by the time in milliseconds and has no limit.
  - If `resolveLane` gives a hold time that changes during a design (for example a loop or speed change), it
    stores one full-size image per millisecond.
  - Check what `resolveLane` returns for inactive lanes. If the time isn't fixed, limit the cache.
- **Sped-up clips at 60 fps.** `needsRestart` (`Export/CollageRenderer.swift:321`) restarts the reader when the
  source time jumps more than 0.75 s.
  - With a clip at speed 4× or more at 60 fps, each step is 4/60 ≈ 0.067 s, which is fine.
  - Confirm the `CM_SPEED` setting can't make a step bigger than 0.75 s, which would restart the reader every
    frame.
- **Composition output.** `AVAssetReaderVideoCompositionOutput` is used to get the preferred-transform rotation.
  A plain `AVAssetReaderTrackOutput` plus rotation in Core Image would skip the composition stage. Look at this
  only if decode is still the slowest step after issues 1 and 2.
- **The first frame's buffer** (`Exporter.swift:544–548`) is created outside the adaptor's pool. That's fine,
  but its size isn't counted in the pool's limits.
- **There's no time estimate.** The export sheet only says "Bigger exports take longer to make"
  (`UI/ExportSheet.swift:360`). Once device times are known, show an estimate for 4K60, such as "about N min for
  this video".

---

## 4. Suggested order

1. Issue 0: measure on devices (4 GB and 8 GB).
2. Issue 4: confirm and fix what happens on backgrounding. It's small, and it's a real bug that users will hit.
3. Issue 3: make retries depend on the cause, and show them in the UI.
4. Issue 2: decode at the size drawn. Probably the biggest memory and time gain.
5. Issue 1: read ahead and keep 2 frames in flight.
6. Issues 5 and 6: check 4K60 capability, set the bitrate, check free space.
7. Issues 7 and 8: memory and speed work for captions, layers and HDR motion.
8. Run the comparison matrix again (`SIM_UDID=<udid> ios/scripts/compare_export_engines.sh compare`) and run
   the device cases again. Update `ios/docs/gpu-export-results.md`.
9. Keep `ios/README.md` and `CLAUDE.md` up to date if behaviour changes, for example a new error message, a
   4K60 restriction or a different bitrate.

## 5. Rules to keep (from CLAUDE.md and the existing design)

- The preview and every export must keep using the same renderers. Visual changes go into the shared renderer
  (`CollageRenderer` or `GPUFrameComposer` with the shared print drawing), never into one engine only.
- The CPU and GPU engines must never be mixed in one output file.
- Exports always read the **original** video files, never the 720p preview copies (`Media/PreviewCopies.swift`).
- HDR output stays 10-bit HEVC HLG with BT.2020 tags (check with `ffprobe`: `yuv420p10le`, `arib-std-b67`,
  `bt2020`).
- There is no test target. Verify through the debug harness and `compare_export_engines.sh`.
- Build: `xcodebuild -project ios/CollageMagik/CollageMagik.xcodeproj -scheme CollageMagik -destination 'generic/platform=iOS Simulator' build`
