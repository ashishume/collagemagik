# Google Ads creatives: Insta Collage

```
google-ads/
├── source/      Remotion project that makes every video and image (code, voiceover, music, app screenshots)
├── output/      Videos, one folder per version
│   ├── v1/
│   └── v2/  (current)
└── photos/      Images, one folder per version
    └── v1/
        ├── image-assets/     App, Demand Gen and Responsive Display images
        ├── display-banners/  Fixed-size Display image ads (all under 150 KB)
        └── logos/            Square 1:1 and landscape 4:1 logos
```

## v2 (13 Nov 2026), current

Videos only (`output/v2/`, same file names and specs as v1). Images are unchanged, use `photos/v1/`.

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

**Images** (`photos/v1/`), three creatives: `trip` (your whole trip, one post), `carousel` (carousels that flow),
`features` (photos, videos & captions).

| Folder | Sizes | Where |
|---|---|---|
| `image-assets/` | 1200x628 (1.91:1), 1200x1200 (1:1), 1200x1500 (4:5), 1080x1920 (9:16) | App, Demand Gen and Responsive Display campaigns. Each comes as `-text` and `-clean`; upload both and let Google pick. Clean ones are safer where Google limits text on images. |
| `display-banners/` | 300x250, 336x280, 728x90, 300x600, 320x50, 320x100, 468x60, 970x90, 970x250, 250x250, 200x200, 160x600, 300x1050 | Display campaigns, "Upload display ads". Each file is 150 KB or less. |
| `logos/` | 1200x1200 (1:1), 1200x300 (4:1) | Logo assets for Demand Gen and Responsive Display |

## Making a new version (v3, v4…)

From `source/`:

```bash
npm i                                   # first time only
npx remotion studio                     # preview and tweak in the browser
bash scripts/render-videos.sh v3        # videos into output/v3/
node scripts/render-photos.mjs v3       # images into photos/v3/
```

- New voiceover: replace `source/public/audio/voiceover.mp3`, then run `node scripts/transcribe.mjs` and
  `node scripts/merge-words.mjs`. Scenes are tied to spoken words (`cue("trim")` in `src/ad/`), so they follow the new
  timing. If a cue word is no longer said, the render stops with "Word ... not found", and you change that cue. Update
  `VOICE_FRAMES` in `src/ad/cues.ts` to the new length.
- Music level: `MUSIC_UNDER_VOICE` in `src/ad/Ad.tsx` (0.075 keeps the music ~13.5 LU under the voice).
- Which screen shows when, and what it highlights: `segments()` in `src/ad/scenes/AppPhone.tsx` (boxes are fractions
  of the screen: x, y, width, height).
- Image headlines: `THEMES` in `src/photos/AdImage.tsx`. Sizes: `src/photos/sizes.ts`.

## Credits and rights

- Voiceover: ElevenLabs (voice "Amy - Conversational Ad & Commercial").
- Music: `ikoliks_aj-fun-fun-music-614617.mp3`. Check its licence allows use in paid ads before running the campaign.
- App screens: real screenshots from `ios/AppStore/screenshots/raw/`. Trip "photos" are drawn in CSS, so there are no
  stock images to license.
