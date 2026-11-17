# Ad creatives: CollageMagik

```
google-ads/
├── source/      Remotion project that makes every video and image (code, voiceover, music, app screenshots)
├── html5/       Animated HTML5 display ads, one folder per version (zips/ is what you upload)
├── output/      Videos, one folder per version
│   ├── v1/
│   ├── v2/
│   ├── v3/
│   ├── v4/
│   └── v5/  (current)
└── photos/      Images (v1 and v2 were deleted: they said "Insta Collage")
    └── v3/  (current)
        ├── image-assets/     App, Demand Gen and Responsive Display images
        ├── display-banners/  Fixed-size Display image ads (all under 150 KB)
        └── logos/            Square 1:1 and landscape 4:1 logos
```

## v5 HTML5 display ads (17 Nov 2026)

`html5/v5/zips/collagemagik-<size>.zip` for 300x250, 300x600 and 320x480, in the same format as the HTML5 ads Google
already accepted for another app: one `index.html` with inline CSS and CSS-only animation, `logo.png`, a `clickTag`
and `<meta name="ad.size">`. Six small Unsplash photos are included (each zip is about 107 KB; the limit is 150 KB).

Four scenes and an end card in about 13 seconds, then it stops: "Half photos, half videos?" (camera roll), "One
collage. Side by side." (MOVING / STILL), "Trim clips. Add a song." (a clip trimmed, the wind muted, a song added),
"Portrait shot? Fit it whole." (the new Resize tool fitting a photo with blurred sides), then "Photos + videos, one
collage." with "Free on the App Store". Scene 1 is complete on the first frame, and reduced-motion viewers see the
end card. The `clickTag` defaults to https://apps.apple.com/app/id6832640005 (Google Ads swaps in the ad's final URL).

- Build: `python3 scripts/build-html5-v5.py` from `source/` (uses macOS `sips` and `zip`; stops if a zip is over 150 KB).
- Preview: open `html5/v5/preview.html` (all three side by side); add `#t=8` to freeze them at 8 seconds.

## v5 videos: photos + videos in one collage (17 Nov 2026)

