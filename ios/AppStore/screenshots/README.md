# CollageMagik App Store screenshots

Ten portrait PNGs at **1320 × 2868 px** for the **6.9" iPhone** slot in App Store Connect
(upload the files in `png/` in filename order; `overview.jpg` is only a contact sheet).
The style follows the Figureout and Mindstrike sets: pastel field, two-line rounded headline, graphite phone frame.

| # | Poster | Raw capture | Shows |
|---|---|---|---|
| 1 | Photos that flow. Slide to slide. | `raw/01-carousel.png` | Carousel in the Flow style (the default), a picture crossing the slide seam |
| 2 | Swipe to see the rest. | `raw/02-carousel-next.png` | Same carousel scrolled to slide 2 |
| 3 | Drag a border. Resize any cell. | `raw/03-resize.png` | Layout tab, cells resized by dragging borders (new in 1.0.1) |
| 4 | 35 layouts. Your way. | `raw/04-layout.png` | Layout tab, 6 pictures |
| 5 | Collages that really move. | `raw/05-timeline.png` | Two videos on the timeline |
| 6 | Pick the perfect moment. | `raw/06-choose-part.png` | Choose part (new in 1.0.1) |
| 7 | Add words that pop. | `raw/07-captions.png` | Captions |
| 8 | Crop, rotate, straighten. | `raw/08-crop.png` | Crop editor |
| 9 | Export in high quality. | `raw/09-export.png` | "Your collage is ready" |
| 10 | Your work, kept private. | `raw/10-library.png` | My Library with three collages |

**No ads in the screenshots.** Captures 1-8 were taken with `SIMCTL_CHILD_CM_PRO=1` (debug builds treat the app as Pro, so no
banner, no full-screen ad, no consent or tracking prompt). 9 and 10 predate the ads. If an "Apple Account Verification" alert
appears in the simulator (StoreKit asking for the sandbox account), tap Not Now before capturing.

The raw captures are real iPhone 17 Pro Max simulator screens (9:41 status bar) and are placed unmodified;
no app UI is redrawn. The pictures and videos inside the collages are **procedurally drawn stand-ins**
(`source/make_media.py`), so nothing third-party is published. Swap in your own photos for a more
"real" look: pass them to the app via `SIMCTL_CHILD_CM_AUTOLOAD=a.jpg,b.jpg` (see `DebugHarness.swift`) and
re-capture with `xcrun simctl io booted screenshot raw/NN-name.png`.

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
