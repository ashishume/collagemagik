# CollageMagik App Store screenshots

Seven portrait PNGs at **1320 × 2868 px** for the **6.9" iPhone** slot in App Store Connect
(upload the files in `png/` in filename order; `overview.jpg` is only a contact sheet).
The style follows the Figureout and Mindstrike sets: pastel field, two-line rounded headline, graphite phone frame.

| # | Poster | Raw capture | Shows |
|---|---|---|---|
| 1 | Photos that flow. Slide to slide. | `raw/01-carousel.png` | Carousel, a picture crossing the slide seam |
| 2 | Swipe to see the rest. | `raw/02-carousel-next.png` | Same carousel scrolled to slide 2 |
| 3 | 35 layouts. Your way. | `raw/03-layout.png` | Layout tab |
| 4 | Collages that really move. | `raw/04-timeline.png` | Two videos on the timeline |
| 5 | Crop, rotate, straighten. | `raw/05-crop.png` | Crop editor |
| 6 | Export in high quality. | `raw/06-export.png` | "Your collage is ready" |
| 7 | Your work, kept private. | `raw/07-library.png` | My Library with three collages |

The raw captures are real iPhone 17 Pro Max simulator screens (9:41 status bar) and are placed unmodified;
no app UI is redrawn. The pictures and videos inside the collages are **procedurally drawn stand-ins**
(`source/make_media.py`), so nothing third-party is published. Swap in your own photos for a more
"real" look: pass them to the app via `SIMCTL_CHILD_CM_AUTOLOAD=a.jpg,b.jpg` (see `DebugHarness.swift`) and
re-capture with `xcrun simctl io booted screenshot raw/NN-name.png`.

## Which size goes where

App Store Connect's **required** iPhone slot is "iPhone with Dynamic Island (medium display)", 6.1"/6.3", which takes
**1206 × 2622**. Those versions are in `png-6.3/` (made from `png/` by `source/export_63.py`) and are the set uploaded to
the iOS 1.0 version. The 1320 × 2868 set in `png/` is for the optional "large display" 6.9" slot (Media Manager).

## Rebuild the posters

```sh
python3 -m pip install pillow numpy
python3 AppStore/screenshots/source/render.py   # run from collagemagik-web/ios
```

Edit `source/screenshots.json` for copy, colours and source mapping. The renderer writes `png/`, `overview.jpg`
and `manifest.json` (dimensions, sRGB profile, hashes, and a check that the screen pixels are unchanged).
Exports are 8-bit RGB with an embedded sRGB profile and no alpha channel.
