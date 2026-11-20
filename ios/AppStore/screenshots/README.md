# Collage Magic App Store screenshots

Ten portrait PNGs at **1320 × 2868 px** for the **6.9" iPhone** slot in App Store Connect
(upload the files in `png/` in filename order; `overview.jpg` is only a contact sheet).
The style follows the Figureout and Mindstrike sets: pastel field, two-line rounded headline, graphite phone frame.

| # | Poster | Raw capture | Shows |
|---|---|---|---|
| 1 | Photos + videos. One collage. | `raw/01-mix.png` | Two photos and two videos in one collage (tray shows the video badges) |
| 2 | Photos that flow. Slide to slide. | `raw/02-carousel.png` | Carousel in the Flow style, a picture crossing the slide seam |
| 3 | Portrait shot? Fit it whole. | `raw/03-fit.png` | New Resize tool: portrait photos fitted whole with blurred sides |
| 4 | Captions & stickers. | `raw/04-captions.png` | Captions in several looks, emoji and shape stickers, Text tab |
| 5 | Photo on photo. Framed. | `raw/05-on-top.png` | A photo laid on top in an instant frame, its tools open |
| 6 | Backgrounds that pop. | `raw/06-backgrounds.png` | Style tab, Background group, a gradient behind a wide gap |
| 7 | Drag a border. Resize any cell. | `raw/07-resize.png` | Layout tab, cells resized by dragging borders |
| 8 | Trim, split, change speed. | `raw/08-timeline.png` | Two clips on the timeline at 1.5x |
| 9 | Add a song underneath. | `raw/09-sound.png` | Sound panel with an imported song, volume and fade-out |
| 10 | Export in 4K at 60 fps. | `raw/10-export.png` | Export sheet with 4K and 60 fps selected |

**No ads in the screenshots.** Captures were taken with `SIMCTL_CHILD_CM_PRO=1` (debug builds treat the app as Pro, so no
banner, no full-screen ad, no consent or tracking prompt). If an "Apple Account Verification" alert appears in the
simulator (StoreKit asking for the sandbox account), tap Not Now before capturing.

The raw captures are real iPhone 17 Pro Max simulator screens (9:41 status bar, `xcrun simctl status_bar ... override`)
and are placed unmodified; no app UI is redrawn. The pictures are Unsplash travel photos (free for commercial use, no
identifiable people; credits in `google-ads/source/public/travel/credits.json`), loaded with `CM_AUTOLOAD`. The two
videos are slow pans made from those photos (`google-ads/source/assets-raw/app-media/`). Each screen is staged with
the debug hooks in `DebugHarness.swift` (for example `CM_FIT=blur CM_SELECT=0 CM_RESIZE=1` for screen 3,
`CM_TAB=style CM_STYLE_SECTION=background CM_BACKDROP=gradient:3 CM_GAP=30` for screen 6); export was set to 4K and
60 fps by tapping. Re-capture with `xcrun simctl io booted screenshot raw/NN-name.png`.

## Which size goes where

App Store Connect's **required** iPhone slot is "iPhone with Dynamic Island (medium display)", 6.1"/6.3", which takes
**1206 × 2622**. Those versions are in `png-6.3/` (made from `png/` by `source/export_63.py`) and are the set uploaded to
App Store Connect. The 1320 × 2868 set in `png/` is for the optional "large display" 6.9" slot (Media Manager).

## Rebuild the posters

```sh
python3 -m pip install pillow numpy
python3 AppStore/screenshots/source/render.py   # run from collagemagik-web/ios
```

Edit `source/screenshots.json` for copy, colours and source mapping. The renderer writes `png/`, `overview.jpg`
and `manifest.json` (dimensions, sRGB profile, hashes, and a check that the screen pixels are unchanged).
Exports are 8-bit RGB with an embedded sRGB profile and no alpha channel.
