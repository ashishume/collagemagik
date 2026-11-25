# Collage Magic: Collage Maker & Editor (iPhone)

Native SwiftUI port of the web app, built for iOS 26+ with Liquid Glass. Apple ID `6832640005`, bundle ID
`com.axpo.collagemagik`. On the home screen and inside the app it is **Collage Magic** (renamed from "Insta Collage", since "Insta" is a term
Meta treats as its brand). Current version: **1.0.5 (build 3)**.

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

Everything the web app does: up to 12 cells (photos + at most 3 videos) in the collage (20 photos in a carousel), picked from a **media tray** that holds up to 25 pictures and videos (extras wait in the tray as "In tray" and can be swapped in). When the tray is full, adding shows an alert that says to press and hold a tray picture and tap Remove, 66 layouts (up to 12 pictures; 21 free-form ones with overlapping or turned prints via `LayoutRect.tilt`), Story / Post / Square, gap,
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

## Feature tour

`UI/FeatureTour.swift`: seven swipeable pages, each with a small looping animation (welcome, photos + videos, carousels,
templates, frames and filters, captions and stickers, export). It shows once, right after the splash, for new users and
for existing ones who haven't seen it (`cm.tour.seen.v1` in UserDefaults; bump the version to show a new tour to
everyone). Consent, the tracking prompt, ads start-up and the weekly Pro page wait until it is closed. Settings →
Feature tour shows it again. Animations stop with Reduce Motion; `CM_TOUR=1` forces it in Debug.

## Home and templates

The app opens on **Home** (`UI/HomeView.swift`), a system tab bar with **Collage**, **Carousel**, **Templates** and
**Library** (drafts and exports, with Collages | Carousels tabs at the top; it reuses `LibrarySheet` with `kind` and
`embedded`). Every Home tab shows the Collage Magic logo and name top left and a gear for Settings (theme, help, about,
rating, Pro); the editor's menu button is a menu icon.
Collage and Carousel each show a "New" card, a row of templates for that kind and that kind's drafts (Recent); Templates
lists every template with a kind filter and category chips. Starting or opening a design shows the editor full screen
(`RootView`, `store.editorOpen`); its back button saves the draft and returns Home. The kind is chosen on Home, so the
editor's top bar shows it as a title instead of a switch. A carousel's dock reads **Photos · Slides · Style · Text**
(`Tab.label(in:)`); a collage's reads Media · Layout · Style · Text (+ Video).

**Templates** (`Model/Templates.swift`, `UI/TemplateViews.swift`): a `DesignTemplate` is a design without pictures
(layout or carousel style, size, gap, corners, background, frame, placeholder captions and stickers). `allTemplates`
holds 161 (139 collage, 22 carousel) in 23 categories (the "With video" category puts clips in the first, biggest slots; `tags` lists a template under more categories, so a themed motion template also shows under Party, Beach, Love, Date night and so on), including free-form ones (tossed and tilted prints, piles, fans, a heart of photos, pinboard, magazine, film strip, bubbles, staircase) and ones that set a filter or a different frame per photo (`filter`, `cellFrames`); add one by adding an entry. Previews are drawn by the real
renderer (`TemplatePreview`), with sample scenes on Home and the person's own pictures in the editor
(Layout / Slides → Templates). Picking one from Home starts a design with it and opens the photo picker; in the editor
it re-lays the pictures already there, and Undo brings the previous design back. A collage template keeps its slots as
pictures are added (extras wait in the tray); a carousel template keeps its style as the slide count changes.

