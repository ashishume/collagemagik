# Insta Collage Maker & Editor (iPhone)

Native SwiftUI port of the web app, built for iOS 26+ with Liquid Glass. On the App Store it is **Insta Collage Maker &
Editor** (Apple ID `6832640005`); on the home screen and inside the app it is **Insta Collage**. The project, folders and
bundle ID (`com.axpo.collagemagik`) keep the original CollageMagik name. Current version: **1.0.1 (build 2)**.

```bash
open ios/CollageMagik/CollageMagik.xcodeproj    # pick an iPhone simulator or your device, press Run
```

The `CollageMagik/` folder is a synchronized group, so new Swift files are picked up automatically. Xcode fetches two
Swift packages on first open: Google Mobile Ads (with Google's consent SDK, UMP) and Meta Audience Network. To run on a
device set your Team under Signing & Capabilities. The shared scheme uses `Products.storekit`, so the Pro plans load in
the simulator without App Store Connect.

## What it does

Everything the web app does: up to 9 cells (photos + at most 2 videos) in the collage (10 photos in a carousel), picked from a **media tray** that holds up to 15 pictures and videos (extras wait in the tray as "In tray" and can be swapped in). When the tray is full, adding shows an alert that says to press and hold a tray picture and tap Remove, 35 layouts, Story / Post / Square, gap,
corners, background colour (swatches + colour picker), Instagram safe-area overlay, tap / drag / pinch /
press-and-hold-to-swap, rotate / flip / crop / straighten, a timeline (trim, move, split, delete, loop, mute), your
own background music (volume, trim, repeat, fade out), and export to MP4 (H.264 + AAC, 30 fps, 1080 wide or 2x) or PNG,
shared or saved to Photos.

A new collage opens with a **4-photo grid** (`initialCellCount` in `Model/Layouts.swift`); it resizes to the number of
pictures picked. New in 1.0.1:

- **Adjustable collages**: in the Layout tab, drag the border between two pictures to make one bigger and the other
  smaller (`Model/CellSizes.swift`, `dividerAt` in `UI/StageView.swift`). "Reset sizes" goes back to the layout.
- **Choose part**: pick which moment of a video plays, on a filmstrip (`UI/ChoosePartEditor.swift`).
- Duplicate a clip and "Use whole video" in the timeline menu; adding many files shows "Adding 2 of 5" and can be cancelled.

## Carousel mode

The Collage | Carousel switch in the top bar changes what you are making. A carousel is one wide design, `slides` Instagram
slides side by side (4:5 or square, 2 to 10 slides, up to 10 photos, photos only), with pictures laid out so they cross the
seams between slides. `Model/CarouselLayouts.swift` builds the layouts (Flow, Two rows, Stagger, Mosaic, Scatter, Wave,
Wall, Panorama) and guarantees every seam cuts through a picture. A new carousel starts in **Flow** (`defaultCarouselStyle`);
a single picture uses Panorama. The preview (`StageView`) shows one slide and a peek of the next: a drag on an
unselected area swipes, a drag inside the selected picture moves it, and the numbered bar jumps between slides. Export draws
the whole design once and cuts it into one JPEG per slide (`CollageExporter.exportSlides`); My Library keeps them as one entry.

## Captions

The **Text** tab adds captions on top of the collage or carousel (up to 8): 10 lettering styles that ship with iOS (nothing
bundled), any colour, four backings (Shadow, Label, Plate, Outline), alignment and size. In the preview a caption is
dragged to move (it clicks onto the middle of a slide), pinched to resize and twisted to turn; tapping it again opens the
typing screen (`UI/CaptionViews.swift`). `Model/Captions.swift` holds the model and `CaptionRenderer`, the one piece of
drawing code used by the preview and by every export (PNG, carousel slides, and video, where the captions are drawn once
as a layer and stamped on each frame). Captions always fit: long text wraps, letters shrink before a word would break,
and the whole caption is kept inside the design.

The bottom dock has Media, Layout, Style, Text and (collage only) Video, which holds the Timeline and Sound tools. Picture tools
open by themselves while a picture is selected.

## Ads and Insta Collage Pro

The app is free and shows **Google AdMob** ads (`Ads/GoogleAdsManager.swift`): a small banner above the bottom dock, and
one full-screen ad after an export finishes, before the result is shown. Meta Audience Network (`Ads/AdManager.swift`) is
still in the code but switched off; `Ads/AdsSwitch.swift` picks the network. Debug builds use Google's test ad units.

At first launch the order is: Google's consent form (EU/UK only, nothing is requested before it is answered), then Apple's
tracking prompt, then the ad SDK starts. A one-time "Thank you for using Insta Collage" note comes before the first
full-screen ad. EU/UK users can reopen the consent form from About & Privacy → Ad privacy choices.

**Insta Collage Pro** removes all ads and unlocks nothing else (`Store/ProStore.swift`, `Store/ProPaywall.swift`,
StoreKit 2, verified on the device, no server):

| Plan | Product ID |
|---|---|
| Yearly (1-week free trial) | `com.axpo.collagemagik.pro.yearly` |
| Monthly | `com.axpo.collagemagik.pro.monthly` |
| Lifetime (one-time) | `com.axpo.collagemagik.pro.lifetime` |

Prices, the trial and the "Save N%" badge all come from the App Store for the person's country; nothing is hard-coded.
The Pro page opens from More ••• → Remove ads (Pro), from About & Privacy, under each export result, and on its own at
most once a week. Restore purchases is on the Pro page and in About & Privacy.

## My Library and privacy

There is no account and no server of ours. The only network code is the ad SDK and StoreKit. Every export is also copied into the app's own `Documents/MyLibrary/`
folder (`Model/LibraryStore.swift`: the MP4 or PNG, a JPEG thumbnail and a `library.json` index) and shows up in
**More ••• → My Library** (`UI/LibrarySheet.swift`): play, share, save to Photos, delete. **More ••• → About & Privacy**
(`UI/AboutSheet.swift`) has the legal links and **Delete all my data**. Temporary working copies are cleared at launch.
`CollageMagik/PrivacyInfo.xcprivacy` declares tracking and the data types the ad SDKs collect (Device ID, Advertising Data, crash and diagnostic data); photos, videos, music and collages are never collected. The legal pages are on the Axpo Creation
site (`axpo-creations-apps/landing-page`, routes under `/collagemagik`).

## App Store

- [AppStore/release-1.0.1.md](AppStore/release-1.0.1.md): the 1.0.1 checklist (in-app purchases, App Privacy answers,
  AdMob setup, What's New, review notes). This is the current one.
- [APP_STORE.md](APP_STORE.md): the original 1.0 submission pack (before Pro and AdMob).
- [AppStore/screenshots/](AppStore/screenshots/README.md): the 10 App Store screenshots and the scripts that make them.
  They are captured with `CM_PRO=1` so no ads appear.

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
| `Ads/` | Google AdMob (on) and Meta Audience Network (off), the switch between them, ad unit IDs |
| `Store/` | Insta Collage Pro: StoreKit 2 purchases and the Pro page |
| `DebugHarness.swift` | Debug builds only: drives the app from environment variables (below) |

### Debug environment variables

Pass them with `SIMCTL_CHILD_` in front, e.g. `SIMCTL_CHILD_CM_PRO=1 SIMCTL_CHILD_CM_AUTOLOAD=a.jpg,b.jpg xcrun simctl launch booted com.axpo.collagemagik`.
All are ignored in release builds.

| Variable | Does |
|---|---|
| `CM_AUTOLOAD=a,b` | Loads files one by one (`CM_BATCH` all at once, `CM_IMPORT` through the progress loader) |
| `CM_MODE=carousel`, `CM_STYLE=flow`, `CM_OFFSET=1.1` | Carousel mode, style, and how far it is swiped |
| `CM_LAYOUT=n`, `CM_SIZES=0.6,0.4` | Number of cells; moves the first borders as if dragged |
| `CM_TAB=layout`, `CM_SELECT=i`, `CM_CROP=i`, `CM_PART=1` | Opens a tab, selects a cell, opens crop or Choose part |
| `CM_CAPTIONS=1` | Adds sample captions |
| `CM_EXPORT=video\|png\|ultra`, `CM_OUT=/path` | Exports without the UI |
| `CM_PRO=1` / `CM_PRO=0` | Forces Pro on (no ads, no consent or tracking prompt) or off |
| `CM_PAYWALL=1`, `CM_PRO_MOCK=1` | Opens the Pro page; shows it with placeholder plans |
| `CM_CONSENT_EEA=1`, `CM_LIVE_ADS=1` | Tests the EU consent form; uses the live ad units (don't tap them) |

If the simulator shows "Apple Account Verification" (StoreKit asking for the sandbox account), tap Not Now.