`output/v5/collagemagik-mix-ad-*.mp4` (vertical 9:16, square 1:1, landscape 16:9, about 47.7 s). The first ad that says
a collage can mix **photos and videos**. Voiceover: `source/voiceover-script-v5.md` (ElevenLabs, "Candy - Young and
Sweet"), audio `source/public/audio/voiceover-v5.mp3`. Same music and level as v4.

- Word timings: Whisper drifted up to a second on this voice, so `node scripts/align-v5.mjs` pins every phrase to the
  pauses ffmpeg found in the audio and writes `src/data/v5-words.json`. Re-run it (with new phrase times) if the voice
  is regenerated.
- Edit (`source/src/ad5/`): a camera roll lights up its photos and its playing videos; "two separate posts" crash
  together under a "Not anymore!" stamp; then a live editor (`Screen.tsx`) drops two photos and two videos into one
  collage, the clips play while the photos stay still (MOVING / STILL tags), a clip is trimmed and its moment chosen,
  the wind is muted and a song added, a portrait photo is shown cut off and then fitted whole with blurred sides (the
  new Resize tool), a caption is typed and a 60 fps video exported. It ends on Reels / Stories / TikTok frames, the
  collage with "= One collage", and the end card.
- Subtitles (`ad5/Captions.tsx`): pages pop in slightly zoomed and the spoken word grows about 16% and turns gold,
  making room for itself so it never touches its neighbours.
- Photos: the same Unsplash set as v3/v4 (`source/public/travel/credits.json`), no identifiable people.
- Render with `bash scripts/render-videos.sh v5 Ad5 collagemagik-mix-ad` from `source/`.

## v4 HTML5 display ads (15 Nov 2026)

`html5/v4/zips/collagemagik-editor-html5-<size>.zip`: animated banners for Display campaigns ("Upload display ads"), in
the same 13 sizes as the image banners. Each tells the v4 story in 10 seconds: a pile of trip photos drops into a
collage, a photo lands on top in an instant frame and twists straight (yellow guides and a 0° badge, as in the app), a
"golden hour" caption appears, and the headline goes "Back from your trip?" → "Make it a collage." → "Same trip. Way
better post." It plays twice (20 s, under Google's 30 s limit) and stops on the last frame, with the CTA ("Free on the
App Store", or "Get it free" where space is short) always on screen.

- Built by `python3 scripts/build-html5.py v4` from `source/` (needs ImageMagick and `zip`). Layout is worked out per
  size in that script; photos are cropped to each cell at 2x, so every zip is small (largest: 300x1050, about 116 KB;
  Google's limit is 150 KB). The script stops if any zip goes over.
- Each `index.html` has `<meta name="ad.size">` and a `clickTag` that Google Ads replaces with the ad's final URL on
  upload (the `apps.apple.com` link in the file is only a placeholder). No external files, fonts or scripts.
- Preview every size side by side: `python3 -m http.server 8765 --directory google-ads/html5/v4` from the repo root,
  then open `http://localhost:8765/preview.html`.
- Google Ads only accepts HTML5 uploads from accounts that meet its HTML5 policy (account history and spend). If the
  upload is refused, use the image banners in `photos/v3/display-banners/` instead.

## v4 videos: the editor ad (14 Nov 2026)

`output/v4/collagemagik-editor-ad-*.mp4` (vertical 9:16, square 1:1, landscape 16:9, about 42.5 s). Voiceover:
`source/voiceover-script-v4.md`, audio `source/public/audio/voiceover-v4.mp3`, word timings `source/src/data/v4-words.json`.

Instead of screenshots, the app is drawn live (`source/src/ad4/Editor.tsx`), so every gesture the voice names happens on
screen in time with the word: layouts morph, photos are dragged in from the tray, borders slide to resize, hold-and-drag
swaps two cells, a photo is dropped on top, gets an instant then torn-paper frame, is twisted and clicks straight (yellow
guides, as in the app), the caption flips fonts to a script, the slides of a carousel fly out of the phone, the design
changes size and exports in HD. The music sits about 5 dB louder than v3. Render with
`bash scripts/render-videos.sh v4 Ad4 collagemagik-editor-ad` from `source/`.

## Rename to CollageMagik (13 Nov 2026), photos v3 + videos v3 re-rendered

The app is now called **CollageMagik**, subtitle "Collage Maker & Editor" (Meta treats "Insta" as its brand term, so the old
name "Insta Collage" risks ad rejections). Use `photos/v3/` (all text and file names say CollageMagik).

The v3 videos were re-rendered as `output/v3/collagemagik-trip-ad-*.mp4`: same edit as v3, with a new voiceover that says
"CollageMagik" (`source/voiceover-script.md`), so every cue follows the new word timings. They run 42.5 s (the new voice
is 40.75 s). The `insta-collage-*` videos in `output/v1`-`v3` still say and show "Insta Collage": don't upload them
to Meta.

## v3 videos + v2 photos (13 Nov 2026)

Real travel photos everywhere, instead of drawn stand-ins:

- 33 photos from Unsplash (Santorini, Amalfi, Venice, the Maldives, Cappadocia balloons, Lofoten auroras, alpine
  lakes, road trips, food), in `source/public/travel/`. Scenery, food and places only, no identifiable people.
- They fill the camera roll, the photo-dump post, the tiles flying into the icon, the before/after pile, the end card
  and the trip tiles on the images.
- The app screens inside the phone were recaptured in the simulator with the same photos (`source/public/shots/`):
  Santorini carousel, tropical grid, an Italy collage with two travel videos on the timeline, the sunset video in
  Choose part, "Summer in Italy" captions and the Italy collage on the export screen. The two videos are slow pans
  made from photos (`source/assets-raw/app-media/`).
- Same edit, timing, music level (0.075) and specs as v2.

## v2 (13 Nov 2026)

Videos only (`output/v2/`, same file names and specs as v1). Images were unchanged from `photos/v1/`.

- App screens are always shown whole inside the phone. v1 zoomed in up to 2.3x, which cut screens off at the sides;
  v2 keeps the full screen and puts a glowing outline on the part the voice mentions (clip tracks on "trim", the
  filmstrip on "pick the exact moment", "Add music", the caption, the export preview).
- The small app preview in the intro shows full screens too.
- Background music a little louder: 0.075 gain, about 13.5 LU under the voice (v1: 0.05, about 17 LU).

## v1 (13 Nov 2026)

**Videos** (`output/v1/`), 42 s, 30 fps, H.264 + AAC, loudness normalised to -14 LUFS:

| File | Use it for |
|---|---|
| `insta-collage-trip-ad-vertical-9x16-1080x1920.mp4` | App campaigns, YouTube Shorts, Demand Gen, Instagram Reels / Stories |
| `insta-collage-trip-ad-landscape-16x9-1920x1080.mp4` | App campaigns, YouTube in-stream, Demand Gen |

Upload videos to YouTube (unlisted is fine) and add them to the campaign from there; Google Ads takes videos as
YouTube links.

The story: back from a trip with 400 photos, a 20-slide photo dump nobody swipes through, then Insta Collage. The app
badge and a peek of real app screens are on screen from the first second, before the voice names the app. Every
feature shot is timed to the word that mentions it (trim, pick the moment, add a song, caption, carousel, export).
Word-by-word captions are burned in for people watching on mute.

**Images** (`photos/v1/`, since deleted; `photos/v3/` has the same set as CollageMagik), three creatives: `trip` (your whole trip, one post), `carousel` (carousels that flow),
`features` (photos, videos & captions).

| Folder | Sizes | Where |
|---|---|---|
| `image-assets/` | 1200x628 (1.91:1), 1200x1200 (1:1), 1200x1500 (4:5), 1080x1920 (9:16) | App, Demand Gen and Responsive Display campaigns. Each comes as `-text` and `-clean`; upload both and let Google pick. Clean ones are safer where Google limits text on images. |
| `display-banners/` | 300x250, 336x280, 728x90, 300x600, 320x50, 320x100, 468x60, 970x90, 970x250, 250x250, 200x200, 160x600, 300x1050 | Display campaigns, "Upload display ads". Each file is 150 KB or less. |
| `logos/` | 1200x1200 (1:1), 1200x300 (4:1) | Logo assets for Demand Gen and Responsive Display |

## Making a new version (v4, v5…)

From `source/`:

```bash
npm i                                   # first time only
npx remotion studio                     # preview and tweak in the browser
bash scripts/render-videos.sh v4        # videos into output/v4/
node scripts/render-photos.mjs v3       # images into photos/v3/ (photo versions are numbered separately)
```

- New voiceover: replace `source/public/audio/voiceover.mp3`, then run `node scripts/transcribe.mjs` and
  `node scripts/merge-words.mjs`. Scenes are tied to spoken words (`cue("trim")` in `src/ad/`), so they follow the new
  timing. If a cue word is no longer said, the render stops with "Word ... not found", and you change that cue. Update
  `VOICE_FRAMES` in `src/ad/cues.ts` to the new length.
- Music level: `MUSIC_UNDER_VOICE` in `src/ad/Ad.tsx` (0.075 keeps the music ~13.5 LU under the voice).
- Which screen shows when, and what it highlights: `segments()` in `src/ad/scenes/AppPhone.tsx` (boxes are fractions
  of the screen: x, y, width, height).
- Image headlines: `THEMES` in `src/photos/AdImage.tsx`. Sizes: `src/photos/sizes.ts`.
- Photos: put JPEGs in `public/travel/` (and a 480 px copy in `public/travel/thumb/`), list them in `PHOTO_KINDS` in
  `src/ad/TripPhoto.tsx`, and add the photographer to `public/travel/credits.json`.
- App screens: build the app for the simulator (Debug), boot an iPhone 17 Pro Max simulator, then
  `bash scripts/capture-app-screens.sh <path to CollageMagik.app>`. It loads the photos into the app through the
  debug harness (`ios/.../DebugHarness.swift`, debug builds only) and saves `public/shots/01..07`. The export screen
  (`09-export.png`) needs taps: load four photos, tap the export button, Still (PNG), Export picture, then
  `xcrun simctl io booted screenshot public/shots/09-export.png`. Highlight boxes for each screen are in
  `segments()` in `src/ad/scenes/AppPhone.tsx`.

## Credits and rights

- Voiceover: ElevenLabs (voice "Amy - Conversational Ad & Commercial").
- Music: `ikoliks_aj-fun-fun-music-614617.mp3`. Check its licence allows use in paid ads before running the campaign.
- Photos: Unsplash, under the Unsplash License (free for commercial use including ads, no attribution required).
  Photographer and link for each file: `source/public/travel/credits.json`. Not allowed under that licence: selling the
  photos as they are, or implying a photographer endorses the app, so don't name them in ad copy.
- App screens: real simulator screenshots of the app (v3 onwards with the Unsplash photos; v1 and v2 used the drawn
  sample media from `ios/AppStore/screenshots/raw/`).
