# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Scope

Work happens in the iOS app, `ios/`. Do not edit or take reference from the web app (`src/` and the other root-level
web files) unless the user specifically asks for web work. `google-ads/` (Remotion marketing videos) is also out of
scope unless asked.

## The app

**Collage Magic: Collage Maker & Editor**: a native SwiftUI app for iPhone and iPad (iOS 26+, Liquid Glass) that makes
Instagram collages mixing photos and videos that play inside the collage, plus cross-seam carousels. App Store ID
`6832640005`, bundle ID `com.axpo.collagemagik`, Team ID `83FYPW267R`. Version and build are `MARKETING_VERSION` /
`CURRENT_PROJECT_VERSION` in the project file. `ios/README.md` is the full feature and setup reference; keep it current
when features change.

## Build and run

```bash
open ios/CollageMagik/CollageMagik.xcodeproj
xcodebuild -project ios/CollageMagik/CollageMagik.xcodeproj -scheme CollageMagik -destination 'generic/platform=iOS Simulator' build
```

- `CollageMagik/CollageMagik/` is a synchronized group: new Swift files are picked up without editing `project.pbxproj`.
- Swift packages: Google Mobile Ads (with UMP consent), Firebase, Facebook SDK (Meta install tracking only; Meta's ads
  SDK, Audience Network, was removed to save ~8 MB: don't add it back unless asked).
- The shared scheme uses `Products.storekit`, so Pro plans load in the simulator without App Store Connect.
- There is no test target. Verify changes by running the app, usually through the debug harness below.

### Debug harness

`DebugHarness.swift` drives Debug builds from environment variables (ignored in Release). Pass them with `SIMCTL_CHILD_`:

```bash
SIMCTL_CHILD_CM_PRO=1 SIMCTL_CHILD_CM_AUTOLOAD=a.jpg,b.jpg xcrun simctl launch booted com.axpo.collagemagik
```

| Variable | Does |
|---|---|
| `CM_AUTOLOAD=a,b` | Loads files one by one (`CM_BATCH` all at once, `CM_IMPORT` through the progress loader) |
| `CM_MODE=carousel`, `CM_STYLE=flow`, `CM_OFFSET=1.1` | Carousel mode, style, and how far it is swiped |
| `CM_LAYOUT=n`, `CM_SIZES=0.6,0.4` | Number of cells; moves the first borders as if dragged |
| `CM_TAB=layout`, `CM_SELECT=i`, `CM_CROP=i`, `CM_PART=1` | Opens a tab, selects a cell, opens crop or Choose part |
| `CM_CAPTIONS=1` | Adds sample captions |
| `CM_EXPORT=video\|png\|ultra`, `CM_OUT=/path` | Exports without the UI |
| `CM_EXPORT_ENGINE=cpu\|gpu` | Selects the video export engine and logs timing and peak memory as `CM_EXPORT` |
| `CM_PRO=1` / `CM_PRO=0` | Forces Pro on (no ads, no consent or tracking prompt) or off |
| `CM_PAYWALL=1`, `CM_PRO_MOCK=1` | Opens the Pro page; shows it with placeholder plans |
| `CM_CONSENT_EEA=1`, `CM_LIVE_ADS=1` | Tests the EU consent form; uses live ad units (don't tap them) |
| `CM_ANALYTICS=1` | Turns on Firebase install tracking in Debug (log: `CM_INSTALL tracking started`) |
| `CM_FAKE_UPDATE=1` | Shows the "Update available" strip |
| `CM_NO_PREVIEW_COPY=1` | Preview plays the original videos instead of their small copies (log: `CM_PREVIEW_COPY ready`) |
| `CM_SYNC_LOG=1` | Logs when hidden videos pause and when players are jumped back into step (`CM_SYNC hide/jump`) |

If the simulator shows "Apple Account Verification" (StoreKit sandbox), tap Not Now.

Run `SIM_UDID=<booted-device> ios/scripts/compare_export_engines.sh compare` with a Debug build installed and
FFmpeg available. The script measures both engines, checks per-frame SSIM and inspects the HDR output tags.

## Architecture

Code is under `ios/CollageMagik/CollageMagik/`.

- **State**: `Model/CollageStore.swift` is the single `@MainActor @Observable` store holding the design (`project`), the
  media tray (up to 25 items) and UI state. The design is either a **collage** (up to 12 cells, at most 3 videos, 60 s
  max) or a **carousel** (up to 20 photos on 2–20 slides, photos only, pictures crossing slide seams; layouts in
  `Model/CarouselLayouts.swift`, which guarantees every seam cuts through a picture).
- **Pure model maths**: `Layouts.swift` (cell rects as 0..1 fractions; a new collage starts with `initialCellCount` = 4),
  `CellSizes.swift` (user-dragged borders), `Geometry.swift` (cover/zoom/pan/rotate/straighten placement, formats),
  `Timeline.swift` (lanes, trim/split/move/speed, what a video shows at time *t*, music ribbon).
- **Motion designs**: `Model/Motion.swift`. A collage with `project.motion` plays as scenes (layout + slots + length +
  transition). Draw `project.posed(at: t)`, never the raw project, wherever the design is shown at a moment:
  `CollageRenderer.draw` takes `t`, and the preview reads `store.shown`.
- **Layers drawn over the cells**, each with one model + renderer shared by the preview and every export:
  `Backdrop.swift` (colour, gradients, blurred photo, patterns), `Overlays.swift` (free-floating photo prints with
  frames from `Frames.swift`), `Captions.swift` (`CaptionRenderer`, up to 8, always fit inside the design),
  `Stickers.swift` (up to 30). Draw order: backdrop → cells → overlays → captions/stickers. A visual change must go
  into the shared renderer so preview and export stay identical.
- **History**: `Model/History.swift` records an undo step once the design has been still for a moment (one gesture =
  one step, max 60). Tray media is not part of history. A new, reopened or mode-switched design starts fresh history.
- **Persistence**: `Model/Drafts.swift` saves designs to `Documents/` (one folder per draft: `draft.json`, thumbnail,
  hard-linked media copies). `Model/LibraryStore.swift` keeps every export in `Documents/MyLibrary/` with a
  `library.json` index. Temporary working copies are cleared at launch. No account, no server of ours.
- **Media**: `Media/MediaLoader.swift` validates imports up front (playable, decodable, yields a picture; H.264/HEVC,
  HDR, rotated clips). `Media/PlaybackEngine.swift` keeps one `AVPlayer` per video plus one for music in step with the
  timeline clock for live preview.
- **Preview copies**: `Media/PreviewCopies.swift` makes a 720p SDR copy of every video bigger than 720p or HDR, in the
  background, and the live preview (and Choose part) switch to it when it's ready. Exports, thumbnails and drafts
  always read the original file. Copies sit in `tmp/PreviewCopies/` and are cleared at launch.
- **Export**: `Export/GPUFrameComposer.swift` uses Metal-backed Core Image to compose video frames. It shares print
  drawing with the Core Graphics renderer in `Export/CollageRenderer.swift`, which handles stills and video fallback.
  Both consume an `ExportSnapshot` and share `LaneFrameFeeder` for timeline frame selection. HDR clips
  convert to SDR BT.709, unless HDR export is on (10-bit HEVC HLG via the `HDR` helpers). `Export/Exporter.swift`
  (`CollageExporter`) writes MP4 (H.264 + AAC, HD or 4K, 30/60 fps), PNG, or one JPEG per carousel slide
  (`exportSlides`), and saves to Photos with add-only access.
- **Home**: the app opens on `UI/HomeView.swift` (system tab bar: Collage, Carousel, Templates, Library);
  the editor (`RootView`) is shown full screen over it while `store.editorOpen`. Templates are `DesignTemplate`s in
  `Model/Templates.swift` (designs without pictures), applied with `store.applyTemplate`. The debug harness opens the
  editor by itself when any `CM_` variable other than the Pro ones is set.
- **UI**: `UI/RootView.swift` (the editor) picks the layout: phone layout on iPhone and portrait iPad (tools capped at 640 pt);
  preview left + tool column right in windows ≥ 900 pt wide. iPhone is portrait only; iPad supports all orientations,
  single window. `UI/StageView.swift` holds the preview and all gestures (select, pan, pinch, press-and-hold swap,
  border dragging via `dividerAt`, carousel swiping). The bottom dock (`ToolDock.swift`) has Media, Layout, Style, Text
  and (collage only) Video; picture tools open while a picture is selected. Shared glass styling is in
  `GlassComponents.swift`.

## Monetisation, ads and privacy

- **Ads**: Google AdMob is on (`Ads/GoogleAdsManager.swift`): a banner above the dock and one interstitial after an
  export finishes. `Ads/AdsSwitch.swift` turns ads on or off. Debug builds use Google's test ad units.
- **Launch order**: splash (~2.4 s) → Google UMP consent (EU/UK only, nothing requested before it is answered) → ATT
  tracking prompt → ad SDK and Firebase start. A one-time "Thank you" note precedes the first interstitial.
- **Collage Magic Pro** (`Store/`, StoreKit 2, verified on device, no server) removes ads and unlocks nothing else.
  Products: `com.axpo.collagemagik.pro.yearly` (1-week trial), `.monthly`, `.lifetime`. Prices, trial and "Save N%" come
  from the App Store; never hard-code them.
- **Install tracking**: `Ads/InstallTracking.swift` (Firebase Analytics `first_open` for Google Ads) and
  `Ads/MetaInstallTracking.swift` (Facebook SDK app-activate events for Meta install campaigns). Both start after the
  consent/ATT step; the app logs no events of its own. **Push** (`System/PushNotifications.swift`): Firebase Cloud Messaging, provisional
  permission at launch, full permission asked once after the first export, every device on topic `all`.
  **Updates** (`System/UpdateChecker.swift`): iTunes lookup API, shown as a strip, never a popup.
- `PrivacyInfo.xcprivacy` declares tracking and the ad SDKs' data types; photos, videos, music and collages are never
  collected. Keep it in step with any SDK or data change. `.p8` keys never go in the repo.

## App Store material

- `ios/AppStore/release-1.0.1.md`: the current release checklist (IAP, App Privacy answers, AdMob, review notes).
- `ios/AppStore/screenshots/`: screenshot scripts and manifest, captured with `CM_PRO=1`. iPad submissions need 13-inch
  (2064 × 2752) screenshots.
- Pending listing change: name **Collage Magic**, subtitle **Collage Maker & Editor**; rename "Insta Collage Pro" to
  "Collage Magic Pro" in App Store Connect. Avoid "Insta" in user-facing text (Meta treats it as its brand).
