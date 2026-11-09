# CollageMagik for iPhone

Native SwiftUI port of the web app, built for iOS 26+ with Liquid Glass. Bundle ID `com.axpo.collagemagik`.

```bash
open ios/CollageMagik/CollageMagik.xcodeproj    # pick an iPhone simulator or your device, press Run
```

No packages or setup: it is a plain Xcode project (the `CollageMagik/` folder is a synchronized group, so new
Swift files are picked up automatically). To run on a device set your Team under Signing & Capabilities.

## What it does

Everything the web app does: up to 9 cells (photos + at most 2 videos), 35 layouts, Story / Post / Square, gap,
corners, background colour (swatches + colour picker), Instagram safe-area overlay, tap / drag / pinch /
press-and-hold-to-swap, rotate / flip / crop / straighten, a timeline (trim, move, split, delete, loop, mute), your
own background music (volume, trim, repeat, fade out), and export to MP4 (H.264 + AAC, 30 fps, 1080 wide or 2x) or PNG,
shared or saved to Photos.

## Carousel mode

The Collage | Carousel switch in the top bar changes what you are making. A carousel is one wide design, `slides` Instagram
slides side by side (4:5 or square, 2 to 10 slides, up to 10 photos, photos only), with pictures laid out so they cross the
seams between slides. `Model/CarouselLayouts.swift` builds the layouts (Flow, Two rows, Stagger, Mosaic, Panorama) and
guarantees every seam cuts through a picture. The preview (`StageView`) shows one slide and a peek of the next: a drag on an
unselected area swipes, a drag inside the selected picture moves it, and the numbered bar jumps between slides. Export draws
the whole design once and cuts it into one JPEG per slide (`CollageExporter.exportSlides`); My Library keeps them as one entry.

The bottom dock has Media, Layout, Style and (collage only) Video, which holds the Timeline and Sound tools. Picture tools
open by themselves while a picture is selected.

## My Library and privacy

There is no account, server or network code. Every export is also copied into the app's own `Documents/MyLibrary/`
folder (`Model/LibraryStore.swift`: the MP4 or PNG, a JPEG thumbnail and a `library.json` index) and shows up in
**More ••• → My Library** (`UI/LibrarySheet.swift`): play, share, save to Photos, delete. **More ••• → About & Privacy**
(`UI/AboutSheet.swift`) has the legal links and **Delete all my data**. Temporary working copies are cleared at launch.
`CollageMagik/PrivacyInfo.xcprivacy` declares no tracking and no collected data. The legal pages are on the Axpo Creation
site (`axpo-creations-apps/landing-page`, routes under `/collagemagik`). Submission steps and listing text: [APP_STORE.md](APP_STORE.md).

## Apple components used

`NavigationStack` + toolbar, `GlassEffectContainer` / `glassEffect` / `glassEffectID` (the dock's selected tab morphs),
`.glass` and `.glassProminent` button styles, `PhotosPicker`, `fileImporter`, sheets with detents, `fullScreenCover`,
`Menu`, `contextMenu`, `confirmationDialog`, `ContentUnavailableView`, `Picker`, `Slider`, `Toggle`, `ColorPicker`,
`Gauge`, `ShareLink`, `VideoPlayer`, `MeshGradient`, `sensoryFeedback`, SF Symbols with symbol effects.

## Video formats

Imports are validated up front (`MediaLoader`): the file must be playable, readable and decodable on the device, and
yield a picture. Supported: iPhone `.mov` / `.mp4` / `.m4v` in H.264 or HEVC, including HDR (HLG / Dolby Vision) and
portrait or rotated clips, with or without sound. During export HDR is converted to SDR (BT.709) so colours stay
right. AVI, MKV, WebM, MPEG-1/2 can't be decoded by iOS: the app says so and asks for MP4 or MOV.

## Layout of the code

| Path | What |
|---|---|
| `Model/` | Layouts, geometry, timeline maths (ported 1:1 from the web `src/`), the `CollageStore` |
| `Media/` | Import and validation, live playback engine (one `AVPlayer` per video kept in step with the timeline) |
| `Export/` | Frame renderer (Core Graphics), per-clip frame reader, audio mix, MP4 writer |
| `UI/` | Stage, panels, timeline, crop editor, export sheet, glass components |
| `DebugHarness.swift` | Debug builds only: `SIMCTL_CHILD_CM_AUTOLOAD=file1,file2 xcrun simctl launch ...` loads files, `CM_EXPORT=video` exports |