**Motion templates** lead the Collage tab in their own row (category Motion, a sparkles badge on the card, which plays
the design itself), newest first: the 53 themed ones listed below come before the first 18 (Weekend, Neon nights, Before & after, Postcards, Spotlight, Trio, Split open, Photo dump, Print drop,
Film reel, Weekend recap, Shuffle, Side by side, Staircase, Lookbook, Gallery wall, Pinboard and Heart of photos). The
themed ones: party (Party starter, Confetti pop, Dance floor, Disco fever, House party, Cheers), beach (Beach day,
Salt water, Sunset waves, Beach club, Island time, Surf club, Poolside), love (Love letter, Heartbeat, Only you, Forever
us, Rose petals, Then & now), date night (Date night, Dinner for two, Movie night, Coffee date, Under the stars, Picnic
date), birthday, friends, travel, wedding, baby, pets, food, fitness, graduation, holidays (Countdown, Christmas magic,
Spooky season, Festival of lights) and everyday (Outfit of the day, Summer dump, Day in my life). All 71 are free. On the first import into a new one, videos go into the first slots in selection order and the design
starts playing. Later imports and targeted replacements follow the normal editor
behavior. Reduce Motion keeps the sample cards and initial playback still.

**Motion templates** (`Model/Motion.swift`): a collage can carry a `Motion`, a list of scenes. Each scene has a layout,
the slot (cell) shown in each of its places, a length, a transition in (cut, fade, slide left/up, zoom), a slow photo
move (zoom in/out, drift, or sway, which rocks and bobs the whole picture like a print on water) and an optional
staggered entrance (pop, drop, rise, spin, slide in from the nearer side, slam down from big). A slot in two scenes in a row glides
and resizes between its places. `Project.posed(at:)` gives the design as it is at time *t* (cells moved, faded and
restacked through `MotionPose`, which `layout(for:)` uses); the preview (`store.shown`, posed at the playhead), every
export and the template cards draw that copy, so they match. Videos play through scene changes and repeat to fill the
design, whose length is the sum of its scenes. Captions with a `scene` show only during that scene and fade with it.
The last scene of a template shows every picture (the design's still look in cards and drafts).

**Editing scenes** (`UI/MotionPanel.swift`, actions in `Model/MotionEditing.swift`): in a motion design the Layout
tab becomes the scene editor. A strip of scenes (tap one to jump to it, + adds a copy after it), the scene on screen
with move earlier / later and delete, and a More menu (Slower, Faster, Templates, Make it still). Below, the scene's
Layout (layouts for its number of pictures), Pictures (tap to show or hide a picture in this scene; numbers are their
places), Transition (in, plus how new pictures arrive) and Timing (length 0.5–10 s, photo move). The scene being
edited is always the one at the playhead. Up to 12 scenes, 60 s in all. A still collage gets motion from the sparkles
button in the Layout tab. Pictures added to a motion design join its last scene; removed ones leave every scene.
The play bar marks where each scene begins. `CM_START_TEMPLATE=motion-spotlight`, `CM_SEEK=3` pauses the preview at a
moment (and logs each cell's place).

## Frames, captions and photo looks

**Frames** (`PhotoFrame` in `Model/Types.swift`, drawing in `Model/Frames.swift`): None, Border, Instant, Film (35 mm
strip with sprocket holes), Tape (washi tape over the corners), Stamp (perforated edge), Gallery (wide mat with an inner
line), Torn, Shadow, Date (orange camera date stamp), Neon (a glowing line in the frame colour), and the shapes Circle,
Heart and Arch. Style → Frame sets one frame for every picture; picture tools → Frame gives one picture its own
(`CellState.frame`, nil = same as all). Photos on top take the same frames. Edge thickness per side comes from
`PhotoFrame.edgeFactors`; the extras are drawn by `FrameDecor` (under the picture: film holes; over it: tape, mat line,
date, neon) and shapes by `pictureClipPath`. The live preview runs the very same Core Graphics code through a SwiftUI
`Canvas` (`UI/FrameViews.swift`), and it clips the design at its edges like an export.

**Captions** also come in Neon, Sticker and Gradient looks (`CaptionLook`), stacked **vertical** letters
(`Caption.vertical`, a formatting toggle), and six more lettering styles that ship with iOS (Romance, Retro, Note,
Magazine, Engraved, Slab), so nothing is downloaded or bundled for them.

**Photo looks** (`Model/PhotoLook.swift`): picture tools → Look gives a photo a filter (Original, Vivid, Warm, Cool, Fade,
Film, Chrome, Vintage, Mono, Noir; each swatch shows the photo itself) and Light / Contrast / Colour / Warmth. One
Core Image renderer (`PhotoLookRenderer`, cached) feeds the preview, the crop screen and every export. Photos only;
videos play as they are.

## Carousel mode

The Collage | Carousel switch in the top bar changes what you are making. A carousel is one wide design, `slides` Instagram
slides side by side (4:5 or square, 2 to 20 slides, up to 20 photos, photos only), with pictures laid out so they cross the
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
| `Media/` | Import and validation, live playback engine (one `AVPlayer` per video kept in step with the timeline), small preview copies of big or HDR videos (`PreviewCopies`: 720p SDR, made in the background; exports use the originals) |
| `Export/` | Metal-backed Core Image video composer, Core Graphics still and fallback renderer, per-clip reader, audio mix, MP4 writer |
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
| `CM_START_TEMPLATE=id` | Applies a template before `CM_BATCH` and logs slot order and playback |
| `CM_TEMPLATE_FRAMES=dir`, `CM_TEMPLATE_IDS=a,b` | Draws every motion template (or those ids) as a strip of key moments, `dir/<id>.png`, with the loaded photos or sample scenes |
| `CM_LAYOUT=n`, `CM_SIZES=0.6,0.4` | Number of cells; moves the first borders as if dragged |
| `CM_TAB=layout`, `CM_SELECT=i`, `CM_CROP=i`, `CM_PART=1` | Opens a tab, selects a cell, opens crop or Choose part |
| `CM_CAPTIONS=1` | Adds sample captions |
| `CM_EXPORT=video\|png\|ultra`, `CM_OUT=/path` | Exports without the UI |
| `CM_EXPORT_ENGINE=cpu\|gpu` | Chooses a video export engine for comparison |
| `CM_EXPORT_VERIFY_TIMESTAMPS=1` | Checks the GPU reader's selected timestamps against the CPU reader |
| `CM_EXPORT_FORCE_GPU_FAILURE=1` / `=late` | Fails every GPU frame (CPU fallback before the first frame), or from 0.5 s in (the whole video is made again with the CPU) |
| `CM_FIT=i`, `CM_ROTATE=i`, `CM_FLIP=i`, `CM_ANGLE=i:deg` | Applies fit with blurred bars, a 90° turn, a flip, or straightening to the indexed cell |
| `CM_PRO=1` / `CM_PRO=0` | Forces Pro on (no ads, no consent or tracking prompt) or off |
| `CM_PAYWALL=1`, `CM_PRO_MOCK=1` | Opens the Pro page; shows it with placeholder plans |
| `CM_CONSENT_EEA=1`, `CM_LIVE_ADS=1` | Tests the EU consent form; uses the live ad units (don't tap them) |

If the simulator shows "Apple Account Verification" (StoreKit asking for the sandbox account), tap Not Now.

### Verify video export engines

Video export composes decoded frames with Metal-backed Core Image. It reuses Core Graphics artwork for print
frames, shadows, fit bars, captions and other static elements. If GPU setup or the first render fails, video
export retries that frame with the Core Graphics renderer. PNG and carousel JPEG export use Core Graphics.

Install a Debug build on a booted simulator, then run the comparison with FFmpeg and FFprobe installed.

```bash
SIM_UDID=<device-udid> ios/scripts/compare_export_engines.sh compare
SIM_UDID=<device-udid> ios/scripts/compare_export_engines.sh compare '^(rounded|4k60-heavy|hdr)$'
```

The script writes each engine's resolution, frame rate, time, sampled process footprint and SSIM to
`ios/docs/gpu-export-results.md`. Set `CM_COMPARE_REPORT` to write to another file or `CM_COMPARE_DIR` to retain
artifacts elsewhere. The `baseline` mode records CPU outputs for `cpu-parity`, which compares against them after
a renderer refactor. Use `against-baseline` to compare GPU output with those same saved CPU files.
`CM_EXPORT` lines in the simulator log identify the engine that actually produced the file.

## Localization

The native app uses Apple's string catalogs: `CollageMagik/CollageMagik/Localizable.xcstrings` for the interface,
accessibility, model labels, editable template defaults and errors, and `InfoPlist.xcstrings` for the Photos and
tracking permission prompts. **English (U.S.), `en-US`, is the source and fallback language.** Language selection
follows iOS preferred languages, including the app-specific language in Settings; there is no separate in-app picker.
The existing StoreKit price formatting continues to use the App Store's currency and pricing information.

The catalogs contain all 50 requested locales:

- English (U.S., Australia, Canada, U.K.); Arabic; Bangla; Catalan; Chinese (Simplified and Traditional);
  Croatian; Czech; Danish; Dutch; Finnish; French (France and Canada); German; Greek; Gujarati; Hebrew;
  Hindi; Hungarian; Indonesian; Italian; Japanese; Kannada; Korean; Malay; Malayalam; Marathi;
  Norwegian Bokmål; Odia; Polish; Portuguese (Brazil and Portugal); Punjabi; Romanian; Russian;
  Slovak; Slovenian; Spanish (Mexico and Spain); Swedish; Tamil; Telugu; Thai; Turkish; Ukrainian;
  Urdu; Vietnamese.

**Translation status:** non-English translations are initial Google machine translation drafts, with count forms and
terminology corrections, and are marked `needs_review` in Xcode. They are functional in builds, but require native
speaker review before release, especially permission explanations, purchase terms, and regional French, Portuguese
and Spanish variants. No translation service is called at runtime. App Store listing text and screenshots are separate
from these app resources.

Interface controls mirror for Arabic, Hebrew and Urdu. The design canvas, crop preview, filmstrip, timeline and slide
navigation keep their physical left-to-right coordinates so gestures, slide order, playback and exported pixels agree.
Saved enum values, asset names, preference keys and file paths remain language independent. Existing user-written
captions are never translated. Template captions are localized defaults and stay as editable project content once used.
Library format labels are derived from saved dimensions so old exports also display in the current app language.

Use `String(localized: "…")` for user-facing strings constructed outside SwiftUI's literal localization APIs, including
strings passed into helper views or returned by model properties. Translate complete sentences instead of combining
English nouns and plural suffixes. Photo, video and slide counts use catalog plural variations.

Validate the catalogs:

```bash
python3 ios/scripts/validate-localizations.py
```

After adding text, build first, then synchronize the compiler's extracted strings (substitute your DerivedData path):

```bash
xcrun xcstringstool sync ios/CollageMagik/CollageMagik/Localizable.xcstrings \
  --stringsdata /path/to/CollageMagik.build/Objects-normal/arm64/*.stringsdata
python3 ios/scripts/validate-localizations.py \
  --extracted-dir /path/to/CollageMagik.build/Objects-normal/arm64
```

New keys must receive all locale values; keep generated translations marked for review until approved. Preserve
format argument types and positions (`%1$lld`, `%2$@`, etc.). Keep brands and technical notation marked
`shouldTranslate: false` when appropriate. The validator checks locale completeness, compiler-extracted coverage,
empty translations and format argument integrity, and reports how many translations still need review.

To inspect a simulator build in Arabic (use `en-US`, `hi`, `de`, `he`, `ur`, etc. for other languages):

```bash
SIMCTL_CHILD_CM_PRO=1 xcrun simctl launch booted com.axpo.collagemagik \
  -AppleLanguages '(ar)' -AppleLocale ar_SA -cm.tour.seen.v1 YES
```

Terminate the app between language runs. Check Home, the editor, long help and purchase text, and physical editing
coordinates on both iPhone and iPad. Launch without these arguments to return to the simulator's preferred language.
