# Collage Magic: Collage Maker & Editor (iPhone)

Native SwiftUI port of the web app, built for iOS 26+ with Liquid Glass. Apple ID `6832640005`, bundle ID
`com.axpo.collagemagik`. On the home screen and inside the app it is **Collage Magic** (renamed from "Insta Collage", since "Insta" is a term
Meta treats as its brand). Current version: **1.0.3 (build 3)**.

**App Store listing to set with the next version** (App Store Connect → the app → the new version → App Information):
Name **Collage Magic**, Subtitle **Collage Maker & Editor**. The live listing still says "Insta Collage Maker & Editor" until
that version is approved. Also rename the subscription group display name and the Pro plan display names in App Store
Connect from "Insta Collage Pro" to "Collage Magic Pro".

```bash
open ios/CollageMagik/CollageMagik.xcodeproj    # pick an iPhone simulator or your device, press Run
```

The `CollageMagik/` folder is a synchronized group, so new Swift files are picked up automatically. Xcode fetches the
Swift packages on first open: Google Mobile Ads (with Google's consent SDK, UMP), Firebase and the Facebook SDK (install tracking only). To run on a
device set your Team under Signing & Capabilities. The shared scheme uses `Products.storekit`, so the Pro plans load in
the simulator without App Store Connect.

## iPad

The app runs on iPad as well as iPhone (`TARGETED_DEVICE_FAMILY = 1,2`). iPhone stays portrait only; iPad supports every
orientation, as iPadOS expects. In portrait the iPad uses the phone layout, with the tools capped at 640 pt wide. In a wide
window (landscape, 900 pt or more) the preview fills the left side and the tools sit in a column on the right (`RootView`).
The app opens one window only (`UIApplicationSupportsMultipleScenes` is false in `AdInfo.plist`), since the editor holds one
design for the whole app. App Store Connect needs iPad screenshots (13-inch, 2064 × 2752) before a version with iPad
support can be submitted.

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
a single picture uses Panorama. When a set of pictures is added, `bestCarouselFit` picks the slide size (Post or Square)
and strip (Flow 4:5 or Square flow 1:1) that leave the least empty background plus the least trimmed off each picture
(Post wins a near tie); once the person picks Post or Square themselves, that size is kept and only the strip is chosen.
Leading strips start flush at the left edge of slide 1; any spare room is at the far end. The preview (`StageView`) shows one slide and a peek of the next: a drag on an
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

## New in 1.0.3

- **Undo / Redo** (top bar; `Model/History.swift`): one step per gesture or slider move (recorded when the design has been
  still for a moment), up to 60 steps. A new, reopened or Collage/Carousel-switched design starts a fresh history. Full screen
  preview moved into More •••, and the Collage | Carousel switch shows icons only when the bar is narrow.
- **Backgrounds** (Style tab; `Model/Backdrop.swift`): Colour, 12 gradients, a blurred copy of any picture in the tray, or a
  pattern (dots, grid, stripes, checks, confetti, hearts) over the colour. One renderer draws the preview and every export.
  Carousels start on **Blur → Auto** (✨): each gap shows a blur of the picture beside it, over a gradient of the pictures'
  average colours, so the empty space around and after the pictures matches them. Picking one picture blurs that instead.
- **App theme** (More → Theme; `AppTheme` in `UI/GlassComponents.swift`): the drifting colour field behind every screen.
  Nine dark themes (Magic, the default, plus Black Glass, Midnight, Ocean, Aurora, Forest, Sunset, Rose, Ember), kept on
  the device. Add one by adding a case with its 3 × 3 mesh colours.
- **Stickers** (in the Text tab, next to captions; `Model/Stickers.swift`, `UI/StickerPanel.swift`): emoji (Faces, Love, Fun)
  and colourable shapes, up to 30. Drag, pinch and twist like captions; size, tilt, colour, flip, layer order, copy, delete.
- **Clip speed** (timeline): 0.25× to 3×. The clip keeps its start; sound keeps its pitch in the preview and the export.
- **Export**: HD (1080 wide) or 4K (2160 × 3840 for a Story), at 30 or 60 fps.

## Ads and Collage Magic Pro

The app is free and shows **Google AdMob** ads (`Ads/GoogleAdsManager.swift`): a small banner above the bottom dock, and
one full-screen ad after an export finishes, before the result is shown. `Ads/AdsSwitch.swift` turns ads on or off. Debug builds use Google's test ad units. Meta's
ads SDK (Audience Network) was removed; the Facebook SDK stays only to count installs for Meta campaigns
(`Ads/MetaInstallTracking.swift`).

At first launch the order is: Google's consent form (EU/UK only, nothing is requested before it is answered), then Apple's
tracking prompt, then the ad SDK starts. A one-time "Thank you for using Collage Magic" note comes before the first
full-screen ad. EU/UK users can reopen the consent form from About & Privacy → Ad privacy choices.

**Collage Magic Pro** removes all ads and unlocks nothing else (`Store/ProStore.swift`, `Store/ProPaywall.swift`,
StoreKit 2, verified on the device, no server):

| Plan | Product ID |
|---|---|
| Yearly (1-week free trial) | `com.axpo.collagemagik.pro.yearly` |
| Monthly | `com.axpo.collagemagik.pro.monthly` |
| Lifetime (one-time) | `com.axpo.collagemagik.pro.lifetime` |

Prices, the trial and the "Save N%" badge all come from the App Store for the person's country; nothing is hard-coded.
The Pro page opens from More ••• → Remove ads (Pro), from About & Privacy, under each export result, and on its own at
most once a week. Restore purchases is on the Pro page and in About & Privacy.

## Install tracking (Google Ads conversions)

Google Ads counts an install when the app reports a `first_open` event. `Ads/InstallTracking.swift` starts **Google Analytics
for Firebase**, which sends it automatically; the app logs no events of its own. It stays off until the Firebase config file
is added, so nothing is sent today. It starts at the same point as the ads (after Google's consent form in the EU/UK, after
Apple's tracking question elsewhere), and Debug builds stay silent (`CM_ANALYTICS=1` turns it on for testing). Apple's
SKAdNetwork IDs in `AdInfo.plist` let Google count installs even when the person declines tracking.

One-time setup:

1. [Firebase console](https://console.firebase.google.com) → create a project → **Add app → iOS** with bundle ID
   `com.axpo.collagemagik` → download `GoogleService-Info.plist` and put it in `ios/CollageMagik/CollageMagik/` (Xcode picks
   it up by itself). Turn **Google Analytics** on for the project.
2. Firebase → **Project settings → Integrations → Google Ads → Link** your Google Ads account (the one that runs the app
   campaign). Link the same Firebase project to AdMob too, if you want ad revenue in the same place.
3. Google Ads → **Goals → Conversions → New conversion action → App → Google Analytics 4 (Firebase)** → pick the iOS app →
   import `first_open` (the install). Set it as a primary action for the app campaign.
4. Ship a new build (bump the build number). Installs of that version onward start to appear in Google Ads, usually within a day
   (iOS installs can take a few days because Apple delays SKAdNetwork reports). Installs of older versions can't be counted.
5. App Store Connect → **App Privacy**: add *Product Interaction* and confirm *Device ID* and *Advertising Data* are marked as
   used for Analytics and Third-Party Advertising (`PrivacyInfo.xcprivacy` already says so).

To check it before release: set `CM_ANALYTICS=1` for a Debug run, look for `CM_INSTALL tracking started` in the log, and watch
Firebase → **DebugView** (run with `-FIRDebugEnabled`).

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

## Push notifications, app updates and the splash

* **Splash** (`UI/SplashView.swift`): the logo tiles fly in, the icon lights up, the name writes itself in (about 2.4 s;
  a plain fade with Reduce Motion). The consent and tracking questions wait until it has finished.
* **Push** (`System/PushNotifications.swift`) uses Firebase Cloud Messaging, so campaigns are sent from the Firebase console
  with no server. One-time setup: Firebase console → Project settings → Cloud Messaging → *APNs Authentication Key* → upload
  the `.p8` key with its Key ID and the Team ID (`83FYPW267R`). The key stays out of the app and out of git.
  At launch the app gets *provisional* permission (no dialog, quiet delivery); after the first finished export it asks once for
  full permission. Every device is subscribed to the `all` topic. Add custom data `link` = an https URL to open it on tap.
  Debug builds log the device's token as `CM_PUSH FCM token:` for "Send test message".
* **Updates** (`System/UpdateChecker.swift`): Apple's public lookup API (`itunes.apple.com/lookup?id=6832640005`) gives the
  live version. When it is newer, a strip under the top bar offers "Update" (opens the App Store); closing it leaves a dot on
  "More" and an "Update to …" item in its menu. Never a popup. `CM_FAKE_UPDATE=1` shows it in Debug builds.

## Layout of the code

| Path | What |
|---|---|
| `Model/` | Layouts, geometry, timeline maths (ported 1:1 from the web `src/`), the `CollageStore` |
| `Media/` | Import and validation, live playback engine (one `AVPlayer` per video kept in step with the timeline) |
| `Export/` | Frame renderer (Core Graphics), per-clip frame reader, audio mix, MP4 writer |
| `UI/` | Stage, panels, timeline, crop editor, export sheet, glass components |
| `Ads/` | Google AdMob, the ads on/off switch, ad unit IDs, install tracking for Google Ads (Firebase) and Meta (Facebook SDK) |
| `Store/` | Collage Magic Pro: StoreKit 2 purchases and the Pro page |
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
